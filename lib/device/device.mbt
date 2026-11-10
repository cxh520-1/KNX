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
  address : @addrmodel.IndividualAddress
  name : String
  objects : Array[GroupObject]
} derive(Debug, Eq)

///|
pub fn Device::new(
  address : @addrmodel.IndividualAddress,
  name : String,
) -> Device {
  { address, name, objects: [], }
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
fn try_decode(tpdu : Bytes) -> @telegram.Apci? {
  Some(@telegram.Apci::decode(tpdu.exact_view())) catch {
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
