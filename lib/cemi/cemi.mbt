// cEMI is what a KNX/IP gateway carries inside a tunnelling request: the
// telegram plus a message code saying whether it is a request, an indication
// or a confirmation. It is the bridge between the frame layer in this library
// and a real network interface.

///|
/// cEMI failures.
pub(all) suberror CemiError {
  TooShort(Int)
  BadMessageCode(Int)
  BadAdditionalInfo(Int)
  BadLength(Int)
}

///|
/// Which direction a cEMI message describes.
pub(all) enum MessageCode {
  LDataRequest
  LDataIndication
  LDataConfirmation
} derive(Debug, Eq)

///|
pub fn MessageCode::code(self : MessageCode) -> Int {
  match self {
    LDataRequest => 0x11
    LDataIndication => 0x29
    LDataConfirmation => 0x2E
  }
}

///|
pub fn message_code(value : Int) -> MessageCode? {
  match value {
    0x11 => Some(LDataRequest)
    0x29 => Some(LDataIndication)
    0x2E => Some(LDataConfirmation)
    _ => None
  }
}

///|
/// One cEMI L_Data message.
pub(all) struct LData {
  code : MessageCode
  control1 : Int
  control2 : Int
  source : @addrmodel.IndividualAddress
  destination : @telegram.Destination
  tpdu : Bytes
} derive(Debug, Eq)

///|
/// Build a request from a telegram, keeping the same control and NPCI bits.
pub fn LData::from_telegram(
  code : MessageCode,
  telegram : @telegram.Telegram,
) -> LData {
  let control2 = match telegram.destination {
    @telegram.Group(_) => 0x80
    @telegram.Individual(_) => 0x00
  }
  {
    code,
    control1: telegram.control,
    control2,
    source: telegram.source,
    destination: telegram.destination,
    tpdu: telegram.tpdu,
  }
}

///|
pub fn LData::to_telegram(self : LData) -> @telegram.Telegram {
  @telegram.Telegram::new(self.source, self.destination, self.tpdu)
}

///|
pub fn LData::encode(self : LData) -> Bytes raise CemiError {
  let payload_length = self.tpdu.length()
  if payload_length < 1 || payload_length > 16 {
    raise BadLength(payload_length)
  }
  let (is_group, destination_word) = match self.destination {
    @telegram.Group(address) => (true, address.to_u16())
    @telegram.Individual(address) => (false, address.to_u16())
  }
  let npci = (if is_group { 0x80 } else { 0x00 }) | (payload_length - 1)
  let out = Buffer()
  out.write_byte(self.code.code().to_byte())
  out.write_byte(0x00)
  out.write_byte(self.control1.to_byte())
  out.write_byte(self.control2.to_byte())
  out.write_byte(((self.source.to_u16() >> 8) & 0xFF).to_byte())
  out.write_byte((self.source.to_u16() & 0xFF).to_byte())
  out.write_byte(((destination_word >> 8) & 0xFF).to_byte())
  out.write_byte((destination_word & 0xFF).to_byte())
  out.write_byte(npci.to_byte())
  out.write_bytes(self.tpdu.exact_view())
  out.to_bytes()
}

///|
pub fn LData::decode(data : BytesView) -> LData raise CemiError {
  if data.length() < 10 {
    raise TooShort(data.length())
  }
  let code = match message_code(data[0].to_int()) {
    Some(code) => code
    None => raise BadMessageCode(data[0].to_int())
  }
  let additional = data[1].to_int()
  if additional != 0 {
    raise BadAdditionalInfo(additional)
  }
  let control1 = data[2].to_int()
  let control2 = data[3].to_int()
  let source = @addrmodel.IndividualAddress::from_u16(
    (data[4].to_int() << 8) | data[5].to_int(),
  )
  let destination_word = (data[6].to_int() << 8) | data[7].to_int()
  let npci = data[8].to_int()
  let is_group = (npci & 0x80) != 0
  let payload_length = (npci & 0x0F) + 1
  if data.length() != 9 + payload_length {
    raise BadLength(data.length())
  }
  let tpdu = data[9:9 + payload_length]
  let destination = if is_group {
    @telegram.Group(@addrmodel.GroupAddress::from_u16(destination_word))
  } else {
    @telegram.Individual(
      @addrmodel.IndividualAddress::from_u16(destination_word),
    )
  }
  { code, control1, control2, source, destination, tpdu: copy(tpdu), }
}

///|
fn copy(view : BytesView) -> Bytes {
  let out = Buffer()
  out.write_bytes(view)
  out.to_bytes()
}
