# Sketch: Migration & System Evolution

## What This Sketch Defines

How Systems change over time. A migration is a transition from one System version to another, passing through a **MixedVersionState** where both versions coexist. The central question: does the mixed state preserve safety?

In LTS/CCS terms: a Migration replaces some Nodes with new versions. The MixedVersionState is a System where some Nodes are v1 and some are v2, composed with CCS parallel. Migration safety = the mixed System's LTS satisfies the same safety properties as both the v1 and v2 Systems.

## Theoretical Foundation: CSLib

### Migration as Node Substitution

A migration replaces Node A (v1) with Node A' (v2) in a System. The CCS congruence theorem (from CSLib) tells us: **if A and A' are bisimilar, the migration trivially preserves all properties.** The interesting case is when they're NOT bisimilar — the Node's observable behavior has changed.

```
-- System v1
System_v1 = (A_v1 | B | C) \ channels

-- System v2 (A changed, B and C unchanged)
System_v2 = (A_v2 | B | C) \ channels

-- Migration is safe if System_v2 satisfies the same properties as System_v1
-- OR if the properties have been explicitly updated
```

### MixedVersionState as CCS Composition

During a rolling deploy, some Nodes are v1 and some are v2:

```
-- Mixed state during rolling deploy (2 of 3 app servers upgraded)
System_mixed = (A_v2 | A_v2 | A_v1 | Database | Cache) \ channels

-- The question: does System_mixed satisfy the safety properties?
-- This depends on compatibility between v1 and v2 actions
```

**Compatibility** is a property of the CCS action alphabets:
- **Backward compatible**: v2's output actions are a superset of v1's (v2 can do everything v1 could, plus more). v1 Nodes can still process v2's messages.
- **Forward compatible**: v1 can handle v2's new output actions (by ignoring unknown fields, etc.).
- **Wire compatible**: v1 and v2 can synchronize on shared channels — their action alphabets overlap correctly.

In LTS terms: v1 and v2 Nodes can coexist in a CCS composition without deadlock on shared channels.

### Bisimulation for Migration Impact

Bisimulation quantifies *how much* a migration changes observable behavior:

- **A_v1 ∼ A_v2** (bisimilar): migration is invisible. Zero risk. Blue-green deploy is safe with instant cutover.
- **A_v1 ≈ A_v2** (weakly bisimilar): internal behavior changed but external interface is the same. Safe for all external observers.
- **A_v1 ≁ A_v2** (not bisimilar): observable behavior changed. Need to check that all consumers can handle the new behavior. The diff between the two LTS characterizes what changed.

The simulation relation (Lynch) gives a one-directional version: A_v2 simulates A_v1 means every behavior of v1 is preserved in v2 (backward compatible). A_v1 simulates A_v2 means v1 can handle everything v2 does (forward compatible).

## Key Types to Formalize

### Version

```
-- Opaque version identifier
structure Version where
  id : Nat
  deriving DecidableEq

-- Or semantic versioning (already in SWELib Basics/Semver)
-- structure Version := Semver
```

### Migration

A structured diff between two System versions:

```
structure Migration (old new : System) where
  -- What changed
  nodesAdded : Finset (NodeId × Node)
  nodesRemoved : Finset NodeId
  nodesModified : Finset (NodeId × Node × Node)    -- (id, old, new)
  topologyChanges : List TopologyChange              -- edges added/removed

  -- Consistency: the diff actually connects old to new
  consistent : applyDiff old this = new
```

### ChangeKind

Classification of individual changes — determines default safety analysis:

```
inductive ChangeKind where
  | additive       -- new optional field, new endpoint, new Node
  | subtractive    -- removed field, removed endpoint, removed Node
  | modifying      -- changed type, changed semantics
  | structural     -- split a Node, merge Nodes, change topology
```

- **Additive** changes are generally safe (bisimulation is preserved if new actions don't interfere with existing ones)
- **Subtractive** changes break bisimulation (the old behavior is no longer available)
- **Modifying** changes require case-by-case analysis
- **Structural** changes require re-proving System-level properties

### MixedVersionState

The System during transition:

```
-- What's happening to a Node during migration
inductive NodeStatus where
  | atOld             -- still on v1
  | atNew             -- already upgraded to v2
  | pendingCreate     -- exists in v2 but not yet running
  | pendingDestroy    -- exists in v1, scheduled for removal, still running

structure MixedVersionState (old new : System) where
  -- Status of each Node (covers upgrades, creates, and destroys)
  nodeStatus : NodeId → NodeStatus

  -- The actual mixed System (CCS composition of whatever is running)
  mixedSystem : System

  -- Consistency: the running system matches node statuses
  status_consistent : ∀ id,
    nodeStatus id = .atOld → mixedSystem.node id = old.node id
    ∧ nodeStatus id = .atNew → mixedSystem.node id = new.node id
    ∧ nodeStatus id = .pendingCreate → mixedSystem.node id = none
    ∧ nodeStatus id = .pendingDestroy → mixedSystem.node id = old.node id
```

### DeploymentPlan

A deployment plan imposes an order on the migration — which Nodes transition in which phase. This captures patterns like "database migrates before app servers."

```
-- A single phase: a group of Nodes that transition together
structure DeploymentPhase where
  targets : Finset NodeId
  action : NodeId → PhaseAction

inductive PhaseAction where
  | upgrade           -- v1 → v2
  | create            -- not running → v2
  | destroy           -- v1 → removed

structure DeploymentPlan (old new : System) where
  -- Ordered list of phases
  phases : List DeploymentPhase

  -- Phases cover the full migration (no Node left behind)
  covers : (phases.bind (·.targets.toList)).toFinset =
    migration.nodesModified ∪ migration.nodesAdded ∪ migration.nodesRemoved

  -- Each phase is safe: the MixedVersionState after completing phase i
  -- satisfies the system policy
  phase_safety : ∀ i, i < phases.length →
    satisfies (stateAfterPhase old phases i).mixedSystem policy

  -- Phase ordering respects dependencies: if Node A depends on Node B,
  -- B's phase comes before A's phase
  respects_deps : ∀ a b, depends a b →
    phaseOf phases b ≤ phaseOf phases a
```

This is intentionally minimal. The key insight is `respects_deps`: if your app server depends on the database, the database's phase index must be ≤ the app server's. Combined with `phase_safety`, this guarantees that at every intermediate state the system is valid.

**Deployment strategies as special cases:**

- **Blue-green**: single phase containing all Nodes (no mixed state)
- **Rolling update**: one phase per Node (or per batch), no ordering constraints
- **Ordered/staged**: multiple phases with `respects_deps` encoding the dependency order
- **Expand-contract**: three phases (add column → migrate readers → drop old column), each phase targets different Nodes

### Compatibility

```
structure Compatibility (v1 v2 : Node) where
  backward : v2.simulatesTraces v1      -- v2 can do everything v1 could
  forward : v1.canHandle v2.outputs     -- v1 can process v2's new outputs
  wire : v1.actions ∩ v2.actions ≠ ∅    -- they can still synchronize
```

In CCS terms: backward = simulation v1 ≤ v2. Forward = v1's input alphabet includes v2's output alphabet. Wire = shared channel names for CCS synchronization.

### RollbackPlan

```
structure RollbackPlan (old new : System) where
  rollback : Migration new old           -- the reverse migration
  data_preservation : Prop               -- does data written during v2 survive?
  -- If the migration is bisimilar, rollback is trivially safe
  -- If not, data_preservation is the key question
```

### VersionedSystem (Inductive)

The System type with history — captures that a real system is a chain of versions:

```
inductive VersionedSystem where
  | base : System → VersionedSystem
  | evolve : (prior : VersionedSystem)
           → (migration : Migration prior.current next)
           → (mixed : MixedVersionState prior.current next)
           → VersionedSystem

-- Projection to current snapshot (forgets history)
def VersionedSystem.current : VersionedSystem → System
  | base s => s
  | evolve _ _ => migration.new    -- simplified
```

## Proof Compaction

### The Problem: Incremental Proofs Accumulate

A real system evolves through many PRs. Each PR carries a small migration proof: "this change preserves invariants." Over time you get a chain:

```
proof₁ : Migration X  X₁ preserves P
proof₂ : Migration X₁ X₂ preserves P
proof₃ : Migration X₂ X₃ preserves P
proof₄ : Migration X₃ X₄ preserves P
proof₅ : Migration X₄ Y  preserves P
```

This chain is valuable during development — each PR was validated. But for a reader (human or LLM) who just wants to understand "why does spec Y satisfy these invariants?", the history is noise. The 5 incremental proofs are **construction scaffolding**; the collapsed proof is the **building**.

### Collapsed Proofs

A collapsed proof is a direct, self-contained proof that the current spec satisfies all invariants — no mention of the prior spec, no mention of intermediate steps:

```
-- Self-contained: "Spec Y satisfies these invariants"
-- No reference to X, no reference to the 5 intermediate steps
-- An LLM can read this and understand what Y guarantees without any history

theorem specY_satisfies_policy : satisfies specY policy where
  auth_coverage := by ...
  schema_compat := by ...
  pool_bounds := by ...
```

This is always possible because invariants are properties of the **endpoint**, not the path. `satisfies new p` doesn't mention `old`. If Y satisfies all invariants, you can prove that directly.

```
-- Compaction operation on VersionedSystem
-- Replaces a chain of evolve steps with a single direct proof
def VersionedSystem.compact (vs : VersionedSystem)
  (directProof : satisfies vs.current policy) : VersionedSystem :=
  base vs.current

-- Compaction is sound: the current system is the same
theorem compact_preserves_current (vs : VersionedSystem) (h : satisfies vs.current policy) :
  (vs.compact h).current = vs.current := rfl
```

### What Compaction Loses

The collapsed proof does **not** cover MixedVersionState safety during the rollout. Each incremental proof showed "the mixed state between step N and step N+1 was safe to deploy." The collapsed proof only shows "Y is correct." If someone later asks "was it safe to deploy this way?", you need the incremental proofs.

This is acceptable because deployment safety is a property of the **path**, and old paths stop being relevant. Nobody is going to re-deploy X₂→X₃ six months from now.

### Retention Cap

Incremental migration proofs should be retained for the most recent K migrations and compacted beyond that. The cap is configurable per policy:

```
structure ProofRetentionPolicy where
  -- Number of recent incremental migration proofs to retain
  retainCount : Nat
  -- Whether to auto-compact when the cap is exceeded
  autoCompact : Bool := true

-- The retention window: keep the last K steps, compact everything before
structure RetainedHistory where
  -- Compacted base: direct proof that the anchor spec satisfies all invariants
  anchor : System
  anchorProof : satisfies anchor policy

  -- Recent incremental proofs (at most retainCount)
  recentSteps : List (Migration × MixedVersionSafety)
  recentBound : recentSteps.length ≤ policy.retainCount

  -- Current system is the result of applying recent steps to anchor
  consistent : applyChain anchor recentSteps = current
```

When a new migration pushes the list past the cap, the oldest step gets folded into the anchor:

```
-- Fold the oldest step into the anchor
-- The new anchor is the old anchor + oldest migration
-- The new anchorProof is a direct proof of the new anchor (re-proved fresh)
-- The oldest MixedVersionSafety proof is discarded — that deploy is ancient history
def RetainedHistory.rotate (rh : RetainedHistory)
  (newMigration : Migration rh.current next)
  (newMixed : MixedVersionSafety rh.current next)
  (freshAnchorProof : satisfies (applyMigration rh.anchor rh.recentSteps.head) policy)
  : RetainedHistory := ...
```

### When to Compact

- **Always compact** when the retention cap is exceeded
- **Compact eagerly** after a feature is fully landed (all PRs merged, feature flag removed) — the intermediate states will never be revisited
- **Don't compact** if you're mid-rollout or might need to rollback through the chain — the MixedVersionState proofs are still load-bearing
- **Compact on major version boundaries** — a major version bump is a natural compaction point since backward compatibility is explicitly broken

### Key Theorems

- **Compaction soundness**: if the incremental chain proves `satisfies Y policy`, a direct proof of `satisfies Y policy` exists (the invariants don't depend on the path)
- **Rotation soundness**: folding the oldest step into the anchor and re-proving the anchor directly yields the same current system
- **Retained rollback**: within the retention window, rollback safety proofs are available; beyond it, they are not (explicitly lost, by design)

## Properties via Temporal Logic and Automata

### Migration Safety as Temporal Properties

- **Safety during transition**: `G (mixed_version → safety_invariant)` — "the safety invariant holds throughout the mixed-version window"
- **Eventual completion**: `F (all_nodes_upgraded)` — "the migration eventually finishes" (liveness, needs fairness assumption that the deploy continues)
- **Rollback safety**: `G (rollback_triggered → F (system = old))` — "if rollback is triggered, the system eventually returns to the old version"
- **Data integrity**: `G (¬ data_loss)` — "data is never lost during migration" (safety)

### Büchi Automata for Migration Verification

Long-running migrations (rolling deploys over hours) produce infinite-length traces during the transition. Büchi automata can express:

- "The system is always in a valid state" (safety — actually a DFA)
- "Every Node eventually gets upgraded" (liveness — Büchi acceptance: visiting `all_upgraded` state infinitely often is wrong; reaching it once with `F` is what we want — this is a reachability property, checkable with DFA on finite traces if the deploy terminates)

## Extension Points

### Timed Migrations (future)

When timed models arrive:
```
-- Today: "migration eventually completes" (no time bound)
-- Future: "migration completes within T" (bounded liveness)
-- Timed automata can express and check this
```

### Probabilistic Migrations (future)

When probabilistic models arrive:
```
-- Today: "mixed state is safe" (all-or-nothing)
-- Future: "mixed state fails with probability < p" (quantitative risk)
-- Probabilistic model checking (PRISM-style)
```

## Key Theorems Sketch

### Compatibility

- Adding an optional field with a default is always backward compatible (simulation preserved)
- Removing a field that no Node reads is always safe (bisimulation preserved in the relevant subsystem)
- If migration is backward + forward compatible, MixedVersionState is safe for any traffic split (CCS composition of any mix of v1/v2 Nodes satisfies the properties)

### Composition

- If migration A→B and B→C are both safe, A→C via A→B→C is safe (transitivity of simulation)
- Atomic migrations (blue-green with instant cutover) don't need MixedVersionState compatibility proofs (no mixed state exists)

### Rollback

- Rollback after a compatible migration preserves all data (bisimulation → same observable state)
- Rollback after an incompatible migration may lose data written during v2 (formalize what's lost as the diff between v2's state and v1's state space)

### Evolution

- Expand-then-contract: adding a field, migrating all readers, then removing the old field is safe (if done in that order — temporal ordering constraint)
- Each step individually preserves safety; the composition preserves safety (monotonicity)

### Compaction (see Proof Compaction section above)

- Compaction soundness: a chain of safe migrations can always be collapsed into a direct endpoint proof
- Rotation soundness: folding the oldest step into the anchor preserves the current system
- Retained rollback: rollback proofs exist within the retention window and are explicitly lost beyond it

## Relationship to Other Sketches

- Operates on **Nodes (sketch 01)** and **Systems (sketch 02)** — migration replaces Nodes, the System's CCS term changes
- **Policy (sketch 04)** defines migration constraints checked in CI — MigrationConstraint is a predicate over (old, new, migration)
- Bisimulation (from CSLib) quantifies migration impact; HML formulas (from CSLib) specify what properties must be preserved

## Source Specs / Prior Art

- **CSLib**: Bisimulation for migration impact, CCS congruence for safe substitution, simulation for compatibility
- **Database migration frameworks** (Rails, Alembic, Atlas): expand/contract pattern
- **Protobuf/gRPC compatibility rules** (buf breaking): field-level additive/subtractive analysis
- **Kubernetes rolling update**: maxSurge, maxUnavailable, readiness gates — instances of MixedVersionState constraints
- **Blue-green and canary patterns**: special cases of MixedVersionState (atomic vs. gradual)
- **Sam Newman, "Building Microservices"**: expand-contract pattern
- **CRDTs**: conflict-free data structures — relevant to data migration safety (data that's a CRDT is inherently safe across versions)
