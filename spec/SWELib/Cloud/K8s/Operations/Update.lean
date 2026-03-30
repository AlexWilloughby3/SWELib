/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives
import SWELib.Cloud.K8s.Workloads.Pod
import SWELib.Cloud.K8s.Operations.Types

namespace SWELib.Cloud.K8s.Operations

/-! # UPDATE Operation

UPDATE operation for Kubernetes resources (Kubernetes spec 6.5)
-/

open SWELib.Cloud.K8s.Primitives
open SWELib.Cloud.K8s.Workloads

/-- Parameters for UPDATE operation -/
structure UpdateParams where
  «namespace» : Option DnsLabel := none
  name : DnsSubdomain
  pod : Pod

/-- UPDATE operation for Pods (axiomatized) -/
axiom podUpdate : UpdateParams → IO (OperationResult Pod)

-- ALGEBRAIC: UPDATE increments resourceVersion
axiom update_increments_resourceVersion : ∀ (params : UpdateParams) (updated : Pod),
  podUpdate params = pure (OperationResult.ok updated) →
  ∃ current updatedVersion : ResourceVersion,
    params.pod.metadata.resourceVersion = some current →
    updated.metadata.resourceVersion = some updatedVersion ∧
    updatedVersion > current

-- ALGEBRAIC: UPDATE increments generation on spec change
axiom update_increments_generation_on_spec_change :
  ∀ (params : UpdateParams) (updated : Pod),
  podUpdate params = pure (OperationResult.ok updated) →
  params.pod.spec ≠ updated.spec →
  ∃ g : Nat,
    params.pod.metadata.generation = some g ∧
    updated.metadata.generation = some (g + 1)

-- ALGEBRAIC: UPDATE preserves generation on status-only change
axiom update_preserves_generation_on_status_only :
  ∀ (params : UpdateParams) (updated : Pod),
  podUpdate params = pure (OperationResult.ok updated) →
  params.pod.spec = updated.spec →
  updated.metadata.generation = params.pod.metadata.generation

-- REQUIRES_HUMAN: Optimistic concurrency control
axiom update_conflict_on_version_mismatch :
  ∀ (params : UpdateParams) (current : Pod),
  current.metadata.resourceVersion ≠ params.pod.metadata.resourceVersion →
  ∃ err, podUpdate params = pure (OperationResult.error err)

end SWELib.Cloud.K8s.Operations
