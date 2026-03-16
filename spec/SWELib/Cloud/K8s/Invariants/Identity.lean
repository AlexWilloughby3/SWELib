/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/


import SWELib.Cloud.K8s.Metadata
import SWELib.Cloud.K8s.Workloads.Pod
import SWELib.Cloud.K8s.Operations

namespace SWELib.Cloud.K8s.Invariants
/-! Identity invariants for Kubernetes resources (Kubernetes spec 7.1) -/
open SWELib.Cloud.K8s.Metadata
open SWELib.Cloud.K8s.Workloads
open SWELib.Cloud.K8s.Operations
open SWELib.Cloud.K8s.Primitives

-- REQUIRES_HUMAN: INV-1: UIDs are globally unique
axiom inv1_uid_unique :
    ∀ (p1 p2 : Pod),
    p1.metadata.uid.isSome →
    p2.metadata.uid.isSome →
    p1.metadata.uid = p2.metadata.uid →
    p1 = p2

-- REQUIRES_HUMAN: INV-2: Names are unique within namespace
axiom inv2_name_unique_in_namespace :
    ∀ (p1 p2 : Pod),
    p1.metadata.name = p2.metadata.name →
    p1.metadata.namespace = p2.metadata.namespace →
    p1.metadata.uid = p2.metadata.uid

-- REQUIRES_HUMAN: INV-3: UIDs never change for a resource
axiom inv3_uid_immutable :
    ∀ (pod : Pod) (params : UpdateParams) (result : Pod),
    podUpdate pod params = IO.pure (OperationResult.ok result) →
    result.metadata.uid = pod.metadata.uid

-- REQUIRES_HUMAN: INV-4: Names cannot be changed via update
axiom inv4_name_immutable :
    ∀ (pod : Pod) (params : UpdateParams) (result : Pod),
    podUpdate pod params = IO.pure (OperationResult.ok result) →
    result.metadata.name = pod.metadata.name

end SWELib.Cloud.K8s.Invariants
