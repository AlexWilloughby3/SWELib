import SWELib.Cloud.Oci.Errors
import SWELib.Cloud.Docker.Types

/-!
# Docker CLI Errors

Error types for Docker CLI operations.
Maps to Docker CLI exit codes and error messages.

## Source Specs
- Docker CLI exit codes: https://docs.docker.com/reference/cli/docker/
-/

namespace SWELib.Cloud.Docker

/-- Docker CLI operation errors. -/
inductive DockerCliError where
  /-- Image not found locally or in registry. -/
  | imageNotFound (ref : String)
  /-- Container not found. -/
  | containerNotFound (id : String)
  /-- Name conflict (container name already in use). -/
  | conflict (name : String)
  /-- Docker daemon is not running. -/
  | daemonNotRunning
  /-- Permission denied (e.g. not in docker group). -/
  | permissionDenied
  /-- Invalid argument or flag. -/
  | invalidArg (msg : String)
  /-- Command failed with exit code and stderr. -/
  | commandFailed (exitCode : Nat) (stderr : String)
  /-- Container is not running (for exec/stop/kill). -/
  | containerNotRunning (id : String)
  /-- Build failed. -/
  | buildFailed (msg : String)
  /-- Network not found. -/
  | networkNotFound (name : String)
  /-- Network name conflict. -/
  | networkConflict (name : String)
  /-- Volume not found. -/
  | volumeNotFound (name : String)
  /-- Volume name conflict. -/
  | volumeConflict (name : String)
  /-- Volume is in use by a container. -/
  | volumeInUse (name : String)
  /-- Image is in use by a container. -/
  | imageInUse (ref : String)
  /-- Wrapped OCI error. -/
  | ociError (err : SWELib.Cloud.Oci.OciError)
  deriving Repr, Inhabited

instance : ToString DockerCliError where
  toString
    | .imageNotFound ref => s!"image not found: {ref}"
    | .containerNotFound id => s!"container not found: {id}"
    | .conflict name => s!"name conflict: container name '{name}' already in use"
    | .daemonNotRunning => "cannot connect to Docker daemon"
    | .permissionDenied => "permission denied"
    | .invalidArg msg => s!"invalid argument: {msg}"
    | .commandFailed code stderr => s!"command failed (exit {code}): {stderr}"
    | .containerNotRunning id => s!"container {id} is not running"
    | .buildFailed msg => s!"build failed: {msg}"
    | .networkNotFound name => s!"network not found: {name}"
    | .networkConflict name => s!"network name conflict: '{name}' already exists"
    | .volumeNotFound name => s!"volume not found: {name}"
    | .volumeConflict name => s!"volume name conflict: '{name}' already exists"
    | .volumeInUse name => s!"volume '{name}' is in use"
    | .imageInUse ref => s!"image '{ref}' is in use by a container"
    | .ociError err => s!"OCI error: {err}"

/-- Check if an error indicates the daemon is unreachable. -/
def DockerCliError.isDaemonError : DockerCliError → Bool
  | .daemonNotRunning => true
  | .permissionDenied => true
  | _ => false

/-- Check if an error is recoverable by retrying. -/
def DockerCliError.isRetryable : DockerCliError → Bool
  | .daemonNotRunning => true
  | .commandFailed _ _ => true  -- transient failures
  | _ => false

end SWELib.Cloud.Docker
