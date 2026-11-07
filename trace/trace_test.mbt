// Trace tests check the words a person reads, not the bytes.

///|
test "connect response is described" {
  let frame = @knxip.connect_response(
    7,
    @knxip.Hpai::new(192, 168, 1, 10, 3671),
  )
  let text = describe(frame.exact_view())
  assert_true(text.contains("CONNECT_RESPONSE"))
  assert_true(text.contains("channel=7"))
}

///|
test "tunnelling request explains the telegram" {
  let cemi = b"\x11\x00\xBC\x80\x11\x01\x11\x01\x81\x00\x81"
  let frame = @knxip.tunnelling_request(1, 0, cemi.exact_view())
  let text = describe(frame.exact_view())
  assert_true(text.contains("TUNNELLING_REQUEST"))
  assert_true(text.contains("GroupWrite"))
  assert_true(text.contains("value=1"))
}

///|
test "garbage is reported as invalid" {
  assert_eq(describe(b"\x00\x01".exact_view()), "invalid KNX/IP frame")
}

///|
test "verbose description appends the body" {
  let frame = @knxip.tunnelling_ack(1, 2, 0)
  let text = describe_verbose(frame.exact_view())
  assert_true(text.contains("TUNNELLING_ACK"))
  assert_true(text.contains("body=0401"))
}

///|
test "capture keeps the frame order" {
  let frames = [
    @knxip.connect_response(1, @knxip.Hpai::new(192, 168, 1, 10, 3671)),
    @knxip.tunnelling_ack(1, 0, 0),
  ]
  let text = describe_capture(frames)
  assert_true(text.contains("#1 CONNECT_RESPONSE"))
  assert_true(text.contains("#2 TUNNELLING_ACK"))
}

///|
test "a bare cemi body can be described" {
  let text = describe_cemi(
    b"\x11\x00\xBC\x80\x11\x01\x11\x01\x81\x00\x81".exact_view(),
  )
  assert_true(text.contains("2/1/1 (group)"))
  assert_true(text.contains("GroupWrite"))
}

///|
test "empty capture is empty text" {
  let frames : Array[Bytes] = []
  assert_eq(describe_capture(frames), "")
}

///|
test "empty frame list has no body" {
  let none : Array[Bytes] = []
  assert_eq(describe_capture(none).length(), 0)
}
