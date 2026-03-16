import SWELib
import SWELibBridge

/-!
# OciRuntime

Executable OCI runtime client.

Invokes an OCI-compliant container runtime (e.g. `runc`, `crun`) via its
command-line interface, as specified in the OCI Runtime Specification v1.0.

Bridges the pure spec functions in `SWELib.Cloud.Oci.Operations` to actual
IO by shelling out to the runtime binary.
-/


namespace SWELibCode.Cloud

open SWELib.Cloud.Oci

/-- Configuration for an OCI runtime invocation. -/
structure OciRuntimeConfig where
  /-- Path to the OCI runtime binary (e.g. "/usr/bin/runc"). -/
  runtimeBin : String := "runc"
  /-- Root directory for runtime state (e.g. "/run/runc"). -/
  root       : String := "/run/runc"
  /-- Log level passed to the runtime ("debug" | "info" | "warn" | "error"). -/
  logLevel   : String := "info"
  deriving Repr

/-- Low-level: invoke the OCI runtime binary with the given arguments.
    Returns stdout on success or an error message. -/
@[extern "swelib_oci_exec"]
opaque ociExec (bin root : @& String) (args : @& Array String) : IO (Except String String)

/-- Run `<runtime> state <id>` and return the state JSON. -/
def containerState (cfg : OciRuntimeConfig) (id : String) : IO (Except String String) :=
  ociExec cfg.runtimeBin cfg.root #["--root", cfg.root, "state", id]

/-- Run `<runtime> create --bundle <bundle> <id>` to create a container. -/
def containerCreate (cfg : OciRuntimeConfig) (id bundle : String) : IO (Except String Unit) := do
  match ← ociExec cfg.runtimeBin cfg.root
      #["--root", cfg.root, "create", "--bundle", bundle, id] with
  | .ok _    => pure (.ok ())
  | .error e => pure (.error e)

/-- Run `<runtime> start <id>` to start a created container. -/
def containerStart (cfg : OciRuntimeConfig) (id : String) : IO (Except String Unit) := do
  match ← ociExec cfg.runtimeBin cfg.root #["--root", cfg.root, "start", id] with
  | .ok _    => pure (.ok ())
  | .error e => pure (.error e)

/-- Run `<runtime> kill <id> <signal>` to send a signal to a container. -/
def containerKill (cfg : OciRuntimeConfig) (id : String) (signal : String := "SIGTERM") :
    IO (Except String Unit) := do
  match ← ociExec cfg.runtimeBin cfg.root
      #["--root", cfg.root, "kill", id, signal] with
  | .ok _    => pure (.ok ())
  | .error e => pure (.error e)

/-- Run `<runtime> delete <id>` to delete a stopped container. -/
def containerDelete (cfg : OciRuntimeConfig) (id : String) : IO (Except String Unit) := do
  match ← ociExec cfg.runtimeBin cfg.root #["--root", cfg.root, "delete", id] with
  | .ok _    => pure (.ok ())
  | .error e => pure (.error e)

/-- Run `<runtime> exec <id> -- <args...>` to execute a command in a running container.
    Returns the combined stdout of the executed command. -/
def containerExec (cfg : OciRuntimeConfig) (id : String) (args : Array String) :
    IO (Except String String) :=
  ociExec cfg.runtimeBin cfg.root
    (#["--root", cfg.root, "exec", id, "--"] ++ args)

/-- Run `<runtime> list` and return the JSON list of all containers. -/
def containerList (cfg : OciRuntimeConfig) : IO (Except String String) :=
  ociExec cfg.runtimeBin cfg.root #["--root", cfg.root, "list", "--format", "json"]

/-- High-level: create and start a container in one step.
    Returns `ok ()` if both operations succeed, `error msg` otherwise. -/
def containerRun (cfg : OciRuntimeConfig) (id bundle : String) : IO (Except String Unit) := do
  match ← containerCreate cfg id bundle with
  | .error e => pure (.error e)
  | .ok _ =>
    match ← containerStart cfg id with
    | .error e =>
      -- Best-effort cleanup on start failure
      let _ ← containerKill cfg id "SIGKILL"
      let _ ← containerDelete cfg id
      pure (.error e)
    | .ok _ => pure (.ok ())

end SWELibCode.Cloud
