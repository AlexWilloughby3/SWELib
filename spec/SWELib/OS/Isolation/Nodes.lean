import SWELib.OS.Isolation.Types

/-!
# Concrete Node Instantiations

Each isolation mechanism (container, VM, bare metal, transient) is a concrete
instantiation of `LTS S α` with its own state type, action type, and transition
relation. `DistilledNode` is the simplest LTS that captures their common behavior.

References:
- OCI Runtime Spec v1.0 (container lifecycle)
- GCE instance lifecycle (VM states)
- MAAS machine lifecycle (bare metal provisioning)
- Cloud Run / ECS (transient instances)
-/

namespace SWELib.OS.Isolation

open SWELib.Foundations (LTS)
open SWELib.Cloud.Oci (ContainerStatus)

/-! ## Node Type Aliases -/

/-- A container Node: OCI lifecycle states with parameterized service actions. -/
def ContainerNode (α : Type) := LTS ContainerStatus (ContainerAction α)

/-- A VM Node: hypervisor lifecycle states with parameterized service actions. -/
def VMNode (α : Type) := LTS VMStatus (VMAction α)

/-- A bare metal Node: hardware provisioning + operational lifecycle. -/
def BareMetalNode (α : Type) := LTS BareMetalStatus (BareMetalAction α)

/-- A transient Node: platform-managed lifecycle (Cloud Run / ECS style). -/
def TransientNode (α : Type) := LTS TransientStatus (TransientAction α)

/-- The distilled Node: minimal 2-state lifecycle capturing the common core. -/
def DistilledNode (α : Type) := LTS DistilledStatus (DistilledAction α)

/-! ## Distilled LTS -/

/-- The distilled LTS: two states, three action kinds.
    The smallest thing you can call "a compute node that does work." -/
def distilledLTS : DistilledNode α where
  Tr src action dst :=
    match action with
    | .start => src = .stopped ∧ dst = .running
    | .stop => src = .running ∧ dst = .stopped
    | .service _ => src = .running ∧ dst = .running
  initial := .stopped

/-! ## OCI Container LTS -/

/-- Concrete LTS for OCI containers.
    Service actions are only possible in the `running` state. -/
def ociContainerLTS : ContainerNode α where
  Tr src action dst :=
    match action with
    | .lifecycle .create => src = .creating ∧ dst = .created
    | .lifecycle .start => src = .created ∧ dst = .running
    | .lifecycle (.kill _) => (src = .running ∨ src = .created) ∧ dst = .stopped
    | .lifecycle .pause => src = .running ∧ dst = .paused
    | .lifecycle .resume => src = .paused ∧ dst = .running
    | .lifecycle .delete => src = .stopped ∧ dst = .stopped
    | .service _ => src = .running ∧ dst = .running
  initial := .creating

/-! ## GCE VM LTS -/

/-- Concrete LTS for Google Compute Engine virtual machines.
    Models both user-initiated actions and platform-driven transitions.
    References: https://cloud.google.com/compute/docs/instances/instance-life-cycle -/
def gceVMNodeLTS : VMNode α where
  Tr src action dst :=
    match action with
    -- User-initiated actions
    | .lifecycle .create => src = .pending ∧ dst = .pending
        -- create enqueues; actual provisioning starts on resourcesAcquired
    | .lifecycle .start => src = .terminated ∧ dst = .provisioning
    | .lifecycle .stop => src = .running ∧ dst = .pendingStop
    | .lifecycle .suspend => src = .running ∧ dst = .suspending
    | .lifecycle .resume => src = .suspended ∧ dst = .provisioning
    | .lifecycle .delete =>
        (src = .terminated ∨ src = .stopping) ∧ dst = .terminated
    | .lifecycle .reset => src = .running ∧ dst = .running
    -- Platform-driven transitions
    | .lifecycle .resourcesAcquired => src = .pending ∧ dst = .provisioning
    | .lifecycle .resourcesAllocated => src = .provisioning ∧ dst = .staging
    | .lifecycle .bootComplete => src = .staging ∧ dst = .running
    | .lifecycle .gracefulPeriodEnded => src = .pendingStop ∧ dst = .stopping
    | .lifecycle .stopComplete => src = .stopping ∧ dst = .terminated
    | .lifecycle .suspendComplete => src = .suspending ∧ dst = .suspended
    | .lifecycle .repairStarted => src = .running ∧ dst = .repairing
    | .lifecycle .repairComplete =>
        src = .repairing ∧ dst = .running  -- simplified: returns to running
    -- Service actions only when running
    | .service _ => src = .running ∧ dst = .running
  initial := .pending

/-! ## MAAS Bare Metal LTS -/

/-- Concrete LTS for MAAS-managed bare metal machines.
    Service actions only possible when deployed. -/
def maasBareMetalLTS : BareMetalNode α where
  Tr src action dst :=
    match action with
    | .provision .commission =>
        (src = .new ∨ src = .failedCommissioning ∨ src = .broken) ∧ dst = .commissioning
    | .provision .allocate => src = .ready ∧ dst = .allocated
    | .provision .deploy => src = .allocated ∧ dst = .deploying
    | .provision .release => src = .deployed ∧ dst = .releasing
    | .provision .abort =>
        (src = .commissioning ∨ src = .deploying) ∧ dst = .ready
    | .provision .markBroken => dst = .broken
    | .provision .retire => src = .ready ∧ dst = .retired
    | .power .powerOn => src = .deploying ∧ dst = .deployed
    | .power .powerOff => src = .deployed ∧ dst = .ready
    | .power .reinstall => src = .deployed ∧ dst = .deploying
    | .service _ => src = .deployed ∧ dst = .deployed
  initial := .new

/-! ## Transient LTS -/

/-- Concrete LTS for transient platform-managed instances (Cloud Run / ECS).
    No user-initiated lifecycle management; the platform drives all transitions. -/
def transientLTS : TransientNode α where
  Tr src action dst :=
    match action with
    | .platform .requestArrives =>
        (src = .starting ∨ src = .idle) ∧ dst = .active
    | .platform .allRequestsComplete => src = .active ∧ dst = .idle
    | .platform .idleTimeout => src = .idle ∧ dst = .shuttingDown
    | .platform .terminate =>
        (src = .active ∨ src = .idle ∨ src = .shuttingDown) ∧ dst = .shuttingDown
    | .service _ => src = .active ∧ dst = .active
  initial := .starting

end SWELib.OS.Isolation
