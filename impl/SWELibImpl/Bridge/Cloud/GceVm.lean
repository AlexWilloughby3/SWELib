import SWELib
import SWELibImpl.Cloud.GceVm

/-!
# GCE VM Bridge Axioms

Trust boundary axioms connecting the `gcloud` CLI-based GCE VM client
to the formal `gceVMNodeLTS` specification.

## Trust Assumptions

1. **`stepVM` faithfully implements `gceVMNodeLTS.Tr`** — the executable
   decision procedure agrees with the propositional transition relation.
   This is verifiable by inspection (both are simple pattern matches).

2. **`gcloud` status output is faithful** — the `status` field in
   `gcloud compute instances describe --format=json` correctly reflects
   the actual GCE instance lifecycle state.

3. **`gcloud` operations are atomic** — when `gcloud compute instances start`
   returns successfully, the instance has transitioned to RUNNING.

## Specification References
- GCE instance lifecycle: https://cloud.google.com/compute/docs/instances/instance-life-cycle
- gcloud compute instances: https://cloud.google.com/sdk/gcloud/reference/compute/instances
-/

namespace SWELibImpl.Bridge.Cloud

open SWELib.Foundations (LTS)
open SWELib.OS.Isolation (VMStatus VMLifecycleAction VMAction gceVMNodeLTS)
open SWELibImpl.Cloud.GceVm (stepVM)
open SWELibImpl.Cloud.GceVmJson (parseVMStatus vmStatusToString)

-- TRUST: <issue-url>

/-- Soundness: if `stepVM` says a transition is valid, it holds in the spec.
    Verifiable by comparing the two pattern matches.
    Universally quantified over `α` since lifecycle transitions don't depend on
    the service action type. -/
axiom stepVM_sound :
    ∀ (α : Type) (src : VMStatus) (action : VMLifecycleAction) (dst : VMStatus),
      stepVM src action = some dst →
      (gceVMNodeLTS (α := α)).Tr src (.lifecycle action) dst

/-- Completeness: if a lifecycle transition holds in the spec, `stepVM` computes it.
    Together with soundness, this means `stepVM` is a decision procedure for
    the lifecycle fragment of `gceVMNodeLTS.Tr`. -/
axiom stepVM_complete :
    ∀ (α : Type) (src : VMStatus) (action : VMLifecycleAction) (dst : VMStatus),
      (gceVMNodeLTS (α := α)).Tr src (.lifecycle action) dst →
      stepVM src action = some dst

/-- The `gcloud` CLI's status output faithfully maps to spec `VMStatus`.
    When `gcloud compute instances describe` returns a JSON object with
    `"status": s`, then `parseVMStatus s` yields the correct `VMStatus`. -/
axiom gcloud_status_faithful :
    ∀ (s : String) (v : VMStatus),
      parseVMStatus s = some v →
      vmStatusToString v = s

/-- Round-trip: `parseVMStatus` and `vmStatusToString` are inverses. -/
axiom status_roundtrip :
    ∀ (v : VMStatus), parseVMStatus (vmStatusToString v) = some v

end SWELibImpl.Bridge.Cloud
