// Time, date, 32-bit and 4-byte-float codecs. They live apart from the
// one- and two-byte types because their layouts need explicit field packing
// rather than a straight big-endian read.

///|
/// KNX time: three bytes carrying weekday, hour, minute and second.
pub(all) struct TimeValue {
  weekday : Int
  hour : Int
  minute : Int
  second : Int
} derive(Debug, Eq)

///|
/// KNX date: three bytes carrying day, month and a two-digit year.
pub(all) struct DateValue {
  year : Int
  month : Int
  day : Int
} derive(Debug, Eq)

///|
pub fn encode(dpt : Dpt, value : Value) -> Bytes raise DptError {
  match dpt {
    Dpt10 => encode_time(value)
    Dpt11 => encode_date(value)
    Dpt12 => encode_u32(value)
    Dpt13 => encode_i32(value)
    Dpt14 => encode_f32(value)
    _ => encode_base(dpt, value)
  }
}

///|
pub fn decode(dpt : Dpt, data : BytesView) -> Value raise DptError {
  match dpt {
    Dpt10 => decode_time(data)
    Dpt11 => decode_date(data)
    Dpt12 => decode_u32(data)
    Dpt13 => decode_i32(data)
    Dpt14 => decode_f32(data)
    _ => decode_base(dpt, data)
  }
}

///|
fn encode_time(value : Value) -> Bytes raise DptError {
  match value {
    Time(time) => {
      check_range(time.weekday, 0, 7)
      check_range(time.hour, 0, 23)
      check_range(time.minute, 0, 59)
      check_range(time.second, 0, 59)
      bytes_of([(time.weekday << 5) | time.hour, time.minute, time.second])
    }
    _ => raise WrongKind
  }
}

///|
fn decode_time(data : BytesView) -> Value raise DptError {
  expect_length(data, 3)
  let first = data[0].to_int()
  Time({
    weekday: (first >> 5) & 0x07,
    hour: first & 0x1F,
    minute: data[1].to_int() & 0x3F,
    second: data[2].to_int() & 0x3F,
  })
}

///|
fn encode_date(value : Value) -> Bytes raise DptError {
  match value {
    Date(date) => {
      check_range(date.year, 1990, 2089)
      check_range(date.month, 1, 12)
      check_range(date.day, 1, 31)
      let year = if date.year >= 2000 {
        date.year - 2000
      } else {
        date.year - 1900
      }
      bytes_of([date.day, date.month, year & 0x7F])
    }
    _ => raise WrongKind
  }
}

///|
fn decode_date(data : BytesView) -> Value raise DptError {
  expect_length(data, 3)
  let year = data[2].to_int() & 0x7F
  Date({
    year: if year >= 90 {
      year + 1900
    } else {
      year + 2000
    },
    month: data[1].to_int() & 0x0F,
    day: data[0].to_int() & 0x1F,
  })
}

///|
fn encode_u32(value : Value) -> Bytes raise DptError {
  match value {
    U32(number) => {
      if number < 0L || number > 4_294_967_295L {
        raise OutOfRange(number.to_int())
      }
      bytes_of_int64(number)
    }
    _ => raise WrongKind
  }
}

///|
fn decode_u32(data : BytesView) -> Value raise DptError {
  expect_length(data, 4)
  U32(int64_of(data))
}

///|
fn encode_i32(value : Value) -> Bytes raise DptError {
  match value {
    I32(number) => {
      if number < -2_147_483_648L || number > 2_147_483_647L {
        raise OutOfRange(number.to_int())
      }
      bytes_of_int64(number & 4_294_967_295L)
    }
    _ => raise WrongKind
  }
}

///|
fn decode_i32(data : BytesView) -> Value raise DptError {
  expect_length(data, 4)
  let raw = int64_of(data)
  I32(if raw >= 2_147_483_648L { raw - 4_294_967_296L } else { raw })
}

///|
fn encode_f32(value : Value) -> Bytes raise DptError {
  match value {
    F32(number) => {
      let bits = Float::from_double(number).reinterpret_as_int()
      bytes_of([
        (bits >> 24) & 0xFF,
        (bits >> 16) & 0xFF,
        (bits >> 8) & 0xFF,
        bits & 0xFF,
      ])
    }
    _ => raise WrongKind
  }
}

///|
fn decode_f32(data : BytesView) -> Value raise DptError {
  expect_length(data, 4)
  let bits = int64_of(data).to_int()
  F32(Float::reinterpret_from_int(bits).to_double())
}

///|
fn bytes_of_int64(value : Int64) -> Bytes {
  bytes_of([
    ((value >> 24) & 0xFFL).to_int(),
    ((value >> 16) & 0xFFL).to_int(),
    ((value >> 8) & 0xFFL).to_int(),
    (value & 0xFFL).to_int(),
  ])
}

///|
fn int64_of(data : BytesView) -> Int64 {
  data[0].to_int().to_int64() * 16_777_216L +
  data[1].to_int().to_int64() * 65_536L +
  data[2].to_int().to_int64() * 256L +
  data[3].to_int().to_int64()
}
