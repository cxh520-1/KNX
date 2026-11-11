// FT1.2 is the character-oriented serial data link framing used by the KNX
// Physical External Interface (PEI16, RS-232). It is defined by IEC 870-5-1
// and adopted by the KNX Standard for the serial interface. A telegram is
// carried in a variable-length SEND_UDAT frame; link management uses
// fixed-length frames and a single-byte acknowledgement.
//
//   variable frame   68 L L 68 C [data ...] CS 16
//   fixed frame      10 C [data ...] CS 16
//   acknowledgement  E5
//
// CS is the 8-bit arithmetic sum (modulo 256) of the control field and the
// following data bytes. C is the control field, laid out as
// DIR/PRM/FCB/FCV plus a four-bit function code:
//
//   bit 7  DIR  0 = host to device, 1 = device to host
//   bit 6  PRM  1 = primary (initiating) station
//   bit 5  FCB  frame count bit, toggled for each new send/confirm
//   bit 4  FCV  frame count valid, always 1 for SEND_UDAT
//   bit 3-0 function code: 0x0 = SEND_RESET, 0x3 = SEND_UDAT, 0x9 = REQ_STATUS

///|
/// Framing failures.
pub(all) suberror BusError {
  Truncated(Int)
  BadStart(Int)
  BadEnd(Int)
  BadLength(Int, Int)
  BadChecksum(Int, Int)
  NotUserData(Int)
}

///|
pub const START_FIXED : Int = 0x10

///|
pub const START_VARIABLE : Int = 0x68

///|
pub const END : Int = 0x16

///|
/// Single-byte positive acknowledgement.
pub const ACK : Int = 0xE5

///|
/// Control field of a SEND_RESET frame.
pub const SEND_RESET : Int = 0x40

///|
/// Control field of a SEND_UDAT frame. FCB toggles for each new send/confirm
/// and is 1 on the first frame after a reset.
pub fn send_udat(fcb : Bool) -> Int {
  if fcb {
    0x73
  } else {
    0x53
  }
}

///|
/// Wrap a telegram in a variable-length SEND_UDAT frame.
pub fn wrap(telegram : BytesView, fcb : Bool) -> Bytes {
  let control = send_udat(fcb)
  let length = 1 + telegram.length()
  let out = Buffer()
  out.write_byte(START_VARIABLE.to_byte())
  out.write_byte(length.to_byte())
  out.write_byte(length.to_byte())
  out.write_byte(START_VARIABLE.to_byte())
  out.write_byte(control.to_byte())
  out.write_bytes(telegram)
  out.write_byte(sum_control_data(control, telegram))
  out.write_byte(END.to_byte())
  out.to_bytes()
}

///|
/// Build the reset-of-remote-link request: a fixed-length SEND_RESET frame.
pub fn reset() -> Bytes {
  b"\x10\x40\x40\x16"
}

///|
/// Build the single-byte positive acknowledgement.
pub fn ack() -> Bytes {
  b"\xE5"
}

///|
/// Strip framing and return the telegram carried by a SEND_UDAT frame. A
/// reset, acknowledgement or status frame carries no telegram and is rejected.
pub fn unwrap(frame : BytesView) -> Bytes raise BusError {
  if frame.length() < 1 {
    raise Truncated(frame.length())
  }
  let first = frame[0].to_int()
  let (control, payload) = if first == START_VARIABLE {
    parse_variable(frame)
  } else if first == START_FIXED {
    parse_fixed(frame)
  } else {
    raise BadStart(first)
  }
  if control != send_udat(false) && control != send_udat(true) {
    raise NotUserData(control)
  }
  payload
}

///|
fn parse_variable(frame : BytesView) -> (Int, Bytes) raise BusError {
  if frame.length() < 6 {
    raise Truncated(frame.length())
  }
  if frame[0].to_int() != START_VARIABLE {
    raise BadStart(frame[0].to_int())
  }
  let length = frame[1].to_int()
  if frame[2].to_int() != length {
    raise BadLength(length, frame[2].to_int())
  }
  if frame[3].to_int() != START_VARIABLE {
    raise BadStart(frame[3].to_int())
  }
  if frame.length() != length + 6 {
    raise BadLength(length + 6, frame.length())
  }
  if frame[frame.length() - 1].to_int() != END {
    raise BadEnd(frame[frame.length() - 1].to_int())
  }
  let body = frame[4:4 + length]
  let received = frame[4 + length].to_int()
  let computed = sum(body)
  if received != computed {
    raise BadChecksum(received, computed)
  }
  (body[0].to_int(), copy(body[1:body.length()]))
}

///|
fn parse_fixed(frame : BytesView) -> (Int, Bytes) raise BusError {
  if frame.length() < 4 {
    raise Truncated(frame.length())
  }
  if frame[0].to_int() != START_FIXED {
    raise BadStart(frame[0].to_int())
  }
  if frame[frame.length() - 1].to_int() != END {
    raise BadEnd(frame[frame.length() - 1].to_int())
  }
  let body = frame[1:frame.length() - 2]
  let received = frame[frame.length() - 2].to_int()
  let computed = sum(body)
  if received != computed {
    raise BadChecksum(received, computed)
  }
  (frame[1].to_int(), copy(frame[2:frame.length() - 2]))
}

///|
/// 8-bit arithmetic sum of a byte view, modulo 256.
fn sum(view : BytesView) -> Int {
  let mut total = 0
  for index in 0..<view.length() {
    total = (total + view[index].to_int()) & 0xFF
  }
  total
}

///|
fn sum_control_data(control : Int, data : BytesView) -> Byte {
  let mut total = control & 0xFF
  for index in 0..<data.length() {
    total = (total + data[index].to_int()) & 0xFF
  }
  total.to_byte()
}

///|
fn copy(view : BytesView) -> Bytes {
  let out = Buffer()
  out.write_bytes(view)
  out.to_bytes()
}
