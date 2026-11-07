// Two application subtypes that are common on real panels: a scene number
// with a store flag, and a dimmer percentage that must be scaled rather than
// cast.

///|
fn encode_scene(value : Value) -> Bytes raise DptError {
  match value {
    Scene(number, store) => {
      check_range(number, 0, 63)
      bytes_of([(if store { 0x80 } else { 0x00 }) | number])
    }
    _ => raise WrongKind
  }
}

///|
fn decode_scene(data : BytesView) -> Value raise DptError {
  expect_length(data, 1)
  let raw = data[0].to_int()
  Scene(raw & 0x3F, (raw & 0x80) != 0)
}

///|
fn encode_percent(value : Value) -> Bytes raise DptError {
  match value {
    Percent(percent) => bytes_of([percent_to_raw(percent)])
    _ => raise WrongKind
  }
}

///|
fn decode_percent(data : BytesView) -> Value raise DptError {
  expect_length(data, 1)
  Percent(raw_to_percent(data[0].to_int()))
}
