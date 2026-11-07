// `knx` is the companion binary: decode one frame, run the three-device demo,
// or dump the frames a demo produced.

///|
fn main {
  let args = @env.args()
  let command = if args.length() > 1 { args[1] } else { "demo" }
  match command {
    "decode" => decode(args)
    "demo" => demo()
    "frames" => frames()
    "soak" => soak(args)
    _ => usage()
  }
}

///|
fn usage() -> Unit {
  println("knx - KNX telegram toolkit")
  println("")
  println("  knx decode <hex>   decode a telegram or an FT1.2 frame")
  println("  knx demo           run the switch, lamp, dimmer and sensor demo")
  println("  knx frames         print the demo frames in FT1.2 form")
  println("  knx soak [n]       repeat the demo n times")
}

///|
fn demo() -> Unit {
  let bus = @net.Bus::new()
  let switch = @device.Device::new(ia("1.1.1"), "switch")
  let lamp = @device.Device::new(ia("1.1.10"), "lamp")
  lamp.add(ga("2/1/1"), @datapoint.Dpt1, @datapoint.Bool(false))
  let dimmer = @device.Device::new(ia("1.1.11"), "dimmer")
  dimmer.add(ga("2/1/2"), @datapoint.Dpt5, @datapoint.U8(0))
  let sensor = @device.Device::new(ia("1.1.12"), "sensor")
  sensor.add(ga("2/1/3"), @datapoint.Dpt9, @datapoint.F16(20.0))
  bus.attach(lamp)
  bus.attach(dimmer)
  bus.attach(sensor)
  println("KNX virtual bus, " + bus.device_count().to_string() + " devices")
  println("")
  ignore(
    bus.write(
      switch.address,
      ga("2/1/1"),
      @datapoint.Dpt1,
      @datapoint.Bool(true),
    ),
  )
  ignore(bus.read(switch.address, ga("2/1/1")))
  ignore(
    bus.write(switch.address, ga("2/1/2"), @datapoint.Dpt5, @datapoint.U8(80)),
  )
  ignore(
    bus.write(
      sensor.address,
      ga("2/1/3"),
      @datapoint.Dpt9,
      @datapoint.F16(21.5),
    ),
  )
  for entry in bus.trace {
    println(
      pad(entry.source.to_text(), 8) +
      " -> " +
      pad(entry.group.to_text(), 8) +
      pad(entry.service, 8) +
      entry.value,
    )
  }
  println("")
  println("lamp   2/1/1 = " + show_value(lamp.value(ga("2/1/1"))))
  println("dimmer 2/1/2 = " + show_value(dimmer.value(ga("2/1/2"))))
  println("sensor 2/1/3 = " + show_value(sensor.value(ga("2/1/3"))))
  println("")
  println("frames on the wire:")
  for frame in bus.frames {
    println("  " + spaced_hex(frame))
  }
}

///|
fn frames() -> Unit {
  let bus = @net.Bus::new()
  let switch = @device.Device::new(ia("1.1.1"), "switch")
  let lamp = @device.Device::new(ia("1.1.10"), "lamp")
  lamp.add(ga("2/1/1"), @datapoint.Dpt1, @datapoint.Bool(false))
  bus.attach(lamp)
  ignore(
    bus.write(
      switch.address,
      ga("2/1/1"),
      @datapoint.Dpt1,
      @datapoint.Bool(true),
    ),
  )
  for frame in bus.frames {
    println(spaced_hex(frame))
  }
}

///|
fn soak(args : Array[String]) -> Unit {
  let count = if args.length() > 2 {
    match parse_int(args[2]) {
      Some(value) => value
      None => 100
    }
  } else {
    100
  }
  let bus = @net.Bus::new()
  let switch = @device.Device::new(ia("1.1.1"), "switch")
  let lamp = @device.Device::new(ia("1.1.10"), "lamp")
  lamp.add(ga("2/1/1"), @datapoint.Dpt1, @datapoint.Bool(false))
  bus.attach(lamp)
  for index in 0..<count {
    ignore(
      bus.write(
        switch.address,
        ga("2/1/1"),
        @datapoint.Dpt1,
        @datapoint.Bool(index % 2 == 0),
      ),
    )
  }
  println(
    "writes=" + count.to_string() + " frames=" + bus.frames.length().to_string(),
  )
  println("last lamp state = " + show_value(lamp.value(ga("2/1/1"))))
}

///|
fn decode(args : Array[String]) -> Unit {
  if args.length() < 3 {
    println("usage: knx decode <hex>")
    return
  }
  let raw = bytes_of_hex(args[2])
  let telegram = match try_telegram(raw) {
    Some(telegram) => telegram
    None => {
      let inner = @busframe.unwrap(raw.exact_view()) catch {
        _ => {
          println("error: not a telegram and not an FT1.2 frame")
          return
        }
      }
      match try_telegram(inner) {
        Some(telegram) => telegram
        None => {
          println("error: frame body is not a telegram")
          return
        }
      }
    }
  }
  println("source      " + telegram.source.to_text())
  println("destination " + destination_text(telegram))
  let apci = @telegram.Apci::decode(telegram.tpdu.exact_view()) catch {
    _ => {
      println("tpdu        " + hex(telegram.tpdu) + " (not a group APCI)")
      return
    }
  }
  println("service     " + service_text(apci))
  match apci.value {
    @telegram.Short(value) => println("value       " + value.to_string())
    @telegram.Long(data) => println("payload     " + hex(data))
  }
}

///|
fn try_telegram(raw : Bytes) -> @telegram.Telegram? {
  Some(@telegram.Telegram::decode(raw.exact_view())) catch {
    _ => None
  }
}

///|
fn destination_text(telegram : @telegram.Telegram) -> String {
  match telegram.destination {
    @telegram.Individual(address) => address.to_text()
    @telegram.Group(address) => address.to_text() + " (group)"
  }
}

///|
fn service_text(apci : @telegram.Apci) -> String {
  match apci.service {
    @telegram.GroupRead => "GroupRead"
    @telegram.GroupResponse => "GroupResponse"
    @telegram.GroupWrite => "GroupWrite"
  }
}

///|
fn show_value(value : @datapoint.Value?) -> String {
  match value {
    None => "-"
    Some(value) => @net.value_text(value)
  }
}

///|
fn pad(text : String, width : Int) -> String {
  let mut out = text
  while out.length() < width {
    out = out + " "
  }
  out
}

///|
fn hex(data : Bytes) -> String {
  let out = StringBuilder()
  for index in 0..<data.length() {
    let value = data[index].to_int()
    out.write_char(nibble(value >> 4))
    out.write_char(nibble(value & 0x0F))
  }
  out.to_string()
}

///|
fn spaced_hex(data : Bytes) -> String {
  let out = StringBuilder()
  for index in 0..<data.length() {
    if index > 0 {
      out.write_char(' ')
    }
    let value = data[index].to_int()
    out.write_char(nibble(value >> 4))
    out.write_char(nibble(value & 0x0F))
  }
  out.to_string()
}

///|
fn nibble(value : Int) -> Char {
  Int::unsafe_to_char(if value < 10 { value + 48 } else { value + 55 })
}

///|
fn bytes_of_hex(text : String) -> Bytes {
  let out = Buffer()
  let mut high = -1
  for index in 0..<text.length() {
    let code = text.get_char(index).unwrap().to_int()
    let value = if code >= 48 && code <= 57 {
      code - 48
    } else if code >= 65 && code <= 70 {
      code - 55
    } else if code >= 97 && code <= 102 {
      code - 87
    } else {
      -1
    }
    if value < 0 {
      continue
    }
    if high < 0 {
      high = value
    } else {
      out.write_byte(((high << 4) | value).to_byte())
      high = -1
    }
  }
  out.to_bytes()
}

///|
fn parse_int(text : String) -> Int? {
  let mut value = 0
  let mut seen = false
  for index in 0..<text.length() {
    let code = text.get_char(index).unwrap().to_int()
    if code < 48 || code > 57 {
      return None
    }
    value = value * 10 + (code - 48)
    seen = true
  }
  if seen {
    Some(value)
  } else {
    None
  }
}

///|
fn ia(text : String) -> @addrmodel.IndividualAddress {
  @addrmodel.IndividualAddress::parse(text) catch {
    _ => @addrmodel.IndividualAddress::from_u16(0)
  }
}

///|
fn ga(text : String) -> @addrmodel.GroupAddress {
  @addrmodel.GroupAddress::parse(text) catch {
    _ => @addrmodel.GroupAddress::from_u16(0)
  }
}
