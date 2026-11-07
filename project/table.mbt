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
