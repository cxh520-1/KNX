// A TP1 standard frame, as it appears on the bus after the FT1.2 wrapper is
// removed. The layout is fixed: control, source, destination, an NPCI byte
// that carries the address type and length, the TPDU, and one checksum byte.

///|
/// Failures while reading a frame.
pub(all) suberror TelegramError {
  TooShort(Int)
  BadControl(Int)
  ExtendedFrame
  BadLength(Int)
  BadChecksum(Int, Int)
}

///|
/// Where a frame is addressed: one device, or one group function.
pub(all) enum Destination {
  Individual(@addrmodel.IndividualAddress)
  Group(@addrmodel.GroupAddress)
} derive(Debug, Eq)

///|
/// Decoded TP1 standard frame.
pub(all) struct Telegram {
  control : Int
  source : @addrmodel.IndividualAddress
  destination : Destination
  tpdu : Bytes
} derive(Debug, Eq)

///|
/// The control byte used for ordinary group communication: standard frame,
/// low priority, no repeat request.
pub const CONTROL_STANDARD : Int = 0xBC

///|
pub fn Telegram::new(
  source : @addrmodel.IndividualAddress,
  destination : Destination,
  tpdu : Bytes,
) -> Telegram {
  { control: CONTROL_STANDARD, source, destination, tpdu, }
}

///|
pub fn Telegram::encode(self : Telegram) -> Bytes raise TelegramError {
  let payload_length = self.tpdu.length()
  if payload_length < 1 || payload_length > 16 {
    raise BadLength(payload_length)
  }
  let destination_word = match self.destination {
    Individual(address) => address.to_u16()
    Group(address) => address.to_u16()
  }
  let is_group = match self.destination {
    Individual(_) => false
    Group(_) => true
  }
  let npci = (if is_group { 0x80 } else { 0x00 }) | (payload_length - 1)
  let out = Buffer()
  out.write_byte(self.control.to_byte())
  out.write_byte(((self.source.to_u16() >> 8) & 0xFF).to_byte())
  out.write_byte((self.source.to_u16() & 0xFF).to_byte())
  out.write_byte(((destination_word >> 8) & 0xFF).to_byte())
  out.write_byte((destination_word & 0xFF).to_byte())
  out.write_byte(npci.to_byte())
  for index in 0..<payload_length {
    out.write_byte(self.tpdu[index])
  }
  let body = out.to_bytes()
  let sum = checksum(body.exact_view())
  let tail = Buffer()
  tail.write_bytes(body.exact_view())
  tail.write_byte(sum)
  tail.to_bytes()
}

///|
pub fn Telegram::decode(data : BytesView) -> Telegram raise TelegramError {
  if data.length() < 7 {
    raise TooShort(data.length())
  }
  let control = data[0].to_int()
  if (control & 0x53) != 0x10 {
    raise BadControl(control)
  }
  if (control & 0x80) == 0 {
    raise ExtendedFrame
  }
  let source = @addrmodel.IndividualAddress::from_u16(
    (data[1].to_int() << 8) | data[2].to_int(),
  )
  let destination_word = (data[3].to_int() << 8) | data[4].to_int()
  let npci = data[5].to_int()
  let is_group = (npci & 0x80) != 0
  let payload_length = (npci & 0x0F) + 1
  if data.length() < 6 + payload_length + 1 {
    raise BadLength(data.length())
  }
  let tpdu = data[6:6 + payload_length]
  let received = data[6 + payload_length].to_int()
  let computed = checksum(data[0:6 + payload_length]).to_int()
  if received != computed {
    raise BadChecksum(received, computed)
  }
  let destination = if is_group {
    Group(@addrmodel.GroupAddress::from_u16(destination_word))
  } else {
    Individual(@addrmodel.IndividualAddress::from_u16(destination_word))
  }
  { control, source, destination, tpdu: copy(tpdu), }
}

///|
/// XOR of every byte from the control field to the last TPDU byte.
pub fn checksum(data : BytesView) -> Byte {
  let mut sum = 0
  for index in 0..<data.length() {
    sum = sum ^ data[index].to_int()
  }
  sum.to_byte()
}

///|
fn copy(view : BytesView) -> Bytes {
  let out = Buffer()
  out.write_bytes(view)
  out.to_bytes()
}
