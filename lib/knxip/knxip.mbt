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
    0x0201 => "SEARCH_REQUEST"
    0x0202 => "SEARCH_RESPONSE"
    0x0203 => "DESCRIPTION_REQUEST"
    0x0205 => "CONNECT_REQUEST"
    0x0206 => "CONNECT_RESPONSE"
    0x0420 => "TUNNELLING_REQUEST"
    0x0421 => "TUNNELLING_ACK"
    0x0209 => "DISCONNECT_REQUEST"
    0x020A => "DISCONNECT_RESPONSE"
    0x0530 => "ROUTING_INDICATION"
    0x0532 => "ROUTING_BUSY"
    _ => "UNKNOWN"
  }
}

///|
fn copy(view : BytesView) -> Bytes {
  let out = Buffer()
  out.write_bytes(view)
  out.to_bytes()
}

///|
pub const SERVICE_SEARCH_REQUEST : Int = 0x0201

///|
pub const SERVICE_SEARCH_RESPONSE : Int = 0x0202

///|
pub const SERVICE_DESCRIPTION_REQUEST : Int = 0x0203

///|
pub const SERVICE_ROUTING_INDICATION : Int = 0x0530

///|
pub const SERVICE_ROUTING_BUSY : Int = 0x0532

///|
/// Device information block carried by a search response.
pub(all) struct DeviceInfo {
  medium : Int
  programming_mode : Bool
  address : @addrmodel.IndividualAddress
  project_number : Int
  installation_number : Int
  serial : Bytes
  multicast : (Int, Int, Int, Int)
  mac : Bytes
  name : String
} derive(Debug, Eq)

///|
pub fn DeviceInfo::encode(self : DeviceInfo) -> Bytes {
  let out = Buffer()
  out.write_byte(0x36)
  out.write_byte(0x01)
  out.write_byte(self.medium.to_byte())
  out.write_byte((if self.programming_mode { 1 } else { 0 }).to_byte())
  out.write_byte(((self.address.to_u16() >> 8) & 0xFF).to_byte())
  out.write_byte((self.address.to_u16() & 0xFF).to_byte())
  let id = self.project_number * 16 + self.installation_number
  out.write_byte(((id >> 8) & 0xFF).to_byte())
  out.write_byte((id & 0xFF).to_byte())
  out.write_bytes(self.serial.exact_view())
  out.write_byte(self.multicast.0.to_byte())
  out.write_byte(self.multicast.1.to_byte())
  out.write_byte(self.multicast.2.to_byte())
  out.write_byte(self.multicast.3.to_byte())
  out.write_bytes(self.mac.exact_view())
  let name = self.name
  for index in 0..<30 {
    if index < name.length() {
      out.write_byte(name.get_char(index).unwrap().to_int().to_byte())
    } else {
      out.write_byte(b'\x00')
    }
  }
  out.to_bytes()
}

///|
pub fn DeviceInfo::decode(data : BytesView) -> DeviceInfo raise KnxipError {
  if data.length() < 54 || data[0].to_int() != 0x36 || data[1].to_int() != 0x01 {
    raise BodyTooShort(data.length())
  }
  let id = (data[6].to_int() << 8) | data[7].to_int()
  let out = StringBuilder()
  for index in 24..<54 {
    let byte = data[index].to_int()
    if byte != 0 {
      out.write_char(Int::unsafe_to_char(byte))
    }
  }
  {
    medium: data[2].to_int(),
    programming_mode: data[3].to_int() != 0,
    address: @addrmodel.IndividualAddress::from_u16(
      (data[4].to_int() << 8) | data[5].to_int(),
    ),
    project_number: id >> 4,
    installation_number: id & 0x0F,
    serial: copy(data[8:14]),
    multicast: (
      data[14].to_int(),
      data[15].to_int(),
      data[16].to_int(),
      data[17].to_int(),
    ),
    mac: copy(data[18:24]),
    name: out.to_string(),
  }
}

///|
/// Build a discovery request. The body is the client endpoint.
pub fn search_request(discovery : Hpai) -> Bytes {
  packet(SERVICE_SEARCH_REQUEST, discovery.encode())
}

///|
/// Build a discovery answer with one device information block.
pub fn search_response(control : Hpai, info : DeviceInfo) -> Bytes {
  let body = Buffer()
  body.write_bytes(control.encode().exact_view())
  body.write_bytes(info.encode().exact_view())
  packet(SERVICE_SEARCH_RESPONSE, body.to_bytes())
}

///|
/// Build a description request, which returns the same blocks as a search.
pub fn description_request(control : Hpai) -> Bytes {
  packet(SERVICE_DESCRIPTION_REQUEST, control.encode())
}

///|
/// Build a routing indication: no tunnel header, the cEMI body follows the
/// KNX/IP header directly.
pub fn routing_indication(cemi : BytesView) -> Bytes {
  packet(SERVICE_ROUTING_INDICATION, copy(cemi))
}

///|
/// Build a routing busy frame.
pub fn routing_busy() -> Bytes {
  packet(SERVICE_ROUTING_BUSY, b"\x04\x00\x00\x00")
}

///|
pub const SERVICE_DEVICE_CONFIGURATION_REQUEST : Int = 0x0310

///|
pub const SERVICE_DEVICE_CONFIGURATION_ACK : Int = 0x0311

///|
/// One service family and the version the device supports.
pub(all) struct ServiceFamily {
  id : Int
  version : Int
} derive(Debug, Eq)

///|
/// The supported-service-families block of a search response.
pub(all) struct ServiceFamilies {
  families : Array[ServiceFamily]
} derive(Debug, Eq)

///|
pub fn ServiceFamilies::encode(self : ServiceFamilies) -> Bytes {
  let length = 2 + self.families.length() * 2
  let out = Buffer()
  out.write_byte(length.to_byte())
  out.write_byte(0x02)
  for family in self.families {
    out.write_byte(family.id.to_byte())
    out.write_byte(family.version.to_byte())
  }
  out.to_bytes()
}

///|
pub fn ServiceFamilies::decode(
  data : BytesView,
) -> ServiceFamilies raise KnxipError {
  if data.length() < 2 || data[1].to_int() != 0x02 {
    raise BodyTooShort(data.length())
  }
  let length = data[0].to_int()
  if length > data.length() || length < 2 {
    raise BadLength(length, data.length())
  }
  let families : Array[ServiceFamily] = []
  let mut index = 2
  while index + 1 < length {
    families.push({
      id: data[index].to_int(),
      version: data[index + 1].to_int(),
    })
    index = index + 2
  }
  { families, }
}

///|
pub fn family_name(id : Int) -> String {
  match id {
    0x02 => "Core"
    0x03 => "Device Management"
    0x04 => "Tunnelling"
    0x05 => "Routing"
    0x06 => "Remote Logging"
    0x07 => "Remote Configuration"
    0x08 => "Object Server"
    0x09 => "Security"
    _ => "Unknown"
  }
}

///|
/// Build a discovery answer that also advertises service families.
pub fn search_response_with_families(
  control : Hpai,
  info : DeviceInfo,
  families : ServiceFamilies,
) -> Bytes {
  let body = Buffer()
  body.write_bytes(control.encode().exact_view())
  body.write_bytes(info.encode().exact_view())
  body.write_bytes(families.encode().exact_view())
  packet(SERVICE_SEARCH_RESPONSE, body.to_bytes())
}

///|
/// Build a device configuration request, which carries a cEMI body like a
/// tunnelling request but is used for management instead of group traffic.
pub fn device_configuration_request(
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
  packet(SERVICE_DEVICE_CONFIGURATION_REQUEST, body.to_bytes())
}

///|
pub fn device_configuration_ack(
  channel : Int,
  sequence : Int,
  status : Int,
) -> Bytes {
  let body = Buffer()
  body.write_byte(0x04)
  body.write_byte(channel.to_byte())
  body.write_byte(sequence.to_byte())
  body.write_byte(status.to_byte())
  packet(SERVICE_DEVICE_CONFIGURATION_ACK, body.to_bytes())
}

///|
pub const SERVICE_DESCRIPTION_RESPONSE : Int = 0x0204

///|
pub const SERVICE_ROUTING_LOST_MESSAGE : Int = 0x0531

///|
/// Build a description response, which carries the same device block as a
/// search response.
pub fn description_response(control : Hpai, info : DeviceInfo) -> Bytes {
  let body = Buffer()
  body.write_bytes(control.encode().exact_view())
  body.write_bytes(info.encode().exact_view())
  packet(SERVICE_DESCRIPTION_RESPONSE, body.to_bytes())
}

///|
/// Build a routing lost message: the sender could not deliver a frame.
pub fn routing_lost_message() -> Bytes {
  packet(SERVICE_ROUTING_LOST_MESSAGE, b"\x04\x00\x00\x00")
}

///|
/// Fields of a connect response body.
pub(all) struct ConnectResponseInfo {
  channel : Int
  status : Int
} derive(Debug, Eq)

///|
pub fn parse_connect_response(
  body : BytesView,
) -> ConnectResponseInfo raise KnxipError {
  if body.length() < 2 {
    raise BodyTooShort(body.length())
  }
  { channel: body[0].to_int(), status: body[1].to_int(), }
}

///|
/// Channel, sequence and status shared by the tunnelling and device
/// management bodies.
pub(all) struct TunnelHeader {
  channel : Int
  sequence : Int
  status : Int
} derive(Debug, Eq)

///|
pub fn parse_tunnel_header(body : BytesView) -> TunnelHeader raise KnxipError {
  if body.length() < 4 || body[0].to_int() != 0x04 {
    raise BodyTooShort(body.length())
  }
  {
    channel: body[1].to_int(),
    sequence: body[2].to_int(),
    status: body[3].to_int(),
  }
}

///|
/// A search response decomposed into its endpoint and device block.
pub(all) struct SearchAnswer {
  endpoint : Hpai
  info : DeviceInfo
} derive(Debug, Eq)

///|
pub fn parse_search_response(body : BytesView) -> SearchAnswer raise KnxipError {
  if body.length() < 62 {
    raise BodyTooShort(body.length())
  }
  {
    endpoint: Hpai::decode(body[0:8]),
    info: DeviceInfo::decode(body[8:body.length()]),
  }
}

///|
/// Build a disconnect request for an open channel.
pub fn disconnect_request(channel : Int, control : Hpai) -> Bytes {
  let body = Buffer()
  body.write_byte(channel.to_byte())
  body.write_byte(0x00)
  body.write_bytes(control.encode().exact_view())
  packet(SERVICE_DISCONNECT_REQUEST, body.to_bytes())
}

///|
/// Build the acknowledgement for a disconnect request.
pub fn disconnect_response(channel : Int, status : Int) -> Bytes {
  let body = Buffer()
  body.write_byte(channel.to_byte())
  body.write_byte(status.to_byte())
  packet(SERVICE_DISCONNECT_RESPONSE, body.to_bytes())
}
