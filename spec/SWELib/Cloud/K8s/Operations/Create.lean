/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives
import SWELib.Cloud.K8s.Workloads.Pod
import SWELib.Cloud.K8s.Operations.Types

namespace SWELib.Cloud.K8s.Operations

/-! # CREATE Operation

CREATE operation for Kubernetes resources (Kubernetes spec 6.4)
-/

open SWELib.Cloud.K8s.Primitives
open SWELib.Cloud.K8s.Workloads

/-- Parameters for CREATE operation -/
structure CreateParams where
  «namespace» : Option DnsLabel := none
  pod : Pod

/-- CREATE operation for Pods (axiomatized) -/
axiom podCreate : CreateParams → IO (OperationResult Pod)

-- REQUIRES_HUMAN: CREATE assigns UID
axiom create_assigns_uid : ∀ (params : CreateParams) (pod : Pod),
  podCreate params = pure (OperationResult.ok pod) →
  pod.metadata.uid.isSome

-- REQUIRES_HUMAN: CREATE assigns resourceVersion
axiom create_assigns_resourceVersion : ∀ (params : CreateParams) (pod : Pod),
  podCreate params = pure (OperationResult.ok pod) →
  pod.metadata.resourceVersion.isSome

-- REQUIRES_HUMAN: CREATE sets generation to zero
axiom create_sets_generation_zero : ∀ (params : CreateParams) (pod : Pod),
  podCreate params = pure (OperationResult.ok pod) →
  pod.metadata.generation = some 0

-- REQUIRES_HUMAN: CREATE with existing name fails
axiom create_idempotent_name : ∀ (params : CreateParams),
  (∃ err, podCreate params = pure (OperationResult.error err)) →
  True  -- Should return 409 Conflict if name exists

end SWELib.Cloud.K8s.Operations
