// A small project table: which group address carries which data point type.
// Real installations have hundreds of entries and duplicate addresses are a
// common commissioning mistake, so the table rejects them at parse time.

///|
/// Table failures.
pub(all) suberror ProjectError {
  BadLine(Int, String)
  Duplicate(String)
  UnknownDpt(String)
  Empty
}

///|
/// One group address assignment.
pub(all) struct Entry {
  address : @addrmodel.GroupAddress
  dpt : @datapoint.Dpt
  name : String
} derive(Debug, Eq)

///|
pub(all) struct Table {
  entries : Array[Entry]
} derive(Debug, Eq)

///|
/// Parse a table where each non-empty, non-comment line is
/// `1/2/3 = DPT1 name`.
pub fn Table::parse(text : String) -> Table raise ProjectError {
  let entries : Array[Entry] = []
  let lines = split_lines(text)
  for index in 0..<lines.length() {
    let line = trim(lines[index])
    if line.length() == 0 || line.get_char(0).unwrap() == '#' {
      continue
    }
    let entry = parse_line(line, index + 1, entries)
    entries.push(entry)
  }
  if entries.length() == 0 {
    raise Empty
  }
  { entries, }
}

///|
fn parse_line(
  line : String,
  number : Int,
  existing : Array[Entry],
) -> Entry raise ProjectError {
  let equals = index_of(line, '=')
  if equals < 0 {
    raise BadLine(number, line)
  }
  let address_text = trim(substring(line, 0, equals))
  let rest = trim(substring(line, equals + 1, line.length()))
  if rest.length() == 0 {
    raise BadLine(number, line)
  }
  let space = index_of(rest, ' ')
  let dpt_text = if space < 0 { rest } else { substring(rest, 0, space) }
  let name = if space < 0 {
    ""
  } else {
    trim(substring(rest, space + 1, rest.length()))
  }
  let dpt = match dpt_of(dpt_text) {
    Some(dpt) => dpt
    None => raise UnknownDpt(dpt_text)
  }
  let address = @addrmodel.GroupAddress::parse(address_text) catch {
    _ => raise BadLine(number, line)
  }
  for entry in existing {
    if entry.address == address {
      raise Duplicate(address_text)
    }
  }
  { address, dpt, name, }
}

///|
pub fn Table::find(self : Table, address : @addrmodel.GroupAddress) -> Entry? {
  let mut found : Entry? = None
  for entry in self.entries {
    if entry.address == address {
      found = Some(entry)
    }
  }
  found
}

///|
pub fn Table::size(self : Table) -> Int {
  self.entries.length()
}

///|
pub fn Table::report(self : Table) -> String {
  let mut out = "entries=" + self.entries.length().to_string()
  for entry in self.entries {
    out = out +
      "\n" +
      entry.address.to_text() +
      "  " +
      @datapoint.name(entry.dpt)
    if entry.name.length() > 0 {
      out = out + "  " + entry.name
    }
  }
  out
}

///|
pub fn dpt_of(text : String) -> @datapoint.Dpt? {
  match text {
    "DPT1" => Some(@datapoint.Dpt1)
    "DPT5" => Some(@datapoint.Dpt5)
    "DPT6" => Some(@datapoint.Dpt6)
    "DPT7" => Some(@datapoint.Dpt7)
    "DPT8" => Some(@datapoint.Dpt8)
    "DPT9" => Some(@datapoint.Dpt9)
    "DPT10" => Some(@datapoint.Dpt10)
    "DPT11" => Some(@datapoint.Dpt11)
    "DPT12" => Some(@datapoint.Dpt12)
    "DPT13" => Some(@datapoint.Dpt13)
    "DPT14" => Some(@datapoint.Dpt14)
    "DPT16" => Some(@datapoint.Dpt16)
    "DPT17" => Some(@datapoint.Dpt17)
    "DPT5PCT" => Some(@datapoint.Dpt5Percent)
    _ => None
  }
}

///|
fn split_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  let current = StringBuilder()
  for index in 0..<text.length() {
    let ch = text.get_char(index).unwrap()
    if ch == '\n' {
      lines.push(current.to_string())
      current.reset()
    } else {
      current.write_char(ch)
    }
  }
  if current.to_string().length() > 0 {
    lines.push(current.to_string())
  }
  lines
}

///|
fn trim(text : String) -> String {
  let mut start = 0
  let mut end = text.length()
  while start < end && is_space(text.get_char(start).unwrap()) {
    start = start + 1
  }
  while end > start && is_space(text.get_char(end - 1).unwrap()) {
    end = end - 1
  }
  substring(text, start, end)
}

///|
fn is_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r'
}

///|
fn index_of(text : String, target : Char) -> Int {
  let mut found = -1
  let mut index = 0
  while index < text.length() {
    if text.get_char(index).unwrap() == target && found < 0 {
      found = index
    }
    index = index + 1
  }
  found
}

///|
fn substring(text : String, start : Int, end : Int) -> String {
  let out = StringBuilder()
  for index in start..<end {
    out.write_char(text.get_char(index).unwrap())
  }
  out.to_string()
}

///|
/// Merge another table, refusing any address that already exists.
pub fn Table::merge(self : Table, other : Table) -> Table raise ProjectError {
  let entries : Array[Entry] = []
  for entry in self.entries {
    entries.push(entry)
  }
  for entry in other.entries {
    for existing in entries {
      if existing.address == entry.address {
        raise Duplicate(entry.address.to_text())
      }
    }
    entries.push(entry)
  }
  { entries, }
}

///|
/// Render the table back to the line format, so a parsed table can be edited
/// and saved again.
pub fn Table::to_text(self : Table) -> String {
  let mut out = ""
  for entry in self.entries {
    out = out + entry.address.to_text() + " = " + dpt_code(entry.dpt)
    if entry.name.length() > 0 {
      out = out + " " + entry.name
    }
    out = out + "\n"
  }
  out
}

///|
pub fn dpt_code(dpt : @datapoint.Dpt) -> String {
  match dpt {
    @datapoint.Dpt1 => "DPT1"
    @datapoint.Dpt5 => "DPT5"
    @datapoint.Dpt5Percent => "DPT5PCT"
    @datapoint.Dpt6 => "DPT6"
    @datapoint.Dpt7 => "DPT7"
    @datapoint.Dpt8 => "DPT8"
    @datapoint.Dpt9 => "DPT9"
    @datapoint.Dpt10 => "DPT10"
    @datapoint.Dpt11 => "DPT11"
    @datapoint.Dpt12 => "DPT12"
    @datapoint.Dpt13 => "DPT13"
    @datapoint.Dpt14 => "DPT14"
    @datapoint.Dpt16 => "DPT16"
    @datapoint.Dpt17 => "DPT17"
  }
}

///|
/// Count entries per data point code, in first-seen order.
pub fn Table::counts(self : Table) -> Array[(String, Int)] {
  let result : Array[(String, Int)] = []
  for entry in self.entries {
    let code = dpt_code(entry.dpt)
    let mut found = -1
    for index in 0..<result.length() {
      if result[index].0 == code {
        found = index
      }
    }
    if found < 0 {
      result.push((code, 1))
    } else {
      result[found] = (code, result[found].1 + 1)
    }
  }
  result
}

///|
/// Addresses in table order, for callers that only need the keys.
pub fn Table::addresses(self : Table) -> Array[@addrmodel.GroupAddress] {
  let result : Array[@addrmodel.GroupAddress] = []
  for entry in self.entries {
    result.push(entry.address)
  }
  result
}
