import SWELib.Db.ConnectionPool.Types

/-!
# Connection Pool State

Pool state representation with invariants for connection management.

## Specification References
- D-014: PoolState as Record with Invariants
-/

namespace SWELib.Db.ConnectionPool

/-- Promise type for asynchronous connection acquisition. -/
abbrev Promise (α : Type) := Nat × α

/-- List of promises for connection acquisition. -/
abbrev PromiseList := List (Promise Connection)

/-- Pool state with size and connection tracking invariants.

    See D-014 for the record structure and invariants. -/
structure PoolState where
  /-- List of active connections currently in use -/
  active : List Connection
  /-- List of idle connections available for reuse -/
  idle : List Connection
  /-- List of promises waiting for connections -/
  waitList : PromiseList
  /-- Total number of connections created (active + idle) -/
  totalCount : Nat
  /-- Pool configuration -/
  config : PoolConfig
  /-- Invariant: active.length + idle.length ≤ maximumPoolSize -/
  size_invariant : active.length + idle.length ≤ config.maximumPoolSize
  /-- Invariant: totalCount = active.length + idle.length -/
  total_eq_sum : totalCount = active.length + idle.length
  /-- Invariant: minimum idle is satisfied or pool has capacity -/
  min_idle_ok : idle.length ≥ config.minimumIdle ∨ totalCount < config.maximumPoolSize
  /-- Invariant: wait list plus active connections ≤ maximumPoolSize -/
  wait_ok : waitList.length + active.length ≤ config.maximumPoolSize
  /-- Invariant: a connection cannot be both active and idle -/
  disjoint_ok : ∀ conn, conn ∈ active → conn ∉ idle

/-- Check if the pool has available capacity for new connections. -/
def hasCapacity (state : PoolState) : Bool :=
  state.totalCount < state.config.maximumPoolSize

/-- Check if minimum idle invariant is satisfied. -/
def satisfiesMinIdle (state : PoolState) : Bool :=
  state.idle.length >= state.config.minimumIdle || state.totalCount < state.config.maximumPoolSize

/-- Theorem: Pool state always satisfies capacity constraints. -/
theorem pool_size_constraint (state : PoolState) :
    state.active.length + state.idle.length ≤ state.config.maximumPoolSize :=
  state.size_invariant

/-- Theorem: Total connection count never exceeds maximum pool size. -/
theorem total_count_constraint (state : PoolState) :
    state.totalCount ≤ state.config.maximumPoolSize := by
  rw [state.total_eq_sum]; exact state.size_invariant

/-- Theorem: Minimum idle invariant is always satisfied (from struct invariant). -/
theorem min_idle_satisfied (state : PoolState) :
    satisfiesMinIdle state = true := by
  rcases state.min_idle_ok with h | h <;> simp [satisfiesMinIdle, h]

end SWELib.Db.ConnectionPool
