# Plan: Linear Logic for Resource Formalizations

## Context

SWELib has several modules that manage resources with acquire/release lifecycles:

| Module | Resource | Acquire | Release | Current invariant style |
|--------|----------|---------|---------|------------------------|
| `Db.ConnectionPool` | Connection | take from idle → active | return from active → idle | Counting (`active.length + idle.length ≤ max`) |
| `OS.Memory` | MemoryRegion | `mmap` adds to AddressSpace | `munmap` removes from AddressSpace | Structural (`regionsDisjoint` proof field) |
| `OS.FileSystem` | OpenFile | `open` allocates fd slot | `close` transitions fd to closed | Table lookup (`Nat → Option FdState`) |
| `OS.Sockets` | Socket | `socket` allocates fd slot | `close` transitions fd to closed | Table lookup + phase enum |
| `OS.Epoll` | EpollInstance | `epollCreate` allocates fd | `closeEpoll` transitions fd | Table lookup |

All five modules share the same pattern: resources are tracked in mutable lookup tables (functions `Nat → Option State`), operations are pure `State → State × Result` functions, and safety properties are proved as theorems about those functions (e.g., `close_closed_ebadf`, `pool_size_constraint`).

**What's missing:** Per-handle linearity. The current formalizations prove aggregate bounds ("pool never exceeds max") but cannot express "this specific connection handle is used exactly once." A caller can, in the current model, hold a `Connection` value and use it after returning it to the pool — nothing in the types prevents it.

Sketch 01 (Node) identifies linear logic as the fix and cites `CSLib: Logics/LinearLogic/`. However, **CSLib's LinearLogic module does not yet exist**. We need to build exactly the fragment we need ourselves, inside SWELib, and design it so that migrating to CSLib's version later is straightforward.

## CSLib Migration Strategy

CSLib is a planned external Lean 4 library that SWELib is designed to build upon. Its `Logics/LinearLogic/` module will eventually provide a full linear logic implementation (multiplicative, additive, exponentials, phase semantics, cut elimination). We can't wait for it.

**Strategy: build a minimal in-tree implementation now, swap it out later.**

- Our implementation lives at `Foundations/LinearLogic/` inside SWELib.
- We implement only the multiplicative fragment + `!` — the subset needed for resource tracking.
- All module-level code (`Db/ConnectionPool/Linear.lean`, `OS/Memory/Linear.lean`, etc.) imports from `SWELib.Foundations.LinearLogic`, never from CSLib directly.
- When CSLib ships its `Logics/LinearLogic/`, we:
  1. Write a shim that maps our `Foundations/LinearLogic` types to CSLib's types (or verify they're structurally compatible).
  2. Replace our `Foundations/LinearLogic/` imports with CSLib imports.
  3. Delete our in-tree implementation.
  4. All downstream module code (`Linear.lean` files) should need only import path changes, not logic changes — as long as we keep our API surface minimal and CSLib-compatible.

**To keep migration easy:**
- Match CSLib's likely naming conventions (e.g., `LFormula`, not `LinearProp`; `tensor`/`lolli`, not custom names).
- Don't build features CSLib will provide better (no phase semantics, no cut elimination proof unless we specifically need it).
- Keep the API surface of `Foundations/LinearLogic/` as small as possible — expose the formula type, the derivation type, and the `LinearResource` typeclass. Nothing else leaks into downstream modules.
- Document every design decision that's "ours vs. what CSLib might do" so the migration author knows what to watch for.

## Design Principles

1. **Build only what we use.** Full linear logic has multiplicative/additive connectives, exponentials, phase semantics, cut elimination. We need the multiplicative fragment (⊗, ⊸, 1) plus the `!` modality — nothing else. Leave the rest for CSLib.

2. **Shallow before deep.** Start with linear logic as a specification language (propositions + sequent derivations). Do not attempt linear types at the Lean term level — Lean 4 has no native support and encoding it is a research project. Instead, state linearity as proof obligations that operations must satisfy.

3. **Layer on top, don't replace.** The existing counting invariants and table-based state models are correct and useful. The linear layer adds per-handle tracking on top. Counting invariants become corollaries of the linear structure.

4. **One generic framework, multiple instances.** Define `LinearResource` once. ConnectionPool, Memory, FileSystem, Sockets, and Epoll each instantiate it.

5. **CSLib-ready.** Every design choice in our in-tree implementation should be made with an eye toward eventual replacement by CSLib. When in doubt, do less — it's easier to adopt a richer upstream API than to untangle a divergent one.

## Architecture

```
spec/SWELib/
├── Foundations/
│   └── LinearLogic/
│       ├── Formula.lean          -- Multiplicative fragment: ⊗, ⊸, 1
│       ├── Sequent.lean          -- Sequent calculus derivations
│       └── Resource.lean         -- LinearResource typeclass + generic theorems
│
├── Db/ConnectionPool/
│   ├── State.lean                -- (existing, unchanged)
│   └── Linear.lean               -- (new) LinearResource instance for connections
│
├── OS/Memory/
│   ├── State.lean                -- (existing, unchanged)
│   └── Linear.lean               -- (new) LinearResource instance for regions
│
├── OS/
│   ├── Io.lean                   -- (existing, unchanged)
│   └── Io/Linear.lean            -- (new) LinearResource instance for fds
│
└── ... (Sockets, Epoll follow same pattern)
```

## Phase 1: Multiplicative Linear Logic Fragment

**File: `Foundations/LinearLogic/Formula.lean`**

Define the propositional language. We need only the multiplicative fragment plus the `!` modality:

```lean
inductive LFormula (α : Type) where
  | atom : α → LFormula α                        -- Atomic proposition (resource type)
  | one : LFormula α                              -- Multiplicative unit (no resource)
  | tensor : LFormula α → LFormula α → LFormula α -- A ⊗ B ("I have A and B")
  | lolli : LFormula α → LFormula α → LFormula α  -- A ⊸ B ("consuming A produces B")
  | bang : LFormula α → LFormula α                 -- !A ("unlimited supply of A")
```

Notation:
- `A ⊗ B` for tensor
- `A ⊸ B` for lolli
- `!A` for bang

We deliberately omit: `⅋` (par), `⊕`/`&` (additives), `?` (why-not), `⊥` (bottom). These are not needed for resource tracking. If future work needs them, they can be added without changing existing code.

**File: `Foundations/LinearLogic/Sequent.lean`**

One-sided sequent calculus for the multiplicative fragment. A sequent is `Γ ⊢ Δ` where `Γ` and `Δ` are multisets of formulas. The key: contexts are **multisets**, not sets — each formula must be consumed exactly once.

```lean
-- Multiset context (List treated as multiset — order irrelevant)
abbrev LCtx (α : Type) := List (LFormula α)

-- Sequent derivation
inductive Derivation : LCtx α → LFormula α → Prop where
  | id : Derivation [A] A
  | tensor_intro :
      Derivation Γ A → Derivation Δ B →
      Derivation (Γ ++ Δ) (A ⊗ B)
  | tensor_elim :
      Derivation Γ (A ⊗ B) →
      Derivation (A :: B :: Δ) C →
      Derivation (Γ ++ Δ) C
  | lolli_intro :
      Derivation (A :: Γ) B →
      Derivation Γ (A ⊸ B)
  | lolli_elim :
      Derivation Γ (A ⊸ B) → Derivation Δ A →
      Derivation (Γ ++ Δ) B
  | one_intro : Derivation [] one
  | one_elim :
      Derivation Γ one → Derivation Δ C →
      Derivation (Γ ++ Δ) C
  | bang_intro :
      Derivation Γ A → (∀ f ∈ Γ, ∃ B, f = bang B) →
      Derivation Γ (bang A)
  | bang_elim :
      Derivation Γ (bang A) →
      Derivation (A :: Δ) C →
      Derivation (Γ ++ Δ) C
  | weaken :
      Derivation Γ C →
      Derivation (bang A :: Γ) C
  | contract :
      Derivation (bang A :: bang A :: Γ) C →
      Derivation (bang A :: Γ) C
```

Key theorem to prove here: **cut elimination** (optional but validates the system is well-behaved). More immediately useful: the **no-weakening** and **no-contraction** properties for non-`!` formulas — these are what make linearity work.

```lean
-- A non-! formula in the context must appear in the derivation
-- (i.e., it cannot be silently dropped — no resource leak)
theorem no_weakening :
    Derivation (atom r :: Γ) C →
    -- r was actually used in the derivation
    usedInDerivation r ...

-- A non-! formula cannot be used twice
-- (i.e., no use-after-free)
theorem no_contraction :
    Derivation Γ C →
    -- each atom in Γ appears at most once
    multisetCount (atom r) Γ ≤ 1 → ...
```

## Phase 2: LinearResource Typeclass

**File: `Foundations/LinearLogic/Resource.lean`**

The bridge between linear logic and SWELib's state-machine style:

```lean
/-- A resource with linear acquire/release discipline.

    `Token` is the capacity unit (e.g., a pool slot, an address range).
    `Handle` is the active resource (e.g., a connection, a memory region, an fd).
    `S` is the system state type. -/
class LinearResource (Token Handle S : Type) where
  /-- Acquire consumes a token from state, producing a handle + new state.
      Modeled as: Token ⊸ Handle (in the linear logic layer). -/
  acquire : S → Token → Option (Handle × S)

  /-- Release consumes a handle, returning a token + new state.
      Modeled as: Handle ⊸ Token (in the linear logic layer). -/
  release : S → Handle → Option (Token × S)

  /-- The linear protocol: acquire followed by release returns the original token.
      This is the round-trip property. -/
  round_trip : ∀ s t h s',
    acquire s t = some (h, s') →
    ∃ t' s'', release s' h = some (t', s'')

  /-- Handle validity: a handle obtained from acquire is valid in the resulting state. -/
  handle_valid : ∀ s t h s',
    acquire s t = some (h, s') → valid h s'

  /-- Handle invalidation: after release, the handle is no longer valid. -/
  handle_invalid : ∀ s h t s',
    release s h = some (t, s') → ¬ valid h s'

  /-- No aliasing: two acquires produce distinct handles. -/
  handles_distinct : ∀ s t₁ t₂ h₁ h₂ s₁ s₂,
    acquire s t₁ = some (h₁, s₁) →
    acquire s₁ t₂ = some (h₂, s₂) →
    h₁ ≠ h₂
```

The linear logic sequent interpretation:

```lean
/-- The resource protocol as a linear logic formula.
    acquire : Token ⊸ Handle
    release : Handle ⊸ Token
    Full lifecycle: Token ⊸ (Handle ⊗ (Handle ⊸ Token))

    This says: consuming a Token gives you a Handle AND an obligation
    to eventually return the Handle (getting the Token back). -/
def resourceProtocol (Token Handle : Type) : LFormula ResourceAtom :=
  .lolli (.atom (.token Token))
         (.tensor (.atom (.handle Handle))
                  (.lolli (.atom (.handle Handle)) (.atom (.token Token))))
```

Generic theorems derivable from the typeclass:

```lean
/-- If you acquire N resources, you hold N handles and the pool has N fewer tokens. -/
theorem acquire_n_handles ...

/-- If you release all handles, the token count is restored. -/
theorem release_restores_count ...

/-- A handle cannot be released twice (second release fails). -/
theorem no_double_release ...

/-- Conservation: tokens + handles = constant (no creation or destruction). -/
theorem resource_conservation ...
```

## Phase 3: Module Instances

### 3a. ConnectionPool (`Db/ConnectionPool/Linear.lean`)

```lean
-- Atoms for connection pool linear logic
inductive PoolAtom where
  | slot          -- A capacity slot in the pool (the Token)
  | connection    -- An active connection (the Handle)

-- The pool protocol in linear logic:
-- N × !Config ⊢ (Slot ⊸ Connection) ⊗ (Connection ⊸ Slot)
-- "Given N slots and unlimited config, you can acquire/release connections"

instance : LinearResource PoolSlot Connection PoolState where
  acquire state slot :=
    -- Take from idle list, move to active list
    match state.idle with
    | conn :: rest => some (conn, { state with
        active := conn :: state.active
        idle := rest
        ... })
    | [] => none  -- No idle connections (slot exists but pool needs to create)

  release state conn :=
    -- Remove from active, return to idle
    if conn ∈ state.active
    then some (poolSlot, { state with
        active := state.active.erase conn
        idle := conn :: state.idle
        ... })
    else none  -- Connection not active (double-release → fails)

  round_trip := by ...
  handle_valid := by ...
  handle_invalid := by ...  -- After release, conn ∉ active
  handles_distinct := by ... -- Each connection object is unique
```

**New theorems enabled:**
- `connection_use_after_release_impossible`: If `release state conn = some _`, then in the resulting state, `conn` is not in `active` and cannot be used for queries.
- `connection_leak_detected`: If a `PoolSlot` was consumed by `acquire` and the corresponding `Connection` handle is not passed to `release` before the pool is shut down, we can detect it (the token count doesn't balance).
- `pool_conservation`: `state.active.length + state.idle.length` is invariant across acquire/release cycles. (This is the existing `total_eq_sum` but now it **follows from** linearity rather than being independently stated.)

### 3b. Memory (`OS/Memory/Linear.lean`)

```lean
inductive MemoryAtom where
  | addressRange (start : VirtualAddress) (len : Nat)  -- Token: available address space
  | mapping (region : MemoryRegion)                      -- Handle: live mapping

instance : LinearResource AddressRange MemoryRegion AddressSpace where
  acquire space range :=
    -- mmap: consume available range, produce a MemoryRegion
    if rangeAvailable space range.start range.len
    then some (mkRegion range, addRegion space (mkRegion range))
    else none

  release space region :=
    -- munmap: consume the MemoryRegion, return the address range
    if region ∈ space.regions
    then some (rangeOf region, removeRange space region.start region.size)
    else none

  round_trip := by ...
  handle_valid := by ...    -- region ∈ space.regions
  handle_invalid := by ...  -- region ∉ resulting space.regions
  handles_distinct := by ... -- disjoint regions (from AddressSpace.disjoint)
```

**New theorems enabled:**
- `use_after_unmap_impossible`: A `MemoryRegion` handle consumed by `munmap` cannot be passed to `mprotect` or read/write operations afterward.
- `double_unmap_fails`: `munmap` on an already-unmapped region returns an error.
- `no_mapping_leak`: Every `mmap`'d region has a corresponding `munmap` in any complete execution trace (or the process exits, which implicitly unmaps all).
- `address_space_conservation`: Total mapped + total available = constant address space.

### 3c. File Descriptors (`OS/Io/Linear.lean`)

```lean
inductive FdAtom where
  | fdSlot (n : Nat)       -- Token: an available fd number
  | openFd (fd : Nat)      -- Handle: an open file descriptor

instance : LinearResource FdSlot OpenFd FdTable where
  acquire table slot :=
    -- open/socket/epoll_create: consume a slot, produce an open fd
    some (openFd slot.n, table.update slot.n (some (FdState.open kind)))

  release table fd :=
    -- close: consume the open fd, return the slot
    match table.lookup fd.n with
    | some (FdState.open _) =>
        some (fdSlot fd.n, table.close fd.n)
    | _ => none

  round_trip := by ...
  handle_valid := by ...    -- table.isOpen fd.n
  handle_invalid := by ...  -- ¬ table.isOpen fd.n after close
  handles_distinct := by ... -- different fd numbers
```

**New theorems enabled:**
- `read_after_close_impossible`: An `OpenFd` handle consumed by `close` cannot be passed to `read`/`write`/`send`/`recv`.
- `double_close_ebadf`: Immediate corollary — the existing `close_closed_ebadf` theorem now follows from linearity.
- `fd_leak_detected`: An `FdSlot` consumed by `open` without a corresponding `close` on the resulting `OpenFd` is a leak.

### 3d. Sockets and Epoll

Follow the same pattern as file descriptors (they already share the fd table). The socket state machine phases (unbound → bound → listening → connected → shutdown) become a **chain of linear implications**:

```
FdSlot ⊸ UnboundSocket
UnboundSocket ⊸ BoundSocket
BoundSocket ⊸ (ListeningSocket ⊕ ConnectedSocket)  -- additive choice
ListeningSocket ⊸ ... (accept loop)
ConnectedSocket ⊸ ... (send/recv) ⊸ ClosedSocket ⊸ FdSlot
```

Each phase transition consumes the previous handle and produces the next. You can't `send` on a `BoundSocket` or `listen` on a `ConnectedSocket` — the types prevent it.

For epoll, the registration is a linear resource too:
```
EpollInstance ⊗ OpenFd ⊸ EpollInstance ⊗ Registration
Registration ⊸ EpollInstance  -- epoll_ctl DEL
```

This captures the existing theorem `close_auto_removes_from_epoll` — closing an fd implicitly consumes its `Registration`.

## Phase 4: Connection to Node LTS (Future)

Once the Systems/Node framework from the sketches exists, resource operations become internal (τ) transitions in the Node's LTS. The linear resource discipline constrains which state transitions are reachable:

```
-- A Node's reachable states respect linear resource conservation
theorem node_resource_conservation (node : Node S α) [LinearResource T H S] :
    ∀ s, node.lts.reachable s →
    tokenCount s + handleCount s = initialTokenCount
```

This connects to sketch 01's vision: "Resources within a Node (connections, file descriptors, memory regions) can be modeled using linear logic."

The Node's LTS state includes the resource state (pool state, address space, fd table). The linear discipline is a **refinement invariant** — it constrains the LTS's reachable states without changing the LTS definition itself.

## Dependency Order

```
Phase 1: Foundations/LinearLogic/Formula.lean      -- no dependencies
Phase 1: Foundations/LinearLogic/Sequent.lean       -- depends on Formula
Phase 2: Foundations/LinearLogic/Resource.lean       -- depends on Sequent
Phase 3a: Db/ConnectionPool/Linear.lean             -- depends on Resource + existing State
Phase 3b: OS/Memory/Linear.lean                     -- depends on Resource + existing State
Phase 3c: OS/Io/Linear.lean                         -- depends on Resource + existing Io
Phase 3d: OS/Sockets/Linear.lean                    -- depends on Resource + existing Sockets
Phase 3e: OS/Epoll/Linear.lean                      -- depends on Resource + existing Epoll
Phase 4: Systems/Node integration                   -- depends on all above + sketch 01 framework
```

Phases 3a-3e are independent of each other and can be done in any order (or in parallel).

## What This Does NOT Change

- **Existing files are not modified.** Every existing theorem, structure, and definition remains. The `Linear.lean` files are new companions, not replacements.
- **Counting invariants stay.** `pool_size_constraint`, `total_count_constraint`, `regionsDisjoint`, etc. remain as they are. The linear layer proves them as corollaries rather than replacing them.
- **Table-based state stays.** `FdTable`, `PoolState`, `AddressSpace` remain the state types. The `LinearResource` typeclass is defined in terms of these existing state types.

## What This Adds

| Property | Before | After |
|----------|--------|-------|
| Use-after-release | Not expressible | Type error (handle consumed) |
| Double release | Runtime theorem (`close_closed_ebadf`) | Structural impossibility (handle already consumed) |
| Resource leak | Not detectable | Detectable (unconsumed handle) |
| Conservation law | Manually stated per module | Generic theorem from `LinearResource` |
| Aggregate bounds | Manually stated (`size_invariant`) | Corollary of conservation |

## Open Questions

1. **Multiset representation.** The sequent calculus needs multisets. Options: `List` with permutation equivalence, `Finset` with multiplicity, or `Multiset` from Mathlib. Mathlib's `Multiset` is cleanest but adds a dependency. Lean's `List` with a custom equivalence relation is self-contained.

2. **How deep should the sequent calculus go?** Option A: prove cut elimination and get the full metatheory. Option B: just define the derivation type and use it as a specification language without proving metatheorems. Option B is faster and sufficient for the resource instances. Option A is better if we plan to use the linear logic for other things later.

3. **`dup` and `fork` as controlled non-linearity.** File descriptors can be duplicated (`dup`/`dup2`), and forked processes inherit fds. These are legitimate violations of linearity. They should be modeled as explicit "split" operations that consume one handle and produce two: `OpenFd ⊸ OpenFd ⊗ OpenFd`. The `!` modality is too strong (it says "unlimited copies"). We may need an explicit `split` constructor or a multiplicity-tracked variant.

4. **Exception paths.** If an operation fails (returns `Err`), the resource handle must still be valid (not consumed). The linear protocol needs an error branch: `Handle ⊸ (Result ⊗ Handle) ⊕ (Error ⊗ Handle)` — on failure, you get your handle back. This is important for `mprotect` (can fail without consuming the region) vs. `munmap` (consumes the region on success).
