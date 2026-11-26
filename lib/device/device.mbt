// A device is a physical address plus a small table of group objects. Each
// object binds a group address to a data point type and a current value, which
// is exactly what a real actuator keeps: the bus writes the object, the
// application reads it.

///|
/// One function exposed by a device.
pub(all) struct GroupObject {
  address : @addrmodel.GroupAddress
  dpt : @datapoint.Dpt
  mut value : @datapoint.Value
} derive(Debug, Eq)

///|
/// A device on the bus.
pub(all) struct Device {
  mut address : @addrmodel.IndividualAddress
  name : String
  objects : Array[GroupObject]
  mut programming : Bool
  descriptor : Int
} derive(Debug, Eq)

///|
/// The factory-fresh address: a device that has not been commissioned yet.
pub const UNASSIGNED_ADDRESS : Int = 0xFFFF

///|
/// A TP1 system-B device descriptor (`0x0002`).
pub const DESCRIPTOR_TP1 : Int = 0x0002

///|
/// Create a device in its factory state: unassigned address and programming
/// mode on, so a commissioning tool can program it.
pub fn Device::new(
  address : @addrmodel.IndividualAddress,
  name : String,
) -> Device {
  {
    address,
    name,
    objects: [],
    programming: false,
    descriptor: DESCRIPTOR_TP1,
  }
}

///|
/// Create a factory-fresh device waiting to be programmed.
pub fn Device::fresh(name : String) -> Device {
  {
    address: @addrmodel.IndividualAddress::from_u16(UNASSIGNED_ADDRESS),
    name,
    objects: [],
    programming: true,
    descriptor: DESCRIPTOR_TP1,
  }
}

///|
pub fn Device::in_programming(self : Device) -> Bool {
  self.programming
}

///|
pub fn Device::set_programming(self : Device, enabled : Bool) -> Unit {
  self.programming = enabled
}

///|
pub fn Device::add(
  self : Device,
  address : @addrmodel.GroupAddress,
  dpt : @datapoint.Dpt,
  initial : @datapoint.Value,
) -> Unit {
  self.objects.push({ address, dpt, value: initial, })
}

///|
pub fn Device::find(
  self : Device,
  address : @addrmodel.GroupAddress,
) -> GroupObject? {
  let mut found : GroupObject? = None
  for object in self.objects {
    if object.address == address {
      found = Some(object)
    }
  }
  found
}

///|
pub fn Device::value(
  self : Device,
  address : @addrmodel.GroupAddress,
) -> @datapoint.Value? {
  match self.find(address) {
    None => None
    Some(object) => Some(object.value)
  }
}

///|
/// Apply an inbound group telegram. A write updates a matching object and
/// produces nothing; a read produces the response telegram.
pub fn Device::apply(
  self : Device,
  telegram : @telegram.Telegram,
) -> @telegram.Telegram? {
  let group = match telegram.destination {
    @telegram.Group(address) => address
    @telegram.Individual(_) => return None
  }
  let object = match self.find(group) {
    None => return None
    Some(object) => object
  }
  let apci = match try_decode(telegram.tpdu) {
    None => return None
    Some(apci) => apci
  }
  match apci.service {
    @telegram.GroupWrite =>
      match value_of(object.dpt, apci) {
        None => None
        Some(value) => {
          object.value = value
          None
        }
      }
    @telegram.GroupRead =>
      match apci_for(object.dpt, object.value) {
        None => None
        Some(answer) => {
          let tpdu = match try_encode(answer) {
            None => return None
            Some(bytes) => bytes
          }
          Some(
            @telegram.Telegram::new(self.address, @telegram.Group(group), tpdu),
          )
        }
      }
    @telegram.GroupResponse => None
  }
}

///|
/// Handle a point-to-point management telegram. An individual-address write
/// programs the device when it is in programming mode; a read answers with the
/// current address or descriptor.
pub fn Device::commission(
  self : Device,
  telegram : @telegram.Telegram,
) -> @telegram.Telegram? {
  match telegram.destination {
    @telegram.Group(_) => return None
    @telegram.Individual(_) => ()
  }
  let mgmt = match try_decode_mgmt(telegram.tpdu) {
    None => return None
    Some(mgmt) => mgmt
  }
  match mgmt {
    @telegram.IndividualAddressWrite(address) => {
      if self.programming {
        self.address = address
        self.programming = false
      }
      None
    }
    @telegram.IndividualAddressRead => {
      let tpdu = @telegram.Mgmt::individual_address_response(self.address).encode() catch {
        _ => return None
      }
      Some(
        @telegram.Telegram::new(
          self.address,
          @telegram.Individual(telegram.source),
          tpdu,
        ),
      )
    }
    @telegram.DeviceDescriptorRead => {
      let tpdu = @telegram.Mgmt::device_descriptor_response(self.descriptor).encode() catch {
        _ => return None
      }
      Some(
        @telegram.Telegram::new(
          self.address,
          @telegram.Individual(telegram.source),
          tpdu,
        ),
      )
    }
    _ => None
  }
}

///|
fn try_decode(tpdu : Bytes) -> @telegram.Apci? {
  Some(@telegram.Apci::decode(tpdu.exact_view())) catch {
    _ => None
  }
}

///|
fn try_decode_mgmt(tpdu : Bytes) -> @telegram.Mgmt? {
  Some(@telegram.Mgmt::decode(tpdu.exact_view())) catch {
    _ => None
  }
}

///|
fn try_encode(apci : @telegram.Apci) -> Bytes? {
  Some(apci.encode()) catch {
    _ => None
  }
}

///|
fn value_of(dpt : @datapoint.Dpt, apci : @telegram.Apci) -> @datapoint.Value? {
  match dpt {
    @datapoint.Dpt1 =>
      match apci.value {
        @telegram.Short(number) => Some(@datapoint.Bool(number != 0))
        @telegram.Long(_) => None
      }
    _ =>
      match apci.value {
        @telegram.Short(_) => None
        @telegram.Long(data) => {
          let decoded = Some(@datapoint.decode(dpt, data.exact_view())) catch {
            _ => None
          }
          decoded
        }
      }
  }
}

///|
fn apci_for(dpt : @datapoint.Dpt, value : @datapoint.Value) -> @telegram.Apci? {
  match dpt {
    @datapoint.Dpt1 =>
      match value {
        @datapoint.Bool(flag) => {
          let answer = Some(
            @telegram.Apci::response_short(if flag { 1 } else { 0 }),
          ) catch {
            _ => None
          }
          answer
        }
        _ => None
      }
    _ => {
      let encoded = Some(@datapoint.encode(dpt, value)) catch { _ => None }
      match encoded {
        None => None
        Some(data) => {
          let answer = Some(@telegram.Apci::response_long(data)) catch {
            _ => None
          }
          answer
        }
      }
    }
  }
}
