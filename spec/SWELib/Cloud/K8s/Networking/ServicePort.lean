/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Workloads.Protocol
import SWELib.Cloud.K8s.Networking.IntOrString

namespace SWELib.Cloud.K8s.Networking

open SWELib.Cloud.K8s.Workloads

/-- Service port specification with validated range -/
structure ServicePort where
  name : Option String := none
  protocol : Protocol := Protocol.default
  port : Nat
  h_port_range : 1 ≤ port ∧ port ≤ 65535
  targetPort : IntOrString := IntOrString.int port
  nodePort : Option Nat := none  -- Only for NodePort/LoadBalancer services
  deriving DecidableEq

/-- Create a service port with just a port number -/
def ServicePort.simple (port : Nat) (h : 1 ≤ port ∧ port ≤ 65535) : ServicePort :=
  ⟨none, Protocol.default, port, h, IntOrString.int port, none⟩

/-- Create a service port with name -/
def ServicePort.withName (name : String) (port : Nat) (h : 1 ≤ port ∧ port ≤ 65535) : ServicePort :=
  ⟨some name, Protocol.default, port, h, IntOrString.int port, none⟩

end SWELib.Cloud.K8s.Networking