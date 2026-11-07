// A virtual bus connects devices that share group addresses. It does not
// model electrical arbitration; it models what the application sees: a write
// reaches every device listening on the group, and a read collects one
// response per device that owns the object.

///|
/// One line of bus activity, kept for the demo and for tests.
pub(all) struct TraceEntry {
  source : @addrmodel.IndividualAddress
  group : @addrmodel.GroupAddress
  service : String
  value : String
} derive(Debug, Eq)

///|
pub(all) struct Bus {
  mut devices : Array[@device.Device]
  mut trace : Array[TraceEntry]
  mut frames : Array[Bytes]
} derive(Debug, Eq)

///|
pub fn Bus::new() -> Bus {
  { devices: [], trace: [], frames: [] }
}

///|
pub fn Bus::attach(self : Bus, device : @device.Device) -> Unit {
  self.devices.push(device)
}

///|
pub fn Bus::device_count(self : Bus) -> Int {
  self.devices.length()
}

///|
/// Broadcast a group write and return the response telegrams, if any.
pub fn Bus::write(
  self : Bus,
  source : @addrmodel.IndividualAddress,
  group : @addrmodel.GroupAddress,
  dpt : @datapoint.Dpt,
  value : @datapoint.Value,
) -> Array[@telegram.Telegram] {
  let apci = match write_apci(dpt, value) {
    None => return []
    Some(apci) => apci
  }
  let tpdu = apci.encode() catch {
    _ => return []
  }
  let telegram = @telegram.Telegram::new(source, @telegram.Group(group), tpdu)
  self.trace.push({
    source,
    group,
    service: "write",
    value: value_text(value),
  })
  self.frames.push(telegram.encode() catch {
    _ => b""
  })
  self.deliver(telegram)
}

///|
/// Broadcast a group read and collect the responses.
pub fn Bus::read(
  self : Bus,
  source : @addrmodel.IndividualAddress,
  group : @addrmodel.GroupAddress,
) -> Array[@telegram.Telegram] {
  let apci = @telegram.Apci::read()
  let telegram = @telegram.Telegram::new(
    source,
    @telegram.Group(group),
    apci.encode() catch {
      _ => b""
    },
  )
  self.trace.push({ source, group, service: "read", value: "" })
  self.frames.push(telegram.encode() catch {
    _ => b""
  })
  self.deliver(telegram)
}

///|
fn Bus::deliver(self : Bus, telegram : @telegram.Telegram) -> Array[@telegram.Telegram] {
  let answers : Array[@telegram.Telegram] = []
  for device in self.devices {
    match device.apply(telegram) {
      None => ()
      Some(answer) => {
        answers.push(answer)
        self.frames.push(answer.encode() catch {
          _ => b""
        })
      }
    }
  }
  answers
}

///|
/// Render a value for the trace without pulling in a full formatter.
pub fn value_text(value : @datapoint.Value) -> String {
  match value {
    @datapoint.Bool(flag) => if flag { "true" } else { "false" }
    @datapoint.U8(number) => number.to_string()
    @datapoint.I8(number) => number.to_string()
    @datapoint.U16(number) => number.to_string()
    @datapoint.I16(number) => number.to_string()
    @datapoint.F16(number) => number.to_string()
    @datapoint.Text(text) => text
  }
}

///|
fn write_apci(
  dpt : @datapoint.Dpt,
  value : @datapoint.Value,
) -> @telegram.Apci? {
  match dpt {
    @datapoint.Dpt1 =>
      match value {
        @datapoint.Bool(flag) => {
          let apci = try {
            Some(@telegram.Apci::write_short(if flag { 1 } else { 0 }))
          } catch {
            _ => None
          }
          apci
        }
        _ => None
      }
    _ => {
      let encoded = try {
        Some(@datapoint.encode(dpt, value))
      } catch {
        _ => None
      }
      match encoded {
        None => None
        Some(data) => {
          let apci = try {
            Some(@telegram.Apci::write_long(data))
          } catch {
            _ => None
          }
          apci
        }
      }
    }
  }
}
