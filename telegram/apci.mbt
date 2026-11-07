// The TPDU of a group telegram starts with a two-byte APCI word. For the
// three group services the low six bits either carry a small value inline or
// the number of bytes that follow, which is what keeps one-byte writes to a
// single frame without a separate length field.

///|
/// Failures while reading an APCI word.
pub(all) suberror ApciError {
  TooShort(Int)
  UnknownService(Int)
  LengthMismatch(Int, Int)
}

///|
/// Group communication services used by this library.
pub(all) enum Service {
  GroupRead
  GroupResponse
  GroupWrite
} derive(Debug, Eq)

///|
/// Inline value (0..63) or an explicit byte payload.
pub(all) enum Value {
  Short(Int)
  Long(Bytes)
} derive(Debug, Eq)

///|
pub(all) struct Apci {
  service : Service
  value : Value
} derive(Debug, Eq)

///|
pub fn Apci::read() -> Apci {
  { service: GroupRead, value: Short(0), }
}

///|
pub fn Apci::write_short(value : Int) -> Apci raise ApciError {
  if value < 0 || value > 63 {
    raise LengthMismatch(value, 63)
  }
  { service: GroupWrite, value: Short(value), }
}

///|
pub fn Apci::write_long(data : Bytes) -> Apci raise ApciError {
  if data.length() < 1 || data.length() > 14 {
    raise LengthMismatch(data.length(), 14)
  }
  { service: GroupWrite, value: Long(data), }
}

///|
pub fn Apci::response_short(value : Int) -> Apci raise ApciError {
  if value < 0 || value > 63 {
    raise LengthMismatch(value, 63)
  }
  { service: GroupResponse, value: Short(value), }
}

///|
pub fn Apci::encode(self : Apci) -> Bytes raise ApciError {
  let code = service_code(self.service)
  match self.value {
    Short(value) => {
      let word = code | value
      let out = Buffer()
      out.write_byte(((word >> 8) & 0xFF).to_byte())
      out.write_byte((word & 0xFF).to_byte())
      out.to_bytes()
    }
    Long(data) => {
      if data.length() < 1 || data.length() > 14 {
        raise LengthMismatch(data.length(), 14)
      }
      let word = code | data.length()
      let out = Buffer()
      out.write_byte(((word >> 8) & 0xFF).to_byte())
      out.write_byte((word & 0xFF).to_byte())
      out.write_bytes(data.exact_view())
      out.to_bytes()
    }
  }
}

///|
pub fn Apci::decode(tpdu : BytesView) -> Apci raise ApciError {
  if tpdu.length() < 2 {
    raise TooShort(tpdu.length())
  }
  let word = (tpdu[0].to_int() << 8) | tpdu[1].to_int()
  let code = word & 0xFFC0
  let service = match code {
    0x0000 => GroupRead
    0x0040 => GroupResponse
    0x0080 => GroupWrite
    _ => raise UnknownService(code)
  }
  let low = word & 0x3F
  if tpdu.length() == 2 {
    { service, value: Short(low), }
  } else {
    let data = tpdu[2:tpdu.length()]
    if data.length() != low {
      raise LengthMismatch(data.length(), low)
    }
    { service, value: Long(copy(data)), }
  }
}

///|
pub fn Apci::group_write_value(self : Apci) -> Int? {
  match self.value {
    Short(value) => Some(value)
    Long(_) => None
  }
}

///|
fn service_code(service : Service) -> Int {
  match service {
    GroupRead => 0x0000
    GroupResponse => 0x0040
    GroupWrite => 0x0080
  }
}

///|
pub fn Apci::response_long(data : Bytes) -> Apci raise ApciError {
  if data.length() < 1 || data.length() > 14 {
    raise LengthMismatch(data.length(), 14)
  }
  { service: GroupResponse, value: Long(data), }
}
