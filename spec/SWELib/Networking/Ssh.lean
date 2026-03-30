import SWELib.Networking.Ssh.Types
import SWELib.Networking.Ssh.Auth
import SWELib.Networking.Ssh.Invariants

/-!
# Secure Shell (SSH) Authentication

Specification of the SSH authentication protocol (RFC 4252).
Focused on the core authentication guarantees:
- SUCCESS is terminal (sent at most once)
- "none" method only queries available methods, never succeeds
- Publickey signatures are bound to the session identifier
- Brute-force protection via max-attempts disconnect

The specification is organized into:
- Core type definitions (`Ssh.Types`)
- Auth protocol state machine (`Ssh.Auth`)
- Authentication invariants (`Ssh.Invariants`)
-/

namespace SWELib.Networking.Ssh

end SWELib.Networking.Ssh
