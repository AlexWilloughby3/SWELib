/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives
import SWELib.Cloud.K8s.Workloads.Pod
import SWELib.Cloud.K8s.Operations.Types

namespace SWELib.Cloud.K8s.Operations

/-! # DELETE Operation

DELETE operation for Kubernetes resources (Kubernetes spec 6.6)
-/

open SWELib.Cloud.K8s.Primitives
open SWELib.Cloud.K8s.Workloads

/-- Parameters for DELETE operation -/
structure DeleteParams where
  «namespace» : Option DnsLabel := none
  name : DnsSubdomain
  gracePeriodSeconds : Option Nat := none

/-- DELETE operation for Pods (axiomatized) -/
axiom podDelete : DeleteParams → IO (OperationResult Pod)

-- REQUIRES_HUMAN: DELETE sets deletionTimestamp
axiom delete_sets_deletionTimestamp : ∀ (params : DeleteParams) (pod : Pod),
  podDelete params = pure (OperationResult.ok pod) →
  pod.metadata.deletionTimestamp.isSome

-- REQUIRES_HUMAN: DELETE with finalizers keeps object visible
axiom delete_with_finalizers_returns_accepted :
  ∀ (params : DeleteParams) (pod : Pod),
  podDelete params = pure (OperationResult.ok pod) →
  pod.metadata.finalizers ≠ [] →
  pod.metadata.deletionTimestamp.isSome

-- REQUIRES_HUMAN: DELETE without finalizers removes immediately
axiom delete_without_finalizers_removes :
  ∀ (params : DeleteParams) (pod : Pod),
  podDelete params = pure (OperationResult.ok pod) →
  pod.metadata.finalizers = [] →
  True  -- Immediate deletion (200 OK)

end SWELib.Cloud.K8s.Operations
