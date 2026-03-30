import SWELib.Networking.Ssh.Auth

/-!
# SSH Authentication Invariants

Provable properties of the SSH authentication model (RFC 4252).

## Specification References
- RFC 4252: SSH Authentication Protocol
-/

namespace SWELib.Networking.Ssh

-- ── SUCCESS is terminal ──────────────────────────────────────────────

/-- Once authentication succeeds, further requests cause disconnect.
    Models RFC 4252 Section 5.1: the server MUST NOT process auth requests
    after sending SUCCESS. -/
theorem success_is_terminal (session : AuthSession) (req : AuthRequest)
    (decide : AuthRequest → Bool) :
    session.state = .success →
    (processAuthRequest session req decide).1.state = .disconnected := by
  intro h; simp [processAuthRequest, h]

/-- Success can only be reached from the idle state. -/
theorem success_only_from_idle (session : AuthSession) (req : AuthRequest)
    (decide : AuthRequest → Bool) :
    (processAuthRequest session req decide).1.state = .success →
    session.state = .idle := by
  match hState : session.state with
  | .idle => intro _; rfl
  | .pending | .success | .disconnected =>
    simp [processAuthRequest, hState]

-- ── "none" never succeeds ────────────────────────────────────────────

/-- The "none" method keeps the session idle (returns failure).
    Models RFC 4252 Section 5.2: "none" only queries available methods. -/
theorem none_method_stays_idle (session : AuthSession) (ctx : AuthContext)
    (decide : AuthRequest → Bool) :
    session.state = .idle →
    (processAuthRequest session (.userauthRequest ctx .none .none) decide).1.state = .idle := by
  intro hIdle; simp [processAuthRequest, hIdle]

/-- The "none" method response lists available methods as failure. -/
theorem none_method_returns_methods (session : AuthSession) (ctx : AuthContext)
    (decide : AuthRequest → Bool) :
    session.state = .idle →
    (processAuthRequest session (.userauthRequest ctx .none .none) decide).2 =
      .failure [.publickey, .password] false := by
  intro hIdle; simp [processAuthRequest, hIdle]

-- ── Publickey session binding ────────────────────────────────────────

/-- A publickey auth request with a wrong session ID causes disconnect.
    Ensures signatures are bound to the correct session
    (RFC 4252 Section 7, RFC 4253 Section 7.2). -/
theorem pubkey_wrong_session_disconnects (session : AuthSession) (ctx : AuthContext)
    (wrongSid : SessionId) (decisionFn : AuthRequest → Bool) :
    session.state = .idle →
    wrongSid ≠ session.sessionId →
    (processAuthRequest session
      (.userauthRequest ctx .publickey (some wrongSid)) decisionFn).1.state = .disconnected := by
  intro hIdle hNeq
  unfold processAuthRequest
  simp [hIdle]
  -- After unfolding, we need to show the pubkey check fails and leads to disconnect
  split
  · -- context matches: sessionId unchanged
    simp [pubkeyBindsToSession, hNeq]
  · -- context changed: sessionId still = session.sessionId
    dsimp only
    simp [pubkeyBindsToSession, hNeq]

-- ── Disconnect is terminal ───────────────────────────────────────────

/-- Once disconnected, the session stays disconnected. -/
theorem disconnected_is_terminal (session : AuthSession) (req : AuthRequest)
    (decide : AuthRequest → Bool) :
    session.state = .disconnected →
    (processAuthRequest session req decide).1.state = .disconnected := by
  intro h; simp [processAuthRequest, h]

-- ── Session ID immutability ──────────────────────────────────────────

/-- The session ID is never modified by processAuthRequest.
    Models RFC 4253 Section 7.2: session ID is immutable. -/
theorem session_id_immutable (session : AuthSession) (req : AuthRequest)
    (decide : AuthRequest → Bool) :
    (processAuthRequest session req decide).1.sessionId = session.sessionId := by
  unfold processAuthRequest
  match hState : session.state with
  | .pending | .success | .disconnected => simp
  | .idle =>
    simp
    match req with
    | .userauthRequest ctx method signedSid =>
      -- Split through all the nested if-then-else branches
      split <;> (try split) <;> (try split) <;> (try split) <;>
        (try rfl) <;> (try simp_all) <;> (try (split <;> rfl))

end SWELib.Networking.Ssh
