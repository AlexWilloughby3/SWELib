import SWELib

/-!
# SSH Authentication Bridge

Bridge axioms asserting that libssh2's SSH operations conform to the
authentication model specified in RFC 4252. Each axiom corresponds to
a guarantee that the C library provides when the underlying function succeeds.

The explicit trust boundary for SSH auth. Every unproven real-world
assumption about libssh2 lives here.

## Specification References
- RFC 4252: SSH Authentication Protocol
- RFC 4253 Section 7.2: Session identifier
-/

namespace SWELibImpl.Bridge.Libssh

open SWELib.Networking.Ssh

-- TRUST: <issue-url>

/-- Axiom: A successful SSH handshake produces an auth session in the idle
    state with a non-empty session identifier and zero failed attempts.
    The session is ready to begin authentication.

    TRUST: Corresponds to `libssh2_session_handshake` completing the full
    SSH transport layer key exchange (RFC 4253 Section 7), after which
    `session->session_id` is set and auth has not yet been attempted.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssh_handshake_establishes_session :
    ∀ (session : AuthSession),
      session.state = .idle →
      session.sessionId.data.size > 0 ∧
      session.failedAttempts = 0

/-- Axiom: The session identifier is never modified by authentication
    requests, matching the spec's `session_id_immutable` theorem.
    The session ID is set once during the first key exchange and remains
    fixed for the lifetime of the connection (RFC 4253 Section 7.2).

    TRUST: Corresponds to libssh2's internal `session->session_id` being
    set once during the first key exchange and never modified by any
    `libssh2_userauth_*` call.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssh_session_id_immutable :
    ∀ (session : AuthSession)
      (req : AuthRequest)
      (decide : AuthRequest → Bool),
      (processAuthRequest session req decide).1.sessionId = session.sessionId

/-- Axiom: Public key authentication binds the signature to the current
    session. If the spec's `pubkeyBindsToSession` check passes, the signed
    session ID necessarily equals the real session ID — preventing
    cross-session replay attacks.

    TRUST: Corresponds to `libssh2_userauth_publickey_fromfile` and
    `libssh2_userauth_publickey_frommemory` signing over a blob that
    includes the session identifier (RFC 4252 Section 7).
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssh_publickey_auth_session_bound :
    ∀ (session : AuthSession)
      (ctx : AuthContext)
      (signedSid : SessionId),
      session.state = .idle →
      pubkeyBindsToSession
        (.userauthRequest ctx .publickey (some signedSid)) session.sessionId = true →
      signedSid = session.sessionId

/-- Axiom: Authentication success is only reachable from the idle state.
    The server never transitions to authenticated from an already-disconnected
    or already-authenticated state.

    TRUST: Corresponds to libssh2's internal state machine which only
    processes `SSH_MSG_USERAUTH_SUCCESS` when awaiting an auth response,
    never in a disconnected or already-authenticated state.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssh_auth_success_requires_idle :
    ∀ (session : AuthSession)
      (req : AuthRequest)
      (decide : AuthRequest → Bool),
      (processAuthRequest session req decide).1.state = .success →
      session.state = .idle

/-- Axiom: The "none" authentication method never results in success.
    It is used only to query the server's list of available methods
    (RFC 4252 Section 5.2).

    TRUST: Corresponds to `libssh2_userauth_list` which sends method "none"
    and always receives `SSH_MSG_USERAUTH_FAILURE` with the list of
    supported methods.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssh_none_method_queries_only :
    ∀ (session : AuthSession)
      (ctx : AuthContext)
      (decide : AuthRequest → Bool),
      session.state = .idle →
      (processAuthRequest session
        (.userauthRequest ctx .none .none) decide).1.state = .idle

end SWELibImpl.Bridge.Libssh
