import SWELibImpl.Db.ConnectionPool.Types
import SWELibImpl.Db.ConnectionPool.FFI
import SWELibImpl.Db.ConnectionPool.Mutex
import SWELibImpl.Db.ConnectionPool.Connection

/-!
# Pool Manager

Connection pool management logic.

## Specification References
- D-014: PoolState with Invariants
- All key operations from the formalization plan
-/

namespace SWELibImpl.Db.ConnectionPool

/-- Pool state for runtime management. -/
structure Pool where
  /-- Connection parameters -/
  params : ConnectionParameters
  /-- Pool configuration -/
  config : PoolConfig
  /-- Active connections -/
  active : SyncMap Connection
  /-- Idle connections queue -/
  idle : IO.Ref (Array Connection)
  /-- Total connection count -/
  totalCount : IO.Ref Nat

/-- Create a new connection pool. -/
def createPool (params : ConnectionParameters) (config : PoolConfig) : IO Pool := do
  match config.validate with
  | some error => throw (IO.userError error)
  | none => do
    let active ← SyncMap.new Connection
    let idle ← IO.mkRef (Array.empty : Array Connection)
    let totalCount ← IO.mkRef 0
    pure {
      params := params
      config := config
      active := active
      idle := idle
      totalCount := totalCount
    }

/-- Get a connection from the pool. -/
def getConnection (pool : Pool) : IO (Except ConnectionError Connection) := do
  -- Check idle connections first
  let idleConns ← pool.idle.get
  if h : idleConns.size > 0 then
    let conn := idleConns[0]'(by omega)
    let remaining := idleConns.extract 1 idleConns.size
    pool.idle.set remaining
    pool.active.insert conn.id conn
    pure (.ok conn)
  else
    -- Check if we can create new connection
    let total ← pool.totalCount.get
    if total < pool.config.maximumPoolSize then
      let id := total.toUInt64
      match ← connect pool.params id with
      | none => pure (.error .ConnectionTimeout)
      | some handle => do
        let conn := Connection.new handle
        pool.active.insert conn.id conn
        pool.totalCount.set (total + 1)
        pure (.ok conn)
    else
      pure (.error .PoolExhausted)

/-- Try to get a connection with timeout. -/
def tryGetConnection (pool : Pool) (_timeout : Nat) : IO (Option Connection) := do
  match ← getConnection pool with
  | .ok conn => pure (some conn)
  | .error _ => pure none

/-- Release a connection back to the pool. -/
def releaseConnection (pool : Pool) (conn : Connection) : IO Unit := do
  -- Remove from active
  pool.active.erase conn.id
  -- Check if connection is still valid
  let isValid ← conn.quickHealthCheck'
  if isValid then
    -- Add to idle if valid
    pool.idle.modify fun idle => idle.push conn
  else
    -- Invalidate and decrement total count
    pool.totalCount.modify fun total => total - 1

/-- Invalidate a connection. -/
def invalidateConnection (pool : Pool) (conn : Connection) : IO Unit := do
  -- Remove from active or idle
  pool.active.erase conn.id
  pool.idle.modify fun idle => idle.filter fun c => c.id ≠ conn.id
  -- Decrement total count
  pool.totalCount.modify fun total => total - 1
  -- Close the connection
  let _ ← conn.release

/-- Validate a connection. -/
def validateConnection (conn : Connection) : IO Bool :=
  conn.validate' 1000  -- 1 second default validation timeout

/-- Close the pool and all connections. -/
def closePool (pool : Pool) : IO Unit := do
  -- Close all active connections
  let activeConns ← pool.active.values
  for conn in activeConns do
    let _ ← conn.release

  -- Close all idle connections
  let idleConns ← pool.idle.get
  for conn in idleConns do
    let _ ← conn.release

  -- Clear all state
  pool.active.clear
  pool.idle.set Array.empty
  pool.totalCount.set 0

/-- Evict idle connections that have timed out. -/
def evictIdleConnections (pool : Pool) : IO Unit := do
  let now ← IO.monoMsNow
  let idleConns ← pool.idle.get
  let (valid, invalid) := idleConns.partition fun conn =>
    let idleElapsed := now - conn.handle.lastUsed
    let totalElapsed := now - conn.handle.createdAt
    idleElapsed < pool.config.idleTimeout && totalElapsed < pool.config.maxLifetime
  pool.idle.set valid
  for conn in invalid do
    pool.totalCount.modify fun total => total - 1
    let _ ← conn.release

/-- Get pool statistics. -/
def getPoolStats (pool : Pool) : IO (Nat × Nat × Nat) := do
  let activeCount ← pool.active.size
  let idleConns ← pool.idle.get
  let idleCount := idleConns.size
  let totalCount ← pool.totalCount.get
  pure (activeCount, idleCount, totalCount)

/-- Check if pool has capacity for new connections. -/
def hasCapacity (pool : Pool) : IO Bool := do
  let total ← pool.totalCount.get
  pure (total < pool.config.maximumPoolSize)

/-- Ensure minimum idle connections are maintained. -/
def ensureMinIdle (pool : Pool) : IO Unit := do
  let idleConns ← pool.idle.get
  let idleCount := idleConns.size
  let total ← pool.totalCount.get

  if idleCount < pool.config.minimumIdle ∧ total < pool.config.maximumPoolSize then
    let needed := min (pool.config.minimumIdle - idleCount) (pool.config.maximumPoolSize - total)
    let mut created := 0
    for _ in [:needed] do
      let id := (total + created).toUInt64
      match ← connect pool.params id with
      | some handle =>
          let conn := Connection.new handle
          pool.idle.modify fun idle => idle.push conn
          created := created + 1
      | none => pure ()  -- Skip failed connections
    pool.totalCount.modify fun t => t + created

end SWELibImpl.Db.ConnectionPool
