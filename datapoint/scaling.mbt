// Percentage scaling for DPT-5. A KNX dimmer carries 0..100 % as one byte,
// and the conversion is not a plain cast: 100 % is 255, so the rounding rule
// matters at the endpoints.

///|
pub fn percent_to_raw(percent : Int) -> Int raise DptError {
  if percent < 0 || percent > 100 {
    raise OutOfRange(percent)
  }
  (percent * 255 + 50) / 100
}

///|
pub fn raw_to_percent(raw : Int) -> Int raise DptError {
  if raw < 0 || raw > 255 {
    raise OutOfRange(raw)
  }
  (raw * 100 + 127) / 255
}

///|
/// A DPT-9 value is a temperature in hundredths of a degree; this exposes the
/// conversion so a caller does not have to remember the scaling.
pub fn temperature_to_value(celsius : Double) -> Value {
  F16(celsius)
}

///|
pub fn value_to_temperature(value : Value) -> Double? {
  match value {
    F16(celsius) => Some(celsius)
    _ => None
  }
}
