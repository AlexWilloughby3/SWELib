/-!
# Pool Manager

Connection pool management logic with thread safety.

## Specification References
- D-014: PoolState with Invariants
- All key operations from the formalization plan
-/

import SWELibCode.Db.ConnectionPool.Types
import SWELibCode.Db.ConnectionPool.FFI
import SWELibCode.Db.ConnectionPool.Mutex
import SWELibCode.Db.ConnectionPool.Connection

namespace SWELibCode.Db.ConnectionPool

/-- Pool state for runtime management. -/
structure Pool where
  /-- Connection parameters -/
  params : ConnectionParameters
  /-- Pool configuration -/
  config : PoolConfig
  /-- Mutex for thread safety -/
  mutex : Mutex
  /-- Condition variable for waiting connections -/
  condition : Condition
  /-- Active connections -/
  active : SyncMap Connection
  /-- Idle connections queue -/
  idle : IO.Ref (Array Connection)
  /-- Total connection count -/
  totalCount : IO.Ref Nat
  /-- Wait queue for connection requests -/
  waitQueue : IO.Ref (Array (Nat × IO.Promise Connection))

/-- Create a new connection pool. -/
def createPool (params : ConnectionParameters) (config : PoolConfig) : IO Pool := do
  match config.validate with
  | some error => throw (IO.userError error)
  | none => do
    let mutex ← newMutex
    let condition ← newCondition
    let active ← SyncMap.new Connection
    let idle ← IO.mkRef (Array.empty : Array Connection)
    let totalCount ← IO.mkRef 0
    let waitQueue ← IO.mkRef (Array.empty : Array (Nat × IO.Promise Connection))
    pure {
      params := params
      config := config
      mutex := mutex
      condition := condition
      active := active
      idle := idle
      totalCount := totalCount
      waitQueue := waitQueue
    }

/-- Get a connection from the pool. -/
def getConnection (pool : Pool) : IO (Except ConnectionError Connection) :=
  withMutex pool.mutex do
    -- Check idle connections first
    let idleConns ← pool.idle.get
    if idleConns.size > 0 then
      let conn := idleConns[0]!
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
        -- Wait for connection to become available
        let promise ← IO.Promise.new
        let waitEntry := (pool.config.connectionTimeout, promise)
        pool.waitQueue.modify fun queue => queue.push waitEntry
        match ← promise.result pool.config.connectionTimeout with
        | .ok conn => pure (.ok conn)
        | .error _ => pure (.error .PoolExhausted)

/-- Try to get a connection with timeout. -/
def tryGetConnection (pool : Pool) (timeout : Nat) : IO (Option Connection) := do
  match ← getConnection pool with
  | .ok conn => pure (some conn)
  | .error _ => pure none

/-- Release a connection back to the pool. -/
def releaseConnection (pool : Pool) (conn : Connection) : IO Unit :=
  withMutex pool.mutex do
    -- Remove from active
    pool.active.erase conn.id

    -- Check if connection is still valid
    let isValid ← conn.quickHealthCheck
    if isValid then
      -- Add to idle if valid
      pool.idle.modify fun idle => idle.push conn
      -- Notify waiters
      pool.condition.signal
    else
      -- Invalidate and decrement total count
      pool.totalCount.modify fun total => total - 1

/-- Invalidate a connection. -/
def invalidateConnection (pool : Pool) (conn : Connection) : IO Unit :=
  withMutex pool.mutex do
    -- Remove from active or idle
    pool.active.erase conn.id
    pool.idle.modify fun idle => idle.filter fun c => c.id ≠ conn.id
    -- Decrement total count
    pool.totalCount.modify fun total => total - 1
    -- Close the connection
    let _ ← conn.release

/-- Validate a connection. -/
def validateConnection (conn : Connection) : IO Bool :=
  conn.validate 1000  -- 1 second default validation timeout

/-- Close the pool and all connections. -/
def closePool (pool : Pool) : IO Unit :=
  withMutex pool.mutex do
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
    pool.waitQueue.set Array.empty

/-- Evict idle connections that have timed out. -/
def evictIdleConnections (pool : Pool) : IO Unit :=
  withMutex pool.mutex do
    let now ← IO.monoMsNow
    let idleConns ← pool.idle.get
    -- Partition using pure timestamp checks on the connection handle fields
    let (valid, invalid) := idleConns.partition fun conn =>
      let idleElapsed := now - conn.handle.lastUsed
      let totalElapsed := now - conn.handle.createdAt
      idleElapsed < pool.config.idleTimeout.toUInt64 &&
      totalElapsed < pool.config.maxLifetime.toUInt64
    pool.idle.set valid
    for conn in invalid do
      pool.totalCount.modify fun total => total - 1
      let _ ← conn.release

/-- Get pool statistics. -/
def getPoolStats (pool : Pool) : IO (Nat × Nat × Nat) :=
  withMutex pool.mutex do
    let activeCount ← pool.active.size
    let idleCount ← (pool.idle.get).size
    let totalCount ← pool.totalCount.get
    pure (activeCount, idleCount, totalCount)

/-- Check if pool has capacity for new connections. -/
def hasCapacity (pool : Pool) : IO Bool :=
  withMutex pool.mutex do
    let total ← pool.totalCount.get
    pure (total < pool.config.maximumPoolSize)

/-- Ensure minimum idle connections are maintained. -/
def ensureMinIdle (pool : Pool) : IO Unit :=
  withMutex pool.mutex do
    let idleCount ← (pool.idle.get).size
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

end SWELibCode.Db.ConnectionPool
