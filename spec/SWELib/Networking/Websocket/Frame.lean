/-!
# WebSocket Frame

Frame structure and operations for WebSocket protocol (RFC 6455).

## References
- RFC 6455 Section 5.2: Base Framing Protocol
- RFC 6455 Section 5.3: Client-to-Server Masking
- RFC 6455 Section 5.4: Fragmentation
- RFC 6455 Section 5.5: Control Frames
-/

import SWELib.Networking.Websocket.Types
import SWELib.Basics.Bytes

namespace SWELib.Networking.Websocket

/-- WebSocket frame structure (RFC 6455 Section 5.2). -/
structure WebSocketFrame where
  /-- FIN bit: indicates final fragment (RFC 6455 Section 5.2). -/
  fin : Bool
  /-- RSV1, RSV2, RSV3 bits: reserved for extensions (RFC 6455 Section 5.2). -/
  rsv1 : Bool
  rsv2 : Bool
  rsv3 : Bool
  /-- Frame opcode (RFC 6455 Section 5.2). -/
  opcode : Opcode
  /-- MASK bit: indicates if payload is masked (RFC 6455 Section 5.3). -/
  mask : Bool
  /-- Payload length in bytes (RFC 6455 Section 5.2). -/
  payload_length : Nat
  /-- Masking key (present only if mask=true) (RFC 6455 Section 5.3). -/
  masking_key : Option UInt32
  /-- Application data (RFC 6455 Section 5.2). -/
  payload_data : ByteArray
  deriving DecidableEq, Repr

/-- Maximum payload length for control frames (RFC 6455 Section 5.5). -/
def maxControlFrameLength : Nat := 125

/-- Check if frame is valid according to RFC 6455. -/
def isValidFrame (frame : WebSocketFrame) : Bool :=
  -- Control frames must not be fragmented (RFC 6455 Section 5.5)
  (¬isControlFrame frame.opcode ∨ frame.fin) ∧
  -- Control frames payload ≤ 125 bytes (RFC 6455 Section 5.5)
  (¬isControlFrame frame.opcode ∨ frame.payload_length ≤ maxControlFrameLength) ∧
  -- If mask=true, masking_key must be present
  (frame.mask → frame.masking_key.isSome) ∧
  -- If mask=false, masking_key must be absent
  (¬frame.mask → frame.masking_key.isNone) ∧
  -- Payload length must match actual payload data length
  frame.payload_data.size = frame.payload_length

/-- Apply masking to payload data (RFC 6455 Section 5.3). -/
def maskPayload (data : ByteArray) (key : UInt32) : ByteArray :=
  let maskBytes := key.toByteArrayBE 4
  ⟨data.data.mapIdx (λ i b => b ^^^ maskBytes[i % 4]!)⟩

/-- Remove masking from payload data (RFC 6455 Section 5.3). -/
def unmaskPayload (data : ByteArray) (key : UInt32) : ByteArray :=
  maskPayload data key  -- XOR is its own inverse

/-- Parse a WebSocket frame from bytes (RFC 6455 Section 5.2). -/
def parseFrame (bytes : ByteArray) : Except String WebSocketFrame :=
  if bytes.size < 2 then
    Except.error "Frame too short"
  else
    let b0 := bytes[0]!
    let b1 := bytes[1]!
    let fin := (b0 &&& 0x80) ≠ 0
    let rsv1 := (b0 &&& 0x40) ≠ 0
    let rsv2 := (b0 &&& 0x20) ≠ 0
    let rsv3 := (b0 &&& 0x10) ≠ 0
    let opcodeNum := b0 &&& 0x0F
    let mask := (b1 &&& 0x80) ≠ 0
    let payloadLen1 := b1 &&& 0x7F

    -- Parse payload length
    let (payload_length, offset) :=
      if payloadLen1 < 126 then
        (payloadLen1.toNat, 2)
      else if payloadLen1 = 126 then
        if bytes.size < 4 then
          Except.error "Extended length field incomplete"
        else
          let len := bytes.getUInt16BE 2
          (len.toNat, 4)
      else  -- payloadLen1 = 127
        if bytes.size < 10 then
          Except.error "Extended length field incomplete"
        else
          let len := bytes.getUInt64BE 2
          (len.toNat, 10)

    -- Parse masking key
    let (masking_key, offset') :=
      if mask then
        if bytes.size < offset + 4 then
          Except.error "Masking key incomplete"
        else
          let key := bytes.getUInt32BE offset
          (some key, offset + 4)
      else
        (none, offset)

    -- Parse payload data
    if bytes.size < offset' + payload_length then
      Except.error "Payload data incomplete"
    else
      let payload_data := bytes.extract offset' (offset' + payload_length)

      -- Parse opcode
      let opcode : Opcode :=
        match opcodeNum with
        | 0x0 => .CONTINUATION
        | 0x1 => .TEXT
        | 0x2 => .BINARY
        | 0x8 => .CLOSE
        | 0x9 => .PING
        | 0xA => .PONG
        | _ => .TEXT  -- Should not happen for valid frames

      Except.ok {
        fin := fin
        rsv1 := rsv1
        rsv2 := rsv2
        rsv3 := rsv3
        opcode := opcode
        mask := mask
        payload_length := payload_length
        masking_key := masking_key
        payload_data := payload_data
      }

/-- Serialize a WebSocket frame to bytes (RFC 6455 Section 5.2). -/
def serializeFrame (frame : WebSocketFrame) : ByteArray :=
  let b0 :=
    (if frame.fin then 0x80 else 0) |||
    (if frame.rsv1 then 0x40 else 0) |||
    (if frame.rsv2 then 0x20 else 0) |||
    (if frame.rsv3 then 0x10 else 0) |||
    (opcodeToNum frame.opcode)

  let b1Base := if frame.mask then 0x80 else 0

  let (lengthBytes, lengthSize) :=
    if frame.payload_length < 126 then
      (ByteArray.mk #[frame.payload_length.toUInt8], 1)
    else if frame.payload_length < 65536 then
      let bytes := ByteArray.mkArray 2 (λ i =>
        ((frame.payload_length >>> (8 * (1 - i))) &&& 0xFF).toUInt8)
      (bytes, 2)
    else
      let bytes := ByteArray.mkArray 8 (λ i =>
        ((frame.payload_length >>> (8 * (7 - i))) &&& 0xFF).toUInt8)
      (bytes, 8)

  let b1 := b1Base ||| (if frame.payload_length < 126 then frame.payload_length.toUInt8 else
                       if frame.payload_length < 65536 then 126 else 127)

  let header := ByteArray.mk #[b0, b1] ++ lengthBytes

  let keyBytes :=
    match frame.masking_key with
    | some key => key.toByteArrayBE 4
    | none => ByteArray.empty

  let payload :=
    match frame.masking_key with
    | some key => maskPayload frame.payload_data key
    | none => frame.payload_data

  header ++ keyBytes ++ payload
where
  opcodeToNum : Opcode → UInt8
    | .CONTINUATION => 0x0
    | .TEXT => 0x1
    | .BINARY => 0x2
    | .CLOSE => 0x8
    | .PING => 0x9
    | .PONG => 0xA

/-- Theorem: Masking and unmasking are inverses. -/
theorem mask_unmask_inverse (data : ByteArray) (key : UInt32) :
    unmaskPayload (maskPayload data key) key = data := by
  simp [maskPayload, unmaskPayload]
  sorry

/-- Theorem: Parse then serialize returns original frame for valid frames. -/
theorem parse_serialize_roundtrip (frame : WebSocketFrame) (h : isValidFrame frame) :
    parseFrame (serializeFrame frame) = Except.ok frame := by
  sorry

/-- Theorem: Client frames must be masked (RFC 6455 Section 5.3). -/
theorem client_frames_masked (frame : WebSocketFrame) (isClient : Bool) :
    isClient → frame.mask := by
  intro hClient
  sorry

/-- Theorem: Control frames cannot be fragmented (RFC 6455 Section 5.5). -/
theorem control_frames_not_fragmented (frame : WebSocketFrame) (h : isControlFrame frame.opcode) :
    frame.fin := by
  sorry

/-- Theorem: Control frames payload length ≤ 125 (RFC 6455 Section 5.5). -/
theorem control_frames_length_limit (frame : WebSocketFrame) (h : isControlFrame frame.opcode) :
    frame.payload_length ≤ maxControlFrameLength := by
  sorry

end SWELib.Networking.Websocket