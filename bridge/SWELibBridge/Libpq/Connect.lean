import SWELib
import SWELib.Db.ConnectionPool.Types

/-!
# Connect

Bridge axioms for Libpq connection management.

## Specification References
- D-011: ConnectionParameters as Record with Optional Fields
- D-013: ConnectionStatus as Inductive Enum (12 states)
- D-015: Connection as Opaque Handle
-/

namespace SWELibBridge.Libpq

/-- Opaque handle to libpq connection structure. -/
opaque ConnectionHandle : Type

/-- Connect to PostgreSQL database with given parameters.

    Returns `some handle` on success, `none` on failure.
    See D-011 for parameter format.

    TRUST: This axiom corresponds to `PQconnectdb` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_connect : SWELib.Db.ConnectionPool.ConnectionParameters → IO (Option ConnectionHandle)

/-- Get the status of a PostgreSQL connection.

    Returns the current connection status.
    See D-013 for status enumeration.

    TRUST: This axiom corresponds to `PQstatus` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_status : ConnectionHandle → IO SWELib.Db.ConnectionPool.ConnectionStatus

/-- Close a PostgreSQL connection.

    Releases all resources associated with the connection.

    TRUST: This axiom corresponds to `PQfinish` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_close : ConnectionHandle → IO Unit

/-- Reset a PostgreSQL connection.

    Attempts to reset the connection to a clean state.
    Returns `true` on success, `false` on failure.

    TRUST: This axiom corresponds to `PQreset` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_reset : ConnectionHandle → IO Bool

/-- Ping a PostgreSQL server.

    Checks if the connection is still alive.
    Returns `true` if the server responds, `false` otherwise.

    TRUST: This axiom corresponds to `PQping` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_ping : ConnectionHandle → IO Bool

end SWELibBridge.Libpq
