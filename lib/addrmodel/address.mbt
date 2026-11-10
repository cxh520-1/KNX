// KNX has two address spaces and they are not interchangeable: individual
// addresses identify a device (area.line.device) while group addresses name a
// function (main/middle/sub). Both pack into sixteen bits, but with different
// field widths, which is a classic source of silent routing bugs.

///|
/// Failures while reading an address from text or from its packed form.
pub(all) suberror AddressError {
  BadFormat(String)
  OutOfRange(String, Int, Int)
}

///|
/// Physical address of a device: 4 bits area, 4 bits line, 8 bits device.
pub(all) struct IndividualAddress {
  area : Int
  line : Int
  device : Int
} derive(Debug, Eq)

///|
pub fn IndividualAddress::new(
  area : Int,
  line : Int,
  device : Int,
) -> IndividualAddress raise AddressError {
  check_range("area", area, 0, 15)
  check_range("line", line, 0, 15)
  check_range("device", device, 0, 255)
  { area, line, device, }
}

///|
pub fn IndividualAddress::parse(
  text : String,
) -> IndividualAddress raise AddressError {
  let (area, rest) = read_number(text, 0, "area")
  let (line, rest) = expect_separator(text, rest, '.', "line")
  let (device, rest) = expect_separator(text, rest, '.', "device")
  if rest != text.length() {
    raise BadFormat(text)
  }
  IndividualAddress::new(area, line, device)
}

///|
pub fn IndividualAddress::to_u16(self : IndividualAddress) -> Int {
  (self.area << 12) | (self.line << 8) | self.device
}

///|
pub fn IndividualAddress::from_u16(value : Int) -> IndividualAddress {
  {
    area: (value >> 12) & 0x0F,
    line: (value >> 8) & 0x0F,
    device: value & 0xFF,
  }
}

///|
pub fn IndividualAddress::to_text(self : IndividualAddress) -> String {
  self.area.to_string() +
  "." +
  self.line.to_string() +
  "." +
  self.device.to_string()
}

///|
/// Group address: 5 bits main, 3 bits middle, 8 bits sub.
pub(all) struct GroupAddress {
  main : Int
  middle : Int
  sub : Int
} derive(Debug, Eq)

///|
pub fn GroupAddress::new(
  main : Int,
  middle : Int,
  sub : Int,
) -> GroupAddress raise AddressError {
  check_range("main", main, 0, 31)
  check_range("middle", middle, 0, 7)
  check_range("sub", sub, 0, 255)
  { main, middle, sub, }
}

///|
pub fn GroupAddress::parse(text : String) -> GroupAddress raise AddressError {
  let (main, rest) = read_number(text, 0, "main")
  let (middle, rest) = expect_separator(text, rest, '/', "middle")
  let (sub, rest) = expect_separator(text, rest, '/', "sub")
  if rest != text.length() {
    raise BadFormat(text)
  }
  GroupAddress::new(main, middle, sub)
}

///|
pub fn GroupAddress::to_u16(self : GroupAddress) -> Int {
  (self.main << 11) | (self.middle << 8) | self.sub
}

///|
pub fn GroupAddress::from_u16(value : Int) -> GroupAddress {
  {
    main: (value >> 11) & 0x1F,
    middle: (value >> 8) & 0x07,
    sub: value & 0xFF,
  }
}

///|
pub fn GroupAddress::to_text(self : GroupAddress) -> String {
  self.main.to_string() +
  "/" +
  self.middle.to_string() +
  "/" +
  self.sub.to_string()
}

///|
fn check_range(
  field : String,
  value : Int,
  low : Int,
  high : Int,
) -> Unit raise AddressError {
  if value < low || value > high {
    raise OutOfRange(field, value, high)
  }
}

///|
fn read_number(
  text : String,
  start : Int,
  field : String,
) -> (Int, Int) raise AddressError {
  let mut index = start
  let mut value = 0
  let mut digits = 0
  while index < text.length() {
    let code = text.get_char(index).unwrap().to_int()
    if code < 48 || code > 57 {
      break
    }
    value = value * 10 + (code - 48)
    digits = digits + 1
    index = index + 1
  }
  if digits == 0 {
    raise BadFormat(field)
  }
  (value, index)
}

///|
fn expect_separator(
  text : String,
  index : Int,
  separator : Char,
  field : String,
) -> (Int, Int) raise AddressError {
  if index >= text.length() || text.get_char(index).unwrap() != separator {
    raise BadFormat(field)
  }
  read_number(text, index + 1, field)
}
