// A TP1 frame, as it appears on the bus after the FT1.2 wrapper is removed.
// Standard frames carry the length in four bits of the NPCI byte; frames with
// longer payloads switch to the extended layout, where a second control byte
// carries the address type and hop count and the length takes a full byte.

///|
/// Failures while reading a frame.
pub(all) suberror TelegramError {
  TooShort(Int)
  BadControl(Int)
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
/// Decoded TP1 frame.
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
/// The extended variant of the same control byte: the frame-type bit cleared.
pub const CONTROL_EXTENDED : Int = 0x3C

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
  if payload_length < 1 || payload_length > 256 {
    raise BadLength(payload_length)
  }
  let (is_group, destination_word) = match self.destination {
    Individual(address) => (false, address.to_u16())
    Group(address) => (true, address.to_u16())
  }
  let out = Buffer()
  if payload_length <= 16 {
    out.write_byte(self.control.to_byte())
    out.write_byte(((self.source.to_u16() >> 8) & 0xFF).to_byte())
    out.write_byte((self.source.to_u16() & 0xFF).to_byte())
    out.write_byte(((destination_word >> 8) & 0xFF).to_byte())
    out.write_byte((destination_word & 0xFF).to_byte())
    let npci = (if is_group { 0x80 } else { 0x00 }) | (payload_length - 1)
    out.write_byte(npci.to_byte())
  } else {
    out.write_byte((self.control & 0x7F).to_byte())
    out.write_byte(((if is_group { 0x80 } else { 0x00 }) | 0x60).to_byte())
    out.write_byte(((self.source.to_u16() >> 8) & 0xFF).to_byte())
    out.write_byte((self.source.to_u16() & 0xFF).to_byte())
    out.write_byte(((destination_word >> 8) & 0xFF).to_byte())
    out.write_byte((destination_word & 0xFF).to_byte())
    out.write_byte((payload_length - 1).to_byte())
  }
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
  let extended = (control & 0x80) == 0
  let (source_offset, destination_offset, length_offset, payload_offset) = if extended {
    (2, 4, 6, 7)
  } else {
    (1, 3, 5, 6)
  }
  let source = @addrmodel.IndividualAddress::from_u16(
    (data[source_offset].to_int() << 8) | data[source_offset + 1].to_int(),
  )
  let destination_word = (data[destination_offset].to_int() << 8) |
    data[destination_offset + 1].to_int()
  let length_byte = data[length_offset].to_int()
  let is_group = if extended {
    (data[1].to_int() & 0x80) != 0
  } else {
    (length_byte & 0x80) != 0
  }
  let payload_length = if extended {
    length_byte + 1
  } else {
    (length_byte & 0x0F) + 1
  }
  let checksum_offset = payload_offset + payload_length
  if data.length() < checksum_offset + 1 {
    raise BadLength(data.length())
  }
  let tpdu = data[payload_offset:payload_offset + payload_length]
  let received = data[checksum_offset].to_int()
  let computed = checksum(data[0:checksum_offset]).to_int()
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
