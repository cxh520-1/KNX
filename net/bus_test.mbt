// Bus tests use two devices that share a group address, which is the smallest
// setup where a write has to reach more than one listener.

///|
fn lamp(
  area_line_device : String,
  group : String,
) -> @device.Device raise @addrmodel.AddressError {
  let device = @device.Device::new(
    @addrmodel.IndividualAddress::parse(area_line_device),
    "lamp",
  )
  device.add(
    @addrmodel.GroupAddress::parse(group),
    @datapoint.Dpt1,
    @datapoint.Bool(false),
  )
  device
}

///|
test "a write reaches every listener" {
  let bus = Bus::new()
  bus.attach(lamp("1.1.10", "2/2/2"))
  bus.attach(lamp("1.1.11", "2/2/2"))
  let group = @addrmodel.GroupAddress::parse("2/2/2")
  let answers = bus.write(
    @addrmodel.IndividualAddress::parse("1.1.1"),
    group,
    @datapoint.Dpt1,
    @datapoint.Bool(true),
  )
  assert_eq(answers.length(), 0)
  assert_eq(bus.trace.length(), 1)
  assert_eq(bus.devices[0].value(group), Some(@datapoint.Bool(true)))
  assert_eq(bus.devices[1].value(group), Some(@datapoint.Bool(true)))
}

///|
test "a read collects one answer per device" {
  let bus = Bus::new()
  bus.attach(lamp("1.1.12", "3/1/1"))
  bus.attach(lamp("1.1.13", "3/1/1"))
  let answers = bus.read(
    @addrmodel.IndividualAddress::parse("1.1.2"),
    @addrmodel.GroupAddress::parse("3/1/1"),
  )
  assert_eq(answers.length(), 2)
}

///|
test "a write to an unused group only leaves a trace" {
  let bus = Bus::new()
  bus.attach(lamp("1.1.14", "4/1/1"))
  let answers = bus.write(
    @addrmodel.IndividualAddress::parse("1.1.3"),
    @addrmodel.GroupAddress::parse("4/2/2"),
    @datapoint.Dpt1,
    @datapoint.Bool(true),
  )
  assert_eq(answers.length(), 0)
  assert_eq(bus.trace.length(), 1)
  assert_eq(bus.trace[0].service, "write")
}
