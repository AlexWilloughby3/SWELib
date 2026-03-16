import SWELib
import SWELibBridge

/-!
# Libpq FFI

Raw `@[extern]` declarations for libpq operations not covered by the bridge
axioms. These provide access to parameterized queries, prepared statements,
async operation, and result introspection via C shims.

The bridge axioms in `SWELibBridge.Libpq` cover connection management and
basic query execution. This module adds the extended libpq API used by
higher-level code (PgClient, QueryBuilder).
-/

namespace SWELibCode.Ffi.Libpq

/-- Execute a query with server-side parameter binding (PQexecParams).
    Parameters are passed as strings; the server handles type conversion.
    This prevents SQL injection by keeping parameters separate from the query.

    Returns (statusCode, rowCount, errorMessage) where:
    - statusCode 2 = PGRES_COMMAND_OK, 5 = PGRES_TUPLES_OK, else error -/
@[extern "swelib_pq_exec_params"]
opaque execParams
    (connPtr : USize)
    (query : @& String)
    (params : @& Array String) : IO (UInt32 × UInt64 × String)

/-- Execute a parameterized query and return rows as an array of string arrays.
    Each inner array is one row; values are `some str` or `none` for NULL.

    Returns (statusCode, rows, errorMessage). -/
@[extern "swelib_pq_exec_params_rows"]
opaque execParamsRows
    (connPtr : USize)
    (query : @& String)
    (params : @& Array String) : IO (UInt32 × Array (Array (Option String)) × String)

/-- Prepare a named statement on the server (PQprepare).
    Returns true on success. -/
@[extern "swelib_pq_prepare"]
opaque prepare
    (connPtr : USize)
    (stmtName : @& String)
    (query : @& String) : IO Bool

/-- Execute a previously prepared statement (PQexecPrepared).
    Returns (statusCode, rows, errorMessage). -/
@[extern "swelib_pq_exec_prepared"]
opaque execPrepared
    (connPtr : USize)
    (stmtName : @& String)
    (params : @& Array String) : IO (UInt32 × Array (Array (Option String)) × String)

/-- Deallocate a prepared statement (DEALLOCATE). -/
@[extern "swelib_pq_deallocate"]
opaque deallocate
    (connPtr : USize)
    (stmtName : @& String) : IO Bool

/-- Begin a transaction (sends "BEGIN"). -/
@[extern "swelib_pq_begin"]
opaque begin_ (connPtr : USize) : IO Bool

/-- Commit a transaction (sends "COMMIT"). -/
@[extern "swelib_pq_commit"]
opaque commit (connPtr : USize) : IO Bool

/-- Rollback a transaction (sends "ROLLBACK"). -/
@[extern "swelib_pq_rollback"]
opaque rollback (connPtr : USize) : IO Bool

/-- Return the libpq protocol version in use. -/
@[extern "swelib_pq_protocol_version"]
opaque protocolVersion (connPtr : USize) : IO UInt32

/-- Return the PostgreSQL server version as an integer (e.g., 170000 for 17.0). -/
@[extern "swelib_pq_server_version"]
opaque serverVersion (connPtr : USize) : IO UInt32

/-- Escape a string for safe inclusion in a SQL literal (PQescapeLiteral).
    Prefer parameterized queries via `execParams` over manual escaping. -/
@[extern "swelib_pq_escape_literal"]
opaque escapeLiteral
    (connPtr : USize)
    (str : @& String) : IO String

/-- Escape a string for use as a SQL identifier (PQescapeIdentifier).
    Use this for dynamically-constructed table/column names. -/
@[extern "swelib_pq_escape_identifier"]
opaque escapeIdentifier
    (connPtr : USize)
    (str : @& String) : IO String

end SWELibCode.Ffi.Libpq
