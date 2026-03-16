/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives
import SWELib.Cloud.K8s.Workloads.Pod
import SWELib.Cloud.K8s.Operations.Types

namespace SWELib.Cloud.K8s.Operations

/-! # GET Operation

GET operation for Kubernetes resources (Kubernetes spec 6.2)
-/

open SWELib.Cloud.K8s.Primitives
open SWELib.Cloud.K8s.Workloads

/-- Parameters for GET operation -/
structure GetParams where
  name : DnsSubdomain
  namespace : Option DnsLabel := none
  resourceVersion : Option ResourceVersion := none
  deriving DecidableEq

/-- GET operation for Pods (axiomatized) -/
axiom podGet : GetParams → IO (OperationResult Pod)

-- REQUIRES_HUMAN: Define postconditions for GET
theorem get_returns_current_state (params : GetParams) :
    ∃ (pod : Pod), podGet params = IO.pure (OperationResult.ok pod) →
    pod.metadata.name = params.name := by
  sorry

-- REQUIRES_HUMAN: GET is idempotent
theorem get_idempotent (params : GetParams) :
    ∀ (r1 r2 : OperationResult Pod),
    podGet params = IO.pure r1 →
    podGet params = IO.pure r2 →
    r1 = r2 := by
  sorry

end SWELib.Cloud.K8s.Operations