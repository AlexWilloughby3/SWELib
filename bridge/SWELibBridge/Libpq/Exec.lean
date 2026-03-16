import SWELib
import SWELibBridge.Libpq.Connect

/-!
# Exec

Bridge axioms for Libpq query execution and validation.

## Specification References
- Connection validation operations
- Query execution
-/

namespace SWELibBridge.Libpq

/-- Opaque handle to libpq query result structure. -/
opaque QueryResult : Type

/-- Execute a SQL query on a PostgreSQL connection.

    Returns `some result` on success, `none` on failure.

    TRUST: This axiom corresponds to `PQexec` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_exec : ConnectionHandle → String → IO (Option QueryResult)

/-- Execute a simple query for validation purposes.

    Returns `true` if the query executes successfully, `false` otherwise.
    Used for connection validation.

    TRUST: This axiom corresponds to `PQexec` with a simple validation query.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_validate : ConnectionHandle → IO Bool

/-- Get the error message from the last operation.

    Returns the error message as a string, or empty string if no error.

    TRUST: This axiom corresponds to `PQerrorMessage` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_error_message : ConnectionHandle → IO String

/-- Check if a connection is in a writable state.

    Returns `true` if the connection can accept write operations.

    TRUST: This axiom corresponds to checking connection status and server state.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_is_writable : ConnectionHandle → IO Bool

/-- Check if a connection is in a readable state.

    Returns `true` if the connection can accept read operations.

    TRUST: This axiom corresponds to checking connection status and server state.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_is_readable : ConnectionHandle → IO Bool

end SWELibBridge.Libpq
