import SWELib.OS.Isolation.Nodes

/-!
# Simulation Relations (Concrete → Distilled)

Each concrete Node type has a forward simulation to `DistilledNode`, connecting
concrete lifecycle states and actions to the minimal {stopped, running} × {start, stop, service}
model. The simulation is lossy by design — it collapses mechanism-specific states into
the common core.

References:
- Milner, "Communication and Concurrency" (1989) — simulation
- Lynch, "Distributed Algorithms" (1996) — simulation relations
- GCE instance lifecycle: https://cloud.google.com/compute/docs/instances/instance-life-cycle
-/

namespace SWELib.OS.Isolation

open SWELib.Cloud.Oci (ContainerStatus)

/-! ## Container → Distilled -/

/-- State mapping: collapse OCI states to {stopped, running}.
    Paused maps to stopped because a paused container can't do service work. -/
def containerStateMap : ContainerStatus → DistilledStatus
  | .creating => .stopped
  | .created => .stopped
  | .running => .running
  | .stopped => .stopped
  | .paused => .stopped

/-- Action mapping: lifecycle → start/stop/none(τ), service → service. -/
def containerActionMap : ContainerAction α → Option (DistilledAction α)
  | .lifecycle .start => some .start
  | .lifecycle (.kill _) => some .stop
  | .lifecycle .create => none
  | .lifecycle .pause => some .stop
  | .lifecycle .resume => some .start
  | .lifecycle .delete => none
  | .service a => some (.service a)

/-- Every OCI container LTS simulates the distilled LTS. -/
theorem container_simulates_distilled :
    MappedForwardSimulation (ociContainerLTS (α := α)) (distilledLTS (α := α))
      containerStateMap containerActionMap := by
  constructor
  · -- initial_maps
    rfl
  · -- sim_visible
    intro s₁ a s₁' a' hTr hMap
    simp [ociContainerLTS, distilledLTS] at *
    cases a with
    | lifecycle l =>
      cases l with
      | start =>
        simp [containerActionMap] at hMap
        subst hMap
        simp [containerStateMap]
        obtain ⟨rfl, rfl⟩ := hTr
        rfl
      | kill sig =>
        simp [containerActionMap] at hMap
        subst hMap
        simp [containerStateMap]
        obtain ⟨h, rfl⟩ := hTr
        cases h with
        | inl h => subst h; rfl
        | inr h => subst h; rfl
      | create => simp [containerActionMap] at hMap
      | pause =>
        simp [containerActionMap] at hMap
        subst hMap
        simp [containerStateMap]
        obtain ⟨rfl, rfl⟩ := hTr
        rfl
      | resume =>
        simp [containerActionMap] at hMap
        subst hMap
        simp [containerStateMap]
        obtain ⟨rfl, rfl⟩ := hTr
        rfl
      | delete => simp [containerActionMap] at hMap
    | service a =>
      simp [containerActionMap] at hMap
      subst hMap
      simp [containerStateMap]
      obtain ⟨rfl, rfl⟩ := hTr
      exact ⟨rfl, rfl⟩
  · -- sim_silent
    intro s₁ a s₁' hTr hMap
    simp [ociContainerLTS] at hTr
    cases a with
    | lifecycle l =>
      cases l with
      | create =>
        simp [containerStateMap]
        obtain ⟨rfl, rfl⟩ := hTr
        rfl
      | delete =>
        simp [containerStateMap]
        obtain ⟨rfl, rfl⟩ := hTr
        rfl
      | start => simp [containerActionMap] at hMap
      | kill => simp [containerActionMap] at hMap
      | pause => simp [containerActionMap] at hMap
      | resume => simp [containerActionMap] at hMap
    | service => simp [containerActionMap] at hMap

/-! ## VM (GCE) → Distilled -/

/-- State mapping: collapse GCE states to {stopped, running}.
    Only `running` maps to running; all provisioning/stopping/suspended/repairing
    states map to stopped. -/
def vmStateMap : VMStatus → DistilledStatus
  | .running => .running
  | _ => .stopped

/-- Action mapping for GCE VM lifecycle.
    User-initiated stop/suspend map to distilled stop.
    Platform bootComplete maps to distilled start.
    All intermediate platform transitions are τ (internal). -/
def vmActionMap : VMAction α → Option (DistilledAction α)
  | .lifecycle .create => none               -- τ: pending → pending
  | .lifecycle .start => none                -- τ: terminated → provisioning (not yet running)
  | .lifecycle .stop => some .stop           -- running → pendingStop
  | .lifecycle .suspend => some .stop        -- running → suspending
  | .lifecycle .resume => none               -- τ: suspended → provisioning
  | .lifecycle .delete => none               -- τ: terminated/stopping → terminated
  | .lifecycle .reset => none                -- τ: running → running
  | .lifecycle .resourcesAcquired => none    -- τ: pending → provisioning
  | .lifecycle .resourcesAllocated => none   -- τ: provisioning → staging
  | .lifecycle .bootComplete => some .start  -- staging → running (visible!)
  | .lifecycle .gracefulPeriodEnded => none  -- τ: pendingStop → stopping
  | .lifecycle .stopComplete => none         -- τ: stopping → terminated
  | .lifecycle .suspendComplete => none      -- τ: suspending → suspended
  | .lifecycle .repairStarted => some .stop  -- running → repairing
  | .lifecycle .repairComplete => some .start -- repairing → running
  | .service a => some (.service a)

/-- Every GCE VM LTS simulates the distilled LTS. -/
theorem vm_simulates_distilled :
    MappedForwardSimulation (gceVMNodeLTS (α := α)) (distilledLTS (α := α))
      vmStateMap vmActionMap := by
  constructor
  · -- initial_maps
    rfl
  · -- sim_visible
    intro s₁ a s₁' a' hTr hMap
    simp [gceVMNodeLTS, distilledLTS] at *
    cases a with
    | lifecycle l =>
      cases l with
      | stop =>
        simp [vmActionMap] at hMap; subst hMap
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | suspend =>
        simp [vmActionMap] at hMap; subst hMap
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | bootComplete =>
        simp [vmActionMap] at hMap; subst hMap
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | repairStarted =>
        simp [vmActionMap] at hMap; subst hMap
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | repairComplete =>
        simp [vmActionMap] at hMap; subst hMap
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | create => simp [vmActionMap] at hMap
      | start => simp [vmActionMap] at hMap
      | resume => simp [vmActionMap] at hMap
      | delete => simp [vmActionMap] at hMap
      | reset => simp [vmActionMap] at hMap
      | resourcesAcquired => simp [vmActionMap] at hMap
      | resourcesAllocated => simp [vmActionMap] at hMap
      | gracefulPeriodEnded => simp [vmActionMap] at hMap
      | stopComplete => simp [vmActionMap] at hMap
      | suspendComplete => simp [vmActionMap] at hMap
    | service a =>
      simp [vmActionMap] at hMap; subst hMap
      simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; exact ⟨rfl, rfl⟩
  · -- sim_silent
    intro s₁ a s₁' hTr hMap
    simp [gceVMNodeLTS] at hTr
    cases a with
    | lifecycle l =>
      cases l with
      | create =>
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | start =>
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | resume =>
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | delete =>
        simp [vmStateMap]; obtain ⟨h, rfl⟩ := hTr
        rcases h with rfl | rfl <;> rfl
      | reset =>
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | resourcesAcquired =>
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | resourcesAllocated =>
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | gracefulPeriodEnded =>
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | stopComplete =>
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | suspendComplete =>
        simp [vmStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | stop => simp [vmActionMap] at hMap
      | suspend => simp [vmActionMap] at hMap
      | bootComplete => simp [vmActionMap] at hMap
      | repairStarted => simp [vmActionMap] at hMap
      | repairComplete => simp [vmActionMap] at hMap
    | service => simp [vmActionMap] at hMap

/-! ## Bare Metal → Distilled -/

/-- State mapping: only `deployed` = running; everything else is stopped.
    The entire MAAS commissioning lifecycle collapses to `stopped`. -/
def bareMetalStateMap : BareMetalStatus → DistilledStatus
  | .deployed => .running
  | _ => .stopped

/-- Action mapping for bare metal provisioning and power actions. -/
def bareMetalActionMap : BareMetalAction α → Option (DistilledAction α)
  | .power .powerOn => some .start
  | .power .powerOff => some .stop
  | .power .reinstall => some .stop
  | .provision .deploy => none
  | .provision .commission => none
  | .provision .allocate => none
  | .provision .release => some .stop
  | .provision .abort => none
  | .provision .markBroken => some .stop
  | .provision .retire => some .stop
  | .service a => some (.service a)

/-- Every MAAS bare metal LTS simulates the distilled LTS. -/
theorem bare_metal_simulates_distilled :
    MappedForwardSimulation (maasBareMetalLTS (α := α)) (distilledLTS (α := α))
      bareMetalStateMap bareMetalActionMap := by
  constructor
  · rfl
  · intro s₁ a s₁' a' hTr hMap
    simp [maasBareMetalLTS, distilledLTS] at *
    cases a with
    | power p =>
      cases p with
      | powerOn =>
        simp [bareMetalActionMap] at hMap; subst hMap
        simp [bareMetalStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | powerOff =>
        simp [bareMetalActionMap] at hMap; subst hMap
        simp [bareMetalStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | reinstall =>
        simp [bareMetalActionMap] at hMap; subst hMap
        simp [bareMetalStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
    | provision p =>
      cases p with
      | release =>
        simp [bareMetalActionMap] at hMap; subst hMap
        simp [bareMetalStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | markBroken =>
        simp [bareMetalActionMap] at hMap; subst hMap
        simp [bareMetalStateMap]; obtain ⟨_, rfl⟩ := hTr; rfl
      | retire =>
        simp [bareMetalActionMap] at hMap; subst hMap
        simp [bareMetalStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | deploy => simp [bareMetalActionMap] at hMap
      | commission => simp [bareMetalActionMap] at hMap
      | allocate => simp [bareMetalActionMap] at hMap
      | abort => simp [bareMetalActionMap] at hMap
    | service a =>
      simp [bareMetalActionMap] at hMap; subst hMap
      simp [bareMetalStateMap]; obtain ⟨rfl, rfl⟩ := hTr; exact ⟨rfl, rfl⟩
  · intro s₁ a s₁' hTr hMap
    simp [maasBareMetalLTS] at hTr
    cases a with
    | provision p =>
      cases p with
      | commission =>
        simp [bareMetalStateMap]
        obtain ⟨h, rfl⟩ := hTr
        rcases h with rfl | rfl | rfl <;> rfl
      | allocate =>
        simp [bareMetalStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | deploy =>
        simp [bareMetalStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | abort =>
        simp [bareMetalStateMap]
        obtain ⟨h, rfl⟩ := hTr
        rcases h with rfl | rfl <;> rfl
      | release => simp [bareMetalActionMap] at hMap
      | markBroken => simp [bareMetalActionMap] at hMap
      | retire => simp [bareMetalActionMap] at hMap
    | power p =>
      cases p with
      | powerOn => simp [bareMetalActionMap] at hMap
      | powerOff => simp [bareMetalActionMap] at hMap
      | reinstall => simp [bareMetalActionMap] at hMap
    | service => simp [bareMetalActionMap] at hMap

/-! ## Transient → Distilled -/

/-- State mapping: `active` and `idle` = running (idle can still serve).
    `starting` and `shuttingDown` = stopped. -/
def transientStateMap : TransientStatus → DistilledStatus
  | .active => .running
  | .idle => .running
  | .starting => .stopped
  | .shuttingDown => .stopped

/-- Action mapping for transient platform actions. -/
def transientActionMap : TransientAction α → Option (DistilledAction α)
  | .platform .requestArrives => some .start
  | .platform .allRequestsComplete => none
  | .platform .idleTimeout => some .stop
  | .platform .terminate => some .stop
  | .service a => some (.service a)

/-- Every transient LTS simulates the distilled LTS. -/
theorem transient_simulates_distilled :
    MappedForwardSimulation (transientLTS (α := α)) (distilledLTS (α := α))
      transientStateMap transientActionMap := by
  constructor
  · rfl
  · intro s₁ a s₁' a' hTr hMap
    simp [transientLTS, distilledLTS] at *
    cases a with
    | platform p =>
      cases p with
      | requestArrives =>
        simp [transientActionMap] at hMap; subst hMap
        simp [transientStateMap]; obtain ⟨h, rfl⟩ := hTr
        cases h with
        | inl h => subst h; rfl
        | inr h => subst h; rfl
      | allRequestsComplete => simp [transientActionMap] at hMap
      | idleTimeout =>
        simp [transientActionMap] at hMap; subst hMap
        simp [transientStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | terminate =>
        simp [transientActionMap] at hMap; subst hMap
        simp [transientStateMap]; obtain ⟨h, rfl⟩ := hTr
        rcases h with rfl | rfl | rfl
        · rfl
        · rfl
        · rfl
    | service a =>
      simp [transientActionMap] at hMap; subst hMap
      simp [transientStateMap]; obtain ⟨rfl, rfl⟩ := hTr; exact ⟨rfl, rfl⟩
  · intro s₁ a s₁' hTr hMap
    simp [transientLTS] at hTr
    cases a with
    | platform p =>
      cases p with
      | allRequestsComplete =>
        simp [transientStateMap]; obtain ⟨rfl, rfl⟩ := hTr; rfl
      | requestArrives => simp [transientActionMap] at hMap
      | idleTimeout => simp [transientActionMap] at hMap
      | terminate => simp [transientActionMap] at hMap
    | service => simp [transientActionMap] at hMap

end SWELib.OS.Isolation
