import SWELib.Foundations.LTS
import SWELib.Cloud.Oci.Types
import SWELib.OS.Namespaces.Types
import SWELib.OS.Cgroups.Types
import SWELib.OS.Seccomp.Types
import SWELib.OS.Capabilities
import SWELib.OS.Process

/-!
# Isolation Boundary Types

Type definitions for concrete Node instantiations (container, VM, bare metal, transient),
the distilled minimal Node, and isolation boundary structures.

This module bridges OS-level isolation primitives (namespaces, cgroups, seccomp, capabilities)
with the LTS-based Node/System framework from Foundations.

References:
- OCI Runtime Spec v1.0: https://github.com/opencontainers/runtime-spec
- libvirt domain states: https://libvirt.org/html/libvirt-libvirt-domain.html
- MAAS lifecycle: https://maas.io/docs/about-machines
- Milner, "Communication and Concurrency" (1989) — LTS, CCS
-/

namespace SWELib.OS.Isolation

open SWELib.Foundations (LTS)
open SWELib.Cloud.Oci (ContainerStatus Root ContainerConfig)
open SWELib.OS (Namespace Cgroup CgroupLimit CapabilitySet ProcessTable Signal)
open SWELib.OS.Seccomp (SockFprog)

/-! ## Container Action Types -/

/-- Container lifecycle actions (OCI runtime operations). -/
inductive ContainerLifecycleAction where
  | create
  | start
  | kill (signal : Signal)
  | pause
  | resume
  | delete
  deriving DecidableEq, Repr

/-- Container actions: lifecycle management or actual service work.
    The type parameter `α` is the service action alphabet. -/
inductive ContainerAction (α : Type) where
  | lifecycle : ContainerLifecycleAction → ContainerAction α
  | service : α → ContainerAction α
  deriving Repr

/-! ## VM Types -/

/-- GCE VM lifecycle states.
    References: https://cloud.google.com/compute/docs/instances/instance-life-cycle -/
inductive VMStatus where
  /-- Flex-start VMs only: waiting for resource acquisition. -/
  | pending
  /-- Allocating resources after create/restart/resume. -/
  | provisioning
  /-- Preparing for first boot. -/
  | staging
  /-- Instance is booting or operational. -/
  | running
  /-- Graceful shutdown in progress (if enabled). -/
  | pendingStop
  /-- Guest OS shutting down. -/
  | stopping
  /-- Stop operation completed; instance remains stopped. -/
  | terminated
  /-- Compute Engine is fixing internal errors or host unavailability. -/
  | repairing
  /-- Suspend operation initiated. -/
  | suspending
  /-- Suspend operation completed; max 60-day retention. -/
  | suspended
  deriving DecidableEq, Repr, Inhabited

/-- GCE VM lifecycle actions (user-initiated and platform-driven). -/
inductive VMLifecycleAction where
  /-- Create a new instance. -/
  | create
  /-- Start (restart) a terminated instance. -/
  | start
  /-- Stop a running instance. -/
  | stop
  /-- Suspend a running instance (memory preserved, 60-day max). -/
  | suspend
  /-- Resume a suspended instance. -/
  | resume
  /-- Delete an instance. -/
  | delete
  /-- Hard reboot a running instance. -/
  | reset
  /-- Platform: resources acquired (PENDING → PROVISIONING). -/
  | resourcesAcquired
  /-- Platform: resources allocated (PROVISIONING → STAGING). -/
  | resourcesAllocated
  /-- Platform: boot complete (STAGING → RUNNING). -/
  | bootComplete
  /-- Platform: graceful period ended (PENDING_STOP → STOPPING). -/
  | gracefulPeriodEnded
  /-- Platform: stop complete (STOPPING → TERMINATED). -/
  | stopComplete
  /-- Platform: suspend complete (SUSPENDING → SUSPENDED). -/
  | suspendComplete
  /-- Platform: repair initiated (RUNNING → REPAIRING). -/
  | repairStarted
  /-- Platform: repair complete (REPAIRING → original state). -/
  | repairComplete
  deriving DecidableEq, Repr

/-- VM actions: lifecycle management or service work. -/
inductive VMAction (α : Type) where
  | lifecycle : VMLifecycleAction → VMAction α
  | service : α → VMAction α
  deriving Repr

/-! ## VM SSH Types -/

/-- Configuration for `gcloud compute ssh` connections.
    References: https://cloud.google.com/sdk/gcloud/reference/compute/ssh -/
structure SshConfig where
  /-- Remote command to execute (non-interactive). If `none`, would open a shell. -/
  command : Option String := none
  /-- Use internal IP address instead of external. -/
  internalIp : Bool := false
  /-- Tunnel through Identity-Aware Proxy. -/
  tunnelThroughIap : Bool := false
  /-- SSH key file path override. -/
  sshKeyFile : Option String := none
  /-- Disable strict host key checking. -/
  strictHostKeyChecking : Bool := true
  deriving Repr

/-- Result of a non-interactive SSH command execution. -/
structure SshResult where
  /-- Standard output from the remote command. -/
  stdout : String
  /-- Standard error from the remote command. -/
  stderr : String
  /-- Exit code of the remote command. -/
  exitCode : UInt32
  deriving Repr

/-- SSH is a service-level operation: requires VM to be running, does not change state. -/
def sshPrecondition (status : VMStatus) : Prop := status = .running

/-! ## VM SCP Types -/

/-- An SCP endpoint: either a local path or a remote `[[USER@]INSTANCE:]PATH`.
    References: https://cloud.google.com/sdk/gcloud/reference/compute/scp -/
structure ScpEndpoint where
  /-- Optional username for the remote side. -/
  user : Option String := none
  /-- Instance name. If `none`, the endpoint is a local path. -/
  instance_ : Option String := none
  /-- Filesystem path (local or remote). -/
  path : String
  deriving Repr, DecidableEq

/-- Whether an SCP endpoint refers to a remote instance. -/
def ScpEndpoint.isRemote (e : ScpEndpoint) : Bool := e.instance_.isSome

/-- Whether an SCP endpoint refers to the local filesystem. -/
def ScpEndpoint.isLocal (e : ScpEndpoint) : Bool := e.instance_.isNone

/-- Transfer direction, inferred from the source/destination endpoints. -/
inductive ScpDirection where
  /-- All sources are local, destination is remote. -/
  | upload
  /-- All sources are remote, destination is local. -/
  | download
  deriving DecidableEq, Repr

/-- Configuration for `gcloud compute scp` file transfers.
    References: https://cloud.google.com/sdk/gcloud/reference/compute/scp -/
structure ScpConfig where
  /-- Use internal IP address instead of external. -/
  internalIp : Bool := false
  /-- Tunnel through Identity-Aware Proxy. -/
  tunnelThroughIap : Bool := false
  /-- SSH key file path override. -/
  sshKeyFile : Option String := none
  /-- Disable strict host key checking. -/
  strictHostKeyChecking : Bool := true
  /-- Copy directories recursively. -/
  recurse : Bool := false
  /-- Enable gzip compression over the wire. -/
  compress : Bool := false
  /-- Non-default SSH port. -/
  port : Option Nat := none
  /-- Print the scp(1) invocation without executing. -/
  dryRun : Bool := false
  /-- Raw flags passed through to scp(1). -/
  scpFlags : List String := []
  deriving Repr

/-- Result of an SCP file transfer operation. -/
structure ScpResult where
  /-- Standard output from scp. -/
  stdout : String
  /-- Standard error from scp. -/
  stderr : String
  /-- Exit code of the scp process. -/
  exitCode : UInt32
  deriving Repr

/-- SCP uses the same precondition as SSH: VM must be running. -/
def scpPrecondition (status : VMStatus) : Prop := status = .running

/-- IAP tunneling and internal-IP are mutually exclusive for both SSH and SCP. -/
def iapInternalIpExclusive (tunnelThroughIap internalIp : Bool) : Prop :=
  ¬(tunnelThroughIap ∧ internalIp)

/-- All sources in an SCP transfer must have the same locality (all local or all remote). -/
def scpSourcesHomogeneous (sources : List ScpEndpoint) : Prop :=
  (∀ s ∈ sources, s.isLocal) ∨ (∀ s ∈ sources, s.isRemote)

/-- For downloads, all remote sources must reference the same instance. -/
def scpDownloadSingleInstance (sources : List ScpEndpoint) : Prop :=
  ∀ s₁ s₂, s₁ ∈ sources → s₂ ∈ sources →
    s₁.instance_ = s₂.instance_

/-! ## Bare Metal Types -/

/-- Bare metal provisioning/operational lifecycle states (MAAS model). -/
inductive BareMetalStatus where
  | new
  | commissioning
  | failedCommissioning
  | ready
  | allocated
  | deploying
  | deployed
  | releasing
  | broken
  | rescueMode
  | retired
  deriving DecidableEq, Repr, Inhabited

/-- Bare metal provisioning actions. -/
inductive BareMetalProvisionAction where
  | commission
  | allocate
  | deploy
  | release
  | abort
  | markBroken
  | retire
  deriving DecidableEq, Repr

/-- Bare metal power actions. -/
inductive BareMetalPowerAction where
  | powerOn
  | powerOff
  | reinstall
  deriving DecidableEq, Repr

/-- Bare metal actions: provisioning, power, or service work. -/
inductive BareMetalAction (α : Type) where
  | provision : BareMetalProvisionAction → BareMetalAction α
  | power : BareMetalPowerAction → BareMetalAction α
  | service : α → BareMetalAction α
  deriving Repr

/-! ## Transient (Cloud Run / ECS) Types -/

/-- Transient instance lifecycle states (platform-managed). -/
inductive TransientStatus where
  | starting
  | active
  | idle
  | shuttingDown
  deriving DecidableEq, Repr, Inhabited

/-- Transient platform-driven actions. -/
inductive TransientPlatformAction where
  | requestArrives
  | allRequestsComplete
  | idleTimeout
  | terminate
  deriving DecidableEq, Repr

/-- Transient actions: platform-driven or service work. -/
inductive TransientAction (α : Type) where
  | platform : TransientPlatformAction → TransientAction α
  | service : α → TransientAction α
  deriving Repr

/-! ## Distilled (Minimal) Node Types -/

/-- The minimal two-state lifecycle: running or stopped. -/
inductive DistilledStatus where
  | stopped
  | running
  deriving DecidableEq, Repr, Inhabited

/-- The minimal action set: start, stop, or do service work. -/
inductive DistilledAction (α : Type) where
  | start : DistilledAction α
  | stop : DistilledAction α
  | service : α → DistilledAction α
  deriving Repr

/-! ## Isolation Boundary Structures -/

/-- An opaque channel identifier for CCS-style restriction. -/
structure Channel where
  name : String
  deriving DecidableEq, Repr

/-- An opaque resource identifier. -/
structure Resource where
  name : String
  deriving DecidableEq, Repr

/-- Failure type classification. -/
inductive FailureType where
  | processCrash
  | oomKill
  | kernelPanic
  | hypervisorCrash
  | hardwareFailure
  | networkPartition
  deriving DecidableEq, Repr

/-- The isolation boundary of a Node: what is restricted, isolated, and contained. -/
structure IsolationBoundary where
  /-- Action channels invisible outside the boundary. -/
  restrictedChannels : List Channel
  /-- Resources private to the Node. -/
  isolatedResources : List Resource
  /-- Failures contained within the boundary (don't propagate). -/
  containedFailures : List FailureType
  /-- Failures NOT contained (shared-substrate failures). -/
  correlatedFailures : List FailureType

/-- Container isolation constructed from Linux primitives. -/
structure ContainerIsolation where
  namespaces : List Namespace
  cgroup : Cgroup
  cgroupLimits : List CgroupLimit
  seccompFilter : Option SockFprog
  capabilities : CapabilitySet
  rootfs : Root
  boundary : IsolationBoundary

/-- Virtual disk descriptor for VM isolation. -/
structure VirtualDisk where
  name : String
  sizeBytes : Nat
  deriving DecidableEq, Repr

/-- Virtual NIC descriptor for VM isolation. -/
structure VirtualNIC where
  name : String
  macAddress : String
  deriving DecidableEq, Repr

/-- GCE VM isolation configuration. -/
structure VMIsolation where
  machineType : String
  virtualCPUs : Nat
  virtualMemory : Nat
  virtualDisks : List VirtualDisk
  virtualNICs : List VirtualNIC
  boundary : IsolationBoundary

/-! ## Forward Simulation with Action Mapping

The standard `ForwardSimulation` requires the same label type for both LTS.
For concrete-to-distilled simulation we need to map between different action types,
where some concrete actions map to `none` (internal/τ transitions). -/

/-- Forward simulation with explicit state and action maps.
    A concrete LTS simulates an abstract LTS if:
    - Visible actions (those that map to `some`) preserve the state map
    - Silent actions (those that map to `none`) don't change the abstract state -/
structure MappedForwardSimulation
    {S₁ S₂ L₁ L₂ : Type}
    (concrete : LTS S₁ L₁) (abstract : LTS S₂ L₂)
    (stateMap : S₁ → S₂) (actionMap : L₁ → Option L₂) : Prop where
  /-- Initial states correspond. -/
  initial_maps : stateMap concrete.initial = abstract.initial
  /-- Visible transitions are matched by the abstract LTS. -/
  sim_visible : ∀ s₁ a s₁' a',
    concrete.Tr s₁ a s₁' → actionMap a = some a' →
    abstract.Tr (stateMap s₁) a' (stateMap s₁')
  /-- Silent transitions don't change the abstract state. -/
  sim_silent : ∀ s₁ a s₁',
    concrete.Tr s₁ a s₁' → actionMap a = none →
    stateMap s₁ = stateMap s₁'

/-! ## Weak Bisimulation (local definition)

Weak bisimulation allows matching transitions through sequences of silent (τ) steps.
Defined locally here; could be promoted to Foundations if needed elsewhere. -/

/-- Weak bisimulation between two LTS with potentially different state/label types,
    mediated by a state relation and action correspondence.
    Each side can match the other's visible transitions, possibly with silent steps. -/
structure WeakBisimulation
    {S₁ S₂ L : Type}
    (lts₁ : LTS S₁ L) (lts₂ : LTS S₂ L)
    (R : S₁ → S₂ → Prop) : Prop where
  /-- If s₁ R s₂ and s₁ steps on `a`, then s₂ can match (possibly with silent steps). -/
  forth : ∀ s₁ s₂ a s₁', R s₁ s₂ → lts₁.Tr s₁ a s₁' →
    ∃ s₂', lts₂.Tr s₂ a s₂' ∧ R s₁' s₂'
  /-- If s₁ R s₂ and s₂ steps on `a`, then s₁ can match. -/
  back : ∀ s₁ s₂ a s₂', R s₁ s₂ → lts₂.Tr s₂ a s₂' →
    ∃ s₁', lts₁.Tr s₁ a s₁' ∧ R s₁' s₂'

end SWELib.OS.Isolation
