/-!
# TLS State Machine

State machine for TLS protocol (RFC 8446 Section 2).
-/

import SWELib.Networking.Tls.ConnectionState

namespace SWELib.Networking.Tls

/-- TLS connection state (RFC 8446 Section 2). -/
inductive TlsState where
  /-- Initial state, no connection -/
  | start : TlsState
  /-- Client Hello sent, waiting for Server Hello -/
  | clientHelloSent : TlsState
  /-- Server Hello received, waiting for rest of handshake -/
  | serverHelloReceived : TlsState
  /-- Server Finished received, handshake complete from server perspective -/
  | serverFinishedReceived : TlsState
  /-- Client Finished received, handshake complete -/
  | connected : TlsState
  /-- Close notify sent, waiting for close notify from peer -/
  | closing : TlsState
  /-- Connection closed -/
  | closed : TlsState
  deriving DecidableEq, Repr, Inhabited

/-- Check if state allows sending application data (RFC 8446 Section 4.4.4). -/
def TlsState.canSendApplicationData : TlsState → Bool
  | .connected => true
  | _ => false

/-- Check if state allows receiving application data (RFC 8446 Section 4.4.4). -/
def TlsState.canReceiveApplicationData : TlsState → Bool
  | .connected => true
  | _ => false

/-- Check if state is a handshake state. -/
def TlsState.isHandshakeState : TlsState → Bool
  | .start | .clientHelloSent | .serverHelloReceived | .serverFinishedReceived => true
  | _ => false

/-- Check if state is a connected state. -/
def TlsState.isConnected : TlsState → Bool
  | .connected => true
  | _ => false

/-- Check if state is a closing state. -/
def TlsState.isClosing : TlsState → Bool
  | .closing => true
  | _ => false

/-- Check if state is a closed state. -/
def TlsState.isClosed : TlsState → Bool
  | .closed => true
  | _ => false

/-- State transition on sending Client Hello (RFC 8446 Section 4.1.2). -/
def TlsState.transitionOnSendClientHello : TlsState → Option TlsState
  | .start => some .clientHelloSent
  | _ => none

/-- State transition on receiving Server Hello (RFC 8446 Section 4.1.3). -/
def TlsState.transitionOnReceiveServerHello : TlsState → Option TlsState
  | .clientHelloSent => some .serverHelloReceived
  | _ => none

/-- State transition on receiving Server Finished (RFC 8446 Section 4.4.4). -/
def TlsState.transitionOnReceiveServerFinished : TlsState → Option TlsState
  | .serverHelloReceived => some .serverFinishedReceived
  | _ => none

/-- State transition on sending Client Finished (RFC 8446 Section 4.4.4). -/
def TlsState.transitionOnSendClientFinished : TlsState → Option TlsState
  | .serverFinishedReceived => some .connected
  | _ => none

/-- State transition on receiving Client Finished (RFC 8446 Section 4.4.4). -/
def TlsState.transitionOnReceiveClientFinished : TlsState → Option TlsState
  | .serverFinishedReceived => some .connected
  | _ => none

/-- State transition on sending close notify (RFC 8446 Section 6.1). -/
def TlsState.transitionOnSendCloseNotify : TlsState → Option TlsState
  | .connected => some .closing
  | .closing => some .closing  -- Already closing
  | _ => none

/-- State transition on receiving close notify (RFC 8446 Section 6.1). -/
def TlsState.transitionOnReceiveCloseNotify : TlsState → Option TlsState
  | .connected => some .closing
  | .closing => some .closed
  | _ => none

/-- State transition on fatal alert (RFC 8446 Section 6.2). -/
def TlsState.transitionOnFatalAlert : TlsState → TlsState
  | _ => .closed

/-- State transition on key update (RFC 8446 Section 4.6.3). -/
def TlsState.transitionOnKeyUpdate : TlsState → Option TlsState
  | .connected => some .connected  -- Stay connected
  | _ => none

/-- Check if a state transition is valid. -/
def TlsState.isValidTransition (from to : TlsState) : Bool :=
  match from, to with
  | .start, .clientHelloSent => true
  | .clientHelloSent, .serverHelloReceived => true
  | .serverHelloReceived, .serverFinishedReceived => true
  | .serverFinishedReceived, .connected => true
  | .connected, .closing => true
  | .closing, .closed => true
  | .connected, .connected => true  -- Key update
  | .closing, .closing => true  -- Multiple close notifies
  | _, .closed => true  -- Fatal alert from any state
  | _, _ => false

/-- Full TLS state including connection state and protocol state. -/
structure FullTlsState where
  /-- Protocol state machine -/
  protocolState : TlsState
  /-- Connection state -/
  connectionState : ConnectionState
  deriving DecidableEq, Repr

/-- Create initial full TLS state. -/
def FullTlsState.initial : FullTlsState :=
  ⟨.start, ConnectionState.initial⟩

/-- Update protocol state. -/
def FullTlsState.withProtocolState (state : FullTlsState) (newState : TlsState) : FullTlsState :=
  { state with protocolState := newState }

/-- Update connection state. -/
def FullTlsState.withConnectionState (state : FullTlsState) (newConnState : ConnectionState) : FullTlsState :=
  { state with connectionState := newConnState }

/-- Check if full state is valid (consistent protocol and connection states). -/
def FullTlsState.validate : FullTlsState → Bool
  | ⟨protocolState, connectionState⟩ =>
    connectionState.validate &&
    match protocolState with
    | .start => connectionState.handshakeState.clientHello.isNone
    | .clientHelloSent => connectionState.handshakeState.clientHello.isSome &&
                         connectionState.handshakeState.serverHello.isNone
    | .serverHelloReceived => connectionState.handshakeState.clientHello.isSome &&
                             connectionState.handshakeState.serverHello.isSome &&
                             connectionState.handshakeState.serverFinished.isNone
    | .serverFinishedReceived => connectionState.handshakeState.clientHello.isSome &&
                                connectionState.handshakeState.serverHello.isSome &&
                                connectionState.handshakeState.serverFinished.isSome &&
                                connectionState.handshakeState.clientFinished.isNone
    | .connected => connectionState.handshakeState.isComplete
    | .closing => connectionState.handshakeState.isComplete
    | .closed => true

/-- Transition on sending a handshake message. -/
def FullTlsState.transitionOnSendHandshake (state : FullTlsState) (msg : HandshakeMessage) : Option FullTlsState :=
  match msg with
  | .clientHello ch =>
    let newConnState := state.connectionState.handshakeState.withClientHello ch
    let newFullState := state.withConnectionState { state.connectionState with handshakeState := newConnState }
    TlsState.transitionOnSendClientHello state.protocolState
      |>.map (λ newProtocolState => newFullState.withProtocolState newProtocolState)
  | .finished f =>
    if state.protocolState = .serverFinishedReceived then
      let newConnState := state.connectionState.handshakeState.withClientFinished f
      let newFullState := state.withConnectionState { state.connectionState with handshakeState := newConnState }
      TlsState.transitionOnSendClientFinished state.protocolState
        |>.map (λ newProtocolState => newFullState.withProtocolState newProtocolState)
    else
      none
  | _ => some state  -- Other messages don't change protocol state

/-- Transition on receiving a handshake message. -/
def FullTlsState.transitionOnReceiveHandshake (state : FullTlsState) (msg : HandshakeMessage) : Option FullTlsState :=
  match msg with
  | .serverHello sh =>
    let newConnState := state.connectionState.handshakeState.withServerHello sh
    let newFullState := state.withConnectionState { state.connectionState with handshakeState := newConnState }
    TlsState.transitionOnReceiveServerHello state.protocolState
      |>.map (λ newProtocolState => newFullState.withProtocolState newProtocolState)
  | .finished f =>
    if state.protocolState = .serverHelloReceived then
      let newConnState := state.connectionState.handshakeState.withServerFinished f
      let newFullState := state.withConnectionState { state.connectionState with handshakeState := newConnState }
      TlsState.transitionOnReceiveServerFinished state.protocolState
        |>.map (λ newProtocolState => newFullState.withProtocolState newProtocolState)
    else if state.protocolState = .serverFinishedReceived then
      let newConnState := state.connectionState.handshakeState.withClientFinished f
      let newFullState := state.withConnectionState { state.connectionState with handshakeState := newConnState }
      TlsState.transitionOnReceiveClientFinished state.protocolState
        |>.map (λ newProtocolState => newFullState.withProtocolState newProtocolState)
    else
      none
  | _ => some state  -- Other messages don't change protocol state

/-- Transition on sending close notify. -/
def FullTlsState.transitionOnSendCloseNotify (state : FullTlsState) : Option FullTlsState :=
  TlsState.transitionOnSendCloseNotify state.protocolState
    |>.map (λ newProtocolState => state.withProtocolState newProtocolState)

/-- Transition on receiving close notify. -/
def FullTlsState.transitionOnReceiveCloseNotify (state : FullTlsState) : Option FullTlsState :=
  TlsState.transitionOnReceiveCloseNotify state.protocolState
    |>.map (λ newProtocolState => state.withProtocolState newProtocolState)

/-- Transition on fatal alert. -/
def FullTlsState.transitionOnFatalAlert (state : FullTlsState) : FullTlsState :=
  state.withProtocolState .closed

/-- Check if full state can send application data. -/
def FullTlsState.canSendApplicationData : FullTlsState → Bool
  | ⟨protocolState, connectionState⟩ =>
    protocolState.canSendApplicationData && connectionState.canSendApplicationData

/-- Check if full state can receive application data. -/
def FullTlsState.canReceiveApplicationData : FullTlsState → Bool
  | ⟨protocolState, connectionState⟩ =>
    protocolState.canReceiveApplicationData && connectionState.canReceiveApplicationData

instance : ToString TlsState where
  toString s := match s with
    | .start => "start"
    | .clientHelloSent => "client_hello_sent"
    | .serverHelloReceived => "server_hello_received"
    | .serverFinishedReceived => "server_finished_received"
    | .connected => "connected"
    | .closing => "closing"
    | .closed => "closed"

end SWELib.Networking.Tls