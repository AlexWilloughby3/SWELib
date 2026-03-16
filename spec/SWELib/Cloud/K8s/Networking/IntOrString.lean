/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.K8s.Networking

/-! # IntOrString

Integer or string type for port references (Kubernetes spec 5.1)
-/

/-- A value that can be either an integer or a string -/
inductive IntOrString where
  | int (value : Nat)
  | string (value : String)
  deriving DecidableEq

instance : ToString IntOrString where
  toString
    | .int n => toString n
    | .string s => s

/-- Convert to optional integer -/
def IntOrString.toInt? : IntOrString → Option Nat
  | .int n => some n
  | .string _ => none

/-- Convert to optional string -/
def IntOrString.toString? : IntOrString → Option String
  | .int _ => none
  | .string s => some s

end SWELib.Cloud.K8s.Networking