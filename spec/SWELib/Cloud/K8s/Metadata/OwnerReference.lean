/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives
import SWELib.Basics.Uuid

namespace SWELib.Cloud.K8s.Metadata

open SWELib.Cloud.K8s.Primitives
open SWELib.Basics

/-- Owner reference for establishing ownership relationships -/
structure OwnerReference where
  apiVersion : ApiVersion
  kind : String
  name : String
  uid : Uuid
  controller : Option Bool := none
  blockOwnerDeletion : Option Bool := none
  deriving DecidableEq

/-- Check that at most one owner is marked as controller -/
def atMostOneController (refs : List OwnerReference) : Bool :=
  refs.filter (fun r => r.controller = some true) |>.length ≤ 1

-- STRUCTURAL
theorem atMostOneController_empty :
    atMostOneController [] = true := by
  sorry

-- STRUCTURAL
theorem atMostOneController_singleton (r : OwnerReference) :
    atMostOneController [r] = true := by
  sorry

end SWELib.Cloud.K8s.Metadata