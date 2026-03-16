/-!
# Connection Wrapper

Connection wrapper with finalizer and reference counting.

## Specification References
- D-015: Connection as Opaque Handle
- Connection lifetime management
-/

import SWELibCode.Db.ConnectionPool.Types
import SWELibCode.Db.ConnectionPool.FFI

namespace SWELibCode.Db.ConnectionPool

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
    close conn.handle
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
def Connection.handle (conn : Connection) : ConnectionHandle :=
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
def Connection.validate (conn : Connection) (timeout : Nat) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    validateWithTimeout conn.handle timeout

/-- Check if connection has expired. -/
def Connection.checkExpired (conn : Connection) (maxLifetime : Nat) : IO Bool := do
  if ¬ conn.isValid then
    pure true
  else
    isExpired conn.handle maxLifetime

/-- Check if connection has been idle too long. -/
def Connection.checkIdleTooLong (conn : Connection) (idleTimeout : Nat) : IO Bool := do
  if ¬ conn.isValid then
    pure true
  else
    isIdleTooLong conn.handle idleTimeout

/-- Update last used timestamp. -/
def Connection.touch (conn : Connection) : IO Connection := do
  let updatedHandle ← updateLastUsed conn.handle
  pure { conn with handle := updatedHandle }

/-- Execute a query on the connection. -/
def Connection.exec (conn : Connection) (query : String) : IO (Option QueryResult) := do
  if ¬ conn.isValid then
    pure none
  else
    exec conn.handle query

/-- Get connection error message. -/
def Connection.errorMessage (conn : Connection) : IO String :=
  errorMessage conn.handle

/-- Quick health check. -/
def Connection.quickHealthCheck (conn : Connection) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    quickHealthCheck conn.handle

/-- Reset connection. -/
def Connection.reset (conn : Connection) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    reset conn.handle

/-- Ping database server. -/
def Connection.ping (conn : Connection) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    ping conn.handle

/-- Get connection status. -/
def Connection.getStatus (conn : Connection) : IO ConnectionStatus :=
  getStatus conn.handle

/-- Check if connection is writable. -/
def Connection.isWritable (conn : Connection) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    isWritable conn.handle

/-- Check if connection is readable. -/
def Connection.isReadable (conn : Connection) : IO Bool := do
  if ¬ conn.isValid then
    pure false
  else
    isReadable conn.handle

end SWELibCode.Db.ConnectionPool
