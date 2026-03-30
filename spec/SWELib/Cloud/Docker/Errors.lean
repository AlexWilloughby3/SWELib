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
