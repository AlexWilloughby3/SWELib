import SWELib.Cloud.Docker.Types
import SWELib.Cloud.Docker.Errors
import SWELib.Cloud.Oci.State

/-!
# Docker State Model

Models the observable state of a Docker daemon as seen through the CLI:
`docker ps`, `docker images`, `docker inspect`.

The Docker daemon manages containers (backed by OCI runtime) and a local
image store. This module models both as lookup tables.
-/

namespace SWELib.Cloud.Docker

/-! ## Image Store -/

/-- Local image store mapping image references to image info.
    Represents the output of `docker images`. -/
def ImageStore := String → Option DockerImageInfo

/-- The empty image store. -/
def ImageStore.empty : ImageStore := fun _ => none

/-- Look up an image by reference (name, name:tag, or sha256 digest). -/
def ImageStore.lookup (store : ImageStore) (ref : String) : Option DockerImageInfo :=
  store ref

/-- Add an image to the store. -/
def ImageStore.insert (store : ImageStore) (ref : String) (info : DockerImageInfo) : ImageStore :=
  fun r => if r = ref then some info else store r

/-- Remove an image from the store. -/
def ImageStore.remove (store : ImageStore) (ref : String) : ImageStore :=
  fun r => if r = ref then none else store r

/-- Check if an image exists locally. -/
def ImageStore.contains (store : ImageStore) (ref : String) : Bool :=
  (store.lookup ref).isSome

/-! ## Container Store -/

/-- Container store mapping container IDs/names to container info.
    Represents the output of `docker ps -a`. -/
def ContainerStore := String → Option DockerContainerInfo

/-- The empty container store. -/
def ContainerStore.empty : ContainerStore := fun _ => none

/-- Look up a container by ID or name. -/
def ContainerStore.lookup (store : ContainerStore) (idOrName : String) : Option DockerContainerInfo :=
  store idOrName

/-- Insert a container into the store. Indexed by both ID and name. -/
def ContainerStore.insert (store : ContainerStore) (info : DockerContainerInfo) : ContainerStore :=
  fun key =>
    if key = info.id then some info
    else if key = info.name then some info
    else store key

/-- Remove a container from the store by ID and name. -/
def ContainerStore.remove (store : ContainerStore) (id : String) (name : String := "") : ContainerStore :=
  fun key => if key = id then none
             else if !name.isEmpty && key = name then none
             else store key

/-- Check if a container exists. -/
def ContainerStore.contains (store : ContainerStore) (idOrName : String) : Bool :=
  (store.lookup idOrName).isSome

/-! ## Docker Daemon State -/

/-- The observable state of a Docker daemon.
    Models what `docker ps`, `docker images`, and `docker inspect` reveal. -/
structure DockerState where
  /-- Local image store. -/
  images : ImageStore
  /-- Container store. -/
  containers : ContainerStore
  /-- The underlying OCI container table (for spec-level reasoning). -/
  ociTable : SWELib.Cloud.Oci.ContainerTable

/-- Initial empty daemon state. -/
def DockerState.empty : DockerState :=
  { images := ImageStore.empty
    containers := ContainerStore.empty
    ociTable := SWELib.Cloud.Oci.ContainerTable.empty }

/-- Look up a container. -/
def DockerState.findContainer (state : DockerState) (idOrName : String) : Option DockerContainerInfo :=
  state.containers.lookup idOrName

/-- Look up an image. -/
def DockerState.findImage (state : DockerState) (ref : String) : Option DockerImageInfo :=
  state.images.lookup ref

/-- Check if an image is available locally. -/
def DockerState.hasImage (state : DockerState) (ref : String) : Bool :=
  state.images.contains ref

/-! ## State Theorems -/

/-- Theorem: lookup after insert finds the image. -/
theorem ImageStore.lookup_insert (store : ImageStore) (ref : String) (info : DockerImageInfo) :
    (store.insert ref info).lookup ref = some info := by
  simp [ImageStore.lookup, ImageStore.insert]

/-- Theorem: insert preserves other entries. -/
theorem ImageStore.insert_preserves_others (store : ImageStore) (ref other : String) (info : DockerImageInfo)
    (h : other ≠ ref) : (store.insert ref info).lookup other = store.lookup other := by
  simp [ImageStore.lookup, ImageStore.insert, h]

end SWELib.Cloud.Docker
