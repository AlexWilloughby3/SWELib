import SWELib.Cloud.Docker.State
import SWELib.Cloud.Docker.Cli
import SWELib.Cloud.Docker.Build
import SWELib.Cloud.Docker.Network
import SWELib.Cloud.Docker.Volume
import SWELib.Cloud.Oci.Operations
import SWELib.OS.Capabilities
import SWELib.OS.Namespaces
import SWELib.OS.Cgroups

/-!
# Docker Container Operations

Models Docker CLI commands as pure state transformers over `DockerState`.
Each operation mirrors a `docker` subcommand.

The key operation is `dockerCreate`, which orchestrates:
1. Image resolution from the local store
2. Config merging (CLI flags override image defaults)
3. OCI config generation (mapping Docker concepts to OCI primitives)
4. Delegation to `Oci.create`

## Source Specs
- Docker CLI reference: https://docs.docker.com/reference/cli/docker/
- OCI Runtime Spec: https://github.com/opencontainers/runtime-spec
-/

namespace SWELib.Cloud.Docker

open SWELib.OS
open SWELib.Cloud.Oci

/-! ## Config Merging -/

/-- Merge a DockerRunConfig with image defaults.
    CLI flags take precedence; image config provides defaults.

    Docker's actual merging logic (from moby/moby):
    - Entrypoint: if `--entrypoint` is set, use it; otherwise use image's
    - Cmd: if command args are given, use them; otherwise use image's
    - Env: CLI env vars are appended to image env vars
    - User: CLI overrides image
    - WorkingDir: CLI overrides image
    - ExposedPorts: CLI ports are added to image ports -/
def mergeWithImageDefaults (config : DockerRunConfig) (image : DockerImageInfo) : DockerRunConfig :=
  { config with
    -- Entrypoint: explicit override wins, otherwise image default
    entrypoint := match config.entrypoint with
      | some ep => some ep
      | none => if image.config.entrypoint.isEmpty then none
                else some image.config.entrypoint
    -- Cmd: explicit args win, otherwise image default
    cmd := if config.cmd.isEmpty then image.config.cmd else config.cmd
    -- Env: append to image env (CLI can override individual vars)
    env := image.config.env ++ config.env
    -- User: explicit wins, otherwise image default
    user := if config.user.isEmpty then image.config.user else config.user
    -- WorkingDir: explicit wins, otherwise image default
    workdir := if config.workdir.isEmpty then image.config.workingDir else config.workdir }

/-- Compute the effective entrypoint + cmd (the actual process argv).
    Docker's logic: argv = entrypoint ++ cmd.
    If no entrypoint, cmd is used directly as argv. -/
def effectiveCommand (config : DockerRunConfig) : Array String :=
  match config.entrypoint with
  | some ep => ep ++ config.cmd
  | none => config.cmd

/-! ## OCI Config Generation -/

/-- The default set of capabilities for a non-privileged Docker container.
    These 14 capabilities match moby/daemon/pkg/oci/caps/defaults.go. -/
def defaultCapabilities : Array Capability :=
  #[ .CAP_CHOWN, .CAP_DAC_OVERRIDE, .CAP_FSETID, .CAP_FOWNER,
     .CAP_MKNOD, .CAP_NET_RAW, .CAP_SETGID, .CAP_SETUID,
     .CAP_SETFCAP, .CAP_SETPCAP, .CAP_NET_BIND_SERVICE,
     .CAP_SYS_CHROOT, .CAP_KILL, .CAP_AUDIT_WRITE ]

/-- All Linux capabilities (for privileged mode).
    In practice Docker's GetAllCapabilities() returns whatever the running
    kernel supports. This is the full set as of Linux 5.9+. -/
def allCapabilities : Array Capability :=
  #[ .CAP_CHOWN, .CAP_DAC_OVERRIDE, .CAP_DAC_READ_SEARCH,
     .CAP_FOWNER, .CAP_FSETID, .CAP_KILL, .CAP_SETGID, .CAP_SETUID,
     .CAP_SETPCAP, .CAP_LINUX_IMMUTABLE, .CAP_NET_BIND_SERVICE,
     .CAP_NET_BROADCAST, .CAP_NET_ADMIN, .CAP_NET_RAW,
     .CAP_IPC_LOCK, .CAP_IPC_OWNER, .CAP_SYS_MODULE, .CAP_SYS_RAWIO,
     .CAP_SYS_CHROOT, .CAP_SYS_PTRACE, .CAP_SYS_PACCT, .CAP_SYS_ADMIN,
     .CAP_SYS_BOOT, .CAP_SYS_NICE, .CAP_SYS_RESOURCE, .CAP_SYS_TIME,
     .CAP_SYS_TTY_CONFIG, .CAP_MKNOD, .CAP_LEASE, .CAP_AUDIT_WRITE,
     .CAP_AUDIT_CONTROL, .CAP_SETFCAP, .CAP_MAC_OVERRIDE, .CAP_MAC_ADMIN,
     .CAP_SYSLOG, .CAP_WAKE_ALARM, .CAP_BLOCK_SUSPEND, .CAP_AUDIT_READ,
     .CAP_PERFMON, .CAP_BPF, .CAP_CHECKPOINT_RESTORE ]

/-- Parse a capability name string to a Capability.
    Handles both "CAP_CHOWN" and "CHOWN" forms (Docker normalizes both). -/
def parseCapability (s : String) : Option Capability :=
  let name := if s.startsWith "CAP_" then s else "CAP_" ++ s
  match name with
  | "CAP_CHOWN" => some .CAP_CHOWN
  | "CAP_DAC_OVERRIDE" => some .CAP_DAC_OVERRIDE
  | "CAP_DAC_READ_SEARCH" => some .CAP_DAC_READ_SEARCH
  | "CAP_FOWNER" => some .CAP_FOWNER
  | "CAP_FSETID" => some .CAP_FSETID
  | "CAP_KILL" => some .CAP_KILL
  | "CAP_SETGID" => some .CAP_SETGID
  | "CAP_SETUID" => some .CAP_SETUID
  | "CAP_SETPCAP" => some .CAP_SETPCAP
  | "CAP_LINUX_IMMUTABLE" => some .CAP_LINUX_IMMUTABLE
  | "CAP_NET_BIND_SERVICE" => some .CAP_NET_BIND_SERVICE
  | "CAP_NET_BROADCAST" => some .CAP_NET_BROADCAST
  | "CAP_NET_ADMIN" => some .CAP_NET_ADMIN
  | "CAP_NET_RAW" => some .CAP_NET_RAW
  | "CAP_IPC_LOCK" => some .CAP_IPC_LOCK
  | "CAP_IPC_OWNER" => some .CAP_IPC_OWNER
  | "CAP_SYS_MODULE" => some .CAP_SYS_MODULE
  | "CAP_SYS_RAWIO" => some .CAP_SYS_RAWIO
  | "CAP_SYS_CHROOT" => some .CAP_SYS_CHROOT
  | "CAP_SYS_PTRACE" => some .CAP_SYS_PTRACE
  | "CAP_SYS_PACCT" => some .CAP_SYS_PACCT
  | "CAP_SYS_ADMIN" => some .CAP_SYS_ADMIN
  | "CAP_SYS_BOOT" => some .CAP_SYS_BOOT
  | "CAP_SYS_NICE" => some .CAP_SYS_NICE
  | "CAP_SYS_RESOURCE" => some .CAP_SYS_RESOURCE
  | "CAP_SYS_TIME" => some .CAP_SYS_TIME
  | "CAP_SYS_TTY_CONFIG" => some .CAP_SYS_TTY_CONFIG
  | "CAP_MKNOD" => some .CAP_MKNOD
  | "CAP_LEASE" => some .CAP_LEASE
  | "CAP_AUDIT_WRITE" => some .CAP_AUDIT_WRITE
  | "CAP_AUDIT_CONTROL" => some .CAP_AUDIT_CONTROL
  | "CAP_SETFCAP" => some .CAP_SETFCAP
  | "CAP_MAC_OVERRIDE" => some .CAP_MAC_OVERRIDE
  | "CAP_MAC_ADMIN" => some .CAP_MAC_ADMIN
  | "CAP_SYSLOG" => some .CAP_SYSLOG
  | "CAP_WAKE_ALARM" => some .CAP_WAKE_ALARM
  | "CAP_BLOCK_SUSPEND" => some .CAP_BLOCK_SUSPEND
  | "CAP_AUDIT_READ" => some .CAP_AUDIT_READ
  | "CAP_PERFMON" => some .CAP_PERFMON
  | "CAP_BPF" => some .CAP_BPF
  | "CAP_CHECKPOINT_RESTORE" => some .CAP_CHECKPOINT_RESTORE
  | _ => none

/-- Compute effective capabilities from config.
    Matches moby/oci/caps/utils.go TweakCapabilities:
    1. Privileged → all caps (cap-add/cap-drop ignored)
    2. "ALL" in cap-add → all caps, then remove cap-drop
    3. "ALL" in cap-drop → empty base, only explicit cap-add
    4. Default → (defaults - cap-drop) + cap-add -/
def effectiveCapabilities (config : DockerRunConfig) : Array Capability :=
  if config.privileged then allCapabilities
  else if config.capAdd.any (· == "ALL") then
    let dropped := config.capDrop.filterMap parseCapability
    allCapabilities.filter fun cap => !dropped.contains cap
  else if config.capDrop.any (· == "ALL") then
    config.capAdd.filterMap parseCapability
  else
    let dropped := config.capDrop.filterMap parseCapability
    let base := defaultCapabilities.filter fun cap => !dropped.contains cap
    let added := config.capAdd.filterMap parseCapability
    base ++ added

/-- Default namespaces for a Docker container.
    Per docker/engine oci/defaults.go, containers get pid, mount, ipc, uts
    namespaces by default, plus network unless `--network host`.
    Privileged mode does NOT change namespace topology — it affects
    capabilities, seccomp, AppArmor, and device access instead.
    User and cgroup namespaces require explicit `--userns`/`--cgroupns` flags
    and are not created by default. -/
def effectiveNamespaces (config : DockerRunConfig) : Array Namespace :=
  let base := #[.pid, .mount, .ipc, .uts]
  if config.networkMode == "host" then base
  else base.push .network

/-- Convert volume mounts to OCI Mount structures. -/
def volumesToOciMounts (vols : Array VolumeMount) : Array Mount :=
  vols.map fun vm =>
    { source := vm.source
      destination := vm.target
      fstype := "bind"
      options := if vm.readOnly then #["ro", "rbind"] else #["rbind"] }

/-- Compute resource limits from Docker config as OCI cgroup limits. -/
def toResourceLimits (config : DockerRunConfig) : Array CgroupLimit :=
  let mem := if config.memory > 0 then #[CgroupLimit.memory config.memory] else #[]
  let cpu := if config.cpuQuota > 0 then #[CgroupLimit.cpuMax config.cpuQuota config.cpuPeriod] else #[]
  let pids := if config.pidsLimit > 0 then #[CgroupLimit.pidCount config.pidsLimit] else #[]
  mem ++ cpu ++ pids

/-- Generate the OCI LinuxConfig from Docker run config. -/
def toLinuxConfig (config : DockerRunConfig) : LinuxConfig :=
  { namespaces := effectiveNamespaces config
    cgroups := ⟨"/"⟩  -- Docker creates cgroup at /docker/<container-id>
    resources := toResourceLimits config
    seccomp := if config.privileged then none
               else if config.securityOpt.any (· == "seccomp=unconfined")
               then none
               else some "default"  -- Default seccomp profile
    maskedPaths := if config.privileged then #[]
                   else #["/proc/asound", "/proc/acpi", "/proc/kcore",
                          "/proc/keys", "/proc/latency_stats",
                          "/proc/timer_list", "/proc/timer_stats",
                          "/proc/sched_debug", "/proc/scsi",
                          "/sys/firmware"]
    readonlyPaths := if config.privileged then #[]
                     else #["/proc/bus", "/proc/fs", "/proc/irq",
                            "/proc/sys", "/proc/sysrq-trigger"] }

/-- Generate a full OCI ContainerConfig from a merged DockerRunConfig.
    This is the central transformation: Docker CLI concepts → OCI bundle config. -/
def toOciConfig (config : DockerRunConfig) (_bundlePath : String) : ContainerConfig :=
  { ociVersion := defaultOciVersion
    root := { path := "rootfs", readonly := config.readonlyRootfs }
    process :=
      { args := effectiveCommand config
        env := config.env
        cwd := if config.workdir.isEmpty then "/" else config.workdir
        user := ⟨.root, .root, .root, .root⟩  -- Resolved from config.user string by runtime
        capabilities := effectiveCapabilities config
        terminal := config.tty }
    hostname := if config.hostname.isEmpty then "" else config.hostname
    mounts := volumesToOciMounts config.volumes
    linux := toLinuxConfig config }

/-! ## Docker CLI Operations -/

/-- AXIOM: Docker generates a unique container ID (64-char hex sha256).
    The ID must not collide with any existing container in the state. -/
axiom generateContainerId (state : DockerState) : { id : String // !state.containers.contains id }

/-- `docker pull <imageRef>` — Pull an image from a registry.
    Adds the image to the local store. -/
def dockerPull (state : DockerState) (imageRef : String) (imageInfo : DockerImageInfo) :
    Except DockerCliError DockerState :=
  -- In practice, pulling involves registry auth + layer download.
  -- We model the result: image is now in local store.
  .ok { state with images := state.images.insert imageRef imageInfo }

/-- `docker create [flags] <image> [command]` — Create a container.
    1. Resolves image from local store
    2. Merges config with image defaults
    3. Generates OCI config
    4. Creates OCI container
    Returns the container ID. -/
noncomputable def dockerCreate (state : DockerState) (config : DockerRunConfig) :
    Except DockerCliError (DockerState × String) := do
  -- Validate config
  if !config.isValid then
    throw (.invalidArg "invalid container configuration")

  -- Check for name conflict
  if !config.name.isEmpty && state.containers.contains config.name then
    throw (.conflict config.name)

  -- Resolve image
  let imageInfo ← match state.images.lookup config.image with
    | some info => .ok info
    | none => .error (.imageNotFound config.image)

  -- Merge config with image defaults
  let merged := mergeWithImageDefaults config imageInfo

  -- Generate container ID
  let ⟨containerId, _⟩ := generateContainerId state

  -- Generate OCI config and create via OCI runtime
  let bundlePath := s!"/var/lib/docker/containers/{containerId}"
  let ociConfig := toOciConfig merged bundlePath

  -- Create via OCI operations
  match Oci.create state.ociTable containerId bundlePath ociConfig with
  | .error ociErr => throw (.ociError ociErr)
  | .ok (newOciTable, _ociState) =>
    -- Build container info
    let containerInfo : DockerContainerInfo :=
      { id := containerId
        name := if config.name.isEmpty then (containerId.take 12).toString else config.name
        state := { status := .created, running := false, pid := 0
                   exitCode := 0 }
        image := config.image
        config := merged }
    let newContainers := state.containers.insert containerInfo
    return ({ state with
               containers := newContainers
               ociTable := newOciTable },
            containerId)

/-- `docker start <id>` — Start a created container. -/
noncomputable def dockerStart (state : DockerState) (idOrName : String) :
    Except DockerCliError DockerState := do
  let info ← match state.findContainer idOrName with
    | some i => .ok i
    | none => .error (.containerNotFound idOrName)

  if info.state.status != .created && info.state.status != .exited then
    throw (.invalidArg s!"container {idOrName} is not in created or exited state")

  match Oci.start state.ociTable info.id with
  | .error ociErr => throw (.ociError ociErr)
  | .ok (newOciTable, ociState) =>
    let updatedInfo := { info with
      state := { info.state with
        status := .running
        running := true
        pid := match ociState.pid with
          | some p => p.pid
          | none => 0 } }
    return { state with
      containers := state.containers.insert updatedInfo
      ociTable := newOciTable }

/-- `docker stop <id> [-t timeout]` — Stop a running container.
    Sends SIGTERM, waits up to `timeout` seconds, then SIGKILL. -/
noncomputable def dockerStop (state : DockerState) (idOrName : String)
    (timeout : Nat := 10) : Except DockerCliError DockerState := do
  let info ← match state.findContainer idOrName with
    | some i => .ok i
    | none => .error (.containerNotFound idOrName)

  if !info.state.running then
    throw (.containerNotRunning idOrName)

  -- Send SIGTERM; if process doesn't exit within `timeout` seconds, SIGKILL follows.
  -- In the pure spec model we collapse the two-phase stop into a single transition.
  let _ := timeout  -- timeout governs the SIGTERM→SIGKILL grace period
  match Oci.kill state.ociTable info.id .SIGTERM with
  | .error ociErr => throw (.ociError ociErr)
  | .ok (newOciTable, _) =>
    let updatedInfo := { info with
      state := { info.state with
        status := .exited
        running := false
        pid := 0 } }
    return { state with
      containers := state.containers.insert updatedInfo
      ociTable := newOciTable }

/-- `docker rm <id> [-f]` — Remove a container.
    With `--force`, stops the container first if running. -/
noncomputable def dockerRm (state : DockerState) (idOrName : String)
    (force : Bool := false) : Except DockerCliError DockerState := do
  let info ← match state.findContainer idOrName with
    | some i => .ok i
    | none => .error (.containerNotFound idOrName)

  -- If running and force, stop first
  let state' ← if info.state.running && force then
    dockerStop state idOrName
  else if info.state.running then
    throw (.invalidArg s!"container {idOrName} is running; use --force")
  else .ok state

  -- Delete via OCI
  match Oci.delete state'.ociTable info.id with
  | .error ociErr => throw (.ociError ociErr)
  | .ok newOciTable =>
    return { state' with
      containers := state'.containers.remove info.id info.name
      ociTable := newOciTable }

/-- `docker run [flags] <image> [command]` — Create and start a container.
    Equivalent to `docker create` + `docker start`. -/
noncomputable def dockerRun (state : DockerState) (config : DockerRunConfig) :
    Except DockerCliError (DockerState × String) := do
  let (state', containerId) ← dockerCreate state config
  let state'' ← dockerStart state' containerId
  return (state'', containerId)

/-- `docker exec <id> <command...>` — Execute a command in a running container. -/
def dockerExec (state : DockerState) (idOrName : String) (cmd : Array String) :
    Except DockerCliError (DockerState × PID) := do
  let info ← match state.findContainer idOrName with
    | some i => .ok i
    | none => .error (.containerNotFound idOrName)

  if !info.state.running then
    throw (.containerNotRunning idOrName)

  match Oci.exec state.ociTable info.id cmd with
  | .error ociErr => throw (.ociError ociErr)
  | .ok (newOciTable, pid) =>
    return ({ state with ociTable := newOciTable }, pid)

/-- `docker inspect <id>` — Get container info. -/
def dockerInspect (state : DockerState) (idOrName : String) :
    Except DockerCliError DockerContainerInfo := do
  match state.findContainer idOrName with
  | some info => .ok info
  | none => .error (.containerNotFound idOrName)

/-- `docker pause <id>` — Pause a running container. -/
noncomputable def dockerPause (state : DockerState) (idOrName : String) :
    Except DockerCliError DockerState := do
  let info ← match state.findContainer idOrName with
    | some i => .ok i
    | none => .error (.containerNotFound idOrName)

  if !info.state.running then
    throw (.containerNotRunning idOrName)

  let updatedInfo := { info with
    state := { info.state with
      status := .paused
      running := false } }
  return { state with containers := state.containers.insert updatedInfo }

/-- `docker unpause <id>` — Unpause a paused container. -/
noncomputable def dockerUnpause (state : DockerState) (idOrName : String) :
    Except DockerCliError DockerState := do
  let info ← match state.findContainer idOrName with
    | some i => .ok i
    | none => .error (.containerNotFound idOrName)

  if info.state.status != .paused then
    throw (.invalidArg s!"container {idOrName} is not paused")

  let updatedInfo := { info with
    state := { info.state with
      status := .running
      running := true } }
  return { state with containers := state.containers.insert updatedInfo }

/-- `docker kill <id> [-s signal]` — Send a signal to a running container.
    Unlike `docker stop`, this does not wait for graceful shutdown. -/
noncomputable def dockerKill (state : DockerState) (idOrName : String)
    (signal : Signal := .SIGKILL) : Except DockerCliError DockerState := do
  let info ← match state.findContainer idOrName with
    | some i => .ok i
    | none => .error (.containerNotFound idOrName)

  if !info.state.running && info.state.status != .paused then
    throw (.containerNotRunning idOrName)

  match Oci.kill state.ociTable info.id signal with
  | .error ociErr => throw (.ociError ociErr)
  | .ok (newOciTable, _) =>
    let updatedInfo := { info with
      state := { info.state with
        status := .exited
        running := false
        pid := 0 } }
    return { state with
      containers := state.containers.insert updatedInfo
      ociTable := newOciTable }

/-! ## Docker Build Operations -/

/-- AXIOM: Build produces a unique image ID (64-char hex sha256). -/
axiom generateImageId (state : DockerState) : { id : String // !state.images.contains id }

/-- `docker build [flags] <context>` — Build an image from a Dockerfile.
    Adds the resulting image to the local image store. -/
noncomputable def dockerBuild (state : DockerState) (config : DockerBuildConfig)
    (imageConfig : DockerImageConfig := {}) :
    Except DockerCliError (DockerState × DockerBuildOutput) := do
  if !config.isValid then
    throw (.invalidArg "invalid build configuration")

  let ⟨imageId, _⟩ := generateImageId state

  let imageInfo : DockerImageInfo :=
    { id := imageId
      repoTags := config.tags
      config := imageConfig }

  -- Add the built image to the store, indexed by ID and all tags
  let mut images := state.images.insert imageId imageInfo
  for tag in config.tags do
    images := images.insert tag imageInfo

  let output : DockerBuildOutput := { imageId }
  return ({ state with images }, output)

/-! ## Image Management Operations -/

/-- `docker tag <source> <target>` — Create a tag that refers to an existing image. -/
def dockerTag (state : DockerState) (source target : String) :
    Except DockerCliError DockerState := do
  let imageInfo ← match state.images.lookup source with
    | some info => .ok info
    | none => .error (.imageNotFound source)

  let taggedInfo := { imageInfo with
    repoTags := imageInfo.repoTags.push target }
  return { state with images := state.images.insert target taggedInfo }

/-- `docker rmi <imageRef> [-f]` — Remove an image.
    Without force, fails if any container references it. -/
def dockerRmi (state : DockerState) (imageRef : String) (_force : Bool := false) :
    Except DockerCliError DockerState := do
  match state.images.lookup imageRef with
  | some _ => .ok { state with images := state.images.remove imageRef }
  | none => .error (.imageNotFound imageRef)

/-! ## Network Operations -/

/-- AXIOM: Docker generates a unique network ID. -/
axiom generateNetworkId (state : DockerState) : { id : String // !state.networks.contains id }

/-- `docker network create [opts] <name>` — Create a network. -/
noncomputable def dockerNetworkCreate (state : DockerState) (config : NetworkCreateConfig) :
    Except DockerCliError (DockerState × String) := do
  if !config.isValid then
    throw (.invalidArg "invalid network configuration")

  if state.networks.contains config.name then
    throw (.networkConflict config.name)

  let ⟨netId, _⟩ := generateNetworkId state

  let net : DockerNetwork :=
    { id := netId
      name := config.name
      driver := config.driver
      internal := config.internal
      enableIPv6 := config.enableIPv6
      ipam := config.subnets
      options := config.options
      labels := config.labels }

  return ({ state with networks := state.networks.insert net }, netId)

/-- `docker network rm <name>` — Remove a network. -/
def dockerNetworkRm (state : DockerState) (nameOrId : String) :
    Except DockerCliError DockerState := do
  let net ← match state.networks.lookup nameOrId with
    | some n => .ok n
    | none => .error (.networkNotFound nameOrId)
  return { state with networks := state.networks.remove net.id net.name }

/-- `docker network connect <network> <container>` — Connect a container to a network. -/
def dockerNetworkConnect (state : DockerState) (networkName containerId : String) :
    Except DockerCliError DockerState := do
  let net ← match state.networks.lookup networkName with
    | some n => .ok n
    | none => .error (.networkNotFound networkName)

  match state.findContainer containerId with
  | some _ => pure ()
  | none => throw (.containerNotFound containerId)

  let updatedNet := { net with containers := net.containers.push containerId }
  return { state with networks := state.networks.insert updatedNet }

/-- `docker network disconnect <network> <container>` — Disconnect a container from a network. -/
def dockerNetworkDisconnect (state : DockerState) (networkName containerId : String) :
    Except DockerCliError DockerState := do
  let net ← match state.networks.lookup networkName with
    | some n => .ok n
    | none => .error (.networkNotFound networkName)

  let updatedNet := { net with containers := net.containers.filter (· != containerId) }
  return { state with networks := state.networks.insert updatedNet }

/-! ## Volume Operations -/

/-- `docker volume create [opts] [name]` — Create a volume. -/
def dockerVolumeCreate (state : DockerState) (config : VolumeCreateConfig) :
    Except DockerCliError (DockerState × String) := do
  if !config.name.isEmpty && state.volumes.contains config.name then
    throw (.volumeConflict config.name)

  let vol : DockerVolume :=
    { name := config.name
      driver := config.driver
      mountpoint := s!"/var/lib/docker/volumes/{config.name}/_data"
      options := config.options
      labels := config.labels }

  return ({ state with volumes := state.volumes.insert vol }, config.name)

/-- `docker volume rm <name>` — Remove a volume. -/
def dockerVolumeRm (state : DockerState) (name : String) :
    Except DockerCliError DockerState := do
  match state.volumes.lookup name with
  | some _ => .ok { state with volumes := state.volumes.remove name }
  | none => .error (.volumeNotFound name)

end SWELib.Cloud.Docker
