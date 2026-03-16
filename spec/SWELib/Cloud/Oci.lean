import SWELib.Cloud.Oci.Types
import SWELib.Cloud.Oci.Errors
import SWELib.Cloud.Oci.State
import SWELib.Cloud.Oci.Operations
import SWELib.Cloud.Oci.Invariants

/-!
# Open Container Initiative Runtime Specification

Formal specification of the OCI runtime v1.0.

## Overview

The Open Container Initiative (OCI) Runtime Specification defines how to run
a "filesystem bundle" that is unpacked on disk. At a high level, an OCI
implementation would download an OCI Image, then unpack that image into an OCI
Runtime filesystem bundle. At this point, the OCI Runtime Bundle would be run
by an OCI Runtime.

## Core Operations

The specification defines 6 core operations:

1. **state**: query container state
2. **create**: create a container from a bundle
3. **start**: start a created container
4. **kill**: send a signal to a container
5. **delete**: delete a stopped container
6. **exec**: execute a command in a running container

## References

- OCI Runtime Specification v1.0: https://github.com/opencontainers/runtime-spec
-/

namespace SWELib.Cloud

/-- Re-export OCI types. -/
export Oci (
  ContainerStatus, Root, Mount, Seccomp, ProcessConfig, Hooks,
  LinuxConfig, ContainerConfig, ContainerState,
  ContainerStatus.creating, ContainerStatus.created, ContainerStatus.running,
  ContainerStatus.stopped, ContainerStatus.paused,
  ContainerConfig.isValid, ContainerStatus.canTransition, defaultOciVersion
)

/-- Re-export OCI errors. -/
export Oci (
  OciError,
  OciError.containerNotFound, OciError.containerIdNotUnique, OciError.invalidState,
  OciError.invalidConfig, OciError.hookFailed, OciError.systemError,
  OciError.toErrorMessage, OciError.isSystemError, OciError.isConfigError,
  OciError.isStateError, OciError.hookFailedError, OciError.fromErrno
)

/-- Re-export container table operations. -/
export Oci (
  ContainerTable, ContainerTable.empty, ContainerTable.lookup,
  ContainerTable.insert, ContainerTable.remove, ContainerTable.update,
  ContainerTable.contains, ContainerTable.isIdUnique
)

/-- Re-export core operations. -/
export Oci (
  state, create, start, kill, delete, exec,
  containerExists, getContainerStatus, transitionStatus
)

/-- Re-export invariants. -/
export Oci (
  invariant_id_uniqueness, invariant_valid_transitions,
  invariant_bundle_consistency, invariant_pid_consistency,
  invariant_config_validity, invariant_timestamp_ordering,
  invariant_hook_ordering, invariant_resource_isolation,
  all_invariants,
  create_preserves_id_uniqueness, start_preserves_valid_transitions,
  kill_preserves_pid_consistency, delete_preserves_invariants,
  empty_table_satisfies_invariants
)

end SWELib.Cloud
