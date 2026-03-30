import SWELibImpl.Db.ConnectionPool.Types
import SWELibImpl.Db.ConnectionPool.FFI

/-!
# Connection Wrapper

Connection wrapper with finalizer and reference counting.

## Specification References
- D-015: Connection as Opaque Handle
- Connection lifetime management
-/

namespace SWELibImpl.Db.ConnectionPool

/-- Create a new connection wrapper. -/
def Connection.new (handle : ConnectionHandle) : Connection :=
  { handle := handle, state := .Idle, refCount := 1 }

/-- Increment reference count. -/
def Connection.addRef (conn : Connection) : Connection :=
  { conn with refCount := conn.refCount + 1 }

/-- Decrement reference count and close if zero. -/
def Connection.release (conn : Connection) : IO Bool := do
  let newCount := conn.refCount - 1
  if newCount = 0 then
    ConnectionPool.close conn.handle
    pure true
  else
    pure false

/-- Check if connection is valid. -/
def Connection.isValid (conn : Connection) : Bool :=
  conn.handle.isValid

/-- Mark connection as invalid. -/
def Connection.invalidate (conn : Connection) : Connection :=
  { conn with handle := { conn.handle with isValid := false } }

/-- Get connection ID. -/
def Connection.id (conn : Connection) : UInt64 :=
  conn.handle.id

/-- Get underlying handle. -/
def Connection.getHandle (conn : Connection) : ConnectionHandle :=
  conn.handle

/-- Update connection state. -/
def Connection.setState (conn : Connection) (state : InternalConnectionStatus) : Connection :=
  { conn with state := state }

/-- Get connection state. -/
def Connection.getState (conn : Connection) : InternalConnectionStatus :=
  conn.state

/-- Check if connection is active. -/
def Connection.isActive (conn : Connection) : Bool :=
  conn.state = .Active

/-- Check if connection is idle. -/
def Connection.isIdle (conn : Connection) : Bool :=
  conn.state = .Idle

/-- Check if connection is broken. -/
def Connection.isBroken (conn : Connection) : Bool :=
  conn.state = .Broken

/-- Check if connection is being validated. -/
def Connection.isValidating (conn : Connection) : Bool :=
  conn.state = .Validating

/-- Validate connection health. -/
def Connection.validate' (conn : Connection) (timeout : Nat) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    ConnectionPool.validateWithTimeout conn.handle timeout

/-- Check if connection has expired. -/
def Connection.checkExpired (conn : Connection) (maxLifetime : Nat) : IO Bool := do
  if ¬ conn.isValid then
    pure true
  else
    ConnectionPool.isExpired conn.handle maxLifetime

/-- Check if connection has been idle too long. -/
def Connection.checkIdleTooLong (conn : Connection) (idleTimeout : Nat) : IO Bool := do
  if ¬ conn.isValid then
    pure true
  else
    ConnectionPool.isIdleTooLong conn.handle idleTimeout

/-- Update last used timestamp. -/
def Connection.touch (conn : Connection) : IO Connection := do
  let updatedHandle ← ConnectionPool.updateLastUsed conn.handle
  pure { conn with handle := updatedHandle }

/-- Execute a query on the connection. -/
def Connection.exec' (conn : Connection) (query : String) : IO (Option Bridge.Libpq.QueryResult) := do
  if ¬ conn.isValid then
    pure none
  else
    ConnectionPool.exec conn.handle query

/-- Get connection error message. -/
def Connection.errorMessage' (conn : Connection) : IO String :=
  ConnectionPool.errorMessage conn.handle

/-- Quick health check. -/
def Connection.quickHealthCheck' (conn : Connection) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    ConnectionPool.quickHealthCheck conn.handle

/-- Reset connection. -/
def Connection.reset' (conn : Connection) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    ConnectionPool.reset conn.handle

/-- Ping database server. -/
def Connection.ping' (conn : Connection) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    ConnectionPool.ping conn.handle

/-- Get connection status. -/
def Connection.getStatus' (conn : Connection) : IO ConnectionStatus :=
  ConnectionPool.getStatus conn.handle

/-- Check if connection is writable. -/
def Connection.isWritable' (conn : Connection) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    ConnectionPool.isWritable conn.handle

/-- Check if connection is readable. -/
def Connection.isReadable' (conn : Connection) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    ConnectionPool.isReadable conn.handle

end SWELibImpl.Db.ConnectionPool
