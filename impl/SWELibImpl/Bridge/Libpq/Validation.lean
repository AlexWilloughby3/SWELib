import SWELib
import SWELib.Db.ConnectionPool.Types
import SWELibImpl.Bridge.Libpq.Connect

/-!
# Validation

Bridge axioms for connection validation and health checking.

## Specification References
- Connection validation operations
- Health checking
- Timeout handling
-/

namespace SWELibImpl.Bridge.Libpq

/-- Validate a connection with a timeout.

    Performs a health check on the connection, returning within the timeout.
    Returns `true` if the connection is healthy, `false` otherwise.

    TRUST: This axiom implements timeout-based validation using libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
@[extern "swelib_pq_validate_with_timeout"]
opaque pq_validate_with_timeout : ConnectionHandle → Nat → IO Bool

/-- Check if a connection has been idle for too long.

    Returns `true` if the connection has exceeded the idle timeout.

    TRUST: This axiom tracks connection idle time.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
@[extern "swelib_pq_is_idle_too_long"]
opaque pq_is_idle_too_long : ConnectionHandle → Nat → IO Bool

/-- Check if a connection has exceeded its maximum lifetime.

    Returns `true` if the connection has been alive longer than maxLifetime.

    TRUST: This axiom checks connection lifetime against maximum.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
@[extern "swelib_pq_is_connection_expired"]
opaque pq_is_connection_expired : ConnectionHandle → Nat → IO Bool

/-- Perform a quick health check without query execution.

    Returns `true` if the connection appears healthy based on socket state.

    TRUST: This axiom performs a lightweight health check.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
@[extern "swelib_pq_quick_health_check"]
opaque pq_quick_health_check : ConnectionHandle → IO Bool

end SWELibImpl.Bridge.Libpq