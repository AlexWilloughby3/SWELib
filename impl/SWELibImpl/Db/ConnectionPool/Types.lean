import SWELib.Db.ConnectionPool.Types
import SWELibImpl.Bridge.Libpq.Connect

/-!
# Connection Pool Types (Code Layer)

Executable type definitions for database connection pooling.

## Specification References
- D-011: ConnectionParameters as Record with Optional Fields
- D-012: PoolConfig as Record with Range Proofs
- D-013: ConnectionStatus as Inductive Enum (12 states)
- D-015: Connection as Opaque Handle
-/

namespace SWELibImpl.Db.ConnectionPool

open SWELib.Db.ConnectionPool

/-- Connection handle with underlying libpq pointer and metadata. -/
structure ConnectionHandle where
  /-- Unique connection ID -/
  id : UInt64
  /-- Underlying libpq connection pointer -/
  ptr : SWELibImpl.Bridge.Libpq.ConnectionHandle
  /-- Creation timestamp (milliseconds since epoch) -/
  createdAt : Nat
  /-- Last used timestamp (milliseconds since epoch) -/
  lastUsed : Nat
  /-- Whether the connection is currently valid -/
  isValid : Bool := true

/-- Internal connection state for pool management. -/
inductive InternalConnectionStatus
  | Active
  | Idle
  | Broken
  | Validating
  deriving DecidableEq, Repr

/-- Connection wrapper with internal state and finalizer. -/
structure Connection where
  /-- The connection handle -/
  handle : ConnectionHandle
  /-- Internal state for pool management -/
  state : InternalConnectionStatus := .Idle
  /-- Reference count for shared ownership -/
  refCount : Nat := 1

/-- Pool configuration without proofs (for runtime use). -/
structure PoolConfig where
  maximumPoolSize : Nat
  minimumIdle : Nat
  connectionTimeout : Nat
  idleTimeout : Nat
  maxLifetime : Nat
  validationTimeout : Nat

/-- Create a runtime pool config from a specification config. -/
def PoolConfig.ofSpec (spec : SWELib.Db.ConnectionPool.PoolConfig) : PoolConfig :=
  {
    maximumPoolSize := spec.maximumPoolSize
    minimumIdle := spec.minimumIdle
    connectionTimeout := spec.connectionTimeout
    idleTimeout := spec.idleTimeout
    maxLifetime := spec.maxLifetime
    validationTimeout := spec.validationTimeout
  }

/-- Check if runtime config satisfies specification constraints. -/
def PoolConfig.validate (config : PoolConfig) : Option String :=
  if config.minimumIdle > config.maximumPoolSize then
    some "minimumIdle cannot exceed maximumPoolSize"
  else if config.validationTimeout >= config.connectionTimeout then
    some "validationTimeout must be less than connectionTimeout"
  else
    none

/-- Connection parameters for runtime use. -/
abbrev ConnectionParameters := SWELib.Db.ConnectionPool.ConnectionParameters

/-- Connection status for runtime use. -/
abbrev ConnectionStatus := SWELib.Db.ConnectionPool.ConnectionStatus

/-- Connection error for runtime use. -/
abbrev ConnectionError := SWELib.Db.ConnectionPool.ConnectionError

end SWELibImpl.Db.ConnectionPool
