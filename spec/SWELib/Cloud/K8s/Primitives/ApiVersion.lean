/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.K8s.Primitives

/-- An API version with optional group and required version -/
structure ApiVersion where
  group : Option String
  version : String
  deriving DecidableEq

instance : ToString ApiVersion where
  toString v := match v.group with
    | none => v.version
    | some g => g ++ "/" ++ v.version

/-- Parse an API version string -/
def parseApiVersion (s : String) : Option ApiVersion :=
  match s.splitOn "/" with
  | [version] => some ⟨none, version⟩
  | [group, version] => some ⟨some group, version⟩
  | _ => none

/-- Core API v1 -/
def apiVersionV1 : ApiVersion :=
  ⟨none, "v1"⟩

/-- Apps API v1 -/
def apiVersionAppsV1 : ApiVersion :=
  ⟨some "apps", "v1"⟩

/-- Batch API v1 -/
def apiVersionBatchV1 : ApiVersion :=
  ⟨some "batch", "v1"⟩

/-- Networking API v1 -/
def apiVersionNetworkingV1 : ApiVersion :=
  ⟨some "networking.k8s.io", "v1"⟩

end SWELib.Cloud.K8s.Primitives