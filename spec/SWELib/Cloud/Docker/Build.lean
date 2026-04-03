import SWELib.Cloud.Docker.Types

/-!
# Docker Build Types

Data model for `docker build` / `docker buildx build` CLI flags
and Dockerfile instructions.

## Source Specs
- Docker build reference: https://docs.docker.com/reference/cli/docker/buildx/build/
- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
-/

namespace SWELib.Cloud.Docker

/-! ## Dockerfile Instruction Model -/

/-- A Dockerfile instruction.
    Models the grammar of a Dockerfile for spec-level reasoning
    (e.g., multi-stage build properties, layer caching). -/
inductive DockerfileInstruction where
  /-- `FROM <image> [AS <name>]` -/
  | from (image : String) (asName : String := "")
  /-- `RUN <command>` (shell form) or `RUN ["exec", "arg1", ...]` -/
  | run (cmd : Array String) (shell : Bool := true)
  /-- `COPY [--from=<stage>] <src...> <dest>` -/
  | copy (srcs : Array String) (dest : String) (from_ : String := "")
  /-- `ADD <src...> <dest>` -/
  | add (srcs : Array String) (dest : String)
  /-- `ENV <key>=<value>` -/
  | env (key : String) (value : String)
  /-- `WORKDIR <path>` -/
  | workdir (path : String)
  /-- `EXPOSE <port>[/<protocol>]` -/
  | expose (port : Nat) (protocol : Protocol := .tcp)
  /-- `CMD ["exec", "arg1", ...]` or `CMD command arg1 ...` -/
  | cmd (args : Array String) (shell : Bool := false)
  /-- `ENTRYPOINT ["exec", "arg1", ...]` -/
  | entrypoint (args : Array String) (shell : Bool := false)
  /-- `ARG <name>[=<default>]` -/
  | arg (name : String) (default_ : Option String := none)
  /-- `LABEL <key>=<value>` -/
  | label (key : String) (value : String)
  /-- `VOLUME <path>` -/
  | volume (path : String)
  /-- `USER <user>[:<group>]` -/
  | user (user : String) (group : String := "")
  /-- `HEALTHCHECK CMD <command>` or `HEALTHCHECK NONE` -/
  | healthcheck (cmd : Option (Array String) := none)
      (interval : Nat := 30) (timeout : Nat := 30)
      (startPeriod : Nat := 0) (retries : Nat := 3)
  /-- `SHELL ["executable", "param1", ...]` -/
  | shell (args : Array String)
  /-- `STOPSIGNAL <signal>` -/
  | stopsignal (signal : String)
  deriving Repr, Inhabited

/-- A Dockerfile is a list of instructions. -/
abbrev Dockerfile := Array DockerfileInstruction

/-- A build stage is a FROM instruction followed by subsequent instructions
    until the next FROM (or end of file). -/
structure BuildStage where
  /-- Base image for this stage. -/
  baseImage : String
  /-- Stage alias (from `AS <name>`). Empty if unnamed. -/
  name : String := ""
  /-- Instructions in this stage (excluding the FROM). -/
  instructions : Array DockerfileInstruction := #[]
  deriving Repr, Inhabited

/-- Extract build stages from a Dockerfile.
    Each `FROM` starts a new stage. -/
def Dockerfile.stages (df : Dockerfile) : Array BuildStage := Id.run do
  let mut stages : Array BuildStage := #[]
  let mut current : Option BuildStage := none
  for instr in (df : Array DockerfileInstruction) do
    match instr with
    | .from image asName =>
      match current with
      | some stage => stages := stages.push stage
      | none => pure ()
      current := some { baseImage := image, name := asName }
    | other =>
      match current with
      | some stage =>
        current := some { stage with instructions := stage.instructions.push other }
      | none => pure ()  -- Instructions before first FROM (unusual but valid)
  match current with
  | some stage => stages := stages.push stage
  | none => pure ()
  return stages

/-- Check if a Dockerfile is a multi-stage build (more than one FROM). -/
def Dockerfile.isMultiStage (df : Dockerfile) : Bool :=
  df.stages.size > 1

/-- Get the final stage of a Dockerfile (the one that produces the output image). -/
def Dockerfile.finalStage (df : Dockerfile) : Option BuildStage :=
  let s := df.stages
  if s.isEmpty then none else some s[s.size - 1]!

/-! ## Build Configuration -/

/-- Target platform for multi-platform builds (`--platform`). -/
structure BuildPlatform where
  os : String := "linux"
  arch : String := "amd64"
  variant : String := ""
  deriving DecidableEq, Repr, Inhabited

instance : ToString BuildPlatform where
  toString bp :=
    let base := s!"{bp.os}/{bp.arch}"
    if bp.variant.isEmpty then base else s!"{base}/{bp.variant}"

/-- Configuration for `docker build` / `docker buildx build`.
    Each field corresponds to a CLI flag. -/
structure DockerBuildConfig where
  /-- Build context path (positional argument). -/
  contextPath : String := "."
  /-- Path to Dockerfile (`-f` / `--file`). Empty = `<context>/Dockerfile`. -/
  dockerfilePath : String := ""
  /-- Image tags (`-t` / `--tag`). Can specify multiple. -/
  tags : Array String := #[]
  /-- Build arguments (`--build-arg KEY=VALUE`). -/
  buildArgs : Array String := #[]
  /-- Target build stage (`--target`). Empty = final stage. -/
  target : String := ""
  /-- Disable build cache (`--no-cache`). -/
  noCache : Bool := false
  /-- Always pull base images (`--pull`). -/
  pull : Bool := false
  /-- Target platforms (`--platform`). Empty = current platform. -/
  platforms : Array BuildPlatform := #[]
  /-- Labels to set on the image (`--label KEY=VALUE`). -/
  labels : Array String := #[]
  /-- Network mode for RUN instructions (`--network`). -/
  network : String := ""
  /-- Remove intermediate containers (`--rm`). Default true in Docker. -/
  rm : Bool := true
  /-- Force remove intermediate containers (`--force-rm`). -/
  forceRm : Bool := false
  /-- Squash layers (`--squash`). Experimental. -/
  squash : Bool := false
  /-- Memory limit for build (`--memory`). 0 = unlimited. -/
  memory : Nat := 0
  /-- CPU quota for build (`--cpu-quota`). 0 = unlimited. -/
  cpuQuota : Nat := 0
  /-- Output destination (`--output`). Empty = load to daemon. -/
  output : String := ""
  /-- Cache sources (`--cache-from`). -/
  cacheFrom : Array String := #[]
  /-- Cache destinations (`--cache-to`). -/
  cacheTo : Array String := #[]
  /-- Secret mounts (`--secret id=mysecret,src=/path`). -/
  secrets : Array String := #[]
  /-- SSH agent sockets (`--ssh default`). -/
  ssh : Array String := #[]
  deriving Repr, Inhabited

/-- Output from a successful `docker build`. -/
structure DockerBuildOutput where
  /-- Image ID (sha256 digest) of the built image. -/
  imageId : String
  /-- Full build log (stdout). -/
  buildLog : String := ""
  deriving Repr, Inhabited

/-! ## Build Flag Serialization -/

/-- Serialize a `DockerBuildConfig` into CLI arguments for `docker build`. -/
def serializeBuildFlags (config : DockerBuildConfig) : Array String := Id.run do
  let mut args : Array String := #[]

  -- Dockerfile path
  if !config.dockerfilePath.isEmpty then
    args := args ++ #["--file", config.dockerfilePath]

  -- Tags
  for tag in config.tags do
    args := args ++ #["--tag", tag]

  -- Build args
  for ba in config.buildArgs do
    args := args ++ #["--build-arg", ba]

  -- Target stage
  if !config.target.isEmpty then
    args := args ++ #["--target", config.target]

  -- No cache
  if config.noCache then
    args := args.push "--no-cache"

  -- Pull
  if config.pull then
    args := args.push "--pull"

  -- Platforms
  if !config.platforms.isEmpty then
    let platStr := String.intercalate "," (config.platforms.toList.map toString)
    args := args ++ #["--platform", platStr]

  -- Labels
  for label in config.labels do
    args := args ++ #["--label", label]

  -- Network
  if !config.network.isEmpty then
    args := args ++ #["--network", config.network]

  -- Remove intermediate containers
  if !config.rm then
    args := args.push "--rm=false"

  -- Force remove
  if config.forceRm then
    args := args.push "--force-rm"

  -- Squash
  if config.squash then
    args := args.push "--squash"

  -- Memory
  if config.memory > 0 then
    args := args ++ #["--memory", toString config.memory]

  -- CPU quota
  if config.cpuQuota > 0 then
    args := args ++ #["--cpu-quota", toString config.cpuQuota]

  -- Output
  if !config.output.isEmpty then
    args := args ++ #["--output", config.output]

  -- Cache from
  for cf in config.cacheFrom do
    args := args ++ #["--cache-from", cf]

  -- Cache to
  for ct in config.cacheTo do
    args := args ++ #["--cache-to", ct]

  -- Secrets
  for secret in config.secrets do
    args := args ++ #["--secret", secret]

  -- SSH
  for s in config.ssh do
    args := args ++ #["--ssh", s]

  -- Context path (positional, must be last)
  args := args.push config.contextPath

  return args

/-! ## Build Validation -/

/-- Check if a build config is valid. -/
def DockerBuildConfig.isValid (config : DockerBuildConfig) : Bool :=
  -- Context path must be specified
  !config.contextPath.isEmpty &&
  -- CPU quota needs positive period (implicit 100000μs default)
  true

/-! ## Build Properties -/

/-- A multi-stage build's final image only contains layers from the last stage
    (plus its base image layers). Intermediate stages are discarded unless
    explicitly copied via `COPY --from=<stage>`. -/
axiom multistage_final_image_layers (df : Dockerfile)
    (h : df.isMultiStage) :
    match df.finalStage with
    | some _stage =>
      -- The final image's layer count is bounded by the final stage's
      -- instruction count plus its base image layers.
      -- Intermediate stage layers are not included unless COPY --from is used.
      True  -- Placeholder: the full property needs OCI layer types
    | none => False

end SWELib.Cloud.Docker
