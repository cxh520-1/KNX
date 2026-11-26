// Management services ride the point-to-point (individual address) transport.
// They are how a commissioning tool turns a factory-fresh device into one that
// can talk on the group bus: program its individual address, read its device
// descriptor, and read/write its memory (the group-object table lives there).

///|
/// Failures while encoding/decoding a management APCI.
pub(all) suberror MgmtError {
  TooShort(Int)
  UnknownService(Int)
  LengthMismatch(Int, Int)
}

///|
/// 16-bit APCI words for the management services. The low six bits of the word
/// are service-specific: zero for reads, the byte count for memory services.
pub const A_INDIVIDUAL_ADDRESS_READ : Int = 0x0100

///|
pub const A_INDIVIDUAL_ADDRESS_RESPONSE : Int = 0x0140

///|
pub const A_INDIVIDUAL_ADDRESS_WRITE : Int = 0x03C0

///|
pub const A_MEMORY_READ : Int = 0x0200

///|
pub const A_MEMORY_RESPONSE : Int = 0x0240

///|
pub const A_MEMORY_WRITE : Int = 0x0280

///|
pub const A_DEVICE_DESCRIPTOR_READ : Int = 0x0300

///|
pub const A_DEVICE_DESCRIPTOR_RESPONSE : Int = 0x0340

///|
/// A management service and its payload.
pub(all) enum Mgmt {
  IndividualAddressRead
  IndividualAddressResponse(@addrmodel.IndividualAddress)
  IndividualAddressWrite(@addrmodel.IndividualAddress)
  MemoryRead(Int, Int)
  MemoryResponse(Int, Bytes)
  MemoryWrite(Int, Bytes)
  DeviceDescriptorRead
  DeviceDescriptorResponse(Int)
} derive(Debug, Eq)

///|
pub fn Mgmt::individual_address_write(
  address : @addrmodel.IndividualAddress,
) -> Mgmt {
  IndividualAddressWrite(address)
}

///|
pub fn Mgmt::individual_address_response(
  address : @addrmodel.IndividualAddress,
) -> Mgmt {
  IndividualAddressResponse(address)
}

///|
pub fn Mgmt::individual_address_read() -> Mgmt {
  IndividualAddressRead
}

///|
pub fn Mgmt::device_descriptor_response(descriptor : Int) -> Mgmt {
  DeviceDescriptorResponse(descriptor)
}

///|
pub fn Mgmt::device_descriptor_read() -> Mgmt {
  DeviceDescriptorRead
}

///|
pub fn Mgmt::memory_read(address : Int, count : Int) -> Mgmt {
  MemoryRead(address, count)
}

///|
pub fn Mgmt::memory_write(address : Int, data : Bytes) -> Mgmt {
  MemoryWrite(address, data)
}

///|
pub fn Mgmt::encode(self : Mgmt) -> Bytes raise MgmtError {
  match self {
    IndividualAddressRead => word(A_INDIVIDUAL_ADDRESS_READ, b"")
    IndividualAddressResponse(address) =>
      word(A_INDIVIDUAL_ADDRESS_RESPONSE, u16(address.to_u16()))
    IndividualAddressWrite(address) =>
      word(A_INDIVIDUAL_ADDRESS_WRITE, u16(address.to_u16()))
    DeviceDescriptorRead => word(A_DEVICE_DESCRIPTOR_READ, b"")
    DeviceDescriptorResponse(descriptor) =>
      word(A_DEVICE_DESCRIPTOR_RESPONSE, u16(descriptor))
    MemoryRead(address, count) => {
      if count < 1 || count > 63 {
        raise LengthMismatch(count, 63)
      }
      let out = Buffer()
      out.write_bytes(u16(A_MEMORY_READ))
      out.write_bytes(u16(address))
      out.write_byte(count.to_byte())
      out.to_bytes()
    }
    MemoryResponse(address, data) => memory(A_MEMORY_RESPONSE, address, data)
    MemoryWrite(address, data) => memory(A_MEMORY_WRITE, address, data)
  }
}

///|
pub fn Mgmt::decode(tpdu : BytesView) -> Mgmt raise MgmtError {
  if tpdu.length() < 2 {
    raise TooShort(tpdu.length())
  }
  let word = (tpdu[0].to_int() << 8) | tpdu[1].to_int()
  let code = word & 0xFFC0
  let low = word & 0x3F
  match code {
    A_INDIVIDUAL_ADDRESS_READ => {
      expect(tpdu, 2)
      IndividualAddressRead
    }
    A_INDIVIDUAL_ADDRESS_RESPONSE => {
      expect(tpdu, 4)
      IndividualAddressResponse(
        @addrmodel.IndividualAddress::from_u16(read_u16(tpdu, 2)),
      )
    }
    A_INDIVIDUAL_ADDRESS_WRITE => {
      expect(tpdu, 4)
      IndividualAddressWrite(
        @addrmodel.IndividualAddress::from_u16(read_u16(tpdu, 2)),
      )
    }
    A_DEVICE_DESCRIPTOR_READ => {
      expect(tpdu, 2)
      DeviceDescriptorRead
    }
    A_DEVICE_DESCRIPTOR_RESPONSE => {
      expect(tpdu, 4)
      DeviceDescriptorResponse(read_u16(tpdu, 2))
    }
    A_MEMORY_READ => {
      expect(tpdu, 5)
      MemoryRead(read_u16(tpdu, 2), tpdu[4].to_int())
    }
    A_MEMORY_RESPONSE => {
      if tpdu.length() < 4 || tpdu.length() != 4 + low {
        raise LengthMismatch(tpdu.length(), 4 + low)
      }
      MemoryResponse(read_u16(tpdu, 2), copy_bytes(tpdu[4:tpdu.length()]))
    }
    A_MEMORY_WRITE => {
      if tpdu.length() < 4 || tpdu.length() != 4 + low {
        raise LengthMismatch(tpdu.length(), 4 + low)
      }
      MemoryWrite(read_u16(tpdu, 2), copy_bytes(tpdu[4:tpdu.length()]))
    }
    _ => raise UnknownService(code)
  }
}

///|
/// A two-byte APCI word plus an optional fixed payload, for the simple
/// services whose payload is not a counted byte string.
fn word(code : Int, data : Bytes) -> Bytes {
  let out = Buffer()
  out.write_bytes(u16(code))
  out.write_bytes(data.exact_view())
  out.to_bytes()
}

///|
/// A memory service: the low six bits carry the byte count of the payload.
fn memory(code : Int, address : Int, data : Bytes) -> Bytes raise MgmtError {
  if data.length() < 1 || data.length() > 63 {
    raise LengthMismatch(data.length(), 63)
  }
  let out = Buffer()
  out.write_bytes(u16(code | data.length()))
  out.write_bytes(u16(address))
  out.write_bytes(data.exact_view())
  out.to_bytes()
}

///|
fn u16(value : Int) -> Bytes {
  let out = Buffer()
  out.write_byte(((value >> 8) & 0xFF).to_byte())
  out.write_byte((value & 0xFF).to_byte())
  out.to_bytes()
}

///|
fn read_u16(view : BytesView, offset : Int) -> Int {
  (view[offset].to_int() << 8) | view[offset + 1].to_int()
}

///|
fn expect(view : BytesView, length : Int) -> Unit raise MgmtError {
  if view.length() != length {
    raise LengthMismatch(view.length(), length)
  }
}

///|
fn copy_bytes(view : BytesView) -> Bytes {
  let out = Buffer()
  out.write_bytes(view)
  out.to_bytes()
}
