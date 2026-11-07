// Data point types turn a KNX payload into a typed value and back. This
// module covers the one- and two-byte numeric types plus the fixed-width
// string; 32-bit values and time/date layouts are left out rather than
// half-implemented, because a wrong bit pattern is worse than a missing type.

///|
/// Failures while converting values.
pub(all) suberror DptError {
  WrongLength(Int, Int)
  OutOfRange(Int)
  WrongKind
  TextTooLong(Int)
  NonAscii
}

///|
/// Data point types implemented by this module.
pub(all) enum Dpt {
  Dpt1
  Dpt5
  Dpt6
  Dpt7
  Dpt8
  Dpt9
  Dpt16
} derive(Debug, Eq)

///|
/// Typed value carried by a data point.
pub(all) enum Value {
  Bool(Bool)
  U8(Int)
  I8(Int)
  U16(Int)
  I16(Int)
  F16(Double)
  Text(String)
} derive(Debug, Eq)

///|
pub fn name(dpt : Dpt) -> String {
  match dpt {
    Dpt1 => "DPT-1 boolean"
    Dpt5 => "DPT-5 8-bit unsigned"
    Dpt6 => "DPT-6 8-bit signed"
    Dpt7 => "DPT-7 16-bit unsigned"
    Dpt8 => "DPT-8 16-bit signed"
    Dpt9 => "DPT-9 2-byte float"
    Dpt16 => "DPT-16 string"
  }
}

///|
pub fn unit(dpt : Dpt) -> String {
  match dpt {
    Dpt9 => "°C"
    _ => ""
  }
}

///|
pub fn encode(dpt : Dpt, value : Value) -> Bytes raise DptError {
  match dpt {
    Dpt1 =>
      match value {
        Bool(flag) => bytes_of([if flag { 1 } else { 0 }])
        _ => raise WrongKind
      }
    Dpt5 =>
      match value {
        U8(number) => {
          check_range(number, 0, 255)
          bytes_of([number])
        }
        _ => raise WrongKind
      }
    Dpt6 =>
      match value {
        I8(number) => {
          check_range(number, -128, 127)
          bytes_of([number & 0xFF])
        }
        _ => raise WrongKind
      }
    Dpt7 =>
      match value {
        U16(number) => {
          check_range(number, 0, 65535)
          bytes_of([(number >> 8) & 0xFF, number & 0xFF])
        }
        _ => raise WrongKind
      }
    Dpt8 =>
      match value {
        I16(number) => {
          check_range(number, -32768, 32767)
          let bits = number & 0xFFFF
          bytes_of([(bits >> 8) & 0xFF, bits & 0xFF])
        }
        _ => raise WrongKind
      }
    Dpt9 =>
      match value {
        F16(number) => {
          let bits = encode_float16(number)
          bytes_of([(bits >> 8) & 0xFF, bits & 0xFF])
        }
        _ => raise WrongKind
      }
    Dpt16 =>
      match value {
        Text(text) => {
          check_ascii(text)
          if text.length() > 14 {
            raise TextTooLong(text.length())
          }
          let out = Buffer()
          for index in 0..<text.length() {
            out.write_byte(text.get_char(index).unwrap().to_int().to_byte())
          }
          let mut padding = 14 - text.length()
          while padding > 0 {
            out.write_byte(b'\x00')
            padding = padding - 1
          }
          out.to_bytes()
        }
        _ => raise WrongKind
      }
  }
}

///|
pub fn decode(dpt : Dpt, data : BytesView) -> Value raise DptError {
  match dpt {
    Dpt1 => {
      expect_length(data, 1)
      Bool(data[0].to_int() != 0)
    }
    Dpt5 => {
      expect_length(data, 1)
      U8(data[0].to_int())
    }
    Dpt6 => {
      expect_length(data, 1)
      let raw = data[0].to_int()
      I8(if raw >= 128 { raw - 256 } else { raw })
    }
    Dpt7 => {
      expect_length(data, 2)
      U16((data[0].to_int() << 8) | data[1].to_int())
    }
    Dpt8 => {
      expect_length(data, 2)
      let raw = (data[0].to_int() << 8) | data[1].to_int()
      I16(if raw >= 32768 { raw - 65536 } else { raw })
    }
    Dpt9 => {
      expect_length(data, 2)
      F16(decode_float16((data[0].to_int() << 8) | data[1].to_int()))
    }
    Dpt16 => {
      expect_length(data, 14)
      let out = StringBuilder()
      for index in 0..<14 {
        let byte = data[index].to_int()
        if byte != 0 {
          out.write_char(Int::unsafe_to_char(byte))
        }
      }
      Text(out.to_string())
    }
  }
}

///|
fn encode_float16(value : Double) -> Int {
  let sign = if value < 0.0 { 1 } else { 0 }
  let magnitude = if value < 0.0 { -value } else { value }
  let mut mantissa = magnitude * 100.0
  let mut exponent = 0
  while mantissa.round() > 2047.0 && exponent < 15 {
    mantissa = mantissa / 2.0
    exponent = exponent + 1
  }
  let m = mantissa.round().to_int()
  (sign << 15) | ((exponent & 0x0F) << 11) | (m & 0x7FF)
}

///|
fn decode_float16(bits : Int) -> Double {
  let sign = (bits >> 15) & 0x01
  let exponent = (bits >> 11) & 0x0F
  let mantissa = bits & 0x7FF
  let mut scale = 1.0
  for _ in 0..<exponent {
    scale = scale * 2.0
  }
  let value = 0.01 * mantissa.to_double() * scale
  if sign == 1 {
    -value
  } else {
    value
  }
}

///|
fn expect_length(data : BytesView, expected : Int) -> Unit raise DptError {
  if data.length() != expected {
    raise WrongLength(expected, data.length())
  }
}

///|
fn check_range(value : Int, low : Int, high : Int) -> Unit raise DptError {
  if value < low || value > high {
    raise OutOfRange(value)
  }
}

///|
fn bytes_of(values : Array[Int]) -> Bytes {
  let out = Buffer()
  for value in values {
    out.write_byte((value & 0xFF).to_byte())
  }
  out.to_bytes()
}

///|
fn check_ascii(text : String) -> Unit raise DptError {
  for index in 0..<text.length() {
    let code = text.get_char(index).unwrap().to_int()
    if code > 127 {
      raise NonAscii
    }
  }
}
