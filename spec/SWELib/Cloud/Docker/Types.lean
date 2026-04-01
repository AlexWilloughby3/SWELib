import SWELib.OS.Capabilities
import SWELib.Cloud.Oci.Types

/-!
# Docker Container Types

Data model for the Docker CLI interface. These types model the flags
to `docker create`/`docker run` and the JSON output of `docker inspect`.

## Source Specs
- Docker CLI reference: https://docs.docker.com/reference/cli/docker/container/create/
- Docker Engine API v1.45: https://docs.docker.com/engine/api/v1.45/
-/

namespace SWELib.Cloud.Docker

open SWELib.OS
open SWELib.Cloud.Oci

/-! ## Port and Volume Types -/

/-- Transport protocol for port mappings. -/
inductive Protocol where
  | tcp
  | udp
  | sctp
  deriving DecidableEq, Repr, Inhabited

instance : ToString Protocol where
  toString
    | .tcp => "tcp"
    | .udp => "udp"
    | .sctp => "sctp"

/-- A port mapping (`--publish`).
    Maps a host port to a container port. -/
structure PortMapping where
  /-- Host IP to bind (empty = all interfaces). -/
  hostIp : String := ""
  /-- Host port (0 = auto-assign). -/
  hostPort : Nat := 0
  /-- Container port. -/
  containerPort : Nat
  /-- Protocol (default tcp). -/
  protocol : Protocol := .tcp
  deriving DecidableEq, Repr, Inhabited

instance : ToString PortMapping where
  toString pm :=
    let host := if pm.hostIp.isEmpty then "" else s!"{pm.hostIp}:"
    let hport := if pm.hostPort = 0 then "" else s!"{pm.hostPort}:"
    s!"{host}{hport}{pm.containerPort}/{pm.protocol}"

/-- A volume/bind mount (`--volume`). -/
structure VolumeMount where
  /-- Host path or named volume. -/
  source : String
  /-- Container path. -/
  target : String
  /-- Whether the mount is read-only. -/
  readOnly : Bool := false
  deriving DecidableEq, Repr, Inhabited

instance : ToString VolumeMount where
  toString vm :=
    let ro := if vm.readOnly then ":ro" else ""
    s!"{vm.source}:{vm.target}{ro}"

/-! ## Docker Container Status -/

/-- Docker container status (richer than OCI's 5 states). -/
inductive DockerStatus where
  | created
  | running
  | paused
  | restarting
  | removing
  | exited
  | dead
  deriving DecidableEq, Repr, Inhabited

instance : ToString DockerStatus where
  toString
    | .created => "created"
    | .running => "running"
    | .paused => "paused"
    | .restarting => "restarting"
    | .removing => "removing"
    | .exited => "exited"
    | .dead => "dead"

/-- Map Docker status to OCI status. -/
def DockerStatus.toOci : DockerStatus → ContainerStatus
  | .created => .created
  | .running => .running
  | .paused => .paused
  | .restarting => .running
  | .removing => .stopped
  | .exited => .stopped
  | .dead => .stopped

/-! ## Docker Run Configuration -/

/-- Restart policy for a container (`--restart`). -/
inductive RestartPolicy where
  | no
  | onFailure (maxRetries : Nat := 0)
  | always
  | unlessStopped
  deriving DecidableEq, Repr, Inhabited

/-- Configuration for `docker create` / `docker run`.
    Each field corresponds to a CLI flag. -/
structure DockerRunConfig where
  /-- Image name/tag/digest to run. -/
  image : String
  /-- Command to run (overrides image CMD). -/
  cmd : Array String := #[]
  /-- Container name (`--name`). Empty = auto-generated. -/
  name : String := ""
  /-- Entrypoint override (`--entrypoint`). -/
  entrypoint : Option (Array String) := none
  /-- Environment variables (`--env KEY=VALUE`). -/
  env : Array String := #[]
  /-- Hostname (`--hostname`). -/
  hostname : String := ""
  /-- User (`--user`). -/
  user : String := ""
  /-- Working directory (`--workdir`). -/
  workdir : String := ""
  /-- Port mappings (`--publish`). -/
  publish : Array PortMapping := #[]
  /-- Volume mounts (`--volume`). -/
  volumes : Array VolumeMount := #[]
  /-- Network mode (`--network`): bridge, host, none, or container:<id>. -/
  networkMode : String := "bridge"
  /-- Memory limit in bytes (`--memory`). 0 = unlimited. -/
  memory : Nat := 0
  /-- CPU quota in microseconds (`--cpu-quota`). 0 = unlimited. -/
  cpuQuota : Nat := 0
  /-- CPU period in microseconds (`--cpu-period`). Default 100000. -/
  cpuPeriod : Nat := 100000
  /-- Max number of PIDs (`--pids-limit`). 0 = unlimited. -/
  pidsLimit : Nat := 0
  /-- CPUs to use (`--cpuset-cpus`, e.g. "0-3" or "0,2"). -/
  cpusetCpus : String := ""
  /-- Capabilities to add (`--cap-add`). -/
  capAdd : Array String := #[]
  /-- Capabilities to drop (`--cap-drop`). -/
  capDrop : Array String := #[]
  /-- Security options (`--security-opt`). -/
  securityOpt : Array String := #[]
  /-- Read-only root filesystem (`--read-only`). -/
  readonlyRootfs : Bool := false
  /-- Privileged mode (`--privileged`). -/
  privileged : Bool := false
  /-- Allocate a TTY (`--tty`). -/
  tty : Bool := false
  /-- Keep STDIN open (`--interactive`). -/
  interactive : Bool := false
  /-- Run in background (`--detach`). -/
  detach : Bool := false
  /-- Auto-remove on exit (`--rm`). -/
  autoRemove : Bool := false
  /-- Restart policy (`--restart`). -/
  restart : RestartPolicy := .no
  /-- Extra labels (`--label KEY=VALUE`). -/
  labels : Array String := #[]
  deriving Repr, Inhabited

/-! ## Docker Inspect Output Types -/

/-- Container state from `docker inspect .State`. -/
structure DockerContainerState where
  /-- Container status. -/
  status : DockerStatus
  /-- Whether the container is running. -/
  running : Bool
  /-- Container PID (0 if not running). -/
  pid : Nat
  /-- Exit code (0 if still running). -/
  exitCode : Int
  /-- Start timestamp (ISO 8601). -/
  startedAt : String := ""
  /-- Finish timestamp (ISO 8601). -/
  finishedAt : String := ""
  deriving Repr, Inhabited

/-- Image configuration from `docker image inspect .Config`. -/
structure DockerImageConfig where
  /-- Default command. -/
  cmd : Array String := #[]
  /-- Default entrypoint. -/
  entrypoint : Array String := #[]
  /-- Default environment variables. -/
  env : Array String := #[]
  /-- Default working directory. -/
  workingDir : String := ""
  /-- Default user. -/
  user : String := ""
  /-- Exposed ports (e.g. "80/tcp"). -/
  exposedPorts : Array String := #[]
  /-- Volume mount points. -/
  volumes : Array String := #[]
  deriving Repr, Inhabited

/-- Image info from `docker image inspect`. -/
structure DockerImageInfo where
  /-- Image ID (sha256 digest). -/
  id : String
  /-- Repository tags (e.g. ["nginx:latest"]). -/
  repoTags : Array String := #[]
  /-- Image size in bytes. -/
  size : Nat := 0
  /-- Image configuration. -/
  config : DockerImageConfig := {}
  deriving Repr, Inhabited

/-- Full container info from `docker inspect`. -/
structure DockerContainerInfo where
  /-- Container ID (full sha256). -/
  id : String
  /-- Container name. -/
  name : String
  /-- Container state. -/
  state : DockerContainerState
  /-- Image used. -/
  image : String
  /-- The run configuration this container was created with. -/
  config : DockerRunConfig
  deriving Repr, Inhabited

/-! ## Validation -/

/-- Check if a port mapping is valid. -/
def PortMapping.isValid (pm : PortMapping) : Bool :=
  pm.containerPort > 0 && pm.containerPort ≤ 65535 &&
  pm.hostPort ≤ 65535

/-- Check if a volume mount is valid. -/
def VolumeMount.isValid (vm : VolumeMount) : Bool :=
  !vm.source.isEmpty && !vm.target.isEmpty &&
  vm.target.startsWith "/"

/-- Check if a DockerRunConfig is valid. -/
def DockerRunConfig.isValid (config : DockerRunConfig) : Bool :=
  -- Image must be specified
  !config.image.isEmpty &&
  -- All port mappings must be valid
  config.publish.all PortMapping.isValid &&
  -- All volume mounts must be valid
  config.volumes.all VolumeMount.isValid &&
  -- CPU period must be positive if quota is set
  (config.cpuQuota = 0 || config.cpuPeriod > 0)

end SWELib.Cloud.Docker
