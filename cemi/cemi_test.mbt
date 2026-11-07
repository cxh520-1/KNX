// cEMI tests pin the byte layout that sits between a telegram and a
// tunnelling request.

///|
test "group write encodes to cemi" {
  let telegram = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.1"),
    @telegram.Group(@addrmodel.GroupAddress::parse("2/1/1")),
    b"\x00\x81",
  )
  let cemi = LData::from_telegram(LDataRequest, telegram)
  let encoded = cemi.encode()
  assert_eq(hex_of(encoded), "1100BC8011011101810081")
  let back = LData::decode(encoded.exact_view())
  assert_eq(back.code, LDataRequest)
  assert_eq(back.control2, 0x80)
  assert_eq(back.to_telegram().destination, telegram.destination)
}

///|
test "indication and confirmation codes" {
  assert_eq(MessageCode::code(LDataIndication), 0x29)
  assert_eq(message_code(0x2E), Some(LDataConfirmation))
  assert_eq(message_code(0x99), None)
}

///|
test "bad cemi length is rejected" {
  let caught = try {
    ignore(LData::decode(b"\x11\x00\xBC\x80\x11\x01".exact_view()))
    false
  } catch {
    CemiError::TooShort(_) => true
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
