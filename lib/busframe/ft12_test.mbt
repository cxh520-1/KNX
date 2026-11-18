// FT1.2 tests pin the wire format against byte vectors from the KNX serial
// data link: variable-length SEND_UDAT/RESPOND_UDAT frames, the fixed-length
// reset and status requests, the single-byte ACK, the arithmetic checksum and
// the FCB toggle. The payload is a cEMI L_Data message, which is what the
// PEI16/RS-232 link actually carries, not a raw TP1 frame.

///|
test "wrap builds a SEND_UDAT frame around a cemi message" {
  let message = cemi()
  let frame = wrap(message.exact_view(), false)
  assert_eq(hex(frame), "680C0C68531100BCE011011101010081A616")
}

///|
test "wrap toggles the FCB bit in the control field" {
  let message = cemi()
  let frame = wrap(message.exact_view(), true)
  assert_eq(hex(frame), "680C0C68731100BCE011011101010081C616")
}

///|
test "unwrap recovers the cemi message" {
  let message = cemi()
  let frame = wrap(message.exact_view(), true)
  let back = unwrap(frame.exact_view())
  assert_eq(hex(back), "1100BCE011011101010081")
}

///|
test "reset and ack have the fixed wire form" {
  assert_eq(hex(reset()), "10404016")
  assert_eq(hex(ack()), "E5")
}

///|
test "req_status has the fixed wire form" {
  assert_eq(hex(req_status()), "10494916")
}

///|
test "respond_udat builds a secondary user-data frame" {
  assert_eq(
    hex(respond_udat(cemi().exact_view())),
    "680C0C68881100BCE011011101010081DB16",
  )
}

///|
test "respond_udat round-trips through unwrap" {
  let back = unwrap(respond_udat(cemi().exact_view()).exact_view())
  assert_eq(hex(back), "1100BCE011011101010081")
}

///|
test "req_status is rejected as non-user-data" {
  let caught = try {
    ignore(unwrap(req_status().exact_view()))
    false
  } catch {
    BusError::NotUserData(_) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "reset is rejected as non-user-data" {
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
        b"\x68\x0C\x0C\x68\x73\x11\x00\xBC\xE0\x11\x01\x11\x01\x01\x00\x81\x00\x16".exact_view(),
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
    ignore(unwrap(b"\x68\x0C\x0C\x68\x73\x11\x00\x16".exact_view()))
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
        b"\x68\x0C\x0C\x68\x73\x11\x00\xBC\xE0\x11\x01\x11\x01\x01\x00\x81\xC6\x15".exact_view(),
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
/// A cEMI L_Data.req carrying a GroupWrite true from 1.1.1 to group 2/1/1.
fn cemi() -> Bytes {
  b"\x11\x00\xBC\xE0\x11\x01\x11\x01\x01\x00\x81"
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
