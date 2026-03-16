/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.K8s.Workloads

/-! # Network Protocols

Network protocols in Kubernetes (Kubernetes spec 4.1)
-/

/-- Supported network protocols -/
inductive Protocol where
  | TCP
  | UDP
  | SCTP
  deriving DecidableEq

instance : ToString Protocol where
  toString
    | .TCP => "TCP"
    | .UDP => "UDP"
    | .SCTP => "SCTP"

/-- Default protocol is TCP -/
def Protocol.default : Protocol := .TCP

end SWELib.Cloud.K8s.Workloads