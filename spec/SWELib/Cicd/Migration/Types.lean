import SWELib.Foundations.System

/-!
# Migration & System Evolution — Types

How distributed systems change over time. A migration transitions from one
DistSystem version to another, passing through a **MixedVersionState** where
both versions coexist. The central question: does the mixed state preserve safety?

In LTS/CCS terms a Migration replaces some Nodes with new versions. The
MixedVersionState is a DistSystem where some Nodes are v1 and some are v2,
composed with CCS parallel. Migration safety = the mixed System's LTS
satisfies the same safety properties as both the v1 and v2 Systems.

References:
- Milner, "Communication and Concurrency" (1989)
- Lynch, "Distributed Algorithms" (1996)
- Aceto et al., "Reactive Systems" (2007)
- Sam Newman, "Building Microservices" — expand-contract pattern
-/

namespace SWELib.Cicd.Migration

open SWELib.Foundations

-- ═══════════════════════════════════════════════════════════
-- Version
-- ═══════════════════════════════════════════════════════════

/-- Opaque version identifier for a system snapshot. -/
structure Version where
  id : Nat
  deriving DecidableEq, Repr, BEq, Hashable

-- ═══════════════════════════════════════════════════════════
-- Change Classification
-- ═══════════════════════════════════════════════════════════

/-- Classification of individual changes — determines default safety analysis.
    - `additive`: new optional field, new endpoint, new Node (generally safe)
    - `subtractive`: removed field/endpoint/Node (breaks bisimulation)
    - `modifying`: changed type or semantics (case-by-case)
    - `structural`: split/merge Nodes, change topology (requires re-proving) -/
inductive ChangeKind where
  | additive
  | subtractive
  | modifying
  | structural
  deriving DecidableEq, Repr

-- ═══════════════════════════════════════════════════════════
-- Topology Changes
-- ═══════════════════════════════════════════════════════════

/-- A change to the system's network topology. -/
inductive TopologyChange where
  | addEdge (src dst : NodeId)
  | removeEdge (src dst : NodeId)
  deriving DecidableEq, Repr

-- ═══════════════════════════════════════════════════════════
-- Migration
-- ═══════════════════════════════════════════════════════════

/-- A structured diff between two DistSystem versions.
    Records what Nodes were added, removed, or modified, and what
    topology changes occurred. -/
structure Migration (α : Type) where
  /-- The system before the migration. -/
  old : DistSystem α
  /-- The system after the migration. -/
  new : DistSystem α
  /-- Nodes added (present in new, absent in old). -/
  nodesAdded : List (NodeId × IdentifiedNode α)
  /-- Nodes removed (present in old, absent in new). -/
  nodesRemoved : List NodeId
  /-- Nodes modified: (id, old node, new node). -/
  nodesModified : List (NodeId × IdentifiedNode α × IdentifiedNode α)
  /-- Topology changes (edges added/removed). -/
  topologyChanges : List TopologyChange
  /-- Classification of the overall change. -/
  changeKind : ChangeKind

-- ═══════════════════════════════════════════════════════════
-- Node Status During Migration
-- ═══════════════════════════════════════════════════════════

/-- What is happening to a Node during migration. -/
inductive NodeStatus where
  /-- Still on v1. -/
  | atOld
  /-- Already upgraded to v2. -/
  | atNew
  /-- Exists in v2 but not yet running. -/
  | pendingCreate
  /-- Exists in v1, scheduled for removal, still running. -/
  | pendingDestroy
  deriving DecidableEq, Repr

-- ═══════════════════════════════════════════════════════════
-- MixedVersionState
-- ═══════════════════════════════════════════════════════════

/-- The system during a migration transition. Some Nodes are at v1,
    some at v2, some pending creation or destruction.

    This is a CCS composition of whatever is currently running. -/
structure MixedVersionState (α : Type) where
  /-- The pre-migration system. -/
  old : DistSystem α
  /-- The post-migration system. -/
  new : DistSystem α
  /-- Status of each Node in the migration. -/
  nodeStatus : NodeId → NodeStatus
  /-- The actual mixed system currently running. -/
  mixedSystem : DistSystem α

-- ═══════════════════════════════════════════════════════════
-- Compatibility
-- ═══════════════════════════════════════════════════════════

/-- Compatibility between two versions of a Node, expressed through
    simulation relations on their LTS.

    - `backward`: v2 simulates v1 (v2 can do everything v1 could)
    - `forward`: v1 can handle v2's output actions
    - `wireCompat`: they share enough actions to synchronize on common channels -/
structure Compatibility (α : Type) (S₁ S₂ : Type) where
  /-- The old version of the Node. -/
  v1 : Node α S₁
  /-- The new version of the Node. -/
  v2 : Node α S₂
  /-- Backward: v2 simulates v1's traces (every v1 behavior is preserved in v2).
      Formalized as forward simulation from v1 to v2. -/
  backward : ∃ R, LTS.ForwardSimulation v1.lts v2.lts R ∧ R v1.lts.initial v2.lts.initial
  /-- Forward: v1 can handle v2's output actions.
      v2's output alphabet is a subset of v1's input alphabet. -/
  forward : ∀ a, v2.outputs a → v1.inputs a
  /-- Wire: they can still synchronize — their action alphabets overlap. -/
  wireCompat : ∃ a, v1.outputs a ∧ v2.inputs a

-- ═══════════════════════════════════════════════════════════
-- Deployment Plan
-- ═══════════════════════════════════════════════════════════

/-- Action taken on a Node during a deployment phase. -/
inductive PhaseAction where
  /-- Upgrade from v1 to v2. -/
  | upgrade
  /-- Create a new Node (not running → v2). -/
  | create
  /-- Destroy a Node (v1 → removed). -/
  | destroy
  deriving DecidableEq, Repr

/-- A single deployment phase: a group of Nodes that transition together. -/
structure DeploymentPhase where
  /-- Nodes targeted in this phase. -/
  targets : List NodeId
  /-- Action for each targeted Node. -/
  action : NodeId → PhaseAction
  /-- Targets must be non-empty. -/
  h_nonempty : targets ≠ []

/-- A deployment plan: an ordered list of phases that transitions a system
    from old to new. Captures patterns like "database migrates before app servers."

    Deployment strategies are special cases:
    - **Blue-green**: single phase containing all Nodes (no mixed state)
    - **Rolling update**: one phase per Node (or per batch)
    - **Ordered/staged**: multiple phases with dependency ordering
    - **Expand-contract**: add → migrate readers → drop old -/
structure DeploymentPlan (α : Type) where
  /-- The migration this plan executes. -/
  migration : Migration α
  /-- Ordered list of phases. -/
  phases : List DeploymentPhase
  /-- Phases must be non-empty. -/
  h_phases_nonempty : phases ≠ []

/-- A dependency relation between Nodes: `depends a b` means Node `a`
    depends on Node `b` (so `b` should be migrated first). -/
abbrev DependencyRel := NodeId → NodeId → Prop

/-- Find the phase index of a Node in a deployment plan. -/
def DeploymentPlan.phaseOf {α : Type} (plan : DeploymentPlan α)
    (nid : NodeId) : Option Nat :=
  plan.phases.findIdx? (fun phase => phase.targets.any (· == nid))

-- ═══════════════════════════════════════════════════════════
-- Rollback
-- ═══════════════════════════════════════════════════════════

/-- A rollback plan: the reverse migration plus data preservation guarantees. -/
structure RollbackPlan (α : Type) where
  /-- The reverse migration (new → old). -/
  rollback : Migration α
  /-- Does data written during v2 survive rollback? -/
  dataPreservation : Prop

-- ═══════════════════════════════════════════════════════════
-- Versioned System (evolution chain)
-- ═══════════════════════════════════════════════════════════

/-- A system with history — captures that a real system is a chain of versions.
    Each `evolve` step records the migration and the mixed-version state
    that existed during rollout. -/
inductive VersionedSystem (α : Type) where
  /-- The initial system (no history). -/
  | base : DistSystem α → VersionedSystem α
  /-- An evolution step: a prior system, a migration to a new one,
      and the mixed-version state that existed during transition. -/
  | evolve : (prior : VersionedSystem α)
           → (migration : Migration α)
           → (mixed : MixedVersionState α)
           → VersionedSystem α

/-- Project a VersionedSystem to its current snapshot (forgets history). -/
def VersionedSystem.current {α : Type} : VersionedSystem α → DistSystem α
  | .base s => s
  | .evolve _ m _ => m.new

-- ═══════════════════════════════════════════════════════════
-- Proof Compaction
-- ═══════════════════════════════════════════════════════════

/-- Policy for retaining incremental migration proofs.
    Incremental proofs accumulate over time; compaction collapses
    them into a single direct proof of the current system. -/
structure ProofRetentionPolicy where
  /-- Number of recent incremental migration proofs to retain. -/
  retainCount : Nat
  /-- Whether to auto-compact when the cap is exceeded. -/
  autoCompact : Bool := true
  deriving DecidableEq, Repr

/-- A safety claim about a system: the system satisfies a given property. -/
structure SafetyClaim (α : Type) where
  /-- The system in question. -/
  system : DistSystem α
  /-- The property it satisfies. -/
  property : SafetyProperty α
  /-- Proof that the property holds on all finite traces. -/
  holds : ∀ trace, property trace

/-- An incremental migration step with its safety proof. -/
structure MigrationStep (α : Type) where
  /-- The migration applied. -/
  migration : Migration α
  /-- The mixed-version state during rollout. -/
  mixed : MixedVersionState α

/-- Retained history: a compacted anchor plus recent incremental steps.
    The anchor is a direct proof that a base system satisfies invariants.
    Recent steps are the most recent K migrations with their mixed-state proofs. -/
structure RetainedHistory (α : Type) where
  /-- The compacted anchor system. -/
  anchor : DistSystem α
  /-- Direct proof that the anchor satisfies the safety property. -/
  anchorClaim : SafetyClaim α
  /-- Recent incremental migration steps (at most retainCount). -/
  recentSteps : List (MigrationStep α)
  /-- The retention policy. -/
  policy : ProofRetentionPolicy
  /-- Recent steps respect the retention bound. -/
  h_bound : recentSteps.length ≤ policy.retainCount

-- ═══════════════════════════════════════════════════════════
-- Operations on MixedVersionState
-- ═══════════════════════════════════════════════════════════

/-- Check whether the migration is fully complete (all Nodes at new version). -/
def MixedVersionState.isComplete {α : Type} (mvs : MixedVersionState α) : Prop :=
  ∀ nid, mvs.nodeStatus nid = .atNew ∨ mvs.nodeStatus nid = .pendingCreate

/-- Check whether the migration hasn't started (all Nodes still at old version). -/
def MixedVersionState.isPreMigration {α : Type} (mvs : MixedVersionState α) : Prop :=
  ∀ nid, mvs.nodeStatus nid = .atOld ∨ mvs.nodeStatus nid = .pendingCreate

-- ═══════════════════════════════════════════════════════════
-- Operations on DeploymentPlan
-- ═══════════════════════════════════════════════════════════

/-- All Node IDs targeted across all phases. -/
def DeploymentPlan.allTargets {α : Type} (plan : DeploymentPlan α) : List NodeId :=
  plan.phases.flatMap (·.targets)

/-- Whether a deployment plan respects a dependency ordering:
    if Node `a` depends on Node `b`, then `b`'s phase index ≤ `a`'s phase index. -/
def DeploymentPlan.respectsDeps {α : Type}
    (plan : DeploymentPlan α) (deps : DependencyRel) : Prop :=
  ∀ a b, deps a b →
    match plan.phaseOf a, plan.phaseOf b with
    | some ia, some ib => ib ≤ ia
    | _, _ => True

/-- A deployment plan is blue-green if it has exactly one phase. -/
def DeploymentPlan.isBlueGreen {α : Type} (plan : DeploymentPlan α) : Prop :=
  plan.phases.length = 1

/-- A deployment plan is a rolling update if each phase has exactly one target. -/
def DeploymentPlan.isRolling {α : Type} (plan : DeploymentPlan α) : Prop :=
  ∀ phase, phase ∈ plan.phases → phase.targets.length = 1

-- ═══════════════════════════════════════════════════════════
-- Operations on VersionedSystem
-- ═══════════════════════════════════════════════════════════

/-- Compact a VersionedSystem by discarding history. The result is a base
    system equal to the current snapshot. Requires a direct safety proof
    of the current system (the collapsed proof). -/
def VersionedSystem.compact {α : Type}
    (vs : VersionedSystem α) : VersionedSystem α :=
  .base vs.current

/-- Number of evolution steps in a VersionedSystem's history. -/
def VersionedSystem.depth {α : Type} : VersionedSystem α → Nat
  | .base _ => 0
  | .evolve prior _ _ => prior.depth + 1

-- ═══════════════════════════════════════════════════════════
-- Operations on RetainedHistory
-- ═══════════════════════════════════════════════════════════

/-- The current system of a retained history: apply all recent steps to the anchor. -/
def RetainedHistory.currentSystem {α : Type} (rh : RetainedHistory α) : DistSystem α :=
  match rh.recentSteps.getLast? with
  | some step => step.migration.new
  | none => rh.anchor

end SWELib.Cicd.Migration
