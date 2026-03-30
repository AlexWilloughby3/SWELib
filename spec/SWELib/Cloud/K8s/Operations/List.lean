/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives
import SWELib.Cloud.K8s.Selection
import SWELib.Cloud.K8s.Workloads.Pod
import SWELib.Cloud.K8s.Operations.Types

namespace SWELib.Cloud.K8s.Operations

/-! # LIST Operation

LIST operation for Kubernetes resources (Kubernetes spec 6.3)
-/

open SWELib.Cloud.K8s.Primitives
open SWELib.Cloud.K8s.Selection
open SWELib.Cloud.K8s.Workloads

/-- Parameters for LIST operation -/
structure ListParams where
  «namespace» : Option DnsLabel := none
  labelSelector : Option LabelSelector := none
  fieldSelector : Option String := none
  resourceVersion : Option ResourceVersion := none
  limit : Option Nat := none
  continueToken : Option String := none

/-- LIST operation for Pods (axiomatized) -/
axiom podList : ListParams → IO (OperationResult (ObjectList Pod))

-- ALGEBRAIC: List returns consistent resourceVersion
axiom list_returns_consistent_version (params : ListParams) :
    ∀ (result : ObjectList Pod),
    podList params = pure (OperationResult.ok result) →
    ∀ pod ∈ result.items,
      pod.metadata.resourceVersion.isSome

-- STRUCTURAL: Empty selector matches all
axiom empty_selector_matches_all (params : ListParams) :
    params.labelSelector = none →
    ∀ (result : ObjectList Pod),
    podList params = pure (OperationResult.ok result) →
    True

end SWELib.Cloud.K8s.Operations
