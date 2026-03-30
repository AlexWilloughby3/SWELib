/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives.DnsSubdomain

namespace SWELib.Cloud.K8s.Primitives

/-- Validation for label name. -/
def isValidLabelName (s : String) : Bool :=
  s.length > 0 && s.length ≤ 63 &&
  s.all (fun c => c.isAlphanum || c = '-' || c = '_' || c = '.') &&
  (s.front? != none) && s.front?.get!.isAlphanum &&
  (s.back? != none) && s.back?.get!.isAlphanum

/-- The name part of a label key -/
structure LabelName where
  val : String
  h_valid : isValidLabelName val = true
  deriving DecidableEq

/-- A Kubernetes label key with optional DNS subdomain prefix -/
structure LabelKey where
  prefix? : Option DnsSubdomain
  name : LabelName
  deriving DecidableEq

instance : ToString LabelKey where
  toString k := match k.prefix? with
    | none => k.name.val
    | some p => p.val ++ "/" ++ k.name.val

/-- Parse a label key from a string -/
def parseLabelKey (s : String) : Option LabelKey :=
  match s.splitOn "/" with
  | [name] =>
    if h : isValidLabelName name = true then
      some ⟨none, ⟨name, h⟩⟩
    else
      none
  | [prefixStr, name] =>
    if h : isValidLabelName name = true then
      DnsSubdomain.mk? prefixStr |>.map fun p =>
        ⟨some p, ⟨name, h⟩⟩
    else
      none
  | _ => none

end SWELib.Cloud.K8s.Primitives
