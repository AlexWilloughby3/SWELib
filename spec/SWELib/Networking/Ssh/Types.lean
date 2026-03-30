/-!
# SSH Authentication Types

Core types for the SSH authentication protocol (RFC 4252).
Minimal model focused on authentication guarantees.

## Specification References
- RFC 4252: SSH Authentication Protocol
- RFC 4253 Section 7.2: Session identifier
-/

namespace SWELib.Networking.Ssh

/-- SSH authentication methods (RFC 4252 Section 5). -/
inductive AuthMethod where
  /-- "none" — used to query available methods (RFC 4252 Section 5.2) -/
  | none : AuthMethod
  /-- "publickey" — public key authentication (RFC 4252 Section 7) -/
  | publickey : AuthMethod
  /-- "password" — password authentication (RFC 4252 Section 8) -/
  | password : AuthMethod
  /-- "hostbased" — host-based authentication (RFC 4252 Section 9) -/
  | hostbased : AuthMethod
  deriving DecidableEq, Repr

/-- SSH disconnect reason codes (RFC 4253 Section 11.1). -/
inductive DisconnectReason where
  | hostNotAllowedToConnect : DisconnectReason
  | protocolError : DisconnectReason
  | noMoreAuthMethodsAvailable : DisconnectReason
  | byApplication : DisconnectReason
  deriving DecidableEq, Repr

/-- An opaque session identifier, set during first key exchange (RFC 4253 Section 7.2).
    Immutable for the lifetime of the connection. -/
structure SessionId where
  data : ByteArray
  deriving DecidableEq

/-- The username and service name that scope an auth conversation (RFC 4252 Section 5). -/
structure AuthContext where
  username : String
  serviceName : String
  deriving DecidableEq, Repr

/-- Authentication state machine (RFC 4252 Section 5).
    Models the server's view of the auth conversation. -/
inductive AuthState where
  /-- Waiting for an auth request from the client. -/
  | idle : AuthState
  /-- An auth request is being processed. -/
  | pending : AuthState
  /-- Authentication succeeded — terminal state. -/
  | success : AuthState
  /-- Server disconnected due to auth failure or protocol violation. -/
  | disconnected : AuthState
  deriving DecidableEq, Repr, Inhabited

/-- Messages from client to server (RFC 4252 Section 5). -/
inductive AuthRequest where
  /-- SSH_MSG_USERAUTH_REQUEST (message number 50) -/
  | userauthRequest
      (context : AuthContext)
      (method : AuthMethod)
      -- For publickey: the session ID that the signature covers
      (signedSessionId : Option SessionId)
      : AuthRequest

/-- Messages from server to client (RFC 4252 Section 5). -/
inductive AuthResponse where
  /-- SSH_MSG_USERAUTH_SUCCESS (message number 52) -/
  | success : AuthResponse
  /-- SSH_MSG_USERAUTH_FAILURE (message number 51) -/
  | failure (canContinue : List AuthMethod) (partialSuccess : Bool) : AuthResponse
  /-- SSH_MSG_DISCONNECT -/
  | disconnect (reason : DisconnectReason) : AuthResponse

/-- Full auth session state, carrying the protocol state plus context. -/
structure AuthSession where
  state : AuthState
  /-- The connection's session ID (from first key exchange, immutable). -/
  sessionId : SessionId
  /-- Current auth context; changes flush partial-success state. -/
  context : Option AuthContext
  /-- Number of failed attempts so far. -/
  failedAttempts : Nat
  /-- Maximum allowed attempts before disconnect. -/
  maxAttempts : Nat

end SWELib.Networking.Ssh
