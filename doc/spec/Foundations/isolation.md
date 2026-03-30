# Sketch: Isolation Boundaries (Containers, VMs, Bare Metal)

## What This Sketch Defines

How the abstract Node (sketch 01) connects to concrete isolation mechanisms. A container, a VM, and a bare metal machine are all Nodes — they are all `LTS S α`. But they are different *instantiations* with different state types, action types, and transition relations. This sketch defines those concrete instantiations, a **distilled Node** that captures what they share, and the simulation relations that connect them.

This sketch bridges SWELib's engineering-level OS modules (namespaces, cgroups, seccomp, capabilities) and Cloud modules (OCI runtime, K8s Pod/Container) with the CS-theoretic Node/System framework from sketches 01-05.

## The Core Principle

**Node is just `LTS S α`. Don't add structure to it.**

Sketch 01 defines Node as an LTS parameterized by state type `S` and action type `α`. That's the right level of generality. A CPU pipeline stage, a container, a VM, a bare metal machine, a futures exchange — they're all `LTS S α` with different `S` and `α`. The moment you bake structure into Node itself (like "every Node has a service LTS and a management LTS"), you've committed to a decomposition that doesn't apply to half the use cases. And if you split into two, you'll eventually want three, then four. The right number of interfaces on Node is zero — it's just an LTS.

Instead:
1. **Node stays abstract** — exactly as sketch 01 defines it
2. **ContainerNode, VMNode, BareMetalNode are concrete instantiations** — each with its own `S` and `α`, its own lifecycle, its own failure characteristics
3. **DistilledNode is the simplest LTS that captures their common behavior** — it's itself a Node, not a typeclass or a structural decomposition
4. **Simulation relations connect concrete Nodes to DistilledNode** — using CSLib's existing simulation machinery

This keeps everything within the framework. The glue between containers and VMs is a Node (DistilledNode) and a simulation relation (from CSLib). No new concepts needed.

## Why the Lifecycles Are Different

A survey of real systems shows that containers, VMs, and bare metal have structurally different lifecycle state machines. These differences are not incidental — they reflect fundamentally different isolation mechanisms.

### Container Lifecycles

| System | States | Key Properties |
|--------|--------|----------------|
| OCI Runtime Spec | creating → created → running → stopped | 4 states. Pause is a runtime extension, not core spec. No explicit crashed state. |
| Docker | created → running → paused → restarting → exited → dead | Adds restart policy loop (`restarting`), partial failure (`dead`), and `exited → running` restart. |
| AWS ECS | PROVISIONING → PENDING → ACTIVATING → RUNNING → DEACTIVATING → STOPPING → DEPROVISIONING → STOPPED | Strictly linear. No pause. No in-place restart. Fully transient. |
| GCP Cloud Run | Starting → Active → Idle → Shutting Down | No user-initiated stop/pause/restart. Request-driven lifecycle. Scale to zero. |

**Container-specific properties:**
- Pause = cgroup freezer (SIGSTOP all processes). Memory stays in host RAM. Doesn't survive host reboot.
- Restart = re-execute the entrypoint process. No OS boot cycle. Sub-second.
- Crash is not distinguished from stop (OCI: both → `stopped`).
- Some platforms (Cloud Run, ECS) eliminate lifecycle management entirely — instances are transient.

### VM Lifecycles

| System | States | Key Properties |
|--------|--------|----------------|
| libvirt/KVM | SHUTOFF, RUNNING, BLOCKED, PAUSED, SHUTDOWN, CRASHED, PMSUSPENDED | 7 states. Explicit CRASHED state. PM suspend (ACPI S3/S4). Save/restore to disk. |
| AWS EC2 | pending → running → stopping → stopped → shutting-down → terminated | 6 states. `terminated` is permanent. Hibernate writes RAM to EBS. |
| GCP Compute Engine | PROVISIONING → STAGING → RUNNING → STOPPING → TERMINATED, + SUSPENDING → SUSPENDED | TERMINATED = stopped (not destroyed). SUSPENDED writes memory to disk; auto-terminates after 60 days. |
| Azure | Creating → Starting → Running → Stopping → Stopped / Deallocating → Deallocated | Two distinct stopped states: Stopped (hardware held, billed) vs Deallocated (hardware released, free). |
| VMware vSphere | poweredOff ↔ poweredOn ↔ suspended | 3 power states. Suspended = memory checkpointed to `.vmss`. Distinguishes hard vs guest operations (VMware Tools). |

**VM-specific properties:**
- Pause/suspend can write memory to disk (survives host reboot). Container pause cannot.
- Explicit CRASHED state (libvirt) — guest kernel panic is observable, not just "stopped."
- Restart = full OS boot cycle (BIOS, kernel init). Seconds to minutes, not sub-second.
- Stopped VMs retain identity, disk, and (often) IP. Can restart on same or different host.

### Bare Metal Lifecycles

| System | States | Key Properties |
|--------|--------|----------------|
| AWS EC2 Bare Metal | Same as EC2 VM (pending → running → ...) | Identical API. Nitro firmware hides hardware. Design choice, not universal. |
| Equinix Metal | queued → provisioning → active ↔ inactive, + reinstalling | No pause/suspend. Active/inactive = powered on/off. Reinstall = full OS re-image. |
| MAAS | New → Commissioning → Ready → Allocated → Deploying → Deployed → Releasing, + Broken, Rescue, Retired | 12+ states. Hardware commissioning lifecycle. No analogue in VMs or containers. |

**Bare-metal-specific properties:**
- Hardware commissioning (MAAS: probe inventory, validate firmware) has no VM/container equivalent.
- No pause or suspend — just powered on or powered off.
- Can be hooked up to any management system (PXE boot into anything, manage via MAAS/Foreman/custom IPMI/nothing). AWS chose to make bare metal look like VMs; other providers expose the hardware lifecycle directly.
- The management LTS depends entirely on the tooling built around the BMC/IPMI/Redfish interface.

### What This Means

1. **There is no universal lifecycle.** OCI has 4 states, MAAS has 12+. Forcing them into a common LTS loses information.
2. **"Pause" means three different things.** Cgroup freezer (container), hypervisor suspend in RAM (VM), checkpoint to disk (VM suspend-to-disk). Different failure characteristics.
3. **"Restart" means two different things.** Re-exec entrypoint (container, sub-second) vs full OS boot (VM, seconds-minutes).
4. **Some systems eliminate lifecycle management entirely.** Cloud Run: no stop, no pause, no restart. Instances are request-driven and fully transient.
5. **Bare metal adds a hardware layer** below anything VMs or containers deal with.

These are not differences to abstract away — they're differences to model explicitly in different Node instantiations.

## Concrete Node Instantiations

### ContainerNode

```
-- State: OCI lifecycle states (from existing Cloud.Oci.ContainerStatus)
-- Actions: lifecycle + service actions

inductive ContainerAction (α : Type) where
  | lifecycle : ContainerLifecycleAction → ContainerAction α
  | service : α → ContainerAction α  -- the actual service behavior (parameterized)

inductive ContainerLifecycleAction where
  | create | start | kill (signal : Signal) | pause | resume | delete

-- The container Node's LTS combines lifecycle and service behavior
-- Service actions are only possible in the `running` state
def ContainerNode (α : Type) := LTS ContainerStatus (ContainerAction α)

-- Concrete LTS for OCI containers
def ociContainerLTS (serviceLTS : LTS ServiceState α) : ContainerNode α where
  Tr src action dst :=
    match action with
    | .lifecycle .create => src = .creating ∧ dst = .created
    | .lifecycle .start => src = .created ∧ dst = .running
    | .lifecycle (.kill _) => (src = .running ∨ src = .created) ∧ dst = .stopped
    | .lifecycle .pause => src = .running ∧ dst = .paused
    | .lifecycle .resume => src = .paused ∧ dst = .running
    | .lifecycle .delete => src = .stopped  -- terminal
    | .service a => src = .running ∧ dst = .running  -- service only when running
```

### VMNode

```
-- State: hypervisor-managed lifecycle
-- Using libvirt-style states as the most complete model

inductive VMStatus where
  | shutoff | running | blocked | paused | shutdown | crashed | pmSuspended
  deriving DecidableEq, Repr

inductive VMAction (α : Type) where
  | lifecycle : VMLifecycleAction → VMAction α
  | service : α → VMAction α

inductive VMLifecycleAction where
  | create | destroy | suspend | resume
  | shutdownGuest | save | restore | pmWakeup | reboot

def VMNode (α : Type) := LTS VMStatus (VMAction α)

def libvirtVMNodeLTS (serviceLTS : LTS ServiceState α) : VMNode α where
  Tr src action dst :=
    match action with
    | .lifecycle .create => src = .shutoff ∧ dst = .running
    | .lifecycle .destroy => (src = .running ∨ src = .paused) ∧ dst = .shutoff
    | .lifecycle .suspend => (src = .running ∨ src = .blocked) ∧ dst = .paused
    | .lifecycle .resume => src = .paused ∧ dst = .running
    | .lifecycle .shutdownGuest => src = .running ∧ dst = .shutdown
    | .lifecycle .save => src = .running ∧ dst = .shutoff  -- memory → disk
    | .lifecycle .restore => src = .shutoff ∧ dst = .running  -- memory ← disk
    | .lifecycle .pmWakeup => src = .pmSuspended ∧ dst = .running
    | .lifecycle .reboot => src = .running ∧ dst = .running
    | .service a => (src = .running ∨ src = .blocked) ∧ dst = src
```

### BareMetalNode

```
-- State: hardware provisioning + operational lifecycle
-- Using MAAS as the reference model (most complete)

inductive BareMetalStatus where
  | new | commissioning | failedCommissioning | ready
  | allocated | deploying | deployed
  | releasing | broken | rescueMode | retired
  deriving DecidableEq, Repr

inductive BareMetalAction (α : Type) where
  | provision : BareMetalProvisionAction → BareMetalAction α
  | power : BareMetalPowerAction → BareMetalAction α
  | service : α → BareMetalAction α

inductive BareMetalProvisionAction where
  | commission | allocate | deploy | release | abort | markBroken | retire

inductive BareMetalPowerAction where
  | powerOn | powerOff | reinstall

def BareMetalNode (α : Type) := LTS BareMetalStatus (BareMetalAction α)

-- Service actions only possible when deployed
def maasBareMetalLTS (serviceLTS : LTS ServiceState α) : BareMetalNode α where
  Tr src action dst :=
    match action with
    | .provision .commission => (src = .new ∨ src = .failedCommissioning ∨ src = .broken) ∧ dst = .commissioning
    | .provision .allocate => src = .ready ∧ dst = .allocated
    | .provision .deploy => src = .allocated ∧ dst = .deploying
    | .provision .release => src = .deployed ∧ dst = .releasing
    | .provision .abort => (src = .commissioning ∨ src = .deploying) ∧ dst = .ready
    | .provision .markBroken => dst = .broken
    | .provision .retire => src = .ready ∧ dst = .retired
    | .power .powerOn => src = .deploying ∧ dst = .deployed  -- simplified
    | .power .powerOff => src = .deployed ∧ dst = .ready  -- simplified
    | .power .reinstall => src = .deployed ∧ dst = .deploying
    | .service a => src = .deployed ∧ dst = .deployed
```

### TransientNode (Cloud Run / ECS-style)

```
-- Some systems eliminate lifecycle management entirely
-- The platform controls everything; the Node just handles requests

inductive TransientStatus where
  | starting | active | idle | shuttingDown
  deriving DecidableEq, Repr

inductive TransientAction (α : Type) where
  | platform : TransientPlatformAction → TransientAction α
  | service : α → TransientAction α

inductive TransientPlatformAction where
  | requestArrives | allRequestsComplete | idleTimeout | terminate

def TransientNode (α : Type) := LTS TransientStatus (TransientAction α)

-- No user-initiated lifecycle management at all
-- The platform drives all transitions; the Node just serves or dies
```

## The Distilled Interface

All four concrete Node types share a common behavioral core: they have states where they can do service work and states where they can't, with transitions between the two. Rather than encoding this as a typeclass (which adds non-LTS structure) or decomposing Node (which invites infinite splitting), we define this common core as **itself a Node** — the simplest LTS that captures what containers, VMs, and bare metal share.

### DistilledNode

```
inductive DistilledStatus where
  | stopped
  | running
  deriving DecidableEq, Repr

inductive DistilledAction (α : Type) where
  | start : DistilledAction α       -- transition to running
  | stop : DistilledAction α        -- transition to stopped (graceful or crash)
  | service : α → DistilledAction α -- do actual work (only when running)

def DistilledNode (α : Type) := LTS DistilledStatus (DistilledAction α)

def distilledLTS : DistilledNode α where
  Tr src action dst :=
    match action with
    | .start => src = .stopped ∧ dst = .running
    | .stop => src = .running ∧ dst = .stopped
    | .service _ => src = .running ∧ dst = .running
```

That's it. Two states, three action kinds. This is the smallest thing you can call "a compute node that does work."

### Why This Is a Node, Not a Typeclass

The distilled interface is `LTS DistilledStatus (DistilledAction α)` — it's a Node in the same sense that ContainerNode and VMNode are Nodes. This matters because:

1. **It stays within the framework.** The System level (sketch 02) composes Nodes via CCS. DistilledNode can participate directly — no adapter layer needed.
2. **The glue is a simulation relation.** CSLib already defines simulation and bisimulation between LTS. The relationship between ContainerNode and DistilledNode is a forward simulation. No new concepts needed.
3. **It doesn't invite splitting.** A typeclass like `HasServiceAvailable` is one interface; someone will want `HasHealthCheck`, then `HasGracefulShutdown`, then you're back to the infinite decomposition problem. DistilledNode is a fixed, minimal LTS. If you need more detail, you use the concrete Node directly. There's no in-between to argue about.
4. **Theorems compose naturally.** A theorem proved about DistilledNode applies to anything that simulates it — for free, via the simulation relation. No theorem-lifting machinery needed.

### Simulation Relations (Concrete → Distilled)

Each concrete Node type has a simulation relation to DistilledNode. The simulation is a function that maps concrete states to distilled states and concrete actions to distilled actions (or τ):

#### ContainerNode → DistilledNode

```
-- State mapping: collapse OCI states to {stopped, running}
def containerStateMap : ContainerStatus → DistilledStatus
  | .creating => .stopped
  | .created => .stopped
  | .running => .running
  | .stopped => .stopped
  | .paused => .stopped   -- paused ≠ running: can't do service work

-- Action mapping: lifecycle → start/stop/τ, service → service
def containerActionMap : ContainerAction α → Option (DistilledAction α)
  | .lifecycle .start => some .start       -- created → running maps to start
  | .lifecycle (.kill _) => some .stop     -- running → stopped maps to stop
  | .lifecycle .create => none             -- creating → created is internal (τ)
  | .lifecycle .pause => some .stop        -- running → paused maps to stop
  | .lifecycle .resume => some .start      -- paused → running maps to start
  | .lifecycle .delete => none             -- terminal cleanup is internal (τ)
  | .service a => some (.service a)        -- service maps directly

-- The simulation: every ContainerNode transition maps to a DistilledNode transition (or τ)
theorem container_simulates_distilled (cn : ContainerNode α) :
    ForwardSimulation cn distilledLTS containerStateMap containerActionMap
```

Paused maps to `stopped` because a paused container can't do service work. This is a design choice — you could argue paused is a third state. But the point of DistilledNode is to be minimal. If the distinction between paused and stopped matters for your theorem, use ContainerNode directly.

#### VMNode → DistilledNode

```
-- State mapping: collapse hypervisor states to {stopped, running}
def vmStateMap : VMStatus → DistilledStatus
  | .shutoff => .stopped
  | .running => .running
  | .blocked => .running     -- blocked is a sub-state of running (guest idle)
  | .paused => .stopped      -- paused can't do service work
  | .shutdown => .stopped    -- shutting down, no longer serving
  | .crashed => .stopped     -- crashed, obviously not serving
  | .pmSuspended => .stopped -- ACPI suspended, not serving

-- Action mapping
def vmActionMap : VMAction α → Option (DistilledAction α)
  | .lifecycle .create => some .start
  | .lifecycle .destroy => some .stop
  | .lifecycle .suspend => some .stop
  | .lifecycle .resume => some .start
  | .lifecycle .shutdownGuest => some .stop
  | .lifecycle .save => some .stop        -- save to disk = becomes stopped
  | .lifecycle .restore => some .start    -- restore from disk = becomes running
  | .lifecycle .pmWakeup => some .start
  | .lifecycle .reboot => none            -- running → running, internal (τ)
  | .service a => some (.service a)

theorem vm_simulates_distilled (vn : VMNode α) :
    ForwardSimulation vn distilledLTS vmStateMap vmActionMap
```

Note: `blocked` maps to `running` because a blocked VM can still receive and process service actions — the guest is just idle, not unavailable. This reflects libvirt's semantics where BLOCKED and RUNNING are essentially the same from an external perspective.

#### BareMetalNode → DistilledNode

```
-- State mapping: the entire provisioning lifecycle maps to stopped
-- Only deployed = running
def bareMetalStateMap : BareMetalStatus → DistilledStatus
  | .deployed => .running
  | _ => .stopped   -- everything else: not serving

-- Action mapping
def bareMetalActionMap : BareMetalAction α → Option (DistilledAction α)
  | .power .powerOn => some .start            -- simplified: deploying → deployed
  | .power .powerOff => some .stop
  | .power .reinstall => some .stop           -- takes it out of service
  | .provision .deploy => none                -- internal provisioning (τ)
  | .provision .commission => none            -- internal provisioning (τ)
  | .provision .allocate => none              -- internal provisioning (τ)
  | .provision .release => some .stop
  | .provision .abort => none                 -- internal (τ)
  | .provision .markBroken => some .stop
  | .provision .retire => some .stop
  | .service a => some (.service a)

theorem bare_metal_simulates_distilled (bn : BareMetalNode α) :
    ForwardSimulation bn distilledLTS bareMetalStateMap bareMetalActionMap
```

The entire MAAS commissioning lifecycle (new → commissioning → ready → allocated → deploying) collapses to `stopped` in the distilled view. From a System-level perspective, a machine that's being commissioned is the same as one that's powered off — it's not doing service work. The 12-state MAAS lifecycle is real and important for bare metal management, but invisible to the distributed systems theorems.

#### TransientNode → DistilledNode

```
def transientStateMap : TransientStatus → DistilledStatus
  | .active => .running
  | .idle => .running        -- idle but still can serve (wakes on request)
  | .starting => .stopped
  | .shuttingDown => .stopped

def transientActionMap : TransientAction α → Option (DistilledAction α)
  | .platform .requestArrives => some .start  -- starting/idle → active
  | .platform .allRequestsComplete => none    -- active → idle (still running)
  | .platform .idleTimeout => some .stop      -- idle → shutting down
  | .platform .terminate => some .stop
  | .service a => some (.service a)

theorem transient_simulates_distilled (tn : TransientNode α) :
    ForwardSimulation tn distilledLTS transientStateMap transientActionMap
```

Cloud Run's `idle` maps to `running` because an idle instance can still serve — it wakes up when a request arrives. The `idle → active` transition is internal (τ) from the distilled perspective.

### How the System Level Uses This

The System level (sketch 02) can work at two granularities:

**Option A: Compose DistilledNodes directly.** State theorems over `DistilledNode α`. They apply to any concrete Node that simulates DistilledNode — which is all of them.

```
-- System of distilled Nodes
-- Every theorem here applies to containers, VMs, and bare metal alike
def System (α : Type) := CCS.Composition (DistilledNode α)

-- "Paxos is safe with f < n/2 crash-stop nodes"
-- crash-stop = once the Node enters stopped, it stays stopped
-- This is a property of DistilledNode's LTS
def crashStop (n : DistilledNode α) : Prop :=
  ∀ s, n.Tr s .stop .stopped → ¬ ∃ s', n.Tr .stopped .start s'

theorem paxos_safe (sys : System α)
  (h_crash : ∀ n ∈ sys.nodes, crashStop n)
  (h_bound : crashedCount sys < sys.nodes.card / 2) :
  safe sys
```

**Option B: Compose concrete Nodes and project.** When you need mechanism-specific detail (e.g., "what happens when a VM is paused during a rolling deploy?"), work with VMNode directly. The simulation guarantees that any DistilledNode theorem still holds — you don't lose anything by being more specific.

```
-- A mixed System with both containers and VMs
-- Each concrete Node projects to DistilledNode via simulation
-- System-level theorems apply to the projected view

-- "Replacing a ContainerNode with a VMNode preserves safety"
-- Because both simulate DistilledNode with the same service actions
theorem container_vm_substitution
  (cn : ContainerNode α) (vn : VMNode α)
  (h_service_bisim : serviceBisimilar cn vn)  -- same service behavior
  (sys : System α) :
  safe (sys.replace cn.asDistilled vn.asDistilled)
```

**Option C: Mix granularities.** Some Nodes in the System are distilled (you only care about start/stop/service), others are concrete (you need their lifecycle details). The simulation relation lets you move between levels freely.

### What the Simulation Loses (Intentionally)

The simulation from concrete to distilled is **lossy by design**. It collapses mechanism-specific states and actions into the minimal common core. What gets lost:

| Collapsed Away | Where It Lives | When You Need It |
|---------------|---------------|-----------------|
| Container pause/resume | ContainerNode | Reasoning about cgroup freezer behavior, resource snapshots |
| VM CRASHED state | VMNode | Distinguishing crash from graceful stop, auto-restart policies |
| VM save/restore | VMNode | Live migration, hibernation, checkpoint/restore |
| VM BLOCKED state | VMNode | Guest idle detection, power management |
| Bare metal commissioning | BareMetalNode | Hardware lifecycle, fleet management, MAAS orchestration |
| Azure Stopped vs Deallocated | (cloud-specific VMNode variant) | Billing, hardware allocation guarantees |
| Cloud Run idle | TransientNode | Autoscaling behavior, cold start analysis |
| Docker restarting/dead | (Docker-specific ContainerNode variant) | Restart policy loops, partial failure recovery |

If your theorem needs any of this, use the concrete Node. The distilled view is for theorems that don't — which includes most distributed systems results (consensus, replication, consistency, partition tolerance).

## Isolation as Refinement

The isolation mechanism (how the Node achieves its boundary) is a refinement concern, orthogonal to the Node type and the distilled interface. Two different ContainerNodes can have different isolation configurations; a VMNode and a ContainerNode can expose the same service actions.

### IsolationBoundary

```
structure IsolationBoundary where
  -- Which action channels are restricted (invisible outside)
  restrictedChannels : Set Channel
  -- Which resources are isolated (private to the Node)
  isolatedResources : Set Resource
  -- What failures are contained (don't propagate outside)
  containedFailures : Set FailureType
  -- What failures are NOT contained (shared-substrate failures)
  correlatedFailures : Set FailureType
```

### ContainerIsolation

Constructs an IsolationBoundary from Linux primitives:

```
structure ContainerIsolation where
  namespaces : List Namespace              -- from OS.Namespaces
  cgroup : Cgroup                          -- from OS.Cgroups
  cgroupLimits : List CgroupLimit          -- resource limits
  seccompFilter : Option SockFprog         -- from OS.Seccomp
  capabilities : CapabilitySet             -- from OS.Capabilities
  rootfs : Root                            -- from Cloud.Oci
  boundary : IsolationBoundary
  boundary_correct : boundaryFromPrimitives namespaces cgroup seccompFilter capabilities = boundary
```

### VMIsolation

```
structure VMIsolation where
  virtualCPUs : Nat
  virtualMemory : Nat
  virtualDisks : List VirtualDisk
  virtualNICs : List VirtualNIC
  guestKernelImage : String
  boundary : IsolationBoundary
  boundary_correct : vmBoundaryFromHypervisor virtualCPUs virtualMemory virtualNICs = boundary
```

### Refinement Structures

```
-- Container refinement: links a ContainerNode to its Linux primitives
structure ContainerRefinement (α : Type) where
  node : ContainerNode α
  isolation : ContainerIsolation
  ociConfig : ContainerConfig              -- from Cloud.Oci
  processTree : ProcessTable               -- from OS.Process
  -- Internal process tree, restricted by namespaces, is bisimilar to the Node
  equiv : WeakBisimulation node (processTree.asLTS.restrictedBy isolation.namespaces)

-- VM refinement: links a VMNode to its hypervisor primitives
structure VMRefinement (α : Type) where
  node : VMNode α
  isolation : VMIsolation
  equiv : WeakBisimulation node (guestSystem.asLTS.mediatedBy isolation.virtualNICs)
```

## Namespace Isolation as Channel Restriction

Each namespace type maps to CCS channel restriction on the Node:

```
-- PID namespace: processes inside cannot observe or signal host PIDs
theorem pid_namespace_isolation (c : ContainerRefinement α)
  (h_pid_ns : Namespace.pid ∈ c.isolation.namespaces) :
  ∀ host_pid, ¬ ∃ s s', c.node.Tr s (.service (signal host_pid)) s'

-- Network namespace: container has its own network stack
theorem net_namespace_isolation (c : ContainerRefinement α)
  (h_net_ns : Namespace.network ∈ c.isolation.namespaces) :
  ∀ host_iface, ¬ ∃ s s', c.node.Tr s (.service (sendOn host_iface)) s'

-- Mount namespace: container sees only its own filesystem view
theorem mount_namespace_isolation (c : ContainerRefinement α)
  (h_mnt_ns : Namespace.mount ∈ c.isolation.namespaces) :
  ∀ host_path, host_path ∉ visiblePaths c.ociConfig.mounts →
  ¬ ∃ s s', c.node.Tr s (.service (readFile host_path)) s'
```

## Seccomp as Action Alphabet Restriction

```
-- A seccomp filter that blocks a syscall removes the corresponding service action
theorem seccomp_restricts_actions (c : ContainerRefinement α)
  (h_filter : c.isolation.seccompFilter = some prog)
  (h_blocks : seccompBlocks prog syscall) :
  ∀ s s', ¬ c.node.Tr s (.service (syscallAction syscall)) s'

-- A seccomp-filtered container simulates the unfiltered version
theorem seccomp_simulation (filtered unfiltered : ContainerRefinement α)
  (h_same : sameExceptSeccomp filtered unfiltered)
  (h_filter : filtered.isolation.seccompFilter.isSome) :
  ForwardSimulation filtered.node unfiltered.node
```

## Resource Limits as State Space Constraints

```
theorem cgroup_memory_bounds (c : ContainerRefinement α)
  (h_limit : CgroupLimit.memory bytes ∈ c.isolation.cgroupLimits) :
  ∀ s, c.node.reachable s → memoryUsage s ≤ bytes

theorem cgroup_pid_bounds (c : ContainerRefinement α)
  (h_limit : CgroupLimit.pidCount count ∈ c.isolation.cgroupLimits) :
  ∀ s, c.node.reachable s → processCount s ≤ count
```

## Failure Independence

The isolation mechanism determines correlated failure modes. At the distilled level, failure = transition to `stopped`. The conditions under which two Nodes fail independently depend on the isolation mechanism:

```
-- Container independence: conditioned on kernel + cgroups
theorem container_failure_independent
  (c1 c2 : ContainerRefinement α)
  (h_different_cgroups : c1.isolation.cgroup ≠ c2.isolation.cgroup)
  (h_limits : cgroupLimitsEnforced c1 ∧ cgroupLimitsEnforced c2)
  (h_kernel : kernelAlive) :
  c1.node.asDistilled.state = .stopped →  -- c1 failed
  c2.node.asDistilled.state = .running    -- c2 still running

-- VM independence: conditioned on hypervisor only
theorem vm_failure_independent
  (vm1 vm2 : VMRefinement α)
  (h_hypervisor : hypervisorAlive) :
  vm1.node.asDistilled.state = .stopped →
  vm2.node.asDistilled.state = .running

-- Bare metal independence: unconditional
theorem bare_metal_failure_independent
  (m1 m2 : BareMetalRefinement α) :
  m1.node.asDistilled.state = .stopped →
  m2.node.asDistilled.state = .running
```

The sharing chain:

```
Bare Metal   → nothing shared (separate hardware)       → unconditional independence
VM           → hardware shared (shared hypervisor)       → conditioned on hypervisor liveness
Container    → kernel shared (shared kernel)             → conditioned on kernel + cgroup liveness
```

## Pod as CCS Composition

A K8s Pod is a CCS composition of ContainerNodes with shared channels:

```
-- Containers in a Pod share:
-- 1. Network namespace (localhost channels unrestricted between them)
-- 2. IPC namespace (shared memory channels unrestricted)
-- 3. Volume mounts (filesystem channels to shared volumes unrestricted)

-- They do NOT share:
-- 1. PID namespace (by default)
-- 2. Filesystem (each has own rootfs, except explicit volume mounts)

-- CCS representation:
Pod = (ContainerNode₁ | ContainerNode₂ | ... | ContainerNodeₙ)
      \ container₁_private_fs \ container₂_private_fs ...

-- Intra-Pod communication is synchronous CCS handshake (localhost)
-- which matches sketch 05 row 4: reliable, low-latency, FIFO

-- The Pod as a whole simulates a DistilledNode:
-- Pod is running ↔ all its containers are running
-- Pod service actions = union of container service actions (via shared network)
```

## Existing Type Mappings

```
-- Cloud.Oci.ContainerStatus IS ContainerNode's state type
-- Cloud.Oci.ContainerStatus.canTransition IS the lifecycle part of ContainerNode's LTS
-- The existing code becomes an instance, not a replacement

-- Cloud.K8s.Workloads.Container IS a declarative spec for a ContainerNode
-- ports → service action channels
-- image → which service behavior to instantiate
-- env → initial state parameters

-- Cloud.K8s.Workloads.Pod IS a CCS composition of ContainerNodes

-- OS.Process.ProcessTable IS the internal structure of a ContainerRefinement
-- fork/exec/exit/kill are internal (τ) transitions in the refinement
```

## Extension Points

### Hybrid Isolation (gVisor, Kata, Firecracker)

```
-- These blur the container/VM line:

-- gVisor: ContainerNode lifecycle (OCI API) + VM-like isolation (user-space kernel)
-- Kata: ContainerNode lifecycle (OCI API) + VMIsolation (real hypervisor)
-- Firecracker: custom lifecycle (its own LTS) + VMIsolation (minimal hypervisor)

-- Each is a concrete Node instantiation with its own LTS
-- Each simulates DistilledNode (they all have running/stopped + service)
-- The isolation refinement captures their specific boundary properties
```

### Nested Isolation

```
-- Container inside VM: two refinement layers
-- Layer 1: VMNode → hypervisor boundary
-- Layer 2: ContainerNode inside VM → namespace boundary inside guest kernel
-- Both simulate DistilledNode independently
-- Failure containment composes: both hypervisor AND namespace isolation
```

### Resource Interference (future, needs timed/quantitative models)

```
-- Today: "cgroup limits prevent resource exhaustion" (qualitative)
-- Future: "container A gets at least X% of CPU when B is busy" (quantitative)
```

### Richer Distilled Variants (if needed)

```
-- DistilledNode is deliberately minimal (2 states, 3 actions)
-- If a class of theorems needs more structure, define a richer variant:

-- DistilledWithHealth: adds degraded state
-- {stopped, running, degraded} × {start, stop, degrade, recover, service}

-- DistilledWithDrain: adds draining state for graceful shutdown
-- {stopped, running, draining} × {start, stop, drain, service}

-- These are still Nodes (LTS), still have simulation relations from concrete types
-- DistilledNode simulates all of them (it's the most abstract)
-- The hierarchy: Concrete → Richer Distilled → DistilledNode
-- Use the level of detail your theorem needs
```

## Key Theorems Sketch

### Simulation Soundness

- Every ContainerNode simulates DistilledNode via containerStateMap/containerActionMap
- Every VMNode simulates DistilledNode via vmStateMap/vmActionMap
- Every BareMetalNode simulates DistilledNode via bareMetalStateMap/bareMetalActionMap
- Every TransientNode simulates DistilledNode via transientStateMap/transientActionMap
- Consequence: any theorem proved about DistilledNode applies to all four

### Service Equivalence (Via Simulation)

- Two Nodes that simulate DistilledNode with the same service action type `α` and bisimilar service behavior (same responses to same inputs) can be substituted in any System
- This holds across isolation mechanisms: a ContainerNode and a VMNode running the same software are interchangeable at the System level
- System-level theorems (Paxos safety, 2PC atomicity) are stated over DistilledNode and apply to all concrete Nodes via simulation

### Lifecycle Non-Equivalence (Honest)

- ContainerNode, VMNode, and BareMetalNode have different LTS and are NOT bisimilar as full Nodes
- The simulation to DistilledNode is lossy — it intentionally discards mechanism-specific states and actions
- When the discarded detail matters (pause semantics, crash vs stop, commissioning), use the concrete Node directly

### Isolation Correctness

- A container with all namespace types unshared restricts the corresponding CCS channels
- A container with cgroup memory limit `L` constrains reachable states to memory ≤ `L`
- A seccomp filter blocking syscall `S` removes `S` from the service action alphabet

### Failure Independence

- Containers: independent conditioned on kernel + cgroup liveness
- VMs: independent conditioned on hypervisor liveness
- Bare metal: unconditionally independent
- Stronger isolation → fewer conditions on independence
- These theorems can be stated at either the concrete or distilled level

### Composition

- A Pod's external behavior is the CCS composition of its ContainerNodes with shared localhost
- Adding a sidecar ContainerNode to a Pod preserves existing service behavior (non-interfering parallel composition)
- A K8s Deployment (N replicas of a Pod) is a System of N Nodes with bisimilar service behavior at the distilled level

## Relationship to Other Sketches

- **Node (sketch 01)**: Untouched. ContainerNode, VMNode, BareMetalNode, DistilledNode are all concrete instantiations of `LTS S α`. DistilledNode is the simplest useful instantiation. Simulation relations (from CSLib) connect them.
- **System (sketch 02)**: Composes Nodes via CCS. Can work at the DistilledNode level (for general theorems) or at the concrete level (for mechanism-specific reasoning). The simulation lets you move between levels.
- **Migration (sketch 03)**: Migrating from VM to container = substituting one Node for another. If both simulate DistilledNode with bisimilar service behavior, the migration is safe for consumers. The lifecycle change is an orchestrator concern.
- **Policy (sketch 04)**: Isolation requirements are lint rules on the refinement layer ("every container must have a seccomp profile"). Service-level invariants are checked at the DistilledNode level.
- **Network (sketch 05)**: Intra-Pod = synchronous reliable (localhost). Inter-Pod = depends on CNI. Container ↔ VM = whatever network connects them. Network properties are orthogonal to Node type.

## Relationship to Existing SWELib Modules

- `OS.Namespaces` — building blocks of ContainerIsolation. Each namespace type = CCS channel restriction.
- `OS.Cgroups` — CgroupLimit parameterizes state space bound theorems on ContainerNode.
- `OS.Seccomp` — SockFprog parameterizes action alphabet restriction theorems on ContainerNode.
- `OS.Capabilities` — CapabilitySet further restricts the service action alphabet.
- `OS.Process` — ProcessTable is the internal structure of ContainerRefinement.
- `Cloud.Oci.ContainerStatus` — IS ContainerNode's state type. `canTransition` IS the lifecycle transition relation.
- `Cloud.Oci.ContainerConfig` — determines both which ContainerNode LTS to instantiate and which ContainerIsolation to construct.
- `Cloud.K8s.Workloads.Container` — declarative spec for a ContainerNode (ports → service channels, image → service behavior).
- `Cloud.K8s.Workloads.Pod` — CCS composition of ContainerNodes with shared network namespace.

## Source Specs / Prior Art

### Lifecycle State Machines (surveyed)
- **OCI Runtime Spec v1.0**: 4-state container lifecycle (creating, created, running, stopped). Pause is extension.
- **Docker Engine**: extends OCI with restarting, dead states and restart policies.
- **AWS ECS**: strictly linear task lifecycle. No pause, no in-place restart.
- **GCP Cloud Run**: request-driven lifecycle. No user-initiated management.
- **libvirt/KVM**: 7 domain states including CRASHED and PMSUSPENDED (ACPI S3/S4).
- **AWS EC2**: 6 states including permanent `terminated`. Hibernate writes RAM to EBS. Bare metal uses identical API.
- **GCP Compute Engine**: SUSPENDED writes memory to disk; auto-terminates after 60 days.
- **Azure VMs**: two-axis model (power + provisioning) with Stopped/Deallocated billing distinction.
- **VMware vSphere**: 3 power states with hard-vs-guest operation distinction.
- **Equinix Metal**: bare metal power on/off and reinstall. No pause/suspend.
- **MAAS**: 12+ state hardware commissioning lifecycle.

### Formal Foundations
- **CSLib** (Lean): LTS, CCS restriction operator, bisimulation, simulation relations
- **Popek & Goldberg (1974)**: classical virtualization requirements (efficiency, resource control, equivalence)
- **Soltesz et al. (2007)**: container vs VM tradeoff — shared kernel = more correlated failures, less overhead

### Isolation Mechanisms (already in SWELib)
- **Linux namespaces** (clone(2), unshare(2), setns(2)): `OS.Namespaces`
- **Linux cgroups v2**: `OS.Cgroups`
- **Linux seccomp-bpf**: `OS.Seccomp`
- **Linux capabilities**: `OS.Capabilities`
- **Kubernetes Pod spec**: `Cloud.K8s.Workloads`
- **OCI Runtime Spec**: `Cloud.Oci`

### Hybrid Isolation
- **gVisor**: user-space kernel, OCI lifecycle, VM-like isolation
- **Kata Containers**: OCI lifecycle, real hypervisor isolation
- **Firecracker**: custom lifecycle, minimal hypervisor isolation
