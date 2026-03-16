/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/


import SWELib.Cloud.K8s.Networking
import SWELib.Cloud.K8s.Selection

namespace SWELib.Cloud.K8s.Invariants
/-! Service-specific invariants (Kubernetes spec 7.5) -/
open SWELib.Cloud.K8s.Networking
open SWELib.Cloud.K8s.Selection

-- REQUIRES_HUMAN: INV-15: ClusterIP is immutable once assigned
axiom inv15_clusterip_immutable :
    ∀ (svc1 svc2 : Service),
    svc1.metadata.uid = svc2.metadata.uid →
    svc1.spec.clusterIP.isSome →
    svc1.spec.clusterIP ≠ some "None" →
    svc2.spec.clusterIP = svc1.spec.clusterIP

-- REQUIRES_HUMAN: INV-16: Service selector matches Pod labels
axiom inv16_service_selector_matches :
    ∀ (svc : Service) (pods : List Pod),
    let selector := svc.spec.selector
    let matchingPods := pods.filter (fun pod =>
      selector.toList.all (fun (k, v) =>
        pod.metadata.labels.find? k = some v))
    -- Service endpoints correspond to matching pods
    True  -- Simplified: would need endpoint tracking

end SWELib.Cloud.K8s.Invariants
