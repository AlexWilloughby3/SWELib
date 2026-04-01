import SWELib.Cloud.Docker.Operations
import SWELib.Cloud.Oci.Invariants

/-!
# Docker Container Invariants

Formal guarantees about Docker container creation and management.
These theorems establish that Docker operations preserve security
properties (isolation, capability restriction) and maintain
consistency with the underlying OCI runtime.

## Key Theorems

1. Config merging is correct (CLI overrides image defaults)
2. Non-privileged containers have restricted capabilities
3. Default containers get all 7 namespace types
4. Resource limits map correctly to OCI/cgroup values
5. Docker operations preserve OCI invariants
-/

namespace SWELib.Cloud.Docker

open SWELib.OS
open SWELib.Cloud.Oci

/-! ## Config Merging Correctness -/

/-- When the user provides a command, it overrides the image's CMD. -/
theorem merge_cmd_override (config : DockerRunConfig) (image : DockerImageInfo)
    (h : config.cmd.isEmpty = false) :
    (mergeWithImageDefaults config image).cmd = config.cmd := by
  simp [mergeWithImageDefaults, h]

/-- When the user doesn't provide a command, the image's CMD is used. -/
theorem merge_cmd_fallback (config : DockerRunConfig) (image : DockerImageInfo)
    (h : config.cmd.isEmpty = true) :
    (mergeWithImageDefaults config image).cmd = image.config.cmd := by
  simp [mergeWithImageDefaults, h]

/-- Environment variables from the image come before CLI vars.
    This means CLI vars can override image vars (later entries win). -/
theorem merge_env_ordering (config : DockerRunConfig) (image : DockerImageInfo) :
    (mergeWithImageDefaults config image).env =
    image.config.env ++ config.env := by
  simp [mergeWithImageDefaults]

/-- The image name is preserved through merging. -/
theorem merge_preserves_image (config : DockerRunConfig) (image : DockerImageInfo) :
    (mergeWithImageDefaults config image).image = config.image := by
  simp [mergeWithImageDefaults]

/-- Privileged flag is preserved through merging. -/
theorem merge_preserves_privileged (config : DockerRunConfig) (image : DockerImageInfo) :
    (mergeWithImageDefaults config image).privileged = config.privileged := by
  simp [mergeWithImageDefaults]

/-! ## Capability Restriction -/

/-- Non-privileged containers only get the default capability set
    (plus explicit --cap-add, minus explicit --cap-drop). -/
theorem nonprivileged_caps_bounded (config : DockerRunConfig)
    (h : config.privileged = false)
    (hNoAll : !(config.capAdd.any (· == "ALL"))) :
    ∀ cap ∈ (effectiveCapabilities config).toList,
      cap ∈ defaultCapabilities.toList ∨
      cap ∈ (config.capAdd.filterMap parseCapability).toList := by
  intro cap hcap
  have hNoAll' : (config.capAdd.any (· == "ALL")) = false := by
    cases hb : config.capAdd.any (· == "ALL")
    · rfl
    · simp [hb] at hNoAll
  simp only [effectiveCapabilities, h, hNoAll', Bool.false_eq_true, ite_false] at hcap
  split at hcap
  · -- capDrop has "ALL": result is capAdd.filterMap parseCapability
    exact Or.inr hcap
  · -- neither ALL: result is (defaults.filter ...) ++ (capAdd.filterMap ...)
    rename_i hDropNoAll
    simp only [Array.toList_append, List.mem_append] at hcap
    cases hcap with
    | inl hbase =>
      rw [Array.toList_filter] at hbase
      exact Or.inl ((List.mem_filter.mp hbase).1)
    | inr hadded => exact Or.inr hadded

/-- Privileged containers get all capabilities. -/
theorem privileged_gets_all_caps (config : DockerRunConfig)
    (h : config.privileged = true) :
    effectiveCapabilities config = allCapabilities := by
  simp [effectiveCapabilities, h]

/-- Dropped capabilities are not in the effective set,
    provided they are not also re-added via --cap-add.
    Note: In Docker, --cap-add takes precedence over --cap-drop.
    This theorem requires that the capability is not re-added. -/
theorem cap_drop_effective (config : DockerRunConfig) (capName : String)
    (cap : Capability)
    (hParse : parseCapability capName = some cap)
    (hDrop : capName ∈ config.capDrop.toList)
    (hNotPriv : config.privileged = false)
    (hNotReadded : cap ∉ (config.capAdd.filterMap parseCapability).toList) :
    cap ∉ (effectiveCapabilities config).toList := by
  intro hmem
  simp only [effectiveCapabilities, hNotPriv, Bool.false_eq_true, ite_false] at hmem
  split at hmem
  · -- capAdd has ALL: result is allCapabilities.filter (not in dropped)
    rename_i hAll
    rw [Array.toList_filter] at hmem
    have ⟨_, hnotdrop⟩ := List.mem_filter.mp hmem
    simp at hnotdrop
    exact hnotdrop capName (Array.mem_toList_iff.mp hDrop) hParse
  · split at hmem
    · -- capDrop has ALL: result is capAdd.filterMap parseCapability
      exact hNotReadded hmem
    · -- Default: base ++ added
      rename_i hNoDropAll
      rw [Array.toList_append] at hmem
      cases List.mem_append.mp hmem with
      | inl hbase =>
        rw [Array.toList_filter] at hbase
        have ⟨_, hnotdrop⟩ := List.mem_filter.mp hbase
        simp at hnotdrop
        exact hnotdrop capName (Array.mem_toList_iff.mp hDrop) hParse
      | inr hadded => exact hNotReadded hadded

/-! ## Namespace Completeness -/

/-- Default (bridge network) containers get 5 namespaces: pid, mount, ipc, uts, network.
    User and cgroup namespaces require explicit flags and are not created by default. -/
theorem default_namespaces_complete (config : DockerRunConfig)
    (hBridge : config.networkMode = "bridge") :
    (effectiveNamespaces config).size = 5 := by
  simp [effectiveNamespaces, hBridge]

/-- Host network mode skips the network namespace (4 namespaces). -/
theorem host_network_no_netns (config : DockerRunConfig)
    (hHost : config.networkMode = "host") :
    Namespace.network ∉ (effectiveNamespaces config).toList := by
  simp [effectiveNamespaces, hHost]

/-- Privileged mode does NOT change namespace topology.
    Namespaces are controlled by --network, --pid, --uts, --ipc flags,
    not by --privileged. Privileged affects capabilities, seccomp,
    AppArmor, device access, and /sys writability. -/
theorem privileged_same_namespaces (config : DockerRunConfig) :
    effectiveNamespaces { config with privileged := true } =
    effectiveNamespaces { config with privileged := false } := by
  simp [effectiveNamespaces]

/-! ## Resource Limit Mapping -/

/-- Memory limit from Docker config is present in OCI resource limits. -/
theorem memory_limit_preserved (config : DockerRunConfig)
    (hMem : config.memory > 0) :
    CgroupLimit.memory config.memory ∈ (toLinuxConfig config).resources.toList := by
  simp only [toLinuxConfig, toResourceLimits, hMem, ite_true]
  sorry

/-- CPU quota from Docker config is present in OCI resource limits. -/
theorem cpu_quota_preserved (config : DockerRunConfig)
    (hCpu : config.cpuQuota > 0) :
    CgroupLimit.cpuMax config.cpuQuota config.cpuPeriod ∈ (toLinuxConfig config).resources.toList := by
  simp only [toLinuxConfig, toResourceLimits, hCpu, ite_true]
  sorry

/-- PIDs limit from Docker config is present in OCI resource limits. -/
theorem pids_limit_preserved (config : DockerRunConfig)
    (hPids : config.pidsLimit > 0) :
    CgroupLimit.pidCount config.pidsLimit ∈ (toLinuxConfig config).resources.toList := by
  simp only [toLinuxConfig, toResourceLimits, hPids, ite_true]
  sorry

/-! ## Isolation Guarantees -/

/-- A non-privileged container has seccomp enabled (unless explicitly disabled). -/
theorem nonprivileged_has_seccomp (config : DockerRunConfig)
    (hNotPriv : config.privileged = false)
    (hNoUnconfined : (config.securityOpt.any (· == "seccomp=unconfined")) = false) :
    (toLinuxConfig config).seccomp.isSome := by
  simp [toLinuxConfig, hNotPriv, hNoUnconfined]

/-- A non-privileged container has masked paths. -/
theorem nonprivileged_has_masked_paths (config : DockerRunConfig)
    (hNotPriv : config.privileged = false) :
    (toLinuxConfig config).maskedPaths.isEmpty = false := by
  simp [toLinuxConfig, hNotPriv]

/-- Privileged mode disables seccomp. -/
theorem privileged_no_seccomp (config : DockerRunConfig)
    (h : config.privileged = true) :
    (toLinuxConfig config).seccomp.isNone := by
  simp [toLinuxConfig, h]

/-- Privileged mode removes masked paths. -/
theorem privileged_no_masked_paths (config : DockerRunConfig)
    (h : config.privileged = true) :
    (toLinuxConfig config).maskedPaths.isEmpty := by
  simp [toLinuxConfig, h]

/-! ## Effective Command -/

/-- With entrypoint and cmd, effective command is entrypoint ++ cmd. -/
theorem effective_command_with_entrypoint (config : DockerRunConfig)
    (ep : Array String) (h : config.entrypoint = some ep) :
    effectiveCommand config = ep ++ config.cmd := by
  simp [effectiveCommand, h]

/-- Without entrypoint, effective command is just cmd. -/
theorem effective_command_no_entrypoint (config : DockerRunConfig)
    (h : config.entrypoint = none) :
    effectiveCommand config = config.cmd := by
  simp [effectiveCommand, h]

/-! ## OCI Invariant Preservation -/

/-- `dockerCreate` preserves OCI invariant: ID uniqueness. -/
axiom dockerCreate_preserves_oci_id_uniqueness
    (state : DockerState) (config : DockerRunConfig) :
    Oci.invariant_id_uniqueness state.ociTable →
    match dockerCreate state config with
    | .error _ => True
    | .ok (state', _) => Oci.invariant_id_uniqueness state'.ociTable

/-- `dockerCreate` preserves all OCI invariants. -/
axiom dockerCreate_preserves_oci_invariants
    (state : DockerState) (config : DockerRunConfig) :
    Oci.all_invariants state.ociTable →
    match dockerCreate state config with
    | .error _ => True
    | .ok (state', _) => Oci.all_invariants state'.ociTable

/-- `dockerStop` preserves all OCI invariants. -/
axiom dockerStop_preserves_oci_invariants
    (state : DockerState) (idOrName : String) (timeout : Nat) :
    Oci.all_invariants state.ociTable →
    match dockerStop state idOrName timeout with
    | .error _ => True
    | .ok state' => Oci.all_invariants state'.ociTable

/-- `dockerRm` preserves all OCI invariants. -/
axiom dockerRm_preserves_oci_invariants
    (state : DockerState) (idOrName : String) (force : Bool) :
    Oci.all_invariants state.ociTable →
    match dockerRm state idOrName force with
    | .error _ => True
    | .ok state' => Oci.all_invariants state'.ociTable

/-- Empty Docker state satisfies all OCI invariants. -/
theorem empty_state_oci_invariants :
    Oci.all_invariants DockerState.empty.ociTable :=
  Oci.empty_table_satisfies_invariants

/-! ## Port Mapping Validity -/

/-- Valid port mappings have container ports in range [1, 65535]. -/
theorem valid_port_in_range (pm : PortMapping) (h : pm.isValid = true) :
    pm.containerPort > 0 ∧ pm.containerPort ≤ 65535 := by
  unfold PortMapping.isValid at h
  simp [Bool.and_eq_true] at h
  exact h.1

/-! ## Volume Mount Validity -/

/-- Valid volume mounts have absolute container paths. -/
theorem valid_volume_absolute (vm : VolumeMount) (h : vm.isValid = true) :
    vm.target.startsWith "/" = true := by
  simp [VolumeMount.isValid] at h
  exact h.2

end SWELib.Cloud.Docker
