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

/-! # WATCH Operation

WATCH operation for Kubernetes resources (Kubernetes spec 6.7)
-/

open SWELib.Cloud.K8s.Primitives
open SWELib.Cloud.K8s.Selection
open SWELib.Cloud.K8s.Workloads

/-- Event types for watch stream -/
inductive EventType where
  | ADDED
  | MODIFIED
  | DELETED
  | BOOKMARK
  | ERROR
  deriving DecidableEq, Repr

/-- Watch event -/
structure WatchEvent (α : Type) where
  type : EventType
  object : α
  deriving DecidableEq

/-- Parameters for WATCH operation -/
structure WatchParams where
  namespace : Option DnsLabel := none
  resourceVersion : Option ResourceVersion := none
  labelSelector : Option LabelSelector := none
  deriving DecidableEq

/-- WATCH operation for Pods (axiomatized, returns stream as list) -/
axiom podWatch : WatchParams → IO (OperationResult (List (WatchEvent Pod)))

-- ALGEBRAIC: Watch resumes from resourceVersion
axiom watch_resumes_from_version : ∀ (params : WatchParams) (events : List (WatchEvent Pod)),
  podWatch params = IO.pure (OperationResult.ok events) →
  params.resourceVersion.isSome →
  ∀ event ∈ events,
    event.object.metadata.resourceVersion.isSome

end SWELib.Cloud.K8s.Operations
