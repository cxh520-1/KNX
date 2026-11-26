// Device tests drive it with real telegrams: a write changes the object, a
// read produces the answer the bus expects, and an unknown group is ignored
// rather than guessed at.

///|
test "a write updates the object" {
  let device = Device::new(
    @addrmodel.IndividualAddress::parse("1.1.10"),
    "lamp",
  )
  let group = @addrmodel.GroupAddress::parse("1/2/3")
  device.add(group, @datapoint.Dpt1, @datapoint.Bool(false))
  let write = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.20"),
    @telegram.Group(group),
    @telegram.Apci::write_short(1).encode(),
  )
  let answer = device.apply(write)
  assert_true(answer is None)
  assert_eq(device.value(group), Some(@datapoint.Bool(true)))
}

///|
test "a read produces a response with the current value" {
  let device = Device::new(
    @addrmodel.IndividualAddress::parse("1.1.11"),
    "lamp",
  )
  let group = @addrmodel.GroupAddress::parse("1/2/4")
  device.add(group, @datapoint.Dpt1, @datapoint.Bool(true))
  let read = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.21"),
    @telegram.Group(group),
    @telegram.Apci::read().encode(),
  )
  match device.apply(read) {
    None => fail("expected a response")
    Some(answer) => {
      assert_eq(answer.source, device.address)
      let apci = @telegram.Apci::decode(answer.tpdu.exact_view())
      assert_eq(apci.service, @telegram.GroupResponse)
      assert_eq(apci.group_write_value(), Some(1))
    }
  }
}

///|
test "unknown group is ignored" {
  let device = Device::new(
    @addrmodel.IndividualAddress::parse("1.1.12"),
    "lamp",
  )
  let write = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.22"),
    @telegram.Group(@addrmodel.GroupAddress::parse("9/2/9")),
    @telegram.Apci::write_short(1).encode(),
  )
  assert_true(device.apply(write) is None)
}

///|
test "a fresh device is programmed by an individual address write" {
  let device = Device::fresh("lamp")
  assert_true(device.in_programming())
  let target = @addrmodel.IndividualAddress::parse("1.1.10")
  let write = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.1"),
    @telegram.Individual(@addrmodel.IndividualAddress::parse("15.15.255")),
    @telegram.Mgmt::individual_address_write(target).encode(),
  )
  assert_true(device.commission(write) is None)
  assert_false(device.in_programming())
  assert_eq(device.address, target)
}

///|
test "an individual address read returns the device address" {
  let device = Device::new(
    @addrmodel.IndividualAddress::parse("1.1.10"),
    "lamp",
  )
  let read = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.1"),
    @telegram.Individual(device.address),
    @telegram.Mgmt::individual_address_read().encode(),
  )
  match device.commission(read) {
    None => fail("expected a response")
    Some(answer) => {
      assert_eq(
        answer.destination,
        @telegram.Individual(@addrmodel.IndividualAddress::parse("1.1.1")),
      )
      match @telegram.Mgmt::decode(answer.tpdu.exact_view()) {
        @telegram.IndividualAddressResponse(address) =>
          assert_eq(address, device.address)
        _ => fail("expected an individual address response")
      }
    }
  }
}

///|
test "a device descriptor read returns the descriptor" {
  let device = Device::new(
    @addrmodel.IndividualAddress::parse("1.1.10"),
    "lamp",
  )
  let read = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.1"),
    @telegram.Individual(device.address),
    @telegram.Mgmt::device_descriptor_read().encode(),
  )
  match device.commission(read) {
    None => fail("expected a response")
    Some(answer) =>
      match @telegram.Mgmt::decode(answer.tpdu.exact_view()) {
        @telegram.DeviceDescriptorResponse(descriptor) =>
          assert_eq(descriptor, DESCRIPTOR_TP1)
        _ => fail("expected a device descriptor response")
      }
  }
}

///|
test "a programmed device ignores another address write" {
  let device = Device::new(
    @addrmodel.IndividualAddress::parse("1.1.10"),
    "lamp",
  )
  let write = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.1"),
    @telegram.Individual(@addrmodel.IndividualAddress::parse("1.1.10")),
    @telegram.Mgmt::individual_address_write(
      @addrmodel.IndividualAddress::parse("1.1.20"),
    ).encode(),
  )
  assert_true(device.commission(write) is None)
  assert_eq(device.address, @addrmodel.IndividualAddress::parse("1.1.10"))
}
