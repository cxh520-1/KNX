// A tunnelling client as a state machine over frames. It owns the channel
// number and the sequence counter, answers incoming requests and tracks the
// one outstanding request that has not been acknowledged yet. The transport is
// the caller's problem, which keeps the state machine testable.

///|
/// Where the client is in the tunnel lifecycle.
pub(all) enum GatewayState {
  Idle
  Connecting
  Connected
  Closed
} derive(Debug, Eq)

///|
/// Tunnelling client state.
pub(all) struct Gateway {
  mut state : GatewayState
  mut channel : Int
  mut sequence : Int
  mut awaiting : Int?
  mut last_cemi : Bytes
  mut log : Array[String]
} derive(Debug, Eq)

///|
pub fn Gateway::new() -> Gateway {
  {
    state: Idle,
    channel: 0,
    sequence: 0,
    awaiting: None,
    last_cemi: b"",
    log: [],
  }
}

///|
/// Start a tunnel: the returned frame is a CONNECT_REQUEST.
pub fn Gateway::connect(self : Gateway, endpoint : @knxip.Hpai) -> Bytes {
  self.state = Connecting
  self.log.push("connect")
  @knxip.connect_request(endpoint, endpoint)
}

///|
/// Wrap a telegram and send it through the open tunnel.
pub fn Gateway::send(self : Gateway, telegram : @telegram.Telegram) -> Bytes? {
  if self.state != Connected {
    self.log.push("send refused")
    return None
  }
  let message = @cemi.LData::from_telegram(@cemi.LDataRequest, telegram)
  let cemi = message.encode() catch { _ => return None }
  let frame = @knxip.tunnelling_request(
    self.channel,
    self.sequence,
    cemi.exact_view(),
  )
  self.awaiting = Some(self.sequence)
  self.last_cemi = cemi
  self.sequence = (self.sequence + 1) % 256
  self.log.push("sent")
  Some(frame)
}

///|
/// Re-send the last telegram, for callers that time out on an ack.
pub fn Gateway::retry(self : Gateway) -> Bytes? {
  match self.awaiting {
    None => None
    Some(sequence) => {
      self.log.push("retry")
      Some(
        @knxip.tunnelling_request(
          self.channel,
          sequence,
          self.last_cemi.exact_view(),
        ),
      )
    }
  }
}

///|
/// Handle one inbound KNX/IP frame and return the frames to send back.
pub fn Gateway::on_frame(self : Gateway, frame : BytesView) -> Array[Bytes] {
  let replies : Array[Bytes] = []
  let packet = @knxip.parse(frame) catch { _ => return replies }
  if packet.service == @knxip.SERVICE_CONNECT_RESPONSE {
    if packet.body.length() >= 2 {
      self.channel = packet.body[0].to_int()
      let status = packet.body[1].to_int()
      self.state = if status == 0 { Connected } else { Idle }
      self.log.push("connect response")
    }
  } else if packet.service == @knxip.SERVICE_TUNNELLING_ACK {
    if packet.body.length() >= 3 {
      let sequence = packet.body[2].to_int()
      match self.awaiting {
        Some(expected) =>
          if expected == sequence {
            self.awaiting = None
            self.log.push("ack")
          }
        None => ()
      }
    }
  } else if packet.service == @knxip.SERVICE_TUNNELLING_REQUEST {
    if packet.body.length() >= 4 {
      let channel = packet.body[1].to_int()
      let sequence = packet.body[2].to_int()
      replies.push(@knxip.tunnelling_ack(channel, sequence, 0))
      self.log.push("inbound request")
    }
  }
  replies
}
