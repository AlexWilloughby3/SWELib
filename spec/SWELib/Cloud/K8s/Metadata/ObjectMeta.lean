/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives
import SWELib.Cloud.K8s.Metadata.OwnerReference
import SWELib.Basics.Uuid
import Std.Data.HashMap

namespace SWELib.Cloud.K8s.Metadata

open SWELib.Cloud.K8s.Primitives
open SWELib.Basics

/-- Metadata common to all Kubernetes resources -/
structure ObjectMeta where
  -- User-managed fields
  name : DnsSubdomain
  namespace : Option DnsLabel := none
  labels : Std.HashMap LabelKey LabelValue := Std.HashMap.empty
  annotations : Std.HashMap String String := Std.HashMap.empty

  -- System-managed fields (read-only)
  uid : Option Uuid := none
  resourceVersion : Option ResourceVersion := none
  generation : Option Nat := none
  creationTimestamp : Option RFC3339Time := none
  deletionTimestamp : Option RFC3339Time := none
  deletionGracePeriodSeconds : Option Nat := none
  ownerReferences : List OwnerReference := []
  finalizers : List String := []
  managedFields : List String := []  -- Simplified representation
  selfLink : Option String := none   -- Deprecated but still present
  deriving DecidableEq

/-- Check if a resource is being deleted -/
def ObjectMeta.isBeingDeleted (m : ObjectMeta) : Bool :=
  m.deletionTimestamp.isSome

/-- Get the effective namespace (default if not specified) -/
def ObjectMeta.effectiveNamespace (m : ObjectMeta) : String :=
  match m.namespace with
  | none => "default"
  | some ns => ns.val

/-- Create minimal metadata with just a name -/
def ObjectMeta.withName (name : DnsSubdomain) : ObjectMeta :=
  { name := name }

/-- Add a label to metadata -/
def ObjectMeta.addLabel (m : ObjectMeta) (key : LabelKey) (value : LabelValue) : ObjectMeta :=
  { m with labels := m.labels.insert key value }

/-- Add an annotation to metadata -/
def ObjectMeta.addAnnotation (m : ObjectMeta) (key : String) (value : String) : ObjectMeta :=
  { m with annotations := m.annotations.insert key value }

end SWELib.Cloud.K8s.Metadata