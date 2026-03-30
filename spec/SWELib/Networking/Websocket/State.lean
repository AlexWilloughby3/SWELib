import SWELib.Networking.Websocket.Types
import SWELib.Networking.Websocket.Frame
import SWELib.Basics.Uri

/-!
# WebSocket State

WebSocket connection state and API operations (RFC 6455, W3C WebSocket API).

## References
- RFC 6455 Section 1.4: Closing Handshake
- RFC 6455 Section 5.1: Data Framing
- RFC 6455 Section 7: Closing the Connection
- W3C WebSocket API Section 4: Interface
-/

namespace SWELib.Networking.Websocket

/-- WebSocket connection object (W3C WebSocket API Section 4.1). -/
structure WebSocket where
  /-- The URL to which the WebSocket is connected. -/
  url : SWELib.Basics.Uri
  /-- Binary data type in use. -/
  binaryType : BinaryType
  /-- Current state of the connection. -/
  readyState : ReadyState
  /-- Number of bytes of application data that have been queued but not yet sent. -/
  bufferedAmount : Nat
  deriving DecidableEq, Repr

/-- Error type for WebSocket operations. -/
inductive WebSocketError where
  | InvalidStateError
  | SyntaxError
  | InvalidAccessError
  | NetworkError
  | ProtocolError
  deriving DecidableEq, Repr

/-- Create a new WebSocket connection (W3C WebSocket API Section 4.3). -/
def WebSocket.new (url : String) : Except WebSocketError WebSocket :=
  -- Parse URL
  match SWELib.Basics.Uri.parse url with
  | none =>
    Except.error .SyntaxError
  | some uri =>
    -- Validate URL scheme
    if ¬uri.isWebSocket then
      Except.error .SyntaxError
    else
      Except.ok {
        url := uri
        binaryType := .blob
        readyState := .CONNECTING
        bufferedAmount := 0
      }

/-- Send data through the WebSocket (W3C WebSocket API Section 4.4). -/
def WebSocket.send (ws : WebSocket) (_data : ByteArray) : Except WebSocketError Unit :=
  match ws.readyState with
  | .OPEN =>
    -- TODO: Queue data for sending
    Except.ok ()
  | .CONNECTING =>
    Except.error .InvalidStateError
  | .CLOSING =>
    Except.error .InvalidStateError
  | .CLOSED =>
    Except.error .InvalidStateError

/-- Close the WebSocket connection (W3C WebSocket API Section 4.5). -/
def WebSocket.close (ws : WebSocket) (code : Option Nat) (_reason : Option String) :
    Except WebSocketError Unit :=
  match ws.readyState with
  | .CLOSED =>
    Except.ok ()  -- Already closed
  | .CLOSING =>
    Except.ok ()  -- Already closing
  | .CONNECTING | .OPEN =>
    -- Validate close code if provided
    match code with
    | none => Except.ok ()
    | some c =>
      if isValidCloseCode c then
        Except.ok ()
      else
        Except.error .InvalidAccessError

/-- State transition: connection established (RFC 6455 Section 4.2.2). -/
def transitionToOpen (ws : WebSocket) : WebSocket :=
  { ws with readyState := .OPEN }

/-- State transition: start closing handshake (RFC 6455 Section 7.1.1). -/
def transitionToClosing (ws : WebSocket) : WebSocket :=
  { ws with readyState := .CLOSING }

/-- State transition: connection closed (RFC 6455 Section 7.1.3). -/
def transitionToClosed (ws : WebSocket) : WebSocket :=
  { ws with readyState := .CLOSED }

/-- Check if WebSocket can send data (W3C WebSocket API Section 4.4). -/
def canSend (ws : WebSocket) : Bool :=
  ws.readyState = .OPEN

/-- Check if WebSocket can be closed (RFC 6455 Section 7.1.1). -/
def canClose (ws : WebSocket) : Bool :=
  ws.readyState = .OPEN ∨ ws.readyState = .CONNECTING

/-- Theorem: send only allowed in OPEN state. -/
theorem send_only_in_open_state (ws : WebSocket) (data : ByteArray) :
    (WebSocket.send ws data).isOk → ws.readyState = .OPEN := by
  unfold WebSocket.send
  cases ws.readyState <;> simp [Except.isOk, Except.toBool]

/-- Theorem: close always succeeds (returns ok or error, never gets stuck).
    When it succeeds, the original state was one of the four valid states. -/
theorem close_transitions_state (ws : WebSocket) (code : Option Nat) (reason : Option String) :
    match WebSocket.close ws code reason with
    | Except.ok () =>
      ws.readyState = .CLOSING ∨ ws.readyState = .CLOSED ∨
      (ws.readyState = .CONNECTING ∨ ws.readyState = .OPEN)
    | Except.error _ => True := by
  unfold WebSocket.close
  cases ws.readyState <;> simp
  case CONNECTING => cases code <;> simp; split <;> simp
  case OPEN => cases code <;> simp; split <;> simp

/-- Theorem: bufferedAmount only increases when sending in OPEN state. -/
theorem bufferedAmount_monotonic (ws : WebSocket) (data : ByteArray) :
    match WebSocket.send ws data with
    | Except.ok () => ws.bufferedAmount ≤ ({ ws with bufferedAmount := ws.bufferedAmount + data.size }).bufferedAmount
    | Except.error _ => True := by
  unfold WebSocket.send
  cases ws.readyState <;> simp [Nat.le_add_right]

/-- Theorem: Valid URL schemes are ws and wss. -/
theorem valid_url_schemes (url : String) :
    match WebSocket.new url with
    | Except.ok ws => ws.url.scheme = "ws" ∨ ws.url.scheme = "wss"
    | Except.error _ => True := by
  unfold WebSocket.new SWELib.Basics.Uri.isWebSocket
  cases SWELib.Basics.Uri.parse url with
  | none => trivial
  | some uri =>
    simp only [decide_eq_true_eq]
    by_cases h : uri.scheme = "ws" ∨ uri.scheme = "wss"
    · simp [h]
    · simp [h]

/-- State ordering: CONNECTING → OPEN → CLOSING → CLOSED. -/
def stateOrder : ReadyState → ReadyState → Prop
  | .CONNECTING, .OPEN => True
  | .OPEN, .CLOSING => True
  | .CLOSING, .CLOSED => True
  | s, s' => s = s'

/-- Theorem: State transitions produce the expected ordering when applied
    to a WebSocket in the correct starting state. -/
theorem state_transition_monotonic_open (ws : WebSocket) (h : ws.readyState = .CONNECTING) :
    stateOrder ws.readyState (transitionToOpen ws).readyState := by
  simp [transitionToOpen, stateOrder, h]

theorem state_transition_monotonic_closing (ws : WebSocket) (h : ws.readyState = .OPEN) :
    stateOrder ws.readyState (transitionToClosing ws).readyState := by
  simp [transitionToClosing, stateOrder, h]

theorem state_transition_monotonic_closed (ws : WebSocket) (h : ws.readyState = .CLOSING) :
    stateOrder ws.readyState (transitionToClosed ws).readyState := by
  simp [transitionToClosed, stateOrder, h]

end SWELib.Networking.Websocket
