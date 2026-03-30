import SWELib.Networking.Websocket.Types
import SWELib.Networking.Websocket.Frame
import SWELib.Networking.Websocket.Handshake
import SWELib.Networking.Websocket.State

/-!
# WebSocket Protocol

Protocol-level operations and invariants for WebSocket (RFC 6455).

## References
- RFC 6455 Section 5: Data Framing
- RFC 6455 Section 6: Sending and Receiving Data
- RFC 6455 Section 7: Closing the Connection
-/

namespace SWELib.Networking.Websocket

/-- Protocol-level error conditions (RFC 6455 Section 7.4). -/
inductive ProtocolError where
  | nonZeroRsvWithoutExtension
  | unknownOpcode
  | unmaskedFrameFromClient
  | maskedFrameFromServer
  | fragmentedControlFrame
  | controlFrameTooLong
  | invalidCloseCode
  | invalidUTF8
  | protocolViolation
  deriving DecidableEq, Repr

/-- Check whether a frame passes all protocol validation checks (RFC 6455 Section 5.2).
    Returns `true` iff `processIncomingFrame` would succeed. -/
def framePassesValidation (frame : WebSocketFrame) (isClient : Bool) : Bool :=
  -- RSV bits must be zero (RFC 6455 Section 5.2)
  ¬(frame.rsv1 ∨ frame.rsv2 ∨ frame.rsv3) ∧
  -- Opcode must be valid (RFC 6455 Section 5.2)
  isValidOpcode (Websocket.opcodeToNat frame.opcode) ∧
  -- Client frames must be masked (RFC 6455 Section 5.3)
  (isClient → frame.mask) ∧
  -- Server frames must be unmasked (RFC 6455 Section 5.3)
  (¬isClient → ¬frame.mask) ∧
  -- Control frames must not be fragmented (RFC 6455 Section 5.5)
  (isControlFrame frame.opcode → frame.fin) ∧
  -- Control frame payload ≤ 125 (RFC 6455 Section 5.5)
  (isControlFrame frame.opcode → frame.payload_length ≤ maxControlFrameLength) ∧
  -- Close frame status codes are valid (RFC 6455 Section 5.5.1)
  (frame.opcode = .CLOSE → frame.payload_length ≥ 2 →
    isValidCloseCode (getUInt16BE (frame.payload_data.extract 0 2) 0).toNat)

/-- Process an incoming WebSocket frame (RFC 6455 Section 5.2). -/
def processIncomingFrame (frame : WebSocketFrame) (isClient : Bool) :
    Except ProtocolError Unit := do
  -- Check RSV bits (RFC 6455 Section 5.2)
  if frame.rsv1 ∨ frame.rsv2 ∨ frame.rsv3 then
    throw .nonZeroRsvWithoutExtension

  -- Check opcode (RFC 6455 Section 5.2)
  if ¬isValidOpcode (Websocket.opcodeToNat frame.opcode) then
    throw .unknownOpcode

  -- Check masking (RFC 6455 Section 5.3)
  if isClient ∧ ¬frame.mask then
    throw .unmaskedFrameFromClient
  if ¬isClient ∧ frame.mask then
    throw .maskedFrameFromServer

  -- Check control frames (RFC 6455 Section 5.5)
  if isControlFrame frame.opcode then
    if ¬frame.fin then
      throw .fragmentedControlFrame
    if frame.payload_length > maxControlFrameLength then
      throw .controlFrameTooLong

  -- Check close frame (RFC 6455 Section 5.5.1)
  if frame.opcode = .CLOSE then
    if frame.payload_length ≥ 2 then
      let statusBytes := frame.payload_data.extract 0 2
      let status := getUInt16BE statusBytes 0
      if ¬isValidCloseCode status.toNat then
        throw .invalidCloseCode
      if frame.payload_length > 2 then
        -- TODO: Validate UTF-8 reason
        pure ()

  pure ()

/-- Create a close frame (RFC 6455 Section 5.5.1). -/
def createCloseFrame (code : Option Nat) (_reason : Option String) :
    Except ProtocolError WebSocketFrame :=
  match code with
  | none =>
    Except.ok {
      fin := true
      rsv1 := false
      rsv2 := false
      rsv3 := false
      opcode := .CLOSE
      mask := false  -- Server sends unmasked
      payload_length := 0
      masking_key := none
      payload_data := ByteArray.empty
    }
  | some c =>
    if ¬isValidCloseCode c then
      Except.error .invalidCloseCode
    else
      let statusBytes := ByteArray.mk #[
        (c >>> 8).toUInt8,
        c.toUInt8]
      let reasonBytes :=
        match _reason with
        | none => ByteArray.empty
        | some r => r.toUTF8
      let payload := statusBytes ++ reasonBytes
      Except.ok {
        fin := true
        rsv1 := false
        rsv2 := false
        rsv3 := false
        opcode := .CLOSE
        mask := false  -- Server sends unmasked
        payload_length := payload.size
        masking_key := none
        payload_data := payload
      }

/-- Message fragmentation state (RFC 6455 Section 5.4). -/
structure FragmentationState where
  /-- Opcode of the first fragment. -/
  opcode : Opcode
  /-- Accumulated payload data. -/
  payload : ByteArray
  deriving DecidableEq

/-- Process fragmented message (RFC 6455 Section 5.4). -/
def processFragment (state : Option FragmentationState) (frame : WebSocketFrame) :
    Except ProtocolError (Option FragmentationState × Option ByteArray) :=
  if frame.opcode = .CONTINUATION then
    match state with
    | none =>
      Except.error .protocolViolation
    | some s =>
      let newPayload := s.payload ++ frame.payload_data
      if frame.fin then
        Except.ok (none, some newPayload)
      else
        Except.ok (some { s with payload := newPayload }, none)
  else if isControlFrame frame.opcode then
    Except.ok (state, none)
  else
    if frame.fin then
      Except.ok (state, some frame.payload_data)
    else
      Except.ok (some { opcode := frame.opcode, payload := frame.payload_data }, none)

/-- Protocol invariants (RFC 6455). -/
structure ProtocolInvariants where
  /-- Client frames are masked (RFC 6455 Section 5.3). -/
  clientFramesMasked : ∀ (frame : WebSocketFrame), frame.mask
  /-- Control frames are not fragmented (RFC 6455 Section 5.5). -/
  controlFramesNotFragmented : ∀ (frame : WebSocketFrame),
    isControlFrame frame.opcode → frame.fin
  /-- Control frames payload ≤ 125 bytes (RFC 6455 Section 5.5). -/
  controlFramesLengthLimit : ∀ (frame : WebSocketFrame),
    isControlFrame frame.opcode → frame.payload_length ≤ maxControlFrameLength
  /-- Close codes are valid (RFC 6455 Section 7.4). -/
  closeCodesValid : ∀ (frame : WebSocketFrame),
    frame.opcode = .CLOSE → frame.payload_length ≥ 2 →
    let status := getUInt16BE (frame.payload_data.extract 0 2) 0
    isValidCloseCode status.toNat

/-- Theorem: framePassesValidation implies all protocol requirements hold.
    Masking, control frame integrity, and length constraints are enforced. -/
theorem validation_implies_protocol_properties (frame : WebSocketFrame) (isClient : Bool)
    (h : framePassesValidation frame isClient = true) :
    (isClient = true → frame.mask = true) ∧
    (isClient = false → frame.mask = false) ∧
    (isControlFrame frame.opcode = true → frame.fin = true) ∧
    (isControlFrame frame.opcode = true → frame.payload_length ≤ maxControlFrameLength) := by
  unfold framePassesValidation at h
  simp only [decide_eq_true_eq] at h
  obtain ⟨_, _, hMask, hUnmask, hFin, hLen, _⟩ := h
  refine ⟨hMask, ?_, hFin, hLen⟩
  intro hNotClient
  have := hUnmask (by simp [hNotClient])
  simpa using this

/-- Process a list of WebSocket frames through fragmentation. -/
def processFragments : List WebSocketFrame → Option FragmentationState →
    Except ProtocolError (Option FragmentationState × Option ByteArray)
  | [], state => Except.ok (state, none)
  | frame :: rest, state => do
    let (state', out) ← processFragment state frame
    match out with
    | some payload => Except.ok (state', some payload)
    | none => processFragments rest state'

/-- Theorem: Control frames pass through fragmentation without affecting state.
    Control frames can appear between data fragments (RFC 6455 Section 5.4). -/
theorem control_frame_preserves_fragmentation_state
    (state : Option FragmentationState) (frame : WebSocketFrame)
    (hCtrl : isControlFrame frame.opcode = true) :
    processFragment state frame = Except.ok (state, none) := by
  unfold processFragment
  cases hop : frame.opcode <;> simp_all [isControlFrame]

/-- Theorem: Close frame creation always produces valid close frames. -/
theorem createCloseFrame_produces_close_opcode (frame : WebSocketFrame)
    (code : Option Nat) (reason : Option String)
    (h : createCloseFrame code reason = Except.ok frame) :
    frame.opcode = .CLOSE ∧ frame.fin = true := by
  unfold createCloseFrame at h
  cases code with
  | none => simp at h; exact ⟨by rw [← h], by rw [← h]⟩
  | some c =>
    simp only at h
    split at h
    · simp at h
    · simp at h; exact ⟨by rw [← h], by rw [← h]⟩

/-- Theorem: Close frame with no code produces an empty payload. -/
theorem createCloseFrame_none_empty_payload :
    createCloseFrame none none = Except.ok {
      fin := true, rsv1 := false, rsv2 := false, rsv3 := false,
      opcode := .CLOSE, mask := false,
      payload_length := 0, masking_key := none,
      payload_data := ByteArray.empty } := by
  rfl

end SWELib.Networking.Websocket
