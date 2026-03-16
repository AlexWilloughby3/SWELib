/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.K8s.Primitives

/-- Validates that a string is a valid DNS label per RFC 1123 -/
def isDnsLabel (s : String) : Bool :=
  s.length > 0 && s.length ≤ 63 &&
  s.all (fun c => c.isAlphanum || c = '-') &&
  s.all (fun c => c.isLower || c.isDigit || c = '-') &&
  s.front.isAlphanum && s.back.isAlphanum

/-- A validated DNS label string -/
structure DnsLabel where
  val : String
  h_valid : isDnsLabel val = true
  deriving DecidableEq

instance : ToString DnsLabel where
  toString d := d.val

/-- Smart constructor for DnsLabel -/
def DnsLabel.mk? (s : String) : Option DnsLabel :=
  if h : isDnsLabel s then
    some ⟨s, h⟩
  else
    none

-- STRUCTURAL
theorem DnsLabel.length_bound (d : DnsLabel) :
    d.val.length > 0 ∧ d.val.length ≤ 63 := by
  sorry

-- STRUCTURAL
theorem DnsLabel.no_uppercase (d : DnsLabel) :
    d.val.all (fun c => !c.isUpper) := by
  sorry

end SWELib.Cloud.K8s.Primitives