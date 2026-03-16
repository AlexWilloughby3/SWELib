/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives.DnsSubdomain

namespace SWELib.Cloud.K8s.Primitives

/-- The name part of a label key -/
structure LabelName where
  val : String
  h_valid : val.length > 0 ∧ val.length ≤ 63 ∧
            val.all (fun c => c.isAlphanum || c = '-' || c = '_' || c = '.') ∧
            val.front.isAlphanum ∧ val.back.isAlphanum
  deriving DecidableEq

/-- A Kubernetes label key with optional DNS subdomain prefix -/
structure LabelKey where
  prefix : Option DnsSubdomain
  name : LabelName
  deriving DecidableEq

instance : ToString LabelKey where
  toString k := match k.prefix with
    | none => k.name.val
    | some p => p.val ++ "/" ++ k.name.val

/-- Parse a label key from a string -/
def parseLabelKey (s : String) : Option LabelKey :=
  match s.splitOn "/" with
  | [name] =>
    -- No prefix case
    if h : name.length > 0 ∧ name.length ≤ 63 ∧
           name.all (fun c => c.isAlphanum || c = '-' || c = '_' || c = '.') ∧
           name.front.isAlphanum ∧ name.back.isAlphanum then
      some ⟨none, ⟨name, h⟩⟩
    else
      none
  | [prefix, name] =>
    -- Prefix case
    if h : name.length > 0 ∧ name.length ≤ 63 ∧
           name.all (fun c => c.isAlphanum || c = '-' || c = '_' || c = '.') ∧
           name.front.isAlphanum ∧ name.back.isAlphanum then
      DnsSubdomain.mk? prefix |>.map fun p =>
        ⟨some p, ⟨name, h⟩⟩
    else
      none
  | _ => none

end SWELib.Cloud.K8s.Primitives