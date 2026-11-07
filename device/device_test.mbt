// Device tests drive it with real telegrams: a write changes the object, a
// read produces the answer the bus expects, and an unknown group is ignored
// rather than guessed at.

test "a write updates the object" {
  let device = Device::new(@addrmodel.IndividualAddress::parse("1.1.10"), "lamp")
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

test "a read produces a response with the current value" {
  let device = Device::new(@addrmodel.IndividualAddress::parse("1.1.11"), "lamp")
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

test "unknown group is ignored" {
  let device = Device::new(@addrmodel.IndividualAddress::parse("1.1.12"), "lamp")
  let write = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.22"),
    @telegram.Group(@addrmodel.GroupAddress::parse("9/2/9")),
    @telegram.Apci::write_short(1).encode(),
  )
  assert_true(device.apply(write) is None)
}
