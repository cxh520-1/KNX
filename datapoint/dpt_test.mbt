// DPT tests use the encoded bytes where the representation is fixed, and
// round trips elsewhere. The 2-byte float is checked against 21.0, whose
// exponent must be 1 because the mantissa would otherwise not fit in eleven
// bits.

test "2-byte float encodes 21.0 as 0x0C1A" {
  let encoded = encode(Dpt9, F16(21.0))
  assert_eq(hex_of(encoded), "0C1A")
  assert_eq(decode(Dpt9, encoded.exact_view()), F16(21.0))
}

test "2-byte float keeps sign and zero" {
  assert_eq(decode(Dpt9, bytes_of_hex("0000").exact_view()), F16(0.0))
  let negative = encode(Dpt9, F16(-0.5))
  match decode(Dpt9, negative.exact_view()) {
    F16(value) => assert_true(value < 0.0)
    _ => fail("expected a float")
  }
}

test "one byte types" {
  assert_eq(hex_of(encode(Dpt1, Bool(true))), "01")
  assert_eq(hex_of(encode(Dpt5, U8(255))), "FF")
  assert_eq(hex_of(encode(Dpt6, I8(-1))), "FF")
  assert_eq(decode(Dpt6, bytes_of_hex("FF").exact_view()), I8(-1))
}

test "two byte integers" {
  assert_eq(hex_of(encode(Dpt7, U16(0x1234))), "1234")
  assert_eq(hex_of(encode(Dpt8, I16(-2))), "FFFE")
  assert_eq(decode(Dpt8, bytes_of_hex("FFFE").exact_view()), I16(-2))
}

test "string pads to fourteen bytes" {
  let encoded = encode(Dpt16, Text("hello"))
  assert_eq(encoded.length(), 14)
  assert_eq(decode(Dpt16, encoded.exact_view()), Text("hello"))
}

test "out of range values are refused" {
  let caught = try {
    ignore(encode(Dpt5, U8(256)))
    false
  } catch {
    DptError::OutOfRange(_) => true
    _ => false
  }
  assert_true(caught)
}

test "wrong length is refused" {
  let caught = try {
    ignore(decode(Dpt7, b"\x00".exact_view()))
    false
  } catch {
    DptError::WrongLength(_, _) => true
    _ => false
  }
  assert_true(caught)
}

test "non ascii text is refused" {
  let caught = try {
    ignore(encode(Dpt16, Text("温度")))
    false
  } catch {
    DptError::NonAscii => true
    _ => false
  }
  assert_true(caught)
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
