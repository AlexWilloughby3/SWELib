/-!
# Mutex and Thread Synchronization

Thread-safe synchronization primitives for connection pool.

## Specification References
- Thread safety requirements (documented, not formally proven)
-/

import Std.Data.RBMap

namespace SWELibCode.Db.ConnectionPool

/-- Mutex for thread-safe pool operations. -/
abbrev Mutex := IO.Mutex Unit

/-- Create a new mutex. -/
def newMutex : IO Mutex :=
  IO.Mutex.new ()

/-- Synchronized map for connection tracking. -/
structure SyncMap (α : Type) where
  mutex : Mutex
  data : IO.Ref (Std.RBMap UInt64 α compare)

/-- Create a new synchronized map. -/
def SyncMap.new (α : Type) : IO (SyncMap α) := do
  let mutex ← newMutex
  let ref ← IO.mkRef (Std.RBMap.empty : Std.RBMap UInt64 α compare)
  pure { mutex, data := ref }

/-- Execute an operation with mutex protection. -/
def withMutex [Monad m] [MonadLiftT IO m] (mutex : Mutex) (action : m α) : m α :=
  mutex.atomically action

/-- Get value from synchronized map. -/
def SyncMap.get (map : SyncMap α) (key : UInt64) : IO (Option α) :=
  withMutex map.mutex do
    let data ← map.data.get
    pure (data.find? key)

/-- Insert value into synchronized map. -/
def SyncMap.insert (map : SyncMap α) (key : UInt64) (value : α) : IO Unit :=
  withMutex map.mutex do
    map.data.modify fun data => data.insert key value

/-- Remove value from synchronized map. -/
def SyncMap.erase (map : SyncMap α) (key : UInt64) : IO Unit :=
  withMutex map.mutex do
    map.data.modify fun data => data.erase key

/-- Check if key exists in synchronized map. -/
def SyncMap.contains (map : SyncMap α) (key : UInt64) : IO Bool :=
  withMutex map.mutex do
    let data ← map.data.get
    pure (data.contains key)

/-- Get all keys from synchronized map. -/
def SyncMap.keys (map : SyncMap α) : IO (Array UInt64) :=
  withMutex map.mutex do
    let data ← map.data.get
    pure (data.fold (fun acc key _ => acc.push key) #[])

/-- Get all values from synchronized map. -/
def SyncMap.values (map : SyncMap α) : IO (Array α) :=
  withMutex map.mutex do
    let data ← map.data.get
    pure (data.fold (fun acc _ value => acc.push value) #[])

/-- Get size of synchronized map. -/
def SyncMap.size (map : SyncMap α) : IO Nat :=
  withMutex map.mutex do
    let data ← map.data.get
    pure data.size

/-- Clear synchronized map. -/
def SyncMap.clear (map : SyncMap α) : IO Unit :=
  withMutex map.mutex do
    map.data.set Std.RBMap.empty

/-- Condition variable for waiting on connections. -/
abbrev Condition := IO.Condition

/-- Create a new condition variable. -/
def newCondition : IO Condition :=
  IO.Condition.new

/-- Wait on condition variable with timeout. -/
def Condition.wait (cond : Condition) (mutex : Mutex) (timeout : Nat) : IO Bool :=
  cond.wait mutex (max := timeout)

/-- Notify one waiter on condition variable. -/
def Condition.signal (cond : Condition) : IO Unit :=
  cond.signal

/-- Notify all waiters on condition variable. -/
def Condition.broadcast (cond : Condition) : IO Unit :=
  cond.broadcast

end SWELibCode.Db.ConnectionPool
