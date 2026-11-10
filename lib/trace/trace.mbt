// One line of human-readable KNX/IP. The monitor does not change state; it
// only explains what a frame contains, which is what a commissioning tool
// prints while a bus is live.

///|
pub fn describe(frame : BytesView) -> String {
  let packet = @knxip.parse(frame) catch { _ => return "invalid KNX/IP frame" }
  let name = @knxip.service_name(packet.service)
  let mut text = name
  if packet.service == @knxip.SERVICE_CONNECT_RESPONSE {
    let info = @knxip.parse_connect_response(packet.body.exact_view()) catch {
      _ => return text + " (bad body)"
    }
    text = text +
      " channel=" +
      info.channel.to_string() +
      " status=" +
      info.status.to_string()
  } else if packet.service == @knxip.SERVICE_TUNNELLING_ACK ||
    packet.service == @knxip.SERVICE_DEVICE_CONFIGURATION_ACK {
    let header = @knxip.parse_tunnel_header(packet.body.exact_view()) catch {
      _ => return text + " (bad body)"
    }
    text = text +
      " channel=" +
      header.channel.to_string() +
      " seq=" +
      header.sequence.to_string() +
      " status=" +
      header.status.to_string()
  } else if packet.service == @knxip.SERVICE_TUNNELLING_REQUEST ||
    packet.service == @knxip.SERVICE_DEVICE_CONFIGURATION_REQUEST {
    let header = @knxip.parse_tunnel_header(packet.body.exact_view()) catch {
      _ => return text + " (bad body)"
    }
    text = text +
      " channel=" +
      header.channel.to_string() +
      " seq=" +
      header.sequence.to_string()
    if packet.body.length() > 4 {
      text = text +
        " " +
        describe_cemi(packet.body.exact_view(start=4, end=packet.body.length()))
    }
  }
  text
}

///|
pub fn describe_cemi(data : BytesView) -> String {
  let message = @cemi.LData::decode(data) catch { _ => return "cemi(unparsed)" }
  let telegram = message.to_telegram()
  let mut text = "L_Data " + destination_text(telegram)
  let apci = @telegram.Apci::decode(telegram.tpdu.exact_view()) catch {
    _ => return text + " tpdu=" + hex(telegram.tpdu)
  }
  text = text + " " + service_text(apci)
  match apci.value {
    @telegram.Short(value) => text + " value=" + value.to_string()
    @telegram.Long(payload) => text + " payload=" + hex(payload)
  }
}

///|
fn destination_text(telegram : @telegram.Telegram) -> String {
  match telegram.destination {
    @telegram.Group(address) => address.to_text() + " (group)"
    @telegram.Individual(address) => address.to_text()
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
fn hex(data : Bytes) -> String {
  let out = StringBuilder()
  for index in 0..<data.length() {
    let value = data[index].to_int()
    out.write_char(digit(value >> 4))
    out.write_char(digit(value & 0x0F))
  }
  out.to_string()
}

///|
fn digit(value : Int) -> Char {
  Int::unsafe_to_char(if value < 10 { value + 48 } else { value + 55 })
}

///|
/// Describe a frame and append the raw body, which is what a monitor prints
/// when a user wants both the meaning and the bytes.
pub fn describe_verbose(frame : BytesView) -> String {
  let text = describe(frame)
  let packet = @knxip.parse(frame) catch { _ => return text }
  text + " body=" + hex(packet.body)
}

///|
/// Describe several frames, one per line, with an index so a capture can be
/// read in order.
pub fn describe_capture(frames : Array[Bytes]) -> String {
  let mut out = ""
  for index in 0..<frames.length() {
    out = out +
      "#" +
      (index + 1).to_string() +
      " " +
      describe(frames[index].exact_view()) +
      "\n"
  }
  out
}
