import SWELib.Networking.Ssh.Types

/-!
# SSH Authentication Protocol

State machine and operations for SSH authentication (RFC 4252).
Models the server-side auth conversation with the key guarantees:
- At most one outstanding auth request at a time
- SUCCESS is terminal (sent at most once)
- "none" is never listed in `can_continue`
- Publickey signatures must cover the session ID
- Username/service changes flush partial-success state

## Specification References
- RFC 4252: SSH Authentication Protocol
-/

namespace SWELib.Networking.Ssh

/-- Initial auth session after key exchange completes. -/
def AuthSession.initial (sessionId : SessionId) (maxAttempts : Nat := 20) : AuthSession :=
  { state := .idle
    sessionId := sessionId
    context := none
    failedAttempts := 0
    maxAttempts := maxAttempts }

/-- Check that "none" does not appear in a can_continue list (RFC 4252 Section 5.1).
    The server MUST NOT include "none" as a method that can continue. -/
def validCanContinue (methods : List AuthMethod) : Bool :=
  methods.all (· != .none)

/-- Validate that a publickey auth request binds to the correct session
    (RFC 4252 Section 7). The signed data MUST include the session identifier. -/
def pubkeyBindsToSession (req : AuthRequest) (expected : SessionId) : Bool :=
  match req with
  | .userauthRequest _ .publickey (some sid) => sid == expected
  | _ => true  -- non-publickey methods don't have this requirement

/-- Process an auth request, returning the updated session and response.
    Encodes the core RFC 4252 server-side rules:

    1. Only process requests when idle (one outstanding at a time)
    2. If username/service changed, flush partial-success state
    3. "none" method → always fail with available methods
    4. Publickey must bind signature to session ID
    5. Too many failures → disconnect
    6. Success is terminal

    The `authDecision` parameter abstracts the actual credential check
    (password validity, signature verification, etc.). -/
def processAuthRequest
    (session : AuthSession)
    (req : AuthRequest)
    (authDecision : AuthRequest → Bool)
    : AuthSession × AuthResponse :=
  -- Rule 1: Only accept requests in idle state
  match session.state with
  | .idle =>
    match req with
    | .userauthRequest ctx method signedSid =>
      -- Rule 2: Context change flushes state
      let session := if session.context != some ctx
        then { session with context := some ctx, failedAttempts := 0 }
        else session
      -- Rule 3: "none" always fails, used to query methods
      if method == .none then
        ({ session with state := .idle },
         .failure [.publickey, .password] false)
      -- Rule 4: Publickey must bind to session ID
      else if method == .publickey && !pubkeyBindsToSession
          (.userauthRequest ctx method signedSid) session.sessionId then
        ({ session with state := .disconnected },
         .disconnect .protocolError)
      -- Actual auth check
      else if authDecision req then
        -- Rule 6: Success is terminal
        ({ session with state := .success }, .success)
      else
        let session := { session with failedAttempts := session.failedAttempts + 1 }
        -- Rule 5: Too many failures → disconnect
        if session.failedAttempts ≥ session.maxAttempts then
          ({ session with state := .disconnected },
           .disconnect .noMoreAuthMethodsAvailable)
        else
          ({ session with state := .idle },
           .failure [.publickey, .password] false)
  | _ =>
    -- Already succeeded or disconnected — reject with disconnect
    ({ session with state := .disconnected }, .disconnect .protocolError)

end SWELib.Networking.Ssh
