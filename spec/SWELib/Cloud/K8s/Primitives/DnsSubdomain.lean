/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.K8s.Primitives

/-- Validates that a string is a valid DNS subdomain per RFC 1123 -/
def isDnsSubdomain (s : String) : Bool :=
  s.length > 0 && s.length ≤ 253 &&
  s.all (fun c => c.isAlphanum || c = '.' || c = '-') &&
  s.front.isAlphanum && s.back.isAlphanum &&
  !s.contains ".." && !s.contains ".-" && !s.contains "-."

/-- A validated DNS subdomain string -/
structure DnsSubdomain where
  val : String
  h_valid : isDnsSubdomain val = true
  deriving DecidableEq

instance : ToString DnsSubdomain where
  toString d := d.val

/-- Smart constructor for DnsSubdomain -/
def DnsSubdomain.mk? (s : String) : Option DnsSubdomain :=
  if h : isDnsSubdomain s then
    some ⟨s, h⟩
  else
    none

-- STRUCTURAL
theorem DnsSubdomain.length_bound (d : DnsSubdomain) :
    d.val.length > 0 ∧ d.val.length ≤ 253 := by
  have h := d.h_valid
  simp [isDnsSubdomain, Bool.and_eq_true, decide_eq_true_eq] at h
  exact h.1.1.1.1.1.1

-- STRUCTURAL
theorem DnsSubdomain.alphanumeric_edges (d : DnsSubdomain) :
    d.val.front.isAlphanum ∧ d.val.back.isAlphanum := by
  have h := d.h_valid
  simp [isDnsSubdomain, Bool.and_eq_true, decide_eq_true_eq] at h
  exact ⟨by simpa using h.1.1.1.1.2, by simpa using h.1.1.1.2⟩

end SWELib.Cloud.K8s.Primitives
