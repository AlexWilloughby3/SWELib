/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/


import SWELib.Cloud.K8s.Workloads
import SWELib.Cloud.K8s.Operations

namespace SWELib.Cloud.K8s.Invariants
/-! Pod-specific invariants (Kubernetes spec 7.4) -/
open SWELib.Cloud.K8s.Workloads
open SWELib.Cloud.K8s.Operations

-- REQUIRES_HUMAN: INV-11: Pod phase transitions are monotonic
axiom inv11_pod_phase_transitions :
    ∀ (pod : Pod),
    pod.status.phase = some PodPhase.Succeeded ∨
    pod.status.phase = some PodPhase.Failed →
    -- Terminal states don't change
    ∀ (params : UpdateParams) (result : Pod),
    podUpdate params = pure (OperationResult.ok result) →
    result.status.phase = pod.status.phase

-- REQUIRES_HUMAN: INV-12: Container names are unique
axiom inv12_container_names_unique :
    ∀ (pod : Pod),
    uniqueContainerNames pod.spec.containers = true

-- STRUCTURAL: INV-13: Pod must have at least one container
theorem inv13_pod_has_container (pod : Pod) :
    pod.spec.containers ≠ [] := by
  exact pod.spec.h_containers_nonempty

-- REQUIRES_HUMAN: INV-14: Pod IPs are assigned in Running phase
axiom inv14_pod_ip_in_running :
    ∀ (pod : Pod),
    pod.status.podIP.isSome →
    pod.status.phase = some PodPhase.Running ∨
    pod.status.phase = some PodPhase.Succeeded ∨
    pod.status.phase = some PodPhase.Failed

end SWELib.Cloud.K8s.Invariants
