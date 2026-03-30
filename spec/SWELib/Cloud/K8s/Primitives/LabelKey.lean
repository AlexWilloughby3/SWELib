/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives.DnsSubdomain

namespace SWELib.Cloud.K8s.Primitives

/-- Validation for label name -/
def isValidLabelName (s : String) : Bool :=
  s.length > 0 && s.length ≤ 63 &&
  s.all (fun c => c.isAlphanum || c = '-' || c = '_' || c = '.') &&
  (s.front? != none) && s.front?.get!.isAlphanum &&
  (s.back? != none) && s.back?.get!.isAlphanum

/-- The name part of a label key -/
structure LabelName where
  val : String
  h_valid : isValidLabelName val = true
  deriving DecidableEq, BEq, Hashable

/-- A Kubernetes label key (simplified: just the name part for now) -/
structure LabelKey where
  name : LabelName
  deriving DecidableEq, BEq, Hashable

instance : ToString LabelKey where
  toString k := k.name.val

/-- Safe constructor for LabelName -/
def LabelName.mk? (s : String) : Option LabelName :=
  if h : isValidLabelName s = true then
    some ⟨s, h⟩
  else
    none

/-- Safe constructor for LabelKey -/
def LabelKey.mk? (s : String) : Option LabelKey :=
  LabelName.mk? s |>.map fun ln => ⟨ln⟩

end SWELib.Cloud.K8s.Primitives
