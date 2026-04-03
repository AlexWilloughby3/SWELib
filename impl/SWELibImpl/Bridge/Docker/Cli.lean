import SWELib
import SWELib.Cloud.Docker

/-!
# Docker CLI Bridge Axioms

Bridge axioms asserting the `docker` binary behaves as specified.
Each axiom corresponds to a guarantee about a Docker CLI command
when it exits successfully (exit code 0).

The trust boundary: we axiomatize that Docker's CLI faithfully
implements the operations modeled in `SWELib.Cloud.Docker.Operations`.
These axioms can be validated by testing against a real Docker daemon.

## Specification References
- Docker CLI: https://docs.docker.com/reference/cli/docker/
- Docker Engine API v1.45: https://docs.docker.com/engine/api/v1.45/
-/

namespace SWELibImpl.Bridge.Docker

open SWELib.Cloud.Docker

-- TRUST: <issue-url>

/-- Axiom: `docker create` with flags from `serializeFlags config` produces
    a container whose state matches the spec's `dockerCreate` output.

    TRUST: The Docker daemon interprets CLI flags as documented.
    The container's `docker inspect` output matches the spec model. -/
axiom docker_create_matches_spec
    (state : DockerState) (config : DockerRunConfig) :
    config.isValid →
    state.hasImage config.image →
    match dockerCreate state config with
    | .error _ => True
    | .ok (state', containerId) =>
      -- Container exists in new state
      (state'.findContainer containerId).isSome ∧
      -- Container is in created status
      match state'.findContainer containerId with
      | some info => info.state.status = .created
      | none => False

/-- Axiom: `docker start <id>` transitions a container from `created` to `running`.

    TRUST: Docker's container start sequence (namespace setup, cgroup creation,
    process exec) completes successfully and the container enters running state. -/
axiom docker_start_transitions_running
    (state : DockerState) (id : String) :
    match state.findContainer id with
    | some info => info.state.status = .created →
      match dockerStart state id with
      | .ok state' =>
        match state'.findContainer id with
        | some info' => info'.state.status = .running ∧ info'.state.running = true
        | none => False
      | .error _ => True
    | none => True

/-- Axiom: `docker stop <id>` transitions a container from `running` to `exited`.

    TRUST: Docker sends SIGTERM, waits for timeout, then SIGKILL if needed.
    The container process terminates and enters exited state. -/
axiom docker_stop_transitions_exited
    (state : DockerState) (id : String) (timeout : Nat) :
    match state.findContainer id with
    | some info => info.state.running →
      match dockerStop state id timeout with
      | .ok state' =>
        match state'.findContainer id with
        | some info' => info'.state.status = .exited ∧ info'.state.running = false
        | none => False
      | .error _ => True
    | none => True

/-- Axiom: `docker inspect --format '{{json .}}'` faithfully reflects
    the container's actual state.

    TRUST: Docker's inspect command reads from the daemon's internal state
    and serializes it accurately to JSON. -/
axiom docker_inspect_faithful
    (state : DockerState) (id : String) :
    match dockerInspect state id with
    | .ok info => info.id = id
    | .error _ => True

/-- Axiom: Non-privileged containers created with default Docker settings
    have namespace isolation (pid, net, mnt, ipc, uts).

    TRUST: Docker's default container creation invokes clone(2) with
    CLONE_NEWPID | CLONE_NEWNET | CLONE_NEWNS | CLONE_NEWIPC |
    CLONE_NEWUTS flags. User and cgroup namespaces require explicit
    `--userns`/`--cgroupns` flags.
    This is the core isolation guarantee. -/
axiom docker_isolation_from_flags
    (config : DockerRunConfig)
    (hNotPriv : config.privileged = false)
    (hBridge : config.networkMode = "bridge") :
    (effectiveNamespaces config).size = 5

/-- Axiom: Docker's capability restriction matches our model.
    Non-privileged containers only get the default capability set.

    TRUST: Docker drops capabilities via prctl(PR_CAPBSET_DROP) for
    each capability not in the effective set. -/
axiom docker_capability_restriction
    (config : DockerRunConfig)
    (hNotPriv : config.privileged = false) :
    ∀ cap ∈ (effectiveCapabilities config).toList,
      cap ∈ defaultCapabilities.toList ∨
      (∃ name, parseCapability name = some cap ∧ name ∈ config.capAdd.toList)

/-- Axiom: `docker pull` retrieves an image with valid OCI manifest and config.

    TRUST: Docker's image pull verifies the image manifest digest against
    the registry's content-addressable storage. -/
axiom docker_pull_fetches_valid_image
    (state : DockerState) (imageRef : String) (imageInfo : DockerImageInfo) :
    match dockerPull state imageRef imageInfo with
    | .ok state' => state'.hasImage imageRef
    | .error _ => True

/-- Axiom: `docker build` with valid config produces an image that
    is available in the local image store under all specified tags.

    TRUST: Docker's build engine (BuildKit / legacy builder) executes
    the Dockerfile and stores the result in the image store. -/
axiom docker_build_produces_image
    (state : DockerState) (config : DockerBuildConfig)
    (imageConfig : DockerImageConfig) :
    config.isValid →
    match dockerBuild state config imageConfig with
    | .ok (state', output) =>
      -- The image is available by ID
      state'.hasImage output.imageId ∧
      -- The image is available by all tags
      ∀ tag ∈ config.tags.toList, state'.hasImage tag
    | .error _ => True

/-- Axiom: `docker tag` creates an alias that resolves to the same image.

    TRUST: Docker's tag command creates a reference in the local image
    store pointing to the same image layers. -/
axiom docker_tag_creates_alias
    (state : DockerState) (source target : String) :
    state.hasImage source →
    match dockerTag state source target with
    | .ok state' => state'.hasImage target
    | .error _ => True

/-- Axiom: `docker network create` produces a network that is inspectable.

    TRUST: Docker's network subsystem (libnetwork) creates the network
    and bridge/overlay infrastructure. -/
axiom docker_network_create_exists
    (state : DockerState) (config : NetworkCreateConfig) :
    config.isValid →
    !state.networks.contains config.name →
    match dockerNetworkCreate state config with
    | .ok (state', _netId) =>
      (state'.findNetwork config.name).isSome
    | .error _ => True

/-- Axiom: `docker volume create` produces a volume that is inspectable.

    TRUST: Docker's volume driver creates the volume directory on the host. -/
axiom docker_volume_create_exists
    (state : DockerState) (config : VolumeCreateConfig) :
    !config.name.isEmpty →
    !state.volumes.contains config.name →
    match dockerVolumeCreate state config with
    | .ok (state', _name) =>
      (state'.findVolume config.name).isSome
    | .error _ => True

end SWELibImpl.Bridge.Docker
