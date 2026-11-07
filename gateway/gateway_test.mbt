// Gateway tests drive the state machine with frames, not sockets: a connect
// response opens the tunnel, a send consumes a sequence number, and an ack
// clears the outstanding request.

///|
fn gateway() -> Gateway {
  Gateway::new()
}

///|
fn endpoint() -> @knxip.Hpai {
  @knxip.Hpai::new(192, 168, 1, 10, 3671)
}

///|
test "connect returns a connect request" {
  let client = gateway()
  let frame = client.connect(endpoint())
  assert_eq(
    @knxip.parse(frame.exact_view()).service,
    @knxip.SERVICE_CONNECT_REQUEST,
  )
  assert_true(client.state == Connecting)
}

///|
test "connect response opens the tunnel" {
  let client = gateway()
  ignore(client.connect(endpoint()))
  let response = @knxip.connect_response(7, endpoint())
  ignore(client.on_frame(response.exact_view()))
  assert_true(client.state == Connected)
  assert_eq(client.channel, 7)
}

///|
test "send consumes a sequence number" {
  let client = gateway()
  ignore(client.connect(endpoint()))
  ignore(client.on_frame(@knxip.connect_response(3, endpoint()).exact_view()))
  let telegram = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.1"),
    @telegram.Group(@addrmodel.GroupAddress::parse("2/1/1")),
    b"\x00\x81",
  )
  match client.send(telegram) {
    None => fail("send refused")
    Some(frame) => {
      let packet = @knxip.parse(frame.exact_view())
      assert_eq(packet.service, @knxip.SERVICE_TUNNELLING_REQUEST)
      assert_eq(client.awaiting, Some(0))
      assert_eq(client.sequence, 1)
    }
  }
}

///|
test "ack clears the outstanding request" {
  let client = gateway()
  ignore(client.connect(endpoint()))
  ignore(client.on_frame(@knxip.connect_response(3, endpoint()).exact_view()))
  let telegram = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.1"),
    @telegram.Group(@addrmodel.GroupAddress::parse("2/1/1")),
    b"\x00\x81",
  )
  ignore(client.send(telegram))
  ignore(client.on_frame(@knxip.tunnelling_ack(3, 0, 0).exact_view()))
  assert_true(client.awaiting is None)
}

///|
test "inbound request is acknowledged" {
  let client = gateway()
  ignore(client.connect(endpoint()))
  ignore(client.on_frame(@knxip.connect_response(3, endpoint()).exact_view()))
  let inbound = @knxip.tunnelling_request(3, 9, b"\x11\x00")
  let replies = client.on_frame(inbound.exact_view())
  assert_eq(replies.length(), 1)
  let ack = @knxip.parse(replies[0].exact_view())
  assert_eq(ack.service, @knxip.SERVICE_TUNNELLING_ACK)
  assert_eq(ack.body[2].to_int(), 9)
}

///|
test "send before connect is refused" {
  let client = gateway()
  let telegram = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.1"),
    @telegram.Group(@addrmodel.GroupAddress::parse("2/1/1")),
    b"\x00\x81",
  )
  assert_true(client.send(telegram) is None)
}

///|
test "routing lost messages are counted" {
  let client = gateway()
  ignore(client.on_frame(@knxip.routing_lost_message().exact_view()))
  assert_eq(client.lost, 1)
  assert_eq(client.log.length(), 1)
}

///|
test "retry reuses the outstanding sequence" {
  let client = gateway()
  ignore(client.connect(endpoint()))
  ignore(client.on_frame(@knxip.connect_response(3, endpoint()).exact_view()))
  let telegram = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.1"),
    @telegram.Group(@addrmodel.GroupAddress::parse("2/1/1")),
    b"\x00\x81",
  )
  ignore(client.send(telegram))
  match client.retry() {
    None => fail("expected a retry frame")
    Some(frame) => {
      let header = @knxip.parse_tunnel_header(
        @knxip.parse(frame.exact_view()).body.exact_view(),
      )
      assert_eq(header.sequence, 0)
    }
  }
}

///|
test "ack for another sequence keeps the request pending" {
  let client = gateway()
  ignore(client.connect(endpoint()))
  ignore(client.on_frame(@knxip.connect_response(3, endpoint()).exact_view()))
  let telegram = @telegram.Telegram::new(
    @addrmodel.IndividualAddress::parse("1.1.1"),
    @telegram.Group(@addrmodel.GroupAddress::parse("2/1/1")),
    b"\x00\x81",
  )
  ignore(client.send(telegram))
  ignore(client.on_frame(@knxip.tunnelling_ack(3, 5, 0).exact_view()))
  assert_eq(client.awaiting, Some(0))
}

///|
test "state and log are readable" {
  let client = gateway()
  assert_eq(client.state_name(), "idle")
  ignore(client.connect(endpoint()))
  assert_true(client.log_text().contains("connect"))
}

///|
test "disconnect closes an open tunnel" {
  let client = gateway()
  ignore(client.connect(endpoint()))
  ignore(client.on_frame(@knxip.connect_response(3, endpoint()).exact_view()))
  match client.disconnect() {
    None => fail("expected a disconnect frame")
    Some(frame) => {
      assert_eq(
        @knxip.parse(frame.exact_view()).service,
        @knxip.SERVICE_DISCONNECT_REQUEST,
      )
      assert_true(client.state == Closed)
    }
  }
}

///|
test "disconnect before connect is refused" {
  let client = gateway()
  assert_true(client.disconnect() is None)
}

///|
test "accessors expose channel and pending state" {
  let client = gateway()
  ignore(client.connect(endpoint()))
  ignore(client.on_frame(@knxip.connect_response(3, endpoint()).exact_view()))
  assert_eq(client.channel_number(), 3)
  assert_true(client.pending() is None)
}
