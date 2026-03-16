/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives

namespace SWELib.Cloud.K8s.Operations

/-! # Operation Types

Common types for Kubernetes operations (Kubernetes spec 6.1)
-/

open SWELib.Cloud.K8s.Primitives

/-- Metadata for list responses -/
structure ListMeta where
  selfLink : Option String := none  -- Deprecated
  resourceVersion : Option ResourceVersion := none
  continue : Option String := none
  remainingItemCount : Option Nat := none
  deriving DecidableEq

/-- Generic list of objects -/
structure ObjectList (α : Type) where
  typeMeta : String := "List"  -- Simplified
  metadata : ListMeta
  items : List α
  deriving DecidableEq

/-- Operation error -/
structure OperationError where
  kind : String := "Status"
  apiVersion : String := "v1"
  status : String := "Failure"
  message : String
  reason : Option String := none
  details : Option String := none  -- Simplified
  code : Nat
  deriving DecidableEq

/-- Result of an operation -/
inductive OperationResult (α : Type) where
  | ok (value : α)
  | error (err : OperationError)
  deriving DecidableEq

end SWELib.Cloud.K8s.Operations