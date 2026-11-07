// KNX/IP frames: a fixed six-byte header followed by a service-specific body.
// The library covers the services a tunnelling client needs on day one, and
// leaves the rest as raw bodies with a known service code.

///|
/// KNX/IP frame failures.
pub(all) suberror KnxipError {
  TooShort(Int)
  BadHeader(Int)
  BadProtocol(Int)
  BadLength(Int, Int)
  BodyTooShort(Int)
}

///|
pub const SERVICE_CONNECT_REQUEST : Int = 0x0205

///|
pub const SERVICE_CONNECT_RESPONSE : Int = 0x0206

///|
pub const SERVICE_TUNNELLING_REQUEST : Int = 0x0420

///|
pub const SERVICE_TUNNELLING_ACK : Int = 0x0421

///|
pub const SERVICE_DISCONNECT_REQUEST : Int = 0x0209

///|
pub const SERVICE_DISCONNECT_RESPONSE : Int = 0x020A

///|
/// Host protocol address information: an IP and a UDP port.
pub(all) struct Hpai {
  ip : (Int, Int, Int, Int)
  port : Int
} derive(Debug, Eq)

///|
pub fn Hpai::new(a : Int, b : Int, c : Int, d : Int, port : Int) -> Hpai {
  { ip: (a, b, c, d), port, }
}

///|
pub fn Hpai::encode(self : Hpai) -> Bytes {
  let out = Buffer()
  out.write_byte(0x08)
  out.write_byte(0x01)
  out.write_byte(self.ip.0.to_byte())
  out.write_byte(self.ip.1.to_byte())
  out.write_byte(self.ip.2.to_byte())
  out.write_byte(self.ip.3.to_byte())
  out.write_byte(((self.port >> 8) & 0xFF).to_byte())
  out.write_byte((self.port & 0xFF).to_byte())
  out.to_bytes()
}

///|
pub fn Hpai::decode(data : BytesView) -> Hpai raise KnxipError {
  if data.length() < 8 || data[0].to_int() != 0x08 {
    raise BodyTooShort(data.length())
  }
  {
    ip: (data[2].to_int(), data[3].to_int(), data[4].to_int(), data[5].to_int()),
    port: (data[6].to_int() << 8) | data[7].to_int(),
  }
}

///|
/// A decoded KNX/IP packet: the service code and the body that followed the
/// header, left raw so callers can pick the shape they expect.
pub(all) struct Packet {
  service : Int
  body : Bytes
} derive(Debug, Eq)

///|
/// Wrap a body in the six-byte header.
pub fn packet(service : Int, body : Bytes) -> Bytes {
  let total = 6 + body.length()
  let out = Buffer()
  out.write_byte(0x06)
  out.write_byte(0x10)
  out.write_byte(((service >> 8) & 0xFF).to_byte())
  out.write_byte((service & 0xFF).to_byte())
  out.write_byte(((total >> 8) & 0xFF).to_byte())
  out.write_byte((total & 0xFF).to_byte())
  out.write_bytes(body.exact_view())
  out.to_bytes()
}

///|
pub fn parse(data : BytesView) -> Packet raise KnxipError {
  if data.length() < 6 {
    raise TooShort(data.length())
  }
  if data[0].to_int() != 0x06 {
    raise BadHeader(data[0].to_int())
  }
  if data[1].to_int() != 0x10 {
    raise BadProtocol(data[1].to_int())
  }
  let service = (data[2].to_int() << 8) | data[3].to_int()
  let total = (data[4].to_int() << 8) | data[5].to_int()
  if total != data.length() {
    raise BadLength(total, data.length())
  }
  { service, body: copy(data[6:data.length()]), }
}

///|
/// Build a connect request for a tunnelling client.
pub fn connect_request(control : Hpai, data : Hpai) -> Bytes {
  let body = Buffer()
  body.write_bytes(control.encode().exact_view())
  body.write_bytes(data.encode().exact_view())
  body.write_byte(0x04)
  body.write_byte(0x04)
  body.write_byte(0x02)
  body.write_byte(0x00)
  packet(SERVICE_CONNECT_REQUEST, body.to_bytes())
}

///|
/// Build a connect response that assigns a channel.
pub fn connect_response(channel : Int, data : Hpai) -> Bytes {
  let body = Buffer()
  body.write_byte(channel.to_byte())
  body.write_byte(0x00)
  body.write_bytes(data.encode().exact_view())
  body.write_byte(0x04)
  body.write_byte(0x00)
  body.write_byte(0x00)
  body.write_byte(0x00)
  packet(SERVICE_CONNECT_RESPONSE, body.to_bytes())
}

///|
/// Build a tunnelling request carrying a cEMI message.
pub fn tunnelling_request(
  channel : Int,
  sequence : Int,
  cemi : BytesView,
) -> Bytes {
  let body = Buffer()
  body.write_byte(0x04)
  body.write_byte(channel.to_byte())
  body.write_byte(sequence.to_byte())
  body.write_byte(0x00)
  body.write_bytes(cemi)
  packet(SERVICE_TUNNELLING_REQUEST, body.to_bytes())
}

///|
/// Build the acknowledgement for a tunnelling request.
pub fn tunnelling_ack(channel : Int, sequence : Int, status : Int) -> Bytes {
  let body = Buffer()
  body.write_byte(0x04)
  body.write_byte(channel.to_byte())
  body.write_byte(sequence.to_byte())
  body.write_byte(status.to_byte())
  packet(SERVICE_TUNNELLING_ACK, body.to_bytes())
}

///|
pub fn service_name(service : Int) -> String {
  match service {
    0x0205 => "CONNECT_REQUEST"
    0x0206 => "CONNECT_RESPONSE"
    0x0420 => "TUNNELLING_REQUEST"
    0x0421 => "TUNNELLING_ACK"
    0x0209 => "DISCONNECT_REQUEST"
    0x020A => "DISCONNECT_RESPONSE"
    _ => "UNKNOWN"
  }
}

///|
fn copy(view : BytesView) -> Bytes {
  let out = Buffer()
  out.write_bytes(view)
  out.to_bytes()
}
