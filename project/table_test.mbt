// Table tests cover the three ways a commissioning file goes wrong: a line
// without a separator, an unknown data point name, and the same group address
// used twice.

///|
test "table parses assignments and names" {
  let table = Table::parse(
    "# rooms\n1/2/1 = DPT1 living room lamp\n1/2/2 = DPT5 dimmer\n\n1/2/3 = DPT9 temperature\n",
  )
  assert_eq(table.size(), 3)
  assert_eq(
    table.find(@addrmodel.GroupAddress::parse("1/2/2")).unwrap().name,
    "dimmer",
  )
  let report = table.report()
  assert_true(report.contains("entries=3"))
}

///|
test "duplicate address is refused" {
  let caught = try {
    ignore(Table::parse("1/2/1 = DPT1 a\n1/2/1 = DPT5 b"))
    false
  } catch {
    ProjectError::Duplicate(address) => address == "1/2/1"
    _ => false
  }
  assert_true(caught)
}

///|
test "unknown data point is refused" {
  let caught = try {
    ignore(Table::parse("1/2/1 = DPT99 a"))
    false
  } catch {
    ProjectError::UnknownDpt(name) => name == "DPT99"
    _ => false
  }
  assert_true(caught)
}

///|
test "line without separator is refused" {
  let caught = try {
    ignore(Table::parse("1/2/1 DPT1 a"))
    false
  } catch {
    ProjectError::BadLine(_, _) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "empty table is refused" {
  let caught = try {
    ignore(Table::parse("\n# only a comment\n"))
    false
  } catch {
    ProjectError::Empty => true
    _ => false
  }
  assert_true(caught)
}

///|
test "merge refuses a shared address" {
  let first = Table::parse("1/2/1 = DPT1 a")
  let second = Table::parse("1/2/1 = DPT5 b")
  let caught = try {
    ignore(first.merge(second))
    false
  } catch {
    ProjectError::Duplicate(_) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "merged table keeps both entries" {
  let first = Table::parse("1/2/1 = DPT1 a")
  let second = Table::parse("1/2/2 = DPT5 b")
  assert_eq(first.merge(second).size(), 2)
}

///|
test "table renders back to its line format" {
  let table = Table::parse("1/2/1 = DPT1 a\n1/2/2 = DPT9 温度\n")
  let text = table.to_text()
  assert_true(text.contains("1/2/1 = DPT1 a"))
  assert_true(text.contains("1/2/2 = DPT9 温度"))
  assert_eq(Table::parse(text).size(), 2)
}

///|
test "counts group entries by data point" {
  let table = Table::parse("1/2/1 = DPT1 a\n1/2/2 = DPT1 b\n1/2/3 = DPT9 c")
  let counts = table.counts()
  assert_eq(counts.length(), 2)
  assert_eq(counts[0].0, "DPT1")
  assert_eq(counts[0].1, 2)
}

///|
test "addresses are returned in table order" {
  let table = Table::parse("1/2/3 = DPT1 a\n1/2/1 = DPT1 b")
  let addresses = table.addresses()
  assert_eq(addresses.length(), 2)
  assert_eq(addresses[0].to_text(), "1/2/3")
}
