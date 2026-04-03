import SWELib
import SWELib.Cloud.Docker
import SWELibImpl.Bridge
import SWELibImpl.Ffi.Docker

/-!
# Docker Client

Executable Docker CLI client. Shells out to the `docker` binary,
following the same pattern as `OciRuntime.lean` for `runc`/`crun`.

Each function builds the appropriate CLI arguments from
`SWELib.Cloud.Docker` types and invokes `dockerExec`.
-/

namespace SWELibImpl.Cloud

open SWELib.Cloud.Docker
open SWELibImpl.Ffi.Docker

/-- Configuration for Docker CLI invocation. -/
structure DockerConfig where
  /-- Path to docker binary. -/
  dockerBin : String := "docker"
  /-- Docker host (empty = default socket, or "tcp://..." for remote). -/
  host : String := ""
  /-- Log level. -/
  logLevel : String := "info"
  deriving Repr

/-- Build the base args (before the subcommand) including --host if set. -/
private def baseArgs (cfg : DockerConfig) : Array String :=
  if cfg.host.isEmpty then #[]
  else #["--host", cfg.host]

/-- `docker pull <imageRef>` -/
def dockerPull (cfg : DockerConfig) (imageRef : String) : IO (Except String Unit) := do
  match ← dockerExec cfg.dockerBin (baseArgs cfg ++ #["pull", imageRef]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-- `docker create [flags] <image> [cmd]` — Returns container ID (trimmed). -/
def dockerCreate (cfg : DockerConfig) (config : DockerRunConfig) :
    IO (Except String String) := do
  let flags := serializeFlags config
  match ← dockerExec cfg.dockerBin (baseArgs cfg ++ #["create"] ++ flags) with
  | .ok stdout => pure (.ok stdout.trimAscii.toString)
  | .error e => pure (.error e)

/-- `docker start <id>` -/
def dockerStart (cfg : DockerConfig) (id : String) : IO (Except String Unit) := do
  match ← dockerExec cfg.dockerBin (baseArgs cfg ++ #["start", id]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-- `docker stop <id> [-t timeout]` -/
def dockerStop (cfg : DockerConfig) (id : String) (timeout : Nat := 10) :
    IO (Except String Unit) := do
  match ← dockerExec cfg.dockerBin
      (baseArgs cfg ++ #["stop", "-t", toString timeout, id]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-- `docker rm <id> [-f]` -/
def dockerRm (cfg : DockerConfig) (id : String) (force : Bool := false) :
    IO (Except String Unit) := do
  let forceFlag := if force then #["--force"] else #[]
  match ← dockerExec cfg.dockerBin
      (baseArgs cfg ++ #["rm"] ++ forceFlag ++ #[id]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-- `docker run [flags] <image> [cmd]` — Create + start. Returns container ID. -/
def dockerRun (cfg : DockerConfig) (config : DockerRunConfig) :
    IO (Except String String) := do
  let flags := serializeFlags config
  match ← dockerExec cfg.dockerBin (baseArgs cfg ++ #["run"] ++ flags) with
  | .ok stdout => pure (.ok stdout.trimAscii.toString)
  | .error e => pure (.error e)

/-- `docker inspect <id>` — Returns JSON string. -/
def dockerInspect (cfg : DockerConfig) (id : String) :
    IO (Except String String) :=
  dockerExec cfg.dockerBin
    (baseArgs cfg ++ #["inspect", "--format", "{{json .}}", id])

/-- `docker exec <id> <cmd...>` — Execute command in running container. -/
def dockerExec' (cfg : DockerConfig) (id : String) (cmd : Array String) :
    IO (Except String String) :=
  dockerExec cfg.dockerBin
    (baseArgs cfg ++ #["exec", id] ++ cmd)

/-- `docker logs <id>` — Get container logs. -/
def dockerLogs (cfg : DockerConfig) (id : String) :
    IO (Except String String) :=
  dockerExec cfg.dockerBin (baseArgs cfg ++ #["logs", id])

/-- `docker ps [-a]` — List containers (JSON format). -/
def dockerPs (cfg : DockerConfig) (all : Bool := false) :
    IO (Except String String) :=
  let allFlag := if all then #["--all"] else #[]
  dockerExec cfg.dockerBin
    (baseArgs cfg ++ #["ps", "--format", "{{json .}}"] ++ allFlag)

/-- `docker images` — List local images (JSON format). -/
def dockerImages (cfg : DockerConfig) :
    IO (Except String String) :=
  dockerExec cfg.dockerBin
    (baseArgs cfg ++ #["images", "--format", "{{json .}}"])

/-- `docker kill <id> [-s signal]` — Send signal to container. -/
def dockerKill (cfg : DockerConfig) (id : String) (signal : String := "SIGTERM") :
    IO (Except String Unit) := do
  match ← dockerExec cfg.dockerBin
      (baseArgs cfg ++ #["kill", "-s", signal, id]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-- High-level: pull image (if needed), create, and start a container. -/
def dockerRunWithPull (cfg : DockerConfig) (config : DockerRunConfig) :
    IO (Except String String) := do
  -- Pull image first (ignore error if already present)
  let _ ← dockerPull cfg config.image
  -- Create and start
  match ← dockerCreate cfg config with
  | .error e => pure (.error e)
  | .ok containerId =>
    match ← dockerStart cfg containerId with
    | .error e =>
      -- Best-effort cleanup
      let _ ← dockerRm cfg containerId true
      pure (.error e)
    | .ok _ => pure (.ok containerId)

/-! ## Build -/

/-- `docker build [flags] <context>` — Build an image from a Dockerfile.
    Returns the build output (image ID on the last line of stdout). -/
def dockerBuild (cfg : DockerConfig) (buildCfg : DockerBuildConfig) :
    IO (Except String String) :=
  dockerExec cfg.dockerBin
    (baseArgs cfg ++ #["build"] ++ serializeBuildFlags buildCfg)

/-! ## Image Management -/

/-- `docker tag <source> <target>` — Create a tag for an image. -/
def dockerTag (cfg : DockerConfig) (source target : String) :
    IO (Except String Unit) := do
  match ← dockerExec cfg.dockerBin (baseArgs cfg ++ #["tag", source, target]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-- `docker push <imageRef>` — Push an image to a registry. -/
def dockerPush (cfg : DockerConfig) (imageRef : String) :
    IO (Except String Unit) := do
  match ← dockerExec cfg.dockerBin (baseArgs cfg ++ #["push", imageRef]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-- `docker rmi <imageRef> [-f]` — Remove an image. -/
def dockerRmi (cfg : DockerConfig) (imageRef : String) (force : Bool := false) :
    IO (Except String Unit) := do
  let forceFlag := if force then #["--force"] else #[]
  match ← dockerExec cfg.dockerBin
      (baseArgs cfg ++ #["rmi"] ++ forceFlag ++ #[imageRef]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-- `docker image inspect <imageRef>` — Get image info (JSON). -/
def dockerImageInspect (cfg : DockerConfig) (imageRef : String) :
    IO (Except String String) :=
  dockerExec cfg.dockerBin
    (baseArgs cfg ++ #["image", "inspect", imageRef])

/-! ## Network Management -/

/-- `docker network create [opts] <name>` — Create a network. Returns network ID. -/
def dockerNetworkCreate (cfg : DockerConfig) (netCfg : NetworkCreateConfig) :
    IO (Except String String) := do
  match ← dockerExec cfg.dockerBin
      (baseArgs cfg ++ #["network", "create"] ++ serializeNetworkCreateFlags netCfg) with
  | .ok stdout => pure (.ok stdout.trimAscii.toString)
  | .error e => pure (.error e)

/-- `docker network rm <name>` — Remove a network. -/
def dockerNetworkRm (cfg : DockerConfig) (nameOrId : String) :
    IO (Except String Unit) := do
  match ← dockerExec cfg.dockerBin
      (baseArgs cfg ++ #["network", "rm", nameOrId]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-- `docker network ls` — List networks (JSON format). -/
def dockerNetworkLs (cfg : DockerConfig) :
    IO (Except String String) :=
  dockerExec cfg.dockerBin
    (baseArgs cfg ++ #["network", "ls", "--format", "{{json .}}"])

/-- `docker network inspect <name>` — Get network info (JSON). -/
def dockerNetworkInspect (cfg : DockerConfig) (nameOrId : String) :
    IO (Except String String) :=
  dockerExec cfg.dockerBin
    (baseArgs cfg ++ #["network", "inspect", nameOrId])

/-- `docker network connect <network> <container>` — Connect container to network. -/
def dockerNetworkConnect (cfg : DockerConfig) (network container : String) :
    IO (Except String Unit) := do
  match ← dockerExec cfg.dockerBin
      (baseArgs cfg ++ #["network", "connect", network, container]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-- `docker network disconnect <network> <container>` — Disconnect container from network. -/
def dockerNetworkDisconnect (cfg : DockerConfig) (network container : String) :
    IO (Except String Unit) := do
  match ← dockerExec cfg.dockerBin
      (baseArgs cfg ++ #["network", "disconnect", network, container]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-! ## Volume Management -/

/-- `docker volume create [opts] [name]` — Create a volume. Returns volume name. -/
def dockerVolumeCreate (cfg : DockerConfig) (volCfg : VolumeCreateConfig) :
    IO (Except String String) := do
  match ← dockerExec cfg.dockerBin
      (baseArgs cfg ++ #["volume", "create"] ++ serializeVolumeCreateFlags volCfg) with
  | .ok stdout => pure (.ok stdout.trimAscii.toString)
  | .error e => pure (.error e)

/-- `docker volume rm <name>` — Remove a volume. -/
def dockerVolumeRm (cfg : DockerConfig) (name : String) :
    IO (Except String Unit) := do
  match ← dockerExec cfg.dockerBin
      (baseArgs cfg ++ #["volume", "rm", name]) with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error e)

/-- `docker volume ls` — List volumes (JSON format). -/
def dockerVolumeLs (cfg : DockerConfig) :
    IO (Except String String) :=
  dockerExec cfg.dockerBin
    (baseArgs cfg ++ #["volume", "ls", "--format", "{{json .}}"])

/-- `docker volume inspect <name>` — Get volume info (JSON). -/
def dockerVolumeInspect (cfg : DockerConfig) (name : String) :
    IO (Except String String) :=
  dockerExec cfg.dockerBin
    (baseArgs cfg ++ #["volume", "inspect", name])

/-- `docker volume prune -f` — Remove all unused volumes. -/
def dockerVolumePrune (cfg : DockerConfig) :
    IO (Except String String) :=
  dockerExec cfg.dockerBin
    (baseArgs cfg ++ #["volume", "prune", "--force"])

end SWELibImpl.Cloud
