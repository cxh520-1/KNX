// Address tests pin the bit layout, because an address that round trips
// through text but shifts one bit is still wrong on the bus.

test "individual address packs area line device" {
  let address = IndividualAddress::parse("1.2.3")
  assert_eq(address.to_u16(), 0x1203)
  assert_eq(IndividualAddress::from_u16(0x1203), address)
  assert_eq(address.to_text(), "1.2.3")
}

test "individual address limits" {
  let caught = try {
    ignore(IndividualAddress::new(16, 0, 0))
    false
  } catch {
    AddressError::OutOfRange(field, _, _) => field == "area"
    _ => false
  }
  assert_true(caught)
}

test "group address packs main middle sub" {
  let address = GroupAddress::parse("1/2/3")
  assert_eq(address.to_u16(), 0x0A03)
  assert_eq(GroupAddress::from_u16(0x0A03), address)
  assert_eq(address.to_text(), "1/2/3")
}

test "group address accepts the full main range" {
  let address = GroupAddress::parse("31/7/255")
  assert_eq(address.to_u16(), 0xFFFF)
  assert_eq(GroupAddress::from_u16(0xFFFF).to_text(), "31/7/255")
}

test "malformed text is rejected" {
  let caught = try {
    ignore(GroupAddress::parse("1-2-3"))
    false
  } catch {
    AddressError::BadFormat(_) => true
    _ => false
  }
  assert_true(caught)
}
