// On a serial line the telegram is wrapped in FT1.2 framing: a two-byte
// start, the telegram bytes with 0x10 doubled, and a two-byte end. The
// doubling is the only escaping in the format, and it exists because 0x10 is
// both the start and the end marker.

///|
/// Framing failures.
pub(all) suberror BusError {
  BadStart(Int)
  BadEnd(Int)
  Truncated(Int)
  StrayEscape(Int)
}

///|
pub const START : Int = 0x10
///|
pub const START_KIND : Int = 0x02
///|
pub const END : Int = 0x10
///|
pub const END_KIND : Int = 0x03

///|
/// Wrap a telegram in FT1.2 framing, doubling every 0x10 byte.
pub fn wrap(telegram : BytesView) -> Bytes {
  let out = Buffer()
  out.write_byte(START.to_byte())
  out.write_byte(START_KIND.to_byte())
  for index in 0..<telegram.length() {
    let byte = telegram[index]
    out.write_byte(byte)
    if byte.to_int() == START {
      out.write_byte(byte)
    }
  }
  out.write_byte(END.to_byte())
  out.write_byte(END_KIND.to_byte())
  out.to_bytes()
}

///|
/// Strip framing and undo the doubling.
pub fn unwrap(frame : BytesView) -> Bytes raise BusError {
  if frame.length() < 4 {
    raise Truncated(frame.length())
  }
  if frame[0].to_int() != START || frame[1].to_int() != START_KIND {
    raise BadStart(frame[0].to_int())
  }
  let last = frame.length() - 1
  if frame[last].to_int() != END_KIND || frame[last - 1].to_int() != END {
    raise BadEnd(frame[last].to_int())
  }
  let body = frame[2:last - 1]
  let out = Buffer()
  let mut index = 0
  while index < body.length() {
    let byte = body[index].to_int()
    if byte == START {
      if index + 1 >= body.length() || body[index + 1].to_int() != START {
        raise StrayEscape(index)
      }
      out.write_byte(START.to_byte())
      index = index + 2
    } else {
      out.write_byte(byte.to_byte())
      index = index + 1
    }
  }
  out.to_bytes()
}
