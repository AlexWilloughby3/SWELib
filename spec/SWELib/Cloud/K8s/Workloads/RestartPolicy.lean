/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.K8s.Workloads

/-! # Restart Policies

Restart policies for pods (Kubernetes spec 4.3)
-/

/-- Pod restart policy -/
inductive RestartPolicy where
  | Always     -- Always restart containers
  | OnFailure  -- Restart only on failure
  | Never      -- Never restart
  deriving DecidableEq

instance : ToString RestartPolicy where
  toString
    | .Always => "Always"
    | .OnFailure => "OnFailure"
    | .Never => "Never"

/-- Default restart policy -/
def RestartPolicy.default : RestartPolicy := .Always

end SWELib.Cloud.K8s.Workloads