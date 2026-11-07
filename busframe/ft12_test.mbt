// FT1.2 tests care about one thing beyond round trips: a telegram that
// happens to contain 0x10 must survive the wire without being read as a
// delimiter.

test "wrap adds start and end" {
  let telegram = b"\xBC\x11\x01\x0A\x03\x81\x00\x81\x3A"
  let frame = wrap(telegram.exact_view())
  assert_eq(frame[0].to_int(), 0x10)
  assert_eq(frame[1].to_int(), 0x02)
  assert_eq(frame[frame.length() - 2].to_int(), 0x10)
  assert_eq(frame[frame.length() - 1].to_int(), 0x03)
}

test "telegram containing 0x10 is doubled" {
  let telegram = b"\x10\x00\x10"
  let frame = wrap(telegram.exact_view())
  // 10 02, then 10 10 00 10 10, then 10 03
  assert_eq(frame.length(), 9)
  assert_eq(frame[2].to_int(), 0x10)
  assert_eq(frame[3].to_int(), 0x10)
}

test "unwrap recovers the telegram" {
  let telegram = b"\x10\x00\x10\x11"
  let frame = wrap(telegram.exact_view())
  let back = unwrap(frame.exact_view())
  assert_eq(back.length(), 4)
  assert_eq(back[0].to_int(), 0x10)
  assert_eq(back[3].to_int(), 0x11)
}

test "bad start is rejected" {
  let caught = try {
    ignore(unwrap(b"\x11\x02\x00\x10\x03".exact_view()))
    false
  } catch {
    BusError::BadStart(_) => true
    _ => false
  }
  assert_true(caught)
}

test "stray escape inside the body is rejected" {
  let caught = try {
    ignore(unwrap(b"\x10\x02\x10\x01\x10\x03".exact_view()))
    false
  } catch {
    BusError::StrayEscape(_) => true
    _ => false
  }
  assert_true(caught)
}
