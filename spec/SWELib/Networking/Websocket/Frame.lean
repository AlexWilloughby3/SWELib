import SWELib.Networking.Websocket.Types
import SWELib.Basics.Bytes

/-!
# WebSocket Frame

Frame structure and operations for WebSocket protocol (RFC 6455).

## References
- RFC 6455 Section 5.2: Base Framing Protocol
- RFC 6455 Section 5.3: Client-to-Server Masking
- RFC 6455 Section 5.4: Fragmentation
- RFC 6455 Section 5.5: Control Frames
-/

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
  deriving DecidableEq

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

/-- Convert a UInt32 to a 4-byte big-endian ByteArray. -/
def uint32ToBytesBE (v : UInt32) : ByteArray :=
  ByteArray.mk #[
    (v >>> 24).toUInt8,
    (v >>> 16).toUInt8,
    (v >>> 8).toUInt8,
    v.toUInt8
  ]

/-- Read a big-endian UInt16 from a ByteArray at the given offset. -/
def getUInt16BE (bytes : ByteArray) (off : Nat) : UInt16 :=
  let b0 := bytes[off]!.toUInt16
  let b1 := bytes[off + 1]!.toUInt16
  (b0 <<< 8) ||| b1

/-- Read a big-endian UInt32 from a ByteArray at the given offset. -/
def getUInt32BE (bytes : ByteArray) (off : Nat) : UInt32 :=
  let b0 := bytes[off]!.toUInt32
  let b1 := bytes[off + 1]!.toUInt32
  let b2 := bytes[off + 2]!.toUInt32
  let b3 := bytes[off + 3]!.toUInt32
  (b0 <<< 24) ||| (b1 <<< 16) ||| (b2 <<< 8) ||| b3

/-- Read a big-endian UInt64 from a ByteArray at the given offset. -/
def getUInt64BE (bytes : ByteArray) (off : Nat) : UInt64 :=
  let hi := (getUInt32BE bytes off).toUInt64
  let lo := (getUInt32BE bytes (off + 4)).toUInt64
  (hi <<< 32) ||| lo

/-- Apply masking to payload data (RFC 6455 Section 5.3). -/
def maskPayload (data : ByteArray) (key : UInt32) : ByteArray :=
  let maskBytes := uint32ToBytesBE key
  ⟨data.data.mapIdx (λ i b => b ^^^ maskBytes[i % 4]!)⟩

/-- Remove masking from payload data (RFC 6455 Section 5.3). -/
def unmaskPayload (data : ByteArray) (key : UInt32) : ByteArray :=
  maskPayload data key  -- XOR is its own inverse

/-- Parse a WebSocket frame from bytes (RFC 6455 Section 5.2). -/
def parseFrame (bytes : ByteArray) : Except String WebSocketFrame := do
  if bytes.size < 2 then
    throw "Frame too short"
  let b0 := bytes[0]!
  let b1 := bytes[1]!
  let fin := (b0 &&& 0x80) ≠ 0
  let rsv1 := (b0 &&& 0x40) ≠ 0
  let rsv2 := (b0 &&& 0x20) ≠ 0
  let rsv3 := (b0 &&& 0x10) ≠ 0
  let opcodeNum := b0 &&& 0x0F
  let maskBit := (b1 &&& 0x80) ≠ 0
  let payloadLen1 := b1 &&& 0x7F

  -- Parse payload length
  let (payload_length, offset) ←
    if payloadLen1 < 126 then
      pure (payloadLen1.toNat, 2)
    else if payloadLen1 = 126 then
      if bytes.size < 4 then
        throw "Extended length field incomplete"
      else
        let len := getUInt16BE bytes 2
        pure (len.toNat, 4)
    else  -- payloadLen1 = 127
      if bytes.size < 10 then
        throw "Extended length field incomplete"
      else
        let len := getUInt64BE bytes 2
        pure (len.toNat, 10)

  -- Parse masking key
  let (masking_key, offset') ←
    if maskBit then
      if bytes.size < offset + 4 then
        throw "Masking key incomplete"
      else
        let key := getUInt32BE bytes offset
        pure (some key, offset + 4)
    else
      pure (none, offset)

  -- Parse payload data
  if bytes.size < offset' + payload_length then
    throw "Payload data incomplete"
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

  pure {
    fin := fin
    rsv1 := rsv1
    rsv2 := rsv2
    rsv3 := rsv3
    opcode := opcode
    mask := maskBit
    payload_length := payload_length
    masking_key := masking_key
    payload_data := payload_data
  }

/-- Serialize a WebSocket frame to bytes (RFC 6455 Section 5.2). -/
def serializeFrame (frame : WebSocketFrame) : ByteArray :=
  let b0 : UInt8 :=
    (if frame.fin then 0x80 else 0) |||
    (if frame.rsv1 then 0x40 else 0) |||
    (if frame.rsv2 then 0x20 else 0) |||
    (if frame.rsv3 then 0x10 else 0) |||
    (opcodeToNum frame.opcode)

  let b1Base : UInt8 := if frame.mask then 0x80 else 0

  let lengthBytes :=
    if frame.payload_length < 126 then
      ByteArray.empty
    else if frame.payload_length < 65536 then
      ByteArray.mk #[
        (frame.payload_length >>> 8).toUInt8,
        frame.payload_length.toUInt8]
    else
      ByteArray.mk #[
        (frame.payload_length >>> 56).toUInt8,
        (frame.payload_length >>> 48).toUInt8,
        (frame.payload_length >>> 40).toUInt8,
        (frame.payload_length >>> 32).toUInt8,
        (frame.payload_length >>> 24).toUInt8,
        (frame.payload_length >>> 16).toUInt8,
        (frame.payload_length >>> 8).toUInt8,
        frame.payload_length.toUInt8]

  let b1 : UInt8 := b1Base ||| (if frame.payload_length < 126 then frame.payload_length.toUInt8 else
                       if frame.payload_length < 65536 then 126 else 127)

  let header := ByteArray.mk #[b0, b1] ++ lengthBytes

  let keyBytes :=
    match frame.masking_key with
    | some key => uint32ToBytesBE key
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

/-- XOR is self-inverse at the byte level. -/
private theorem UInt8.xor_self_inverse (a b : UInt8) : (a ^^^ b) ^^^ b = a := by
  cases a with | ofBitVec av => cases b with | ofBitVec bv =>
  show UInt8.ofBitVec ((av ^^^ bv) ^^^ bv) = UInt8.ofBitVec av
  congr 1; rw [BitVec.xor_assoc, BitVec.xor_self, BitVec.xor_zero]

/-- Double application of mapIdx with XOR against the same mask is identity. -/
private theorem mapIdx_xor_self_inverse (arr : Array UInt8) (mask : ByteArray) :
    Array.mapIdx (fun i b => b ^^^ mask[i % 4]!)
      (Array.mapIdx (fun i b => b ^^^ mask[i % 4]!) arr) = arr := by
  ext i
  · simp [Array.size_mapIdx]
  · simp [Array.getElem_mapIdx, UInt8.xor_self_inverse]

/-- Theorem: Masking and unmasking are inverses (RFC 6455 Section 5.3). -/
theorem mask_unmask_inverse (data : ByteArray) (key : UInt32) :
    unmaskPayload (maskPayload data key) key = data := by
  simp only [unmaskPayload, maskPayload, uint32ToBytesBE]
  rw [mapIdx_xor_self_inverse]

/-- Theorem: Unmasking a masked payload recovers the original data. -/
theorem unmask_mask_inverse (data : ByteArray) (key : UInt32) :
    maskPayload (unmaskPayload data key) key = data := by
  -- unmaskPayload = maskPayload, so this is the same as mask_unmask_inverse
  exact mask_unmask_inverse data key

/-- Theorem: Valid control frames are not fragmented (RFC 6455 Section 5.5). -/
theorem valid_control_frames_not_fragmented (frame : WebSocketFrame)
    (hValid : isValidFrame frame = true) (hCtrl : isControlFrame frame.opcode = true) :
    frame.fin = true := by
  unfold isValidFrame at hValid
  simp only [decide_eq_true_eq] at hValid
  obtain ⟨hFin, _⟩ := hValid
  simp [hCtrl] at hFin; exact hFin

/-- Theorem: Valid control frames have payload ≤ 125 bytes (RFC 6455 Section 5.5). -/
theorem valid_control_frames_length_limit (frame : WebSocketFrame)
    (hValid : isValidFrame frame = true) (hCtrl : isControlFrame frame.opcode = true) :
    frame.payload_length ≤ maxControlFrameLength := by
  unfold isValidFrame at hValid
  simp only [decide_eq_true_eq] at hValid
  obtain ⟨_, hLen, _⟩ := hValid
  simp [hCtrl] at hLen; exact hLen

end SWELib.Networking.Websocket
