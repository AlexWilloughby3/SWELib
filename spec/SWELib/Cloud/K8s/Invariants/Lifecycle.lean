/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/


import SWELib.Cloud.K8s.Metadata
import SWELib.Cloud.K8s.Workloads.Pod
import SWELib.Cloud.K8s.Operations

namespace SWELib.Cloud.K8s.Invariants
/-! Lifecycle invariants for Kubernetes resources (Kubernetes spec 7.3) -/
open SWELib.Cloud.K8s.Metadata
open SWELib.Cloud.K8s.Workloads
open SWELib.Cloud.K8s.Operations
open SWELib.Cloud.K8s.Primitives

-- REQUIRES_HUMAN: INV-8: Deletion timestamp is monotonic
axiom inv8_deletion_timestamp_monotonic :
    ∀ (pod : Pod),
    pod.metadata.deletionTimestamp.isNone →
    ∀ (params : DeleteParams) (result : Pod),
    podDelete params = pure (OperationResult.ok result) →
    result.metadata.deletionTimestamp.isSome

-- REQUIRES_HUMAN: INV-9: Deletion timestamp cannot be unset
axiom inv9_deletion_timestamp_final :
    ∀ (pod : Pod),
    pod.metadata.deletionTimestamp.isSome →
    ∀ (params : UpdateParams) (result : Pod),
    podUpdate params = pure (OperationResult.ok result) →
    result.metadata.deletionTimestamp = pod.metadata.deletionTimestamp

-- REQUIRES_HUMAN: INV-10: Finalizers block deletion
axiom inv10_finalizers_block_deletion :
    ∀ (pod : Pod),
    pod.metadata.finalizers ≠ [] →
    pod.metadata.deletionTimestamp.isSome →
    -- Resource exists until finalizers are cleared
    ∀ (params : GetParams),
    params.name = pod.metadata.name →
    ∃ (result : Pod),
    podGet params = pure (OperationResult.ok result)

end SWELib.Cloud.K8s.Invariants
