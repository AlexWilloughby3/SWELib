/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Invariants.Identity
import SWELib.Cloud.K8s.Invariants.Concurrency
import SWELib.Cloud.K8s.Invariants.Lifecycle
import SWELib.Cloud.K8s.Invariants.Pod
import SWELib.Cloud.K8s.Invariants.Service

namespace SWELib.Cloud.K8s

-- Re-export all invariants
export SWELib.Cloud.K8s.Invariants (
  -- Identity invariants
  inv1_uid_unique
  inv2_name_unique_in_namespace
  inv3_uid_immutable
  inv4_name_immutable
  -- Concurrency invariants
  inv5_version_monotonic
  inv6_conflict_detection
  inv7_generation_increment
  -- Lifecycle invariants
  inv8_deletion_timestamp_monotonic
  inv9_deletion_timestamp_final
  inv10_finalizers_block_deletion
  -- Pod invariants
  inv11_pod_phase_transitions
  inv12_container_names_unique
  inv13_pod_has_container
  inv14_pod_ip_in_running
  -- Service invariants
  inv15_clusterip_immutable
  inv16_service_selector_matches
)

end SWELib.Cloud.K8s
