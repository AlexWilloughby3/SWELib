/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/


import SWELib.Cloud.K8s.Primitives
import SWELib.Cloud.K8s.Workloads.Pod
import SWELib.Cloud.K8s.Operations

namespace SWELib.Cloud.K8s.Invariants
/-! Concurrency invariants for Kubernetes resources (Kubernetes spec 7.2) -/
open SWELib.Cloud.K8s.Primitives
open SWELib.Cloud.K8s.Workloads
open SWELib.Cloud.K8s.Operations

-- REQUIRES_HUMAN: INV-5: ResourceVersions are monotonic
axiom inv5_version_monotonic :
    ∀ (pod : Pod) (params : UpdateParams) (result : Pod),
    pod.metadata.resourceVersion.isSome →
    podUpdate pod params = IO.pure (OperationResult.ok result) →
    result.metadata.resourceVersion > pod.metadata.resourceVersion

-- REQUIRES_HUMAN: INV-6: Conflicting updates fail with 409
axiom inv6_conflict_detection :
    ∀ (pod : Pod) (params : UpdateParams),
    pod.metadata.resourceVersion.isSome →
    -- If server version has changed
    (∃ serverPod : Pod,
     serverPod.metadata.uid = pod.metadata.uid ∧
     serverPod.metadata.resourceVersion ≠ pod.metadata.resourceVersion) →
    -- Then update fails with conflict
    ∃ (err : OperationError),
    podUpdate pod params = IO.pure (OperationResult.error err) ∧
    err.code = 409

-- ALGEBRAIC: INV-7: Generation increments on spec changes
theorem inv7_generation_increment :
    ∀ (pod : Pod) (params : UpdateParams) (result : Pod),
    podUpdate pod params = IO.pure (OperationResult.ok result) →
    result.spec ≠ pod.spec →
    result.metadata.generation > pod.metadata.generation := by
  sorry

end SWELib.Cloud.K8s.Invariants
