/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.K8s.Primitives

/-- Validates that a string is a valid label value -/
def isLabelValue (s : String) : Bool :=
  s.length ≤ 63 &&
  (s.isEmpty ||
   (s.all (fun c => c.isAlphanum || c = '-' || c = '_' || c = '.') &&
    s.front.isAlphanum && s.back.isAlphanum))

/-- A validated Kubernetes label value -/
structure LabelValue where
  val : String
  h_valid : isLabelValue val = true
  deriving DecidableEq, Hashable

instance : ToString LabelValue where
  toString v := v.val

/-- Smart constructor for LabelValue -/
def LabelValue.mk? (s : String) : Option LabelValue :=
  if h : isLabelValue s then
    some ⟨s, h⟩
  else
    none

/-- The empty label value -/
def LabelValue.empty : LabelValue :=
  ⟨"", by rfl⟩

end SWELib.Cloud.K8s.Primitives