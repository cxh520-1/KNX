// Frame and APCI tests use literal bytes. The examples are the ones a group
// write and its response produce for a boolean data point, which is the
// smallest complete exchange on the bus.

///|
test "group write of true is two bytes" {
  let apci = Apci::write_short(1)
  assert_eq(hex_of(apci.encode()), "0081")
}

///|
test "group read is the zero word" {
  assert_eq(hex_of(Apci::read().encode()), "0000")
}

///|
test "group response decodes inline value" {
  let apci = Apci::decode(bytes_of_hex("0041"))
  assert_eq(apci.service, GroupResponse)
  assert_eq(apci.group_write_value(), Some(1))
}

///|
test "long write carries a length and a payload" {
  let apci = Apci::write_long(bytes_of_hex("0064"))
  let encoded = apci.encode()
  assert_eq(hex_of(encoded), "00820064")
  let back = Apci::decode(encoded.exact_view())
  assert_eq(back.service, GroupWrite)
  assert_eq(back.value, Long(bytes_of_hex("0064")))
}

///|
test "telegram round trips with group destination" {
  let source = @addrmodel.IndividualAddress::parse("1.1.1")
  let destination = @addrmodel.GroupAddress::parse("1/2/3")
  let apci = Apci::write_short(1)
  let telegram = Telegram::new(source, Group(destination), apci.encode())
  let encoded = telegram.encode()
  assert_eq(encoded.length(), 9)
  let back = Telegram::decode(encoded.exact_view())
  assert_eq(back.source, source)
  assert_eq(back.destination, Group(destination))
}

///|
test "checksum mismatch is reported" {
  let source = @addrmodel.IndividualAddress::parse("1.1.1")
  let destination = @addrmodel.GroupAddress::parse("1/2/3")
  let telegram = Telegram::new(
    source,
    Group(destination),
    Apci::read().encode(),
  )
  let encoded = telegram.encode()
  let corrupted = flip_last(encoded)
  let caught = try {
    ignore(Telegram::decode(corrupted.exact_view()))
    false
  } catch {
    TelegramError::BadChecksum(_, _) => true
    _ => false
  }
  assert_true(caught)
}

///|
fn flip_last(data : Bytes) -> Bytes {
  let out = Buffer()
  for index in 0..<data.length() {
    if index == data.length() - 1 {
      out.write_byte((data[index].to_int() + 1).to_byte())
    } else {
      out.write_byte(data[index])
    }
  }
  out.to_bytes()
}

///|
fn hex_of(data : Bytes) -> String {
  let out = StringBuilder()
  for index in 0..<data.length() {
    let value = data[index].to_int()
    out.write_char(hex_digit(value >> 4))
    out.write_char(hex_digit(value & 0x0F))
  }
  out.to_string()
}

///|
fn hex_digit(value : Int) -> Char {
  if value < 10 {
    Int::unsafe_to_char(value + 48)
  } else {
    Int::unsafe_to_char(value + 55)
  }
}

///|
fn bytes_of_hex(text : String) -> Bytes {
  let out = Buffer()
  let mut high = -1
  for index in 0..<text.length() {
    let value = digit(text.get_char(index).unwrap())
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
fn digit(ch : Char) -> Int {
  let code = ch.to_int()
  if code >= 48 && code <= 57 {
    code - 48
  } else if code >= 97 && code <= 102 {
    code - 87
  } else if code >= 65 && code <= 70 {
    code - 55
  } else {
    -1
  }
}

///|
test "long tpdu switches to the extended frame" {
  let source = @addrmodel.IndividualAddress::parse("1.1.1")
  let destination = @addrmodel.GroupAddress::parse("2/1/1")
  let payload = Buffer()
  for index in 0..<20 {
    payload.write_byte((index + 1).to_byte())
  }
  let telegram = Telegram::new(source, Group(destination), payload.to_bytes())
  let encoded = telegram.encode()
  assert_eq(encoded[0].to_int() & 0x80, 0)
  assert_eq(encoded.length(), 8 + 20)
  let back = Telegram::decode(encoded.exact_view())
  assert_eq(back.tpdu.length(), 20)
  assert_eq(back.destination, Group(destination))
}
