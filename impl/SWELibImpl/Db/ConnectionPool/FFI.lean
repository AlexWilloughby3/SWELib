import SWELibImpl.Db.ConnectionPool.Types
import SWELibImpl.Bridge.Libpq

/-!
# FFI Bindings

Foreign function interface bindings for libpq connection operations.

## Specification References
- Bridge axioms from Connect.lean, Exec.lean, Validation.lean
-/

namespace SWELibImpl.Db.ConnectionPool

open SWELibImpl.Bridge.Libpq

/-- Connect to PostgreSQL database.

    The caller must supply a pool-unique `id` (e.g., the current totalCount). -/
def connect (params : ConnectionParameters) (id : UInt64) : IO (Option ConnectionHandle) := do
  let maybePtr ← pq_connect params
  match maybePtr with
  | none => pure none
  | some ptr => do
    let now ← IO.monoMsNow
    pure (some {
      id := id
      ptr := ptr
      createdAt := now
      lastUsed := now
      isValid := true
    })

/-- Get connection status. -/
def getStatus (handle : ConnectionHandle) : IO ConnectionStatus :=
  pq_status handle.ptr

/-- Close a connection. -/
def close (handle : ConnectionHandle) : IO Unit :=
  pq_close handle.ptr

/-- Reset a connection. -/
def reset (handle : ConnectionHandle) : IO Bool :=
  pq_reset handle.ptr

/-- Ping the database server. -/
def ping (handle : ConnectionHandle) : IO Bool :=
  pq_ping handle.ptr

/-- Execute a SQL query. -/
def exec (handle : ConnectionHandle) (query : String) : IO (Option QueryResult) :=
  pq_exec handle.ptr query

/-- Validate a connection. -/
def validate (handle : ConnectionHandle) : IO Bool :=
  pq_validate handle.ptr

/-- Validate with timeout. -/
def validateWithTimeout (handle : ConnectionHandle) (timeout : Nat) : IO Bool :=
  pq_validate_with_timeout handle.ptr timeout

/-- Check if connection is idle too long. -/
def isIdleTooLong (handle : ConnectionHandle) (idleTimeout : Nat) : IO Bool :=
  pq_is_idle_too_long handle.ptr idleTimeout

/-- Check if connection is expired. -/
def isExpired (handle : ConnectionHandle) (maxLifetime : Nat) : IO Bool :=
  pq_is_connection_expired handle.ptr maxLifetime

/-- Get error message. -/
def errorMessage (handle : ConnectionHandle) : IO String :=
  pq_error_message handle.ptr

/-- Quick health check. -/
def quickHealthCheck (handle : ConnectionHandle) : IO Bool :=
  pq_quick_health_check handle.ptr

/-- Check if connection is writable. -/
def isWritable (handle : ConnectionHandle) : IO Bool :=
  pq_is_writable handle.ptr

/-- Check if connection is readable. -/
def isReadable (handle : ConnectionHandle) : IO Bool :=
  pq_is_readable handle.ptr

/-- Update last used timestamp. -/
def updateLastUsed (handle : ConnectionHandle) : IO ConnectionHandle := do
  let now ← IO.monoMsNow
  pure { handle with lastUsed := now }

end SWELibImpl.Db.ConnectionPool
