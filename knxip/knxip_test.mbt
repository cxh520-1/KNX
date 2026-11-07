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
