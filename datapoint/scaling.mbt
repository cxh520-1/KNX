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
