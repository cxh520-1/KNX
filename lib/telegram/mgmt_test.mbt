// Management APCI tests pin the wire format of the point-to-point services a
// commissioning tool uses to program a device.

///|
test "individual address write encodes the target address" {
  let address = @addrmodel.IndividualAddress::parse("1.1.1")
  let tpdu = Mgmt::individual_address_write(address).encode()
  assert_eq(hex(tpdu), "03C01101")
  match Mgmt::decode(tpdu.exact_view()) {
    IndividualAddressWrite(back) => assert_eq(back, address)
    _ => fail("expected an individual address write")
  }
}

///|
test "individual address read is a two-byte word" {
  assert_eq(hex(Mgmt::individual_address_read().encode()), "0100")
}

///|
test "individual address response carries the address" {
  let address = @addrmodel.IndividualAddress::parse("1.1.1")
  let tpdu = Mgmt::individual_address_response(address).encode()
  assert_eq(hex(tpdu), "01401101")
  match Mgmt::decode(tpdu.exact_view()) {
    IndividualAddressResponse(back) => assert_eq(back, address)
    _ => fail("expected an individual address response")
  }
}

///|
test "device descriptor read and response" {
  assert_eq(hex(Mgmt::device_descriptor_read().encode()), "0300")
  let tpdu = Mgmt::device_descriptor_response(0x0002).encode()
  assert_eq(hex(tpdu), "03400002")
  match Mgmt::decode(tpdu.exact_view()) {
    DeviceDescriptorResponse(descriptor) => assert_eq(descriptor, 0x0002)
    _ => fail("expected a device descriptor response")
  }
}

///|
test "memory write carries the address and data" {
  let tpdu = Mgmt::memory_write(0x0100, b"\x11\x01\x81").encode()
  assert_eq(hex(tpdu), "02830100110181")
  match Mgmt::decode(tpdu.exact_view()) {
    MemoryWrite(address, data) => {
      assert_eq(address, 0x0100)
      assert_eq(hex(data), "110181")
    }
    _ => fail("expected a memory write")
  }
}

///|
test "memory read carries the address and count" {
  let tpdu = Mgmt::memory_read(0x0100, 3).encode()
  assert_eq(hex(tpdu), "0200010003")
  match Mgmt::decode(tpdu.exact_view()) {
    MemoryRead(address, count) => {
      assert_eq(address, 0x0100)
      assert_eq(count, 3)
    }
    _ => fail("expected a memory read")
  }
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
