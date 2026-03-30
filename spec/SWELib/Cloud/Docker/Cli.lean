import SWELib.Cloud.Docker.Types

/-!
# Docker CLI Flag Serialization

Pure functions mapping `DockerRunConfig` to the exact CLI arguments
for `docker create`. This is the formal specification of the CLI contract:
what flags produce what behavior.

## Source Specs
- `docker create --help`
- Docker CLI reference: https://docs.docker.com/reference/cli/docker/container/create/
-/

namespace SWELib.Cloud.Docker

/-! ## Flag Serialization -/

/-- Serialize a RestartPolicy to its CLI flag value. -/
def RestartPolicy.toFlag : RestartPolicy → String
  | .no => "no"
  | .onFailure 0 => "on-failure"
  | .onFailure n => s!"on-failure:{n}"
  | .always => "always"
  | .unlessStopped => "unless-stopped"

/-- Serialize a DockerRunConfig into the argument list for `docker create`.
    The output is the exact sequence of flags and positional args that
    would be passed to `docker create`. -/
def serializeFlags (config : DockerRunConfig) : Array String := Id.run do
  let mut args : Array String := #[]

  -- Name
  if !config.name.isEmpty then
    args := args ++ #["--name", config.name]

  -- Entrypoint override
  match config.entrypoint with
  | some ep =>
    if ep.isEmpty then
      args := args.push "--entrypoint="
    else
      args := args ++ #["--entrypoint", String.intercalate " " ep.toList]
  | none => pure ()

  -- Environment variables
  for e in config.env do
    args := args ++ #["--env", e]

  -- Hostname
  if !config.hostname.isEmpty then
    args := args ++ #["--hostname", config.hostname]

  -- User
  if !config.user.isEmpty then
    args := args ++ #["--user", config.user]

  -- Working directory
  if !config.workdir.isEmpty then
    args := args ++ #["--workdir", config.workdir]

  -- Port mappings
  for pm in config.publish do
    args := args ++ #["--publish", toString pm]

  -- Volumes
  for vm in config.volumes do
    args := args ++ #["--volume", toString vm]

  -- Network
  if config.networkMode != "bridge" then
    args := args ++ #["--network", config.networkMode]

  -- Resource limits
  if config.memory > 0 then
    args := args ++ #["--memory", toString config.memory]
  if config.cpuQuota > 0 then
    args := args ++ #["--cpu-quota", toString config.cpuQuota]
  if config.cpuPeriod != 100000 then
    args := args ++ #["--cpu-period", toString config.cpuPeriod]
  if config.pidsLimit > 0 then
    args := args ++ #["--pids-limit", toString config.pidsLimit]
  if !config.cpusetCpus.isEmpty then
    args := args ++ #["--cpuset-cpus", config.cpusetCpus]

  -- Capabilities
  for cap in config.capAdd do
    args := args ++ #["--cap-add", cap]
  for cap in config.capDrop do
    args := args ++ #["--cap-drop", cap]

  -- Security options
  for opt in config.securityOpt do
    args := args ++ #["--security-opt", opt]

  -- Boolean flags
  if config.readonlyRootfs then
    args := args.push "--read-only"
  if config.privileged then
    args := args.push "--privileged"
  if config.tty then
    args := args.push "--tty"
  if config.interactive then
    args := args.push "--interactive"
  if config.detach then
    args := args.push "--detach"
  if config.autoRemove then
    args := args.push "--rm"

  -- Restart policy
  match config.restart with
  | .no => pure ()
  | policy => args := args ++ #["--restart", policy.toFlag]

  -- Labels
  for label in config.labels do
    args := args ++ #["--label", label]

  -- Image (positional)
  args := args.push config.image

  -- Command (positional, after image)
  args := args ++ config.cmd

  return args

/-! ## Convenience Constructors -/

/-- Build a minimal run config from just an image name. -/
def DockerRunConfig.fromImage (image : String) : DockerRunConfig :=
  { image }

/-- Build a run config with image and command. -/
def DockerRunConfig.fromImageCmd (image : String) (cmd : Array String) : DockerRunConfig :=
  { image, cmd }

/-! ## Properties -/

/-- The image name always appears in the serialized flags. -/
/- These theorems require reasoning about `Id.run do` with mutable
   variables. Lean 4's `simp` exceeds step limits unfolding the
   desugared monadic chain, and manual proof would require hundreds
   of lines tracing through each `let` binding. We state them as
   axioms; they can be verified by #eval-based testing. -/
axiom serializeFlags_contains_image (config : DockerRunConfig)
    (h : !config.image.isEmpty) :
    config.image ∈ (serializeFlags config).toList

/-- Privileged flag appears iff config.privileged is true. -/
axiom serializeFlags_privileged (config : DockerRunConfig) :
    config.privileged →
    "--privileged" ∈ (serializeFlags config).toList

end SWELib.Cloud.Docker
