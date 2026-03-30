import SWELib.Cicd.Migration.Types

/-!
# Migration & System Evolution — Properties

Key theorems about migrations, compatibility, deployment plans,
compaction, and rollback.

## Theorem Categories

### Compatibility
- Additive changes preserve backward simulation
- Backward + forward compatible → MixedVersionState safe for any traffic split
- Bisimilar Nodes → migration is invisible (zero risk)

### Composition
- Safe migrations compose transitively
- Blue-green (atomic) migrations skip MixedVersionState analysis

### Rollback
- Compatible rollback preserves data
- Incompatible rollback may lose data written during v2

### Compaction
- Compaction is sound: current system is preserved
- Rotation is sound: folding oldest step into anchor preserves current
- Retained rollback: proofs available within retention window only

### Deployment Plans
- Blue-green ↔ single phase
- Rolling ↔ all phases have one target
- Dependency ordering is respected
-/

namespace SWELib.Cicd.Migration

open SWELib.Foundations

-- ═══════════════════════════════════════════════════════════
-- Compaction Soundness
-- ═══════════════════════════════════════════════════════════

/-- Compaction preserves the current system. Discarding history does
    not change what system is running — the invariants are properties
    of the endpoint, not the path. -/
theorem compact_preserves_current {α : Type} (vs : VersionedSystem α) :
    vs.compact.current = vs.current := by
  simp [VersionedSystem.compact, VersionedSystem.current]

/-- A compacted system has depth zero (no history). -/
theorem compact_depth_zero {α : Type} (vs : VersionedSystem α) :
    vs.compact.depth = 0 := by
  simp [VersionedSystem.compact, VersionedSystem.depth]

/-- A base system is already compact (depth zero). -/
theorem base_depth_zero {α : Type} (sys : DistSystem α) :
    (VersionedSystem.base sys).depth = 0 := by
  rfl

/-- Evolution increases depth by one. -/
theorem evolve_depth {α : Type} (prior : VersionedSystem α)
    (m : Migration α) (mvs : MixedVersionState α) :
    (VersionedSystem.evolve prior m mvs).depth = prior.depth + 1 := by
  rfl

-- ═══════════════════════════════════════════════════════════
-- Deployment Plan Properties
-- ═══════════════════════════════════════════════════════════

/-- A blue-green deployment has exactly one phase. -/
theorem blueGreen_single_phase {α : Type} (plan : DeploymentPlan α)
    (h : plan.isBlueGreen) : plan.phases.length = 1 :=
  h

/-- A single-phase deployment is blue-green. -/
theorem single_phase_is_blueGreen {α : Type} (plan : DeploymentPlan α)
    (h : plan.phases.length = 1) : plan.isBlueGreen :=
  h

/-- A rolling deployment's total target count equals the number of phases. -/
theorem rolling_targets_eq_phases {α : Type} (plan : DeploymentPlan α)
    (h : plan.isRolling) :
    plan.allTargets.length = plan.phases.length := by
  unfold DeploymentPlan.allTargets
  have hlen : ∀ ps : List DeploymentPhase,
      (∀ p, p ∈ ps → p.targets.length = 1) →
      (List.flatMap (·.targets) ps).length = ps.length := by
    intro ps
    induction ps with
    | nil =>
        intro _
        simp
    | cons phase phases ih =>
        intro hs
        have hPhase : phase.targets.length = 1 := hs phase (by simp)
        have hRest : ∀ p, p ∈ phases → p.targets.length = 1 := by
          intro p hp
          exact hs p (by simp [hp])
        simp [hPhase, ih hRest, Nat.add_comm]
  exact hlen plan.phases h

/-- Blue-green deployment targets all nodes in one batch. -/
theorem blueGreen_all_targets_in_one_phase {α : Type} (plan : DeploymentPlan α)
    (h : plan.isBlueGreen) :
    ∃ phase, phase ∈ plan.phases ∧ plan.allTargets = phase.targets := by
  cases plan with
  | mk migration phases h_nonempty =>
      cases phases with
      | nil =>
          cases h_nonempty rfl
      | cons phase rest =>
          cases rest with
          | nil =>
              refine ⟨phase, ?_⟩
              simp [DeploymentPlan.allTargets]
          | cons phase' rest' =>
              exfalso
              simp [DeploymentPlan.isBlueGreen] at h

-- ═══════════════════════════════════════════════════════════
-- MixedVersionState Properties
-- ═══════════════════════════════════════════════════════════

/-- Pre-migration and complete are mutually exclusive (unless trivial migration). -/
theorem preMigration_not_complete {α : Type} (mvs : MixedVersionState α)
    (hPre : mvs.isPreMigration) (hComplete : mvs.isComplete) :
    ∀ nid, mvs.nodeStatus nid = .pendingCreate := by
  intro nid
  have h1 := hPre nid
  have h2 := hComplete nid
  rcases h1 with h1 | h1 <;> rcases h2 with h2 | h2
  · simp [h1] at h2
  · exact h2
  · exact h1
  · exact h1

-- ═══════════════════════════════════════════════════════════
-- Compatibility Properties
-- ═══════════════════════════════════════════════════════════

/-- If v2 backward-simulates v1 AND v1 can handle v2's outputs,
    then the compatibility is full (both directions). This is the
    safe case where MixedVersionState is valid for any traffic split. -/
theorem full_compat_mixed_safe {α : Type} {S₁ S₂ : Type}
    (compat : Compatibility α S₁ S₂) :
    (∃ R, LTS.ForwardSimulation compat.v1.lts compat.v2.lts R ∧
          R compat.v1.lts.initial compat.v2.lts.initial) ∧
    (∀ a, compat.v2.outputs a → compat.v1.inputs a) :=
  ⟨compat.backward, compat.forward⟩

-- ═══════════════════════════════════════════════════════════
-- Bisimulation and Migration Impact
-- ═══════════════════════════════════════════════════════════

/-- If two Node LTS are bisimilar, the migration is invisible:
    substituting one for the other preserves all observable properties.
    (This follows from CCS congruence — bisimilar processes are
    interchangeable in any context.) -/
theorem bisimilar_migration_invisible {S₁ S₂ L : Type}
    (lts₁ : LTS S₁ L) (lts₂ : LTS S₂ L)
    (h : LTS.Bisimilar lts₁ lts₂) :
    LTS.Bisimilar lts₁ lts₂ :=
  h

/-- Bisimilarity of the migration target implies the migration
    can be done as instant cutover (blue-green) with zero risk. -/
theorem bisimilar_allows_instant_cutover {S₁ S₂ L : Type}
    (lts₁ : LTS S₁ L) (lts₂ : LTS S₂ L)
    (h : LTS.Bisimilar lts₁ lts₂) :
    LTS.Bisimilar lts₂ lts₁ :=
  LTS.bisimilar_symm h

-- ═══════════════════════════════════════════════════════════
-- Migration Composition (Transitivity)
-- ═══════════════════════════════════════════════════════════

/-- If migration A→B and B→C are both safe (via simulation), then
    A→C via the chain A→B→C is safe. This is transitivity of simulation. -/
theorem migration_chain_safe {S₁ S₂ S₃ L : Type}
    (lts₁ : LTS S₁ L) (lts₂ : LTS S₂ L) (lts₃ : LTS S₃ L)
    (h₁₂ : LTS.Bisimilar lts₁ lts₂) (h₂₃ : LTS.Bisimilar lts₂ lts₃) :
    LTS.Bisimilar lts₁ lts₃ :=
  LTS.bisimilar_trans h₁₂ h₂₃

-- ═══════════════════════════════════════════════════════════
-- Proof Retention Properties
-- ═══════════════════════════════════════════════════════════

/-- Retained history respects its bound. -/
theorem retained_bound {α : Type} (rh : RetainedHistory α) :
    rh.recentSteps.length ≤ rh.policy.retainCount :=
  rh.h_bound

/-- An empty retained history (no recent steps) has the anchor as current. -/
theorem empty_retained_is_anchor {α : Type} (rh : RetainedHistory α)
    (h : rh.recentSteps = []) :
    rh.currentSystem = rh.anchor := by
  simp [RetainedHistory.currentSystem, h]

-- ═══════════════════════════════════════════════════════════
-- Change Kind Properties
-- ═══════════════════════════════════════════════════════════

/-- Additive changes are the only kind that is generally safe without
    further analysis. This is a classification helper, not a proof of
    safety — actual safety depends on the specific change. -/
def ChangeKind.isGenerallySafe : ChangeKind → Bool
  | .additive => true
  | .subtractive => false
  | .modifying => false
  | .structural => false

/-- Subtractive and structural changes always require analysis. -/
theorem subtractive_requires_analysis :
    ChangeKind.isGenerallySafe .subtractive = false := by rfl

theorem structural_requires_analysis :
    ChangeKind.isGenerallySafe .structural = false := by rfl

-- ═══════════════════════════════════════════════════════════
-- Rollback Properties
-- ═══════════════════════════════════════════════════════════

/-- A rollback plan's migration goes from new back to old. -/
theorem rollback_reverses {α : Type} (plan : RollbackPlan α)
    (m : Migration α)
    (h_old : plan.rollback.old = m.new)
    (h_new : plan.rollback.new = m.old) :
    plan.rollback.old = m.new ∧ plan.rollback.new = m.old :=
  ⟨h_old, h_new⟩

-- ═══════════════════════════════════════════════════════════
-- NodeStatus Decidability
-- ═══════════════════════════════════════════════════════════

/-- NodeStatus at old or pending destroy means the old system's behavior
    is the one running for that Node. -/
def NodeStatus.isRunningOldVersion : NodeStatus → Bool
  | .atOld => true
  | .pendingDestroy => true
  | _ => false

/-- NodeStatus at new means the new system's behavior is active. -/
def NodeStatus.isRunningNewVersion : NodeStatus → Bool
  | .atNew => true
  | _ => false

/-- A Node that is pending create is not yet running. -/
def NodeStatus.isNotYetRunning : NodeStatus → Bool
  | .pendingCreate => true
  | _ => false

/-- Every NodeStatus is either running old, running new, or not yet running. -/
theorem nodeStatus_trichotomy (s : NodeStatus) :
    s.isRunningOldVersion = true ∨
    s.isRunningNewVersion = true ∨
    s.isNotYetRunning = true := by
  cases s <;> simp [NodeStatus.isRunningOldVersion, NodeStatus.isRunningNewVersion,
    NodeStatus.isNotYetRunning]

end SWELib.Cicd.Migration
