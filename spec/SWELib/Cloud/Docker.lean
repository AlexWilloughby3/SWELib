import SWELib.Cloud.Docker.Types
import SWELib.Cloud.Docker.Errors
import SWELib.Cloud.Docker.State
import SWELib.Cloud.Docker.Cli
import SWELib.Cloud.Docker.Operations
import SWELib.Cloud.Docker.Invariants

/-!
# Docker Container Management

Formal specification of Docker container creation and lifecycle management,
modeled as the Docker CLI interface (`docker create`, `docker run`, etc.).

## Architecture

Docker is an orchestrator that composes:
- **OCI Runtime** — container lifecycle (create/start/stop/delete)
- **OCI Image** — container filesystem (layers, config)
- **Linux Namespaces** — process isolation (pid, net, mnt, ipc, uts, user, cgroup)
- **Cgroups** — resource limits (memory, CPU, PIDs)
- **Capabilities** — privilege restriction
- **Seccomp** — syscall filtering

The `dockerCreate` operation is the central orchestration point:
1. Resolves image from local store
2. Merges CLI flags with image defaults
3. Generates OCI config (mapping Docker concepts to OCI primitives)
4. Delegates to `Oci.create`

## Key Theorems

- Non-privileged containers get restricted capabilities (`nonprivileged_caps_bounded`)
- Default containers get all 7 namespace types (`default_namespaces_complete`)
- Config merging correctly overrides image defaults (`merge_cmd_override`)
- Docker operations preserve OCI invariants (`dockerCreate_preserves_oci_invariants`)
- Privileged mode provably weakens security (`privileged_no_seccomp`, `privileged_minimal_namespaces`)

## Source Specs

- Docker CLI: https://docs.docker.com/reference/cli/docker/
- Docker Engine API: https://docs.docker.com/engine/api/
- OCI Runtime Spec: https://github.com/opencontainers/runtime-spec
- OCI Image Spec: https://github.com/opencontainers/image-spec
-/

namespace SWELib.Cloud

export SWELib.Cloud.Docker (
  Protocol PortMapping VolumeMount DockerStatus RestartPolicy
  DockerRunConfig DockerContainerState DockerImageConfig
  DockerImageInfo DockerContainerInfo
  DockerRunConfig.isValid PortMapping.isValid VolumeMount.isValid
  DockerStatus.toOci
)
export SWELib.Cloud.Docker (
  DockerCliError
)
export SWELib.Cloud.Docker (
  DockerState ImageStore ContainerStore
  DockerState.empty DockerState.findContainer DockerState.findImage DockerState.hasImage
)
export SWELib.Cloud.Docker (
  serializeFlags DockerRunConfig.fromImage DockerRunConfig.fromImageCmd
)
export SWELib.Cloud.Docker (
  mergeWithImageDefaults effectiveCommand effectiveCapabilities effectiveNamespaces
  toLinuxConfig toOciConfig
  dockerPull dockerCreate dockerStart dockerStop dockerRm dockerRun dockerExec dockerInspect
  defaultCapabilities allCapabilities
)

end SWELib.Cloud
