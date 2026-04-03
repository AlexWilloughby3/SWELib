import SWELib.Cloud.Docker.Types

/-!
# Docker Volume Types

Data model for Docker volumes: `docker volume create/rm/ls/inspect/prune`.

## Source Specs
- Docker volume reference: https://docs.docker.com/reference/cli/docker/volume/
- Docker storage overview: https://docs.docker.com/engine/storage/volumes/
-/

namespace SWELib.Cloud.Docker

/-! ## Volume Types -/

/-- Docker volume information (from `docker volume inspect`). -/
structure DockerVolume where
  /-- Volume name. -/
  name : String
  /-- Volume driver (default "local"). -/
  driver : String := "local"
  /-- Mount point on the host filesystem. -/
  mountpoint : String := ""
  /-- Driver-specific options. -/
  options : Array String := #[]
  /-- Labels. -/
  labels : Array String := #[]
  /-- Scope (local or global). -/
  scope : String := "local"
  deriving Repr, Inhabited

/-- Configuration for `docker volume create`. -/
structure VolumeCreateConfig where
  /-- Volume name. Empty = auto-generated. -/
  name : String := ""
  /-- Volume driver. -/
  driver : String := "local"
  /-- Driver-specific options (`--opt key=value`). -/
  options : Array String := #[]
  /-- Labels (`--label key=value`). -/
  labels : Array String := #[]
  deriving Repr, Inhabited

/-! ## Volume Store -/

/-- Volume store mapping volume names to volume info. -/
def VolumeStore := String → Option DockerVolume

/-- The empty volume store. -/
def VolumeStore.empty : VolumeStore := fun _ => none

/-- Look up a volume by name. -/
def VolumeStore.lookup (store : VolumeStore) (name : String) : Option DockerVolume :=
  store name

/-- Insert a volume into the store. -/
def VolumeStore.insert (store : VolumeStore) (vol : DockerVolume) : VolumeStore :=
  fun key => if key = vol.name then some vol else store key

/-- Remove a volume from the store. -/
def VolumeStore.remove (store : VolumeStore) (name : String) : VolumeStore :=
  fun key => if key = name then none else store key

/-- Check if a volume exists. -/
def VolumeStore.contains (store : VolumeStore) (name : String) : Bool :=
  (store.lookup name).isSome

/-! ## Volume Flag Serialization -/

/-- Serialize a `VolumeCreateConfig` into CLI arguments for `docker volume create`. -/
def serializeVolumeCreateFlags (config : VolumeCreateConfig) : Array String := Id.run do
  let mut args : Array String := #[]

  -- Driver
  if config.driver != "local" then
    args := args ++ #["--driver", config.driver]

  -- Options
  for opt in config.options do
    args := args ++ #["--opt", opt]

  -- Labels
  for label in config.labels do
    args := args ++ #["--label", label]

  -- Name (positional, last) — only if specified
  if !config.name.isEmpty then
    args := args.push config.name

  return args

end SWELib.Cloud.Docker
