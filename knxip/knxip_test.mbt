// KNX/IP tests check the header arithmetic and the body lengths, because an
// off-by-one in the total length is the first thing a gateway rejects.

///|
test "connect request has a 26 byte frame" {
  let frame = connect_request(
    Hpai::new(192, 168, 1, 10, 3671),
    Hpai::new(192, 168, 1, 10, 3672),
  )
  assert_eq(
    hex_of(frame),
    "06100205001A0801C0A8010A0E570801C0A8010A0E5804040200",
  )
  let parsed = parse(frame.exact_view())
  assert_eq(parsed.service, SERVICE_CONNECT_REQUEST)
  assert_eq(parsed.body.length(), 20)
}

///|
test "connect response assigns a channel" {
  let frame = connect_response(1, Hpai::new(192, 168, 1, 10, 3671))
  let parsed = parse(frame.exact_view())
  assert_eq(parsed.service, SERVICE_CONNECT_RESPONSE)
  assert_eq(parsed.body[0].to_int(), 1)
}

///|
test "tunnelling request carries a cemi body" {
  let frame = tunnelling_request(1, 7, b"\x11\x00")
  let parsed = parse(frame.exact_view())
  assert_eq(parsed.service, SERVICE_TUNNELLING_REQUEST)
  assert_eq(parsed.body.length(), 6)
  assert_eq(service_name(parsed.service), "TUNNELLING_REQUEST")
}

///|
test "tunnelling ack is four bytes" {
  let frame = tunnelling_ack(1, 7, 0)
  let parsed = parse(frame.exact_view())
  assert_eq(parsed.body.length(), 4)
  assert_eq(parsed.body[2].to_int(), 7)
}

///|
test "bad header is rejected" {
  let caught = try {
    ignore(parse(b"\x07\x10\x02\x05\x00\x06".exact_view()))
    false
  } catch {
    KnxipError::BadHeader(_) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "length mismatch is rejected" {
  let frame = tunnelling_ack(1, 7, 0)
  let caught = try {
    ignore(parse(frame.exact_view(start=0, end=frame.length() - 1)))
    false
  } catch {
    KnxipError::BadLength(_, _) => true
    _ => false
  }
  assert_true(caught)
}

///|
fn hex_of(data : Bytes) -> String {
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
test "search request is fourteen bytes" {
  let frame = search_request(Hpai::new(192, 168, 1, 10, 3671))
  assert_eq(hex_of(frame), "06100201000E0801C0A8010A0E57")
  assert_eq(service_name(parse(frame.exact_view()).service), "SEARCH_REQUEST")
}

///|
test "search response carries a device block" {
  let info : DeviceInfo = {
    medium: 0x02,
    programming_mode: false,
    address: @addrmodel.IndividualAddress::parse("1.1.0"),
    project_number: 1,
    installation_number: 0,
    serial: b"\x00\x01\x02\x03\x04\x05",
    multicast: (224, 0, 23, 12),
    mac: b"\x00\x11\x22\x33\x44\x55",
    name: "Gateway",
  }
  let frame = search_response(Hpai::new(192, 168, 1, 10, 3671), info)
  assert_eq(frame.length(), 68)
  let parsed = parse(frame.exact_view())
  assert_eq(parsed.service, SERVICE_SEARCH_RESPONSE)
  let decoded = DeviceInfo::decode(
    parsed.body.exact_view(start=8, end=parsed.body.length()),
  )
  assert_eq(decoded.name, "Gateway")
  assert_eq(decoded.address, info.address)
  assert_eq(decoded.serial, info.serial)
}

///|
test "routing indication carries a cemi body" {
  let frame = routing_indication(b"\x11\x00")
  let parsed = parse(frame.exact_view())
  assert_eq(parsed.service, SERVICE_ROUTING_INDICATION)
  assert_eq(parsed.body.length(), 2)
}

///|
test "routing busy is four bytes" {
  let parsed = parse(routing_busy().exact_view())
  assert_eq(parsed.service, SERVICE_ROUTING_BUSY)
  assert_eq(parsed.body.length(), 4)
}

///|
test "service families block lists ids and versions" {
  let families : ServiceFamilies = {
    families: [
      { id: 0x02, version: 1, },
      { id: 0x04, version: 2, },
      { id: 0x05, version: 1, },
    ],
  }
  let encoded = families.encode()
  assert_eq(hex_of(encoded), "0802020104020501")
  assert_eq(ServiceFamilies::decode(encoded.exact_view()), families)
  assert_eq(family_name(0x04), "Tunnelling")
}

///|
test "search response can advertise families" {
  let info : DeviceInfo = {
    medium: 0x02,
    programming_mode: false,
    address: @addrmodel.IndividualAddress::parse("1.1.0"),
    project_number: 0,
    installation_number: 0,
    serial: b"\x00\x00\x00\x00\x00\x00",
    multicast: (224, 0, 23, 12),
    mac: b"\x00\x00\x00\x00\x00\x00",
    name: "Gateway",
  }
  let families : ServiceFamilies = { families: [{ id: 0x04, version: 1, }], }
  let frame = search_response_with_families(
    Hpai::new(192, 168, 1, 10, 3671),
    info,
    families,
  )
  assert_eq(frame.length(), 72)
  assert_eq(parse(frame.exact_view()).service, SERVICE_SEARCH_RESPONSE)
}

///|
test "device configuration frames mirror tunnelling" {
  let request = device_configuration_request(1, 3, b"\x11\x00")
  let parsed = parse(request.exact_view())
  assert_eq(parsed.service, SERVICE_DEVICE_CONFIGURATION_REQUEST)
  assert_eq(parsed.body.length(), 6)
  let ack = device_configuration_ack(1, 3, 0)
  assert_eq(parse(ack.exact_view()).body.length(), 4)
}

///|
test "description response mirrors search" {
  let info : DeviceInfo = {
    medium: 0x02,
    programming_mode: false,
    address: @addrmodel.IndividualAddress::parse("1.1.0"),
    project_number: 0,
    installation_number: 0,
    serial: b"\x00\x00\x00\x00\x00\x00",
    multicast: (224, 0, 23, 12),
    mac: b"\x00\x00\x00\x00\x00\x00",
    name: "Gateway",
  }
  let frame = description_response(Hpai::new(192, 168, 1, 10, 3671), info)
  assert_eq(parse(frame.exact_view()).service, SERVICE_DESCRIPTION_RESPONSE)
  assert_eq(frame.length(), 68)
}

///|
test "routing lost message is four bytes" {
  let parsed = parse(routing_lost_message().exact_view())
  assert_eq(parsed.service, SERVICE_ROUTING_LOST_MESSAGE)
  assert_eq(parsed.body.length(), 4)
}

///|
test "connect response fields are extracted" {
  let info = parse_connect_response(b"\x07\x00")
  assert_eq(info.channel, 7)
  assert_eq(info.status, 0)
}

///|
test "tunnel header validates the structure byte" {
  let header = parse_tunnel_header(b"\x04\x03\x09\x00")
  assert_eq(header.channel, 3)
  assert_eq(header.sequence, 9)
  let caught = try {
    ignore(parse_tunnel_header(b"\x05\x03\x09\x00"))
    false
  } catch {
    KnxipError::BodyTooShort(_) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "search response decomposes into endpoint and device" {
  let info : DeviceInfo = {
    medium: 0x02,
    programming_mode: false,
    address: @addrmodel.IndividualAddress::parse("1.1.0"),
    project_number: 0,
    installation_number: 0,
    serial: b"\x00\x00\x00\x00\x00\x00",
    multicast: (224, 0, 23, 12),
    mac: b"\x00\x00\x00\x00\x00\x00",
    name: "Gateway",
  }
  let frame = search_response(Hpai::new(192, 168, 1, 10, 3671), info)
  let packet = parse(frame.exact_view())
  let answer = parse_search_response(packet.body.exact_view())
  assert_eq(answer.endpoint.port, 3671)
  assert_eq(answer.info.name, "Gateway")
}

///|
test "disconnect request carries the endpoint" {
  let frame = disconnect_request(7, Hpai::new(192, 168, 1, 10, 3671))
  assert_eq(frame.length(), 16)
  let parsed = parse(frame.exact_view())
  assert_eq(parsed.service, SERVICE_DISCONNECT_REQUEST)
  assert_eq(parsed.body[0].to_int(), 7)
}

///|
test "disconnect response is two bytes" {
  let frame = disconnect_response(7, 0)
  let parsed = parse(frame.exact_view())
  assert_eq(parsed.service, SERVICE_DISCONNECT_RESPONSE)
  assert_eq(parsed.body.length(), 2)
}
