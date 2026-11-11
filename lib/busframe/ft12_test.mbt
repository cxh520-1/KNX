// FT1.2 tests pin the wire format against byte vectors from the KNX serial
// data link: variable-length SEND_UDAT frames, the fixed-length reset, the
// single-byte ACK, the arithmetic checksum and the FCB toggle.

///|
test "wrap builds a SEND_UDAT frame" {
  let telegram = b"\xBC\x11\x01\x11\x01\x81\x00\x81\xBC"
  let frame = wrap(telegram.exact_view(), false)
  assert_eq(hex(frame), "680A0A6853BC11011101810081BCF116")
}

///|
test "wrap toggles the FCB bit in the control field" {
  let telegram = b"\xBC\x11\x01\x11\x01\x81\x00\x81\xBC"
  let frame = wrap(telegram.exact_view(), true)
  assert_eq(hex(frame), "680A0A6873BC11011101810081BC1116")
}

///|
test "unwrap recovers the telegram" {
  let telegram = b"\xBC\x11\x01\x11\x01\x81\x00\x81\xBC"
  let frame = wrap(telegram.exact_view(), true)
  let back = unwrap(frame.exact_view())
  assert_eq(hex(back), "BC11011101810081BC")
}

///|
test "reset and ack have the fixed wire form" {
  assert_eq(hex(reset()), "10404016")
  assert_eq(hex(ack()), "E5")
}

///|
test "reset round-trips through unwrap is rejected as non-user-data" {
  let caught = try {
    ignore(unwrap(reset().exact_view()))
    false
  } catch {
    BusError::NotUserData(_) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "bad checksum is rejected" {
  let caught = try {
    ignore(
      unwrap(
        b"\x68\x0A\x0A\x68\x73\xBC\x11\x01\x11\x01\x81\x00\x81\xBC\x00\x16".exact_view(),
      ),
    )
    false
  } catch {
    BusError::BadChecksum(_, _) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "length mismatch is rejected" {
  let caught = try {
    ignore(unwrap(b"\x68\x0A\x0A\x68\x73\xBC\x16".exact_view()))
    false
  } catch {
    BusError::BadLength(_, _) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "bad start is rejected" {
  let caught = try {
    ignore(unwrap(b"\x69\x00\x00\x68\x53\x00\x00\x16".exact_view()))
    false
  } catch {
    BusError::BadStart(_) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "stray end marker is rejected" {
  let caught = try {
    ignore(
      unwrap(
        b"\x68\x0A\x0A\x68\x73\xBC\x11\x01\x11\x01\x81\x00\x81\xBC\xF1\x15".exact_view(),
      ),
    )
    false
  } catch {
    BusError::BadEnd(_) => true
    _ => false
  }
  assert_true(caught)
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
fn nibble(value : Int) -> Char {
  Int::unsafe_to_char(if value < 10 { value + 48 } else { value + 55 })
}
