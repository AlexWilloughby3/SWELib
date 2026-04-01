import SWELib
import SWELibImpl.Cloud.GceVmJson
import Lean.Data.Json.Parser

/-!
# GCE VM Client

Executable client for provisioning and managing GCE VMs via the `gcloud` CLI.
Each operation validates the transition against the formal `gceVMNodeLTS` spec
before executing.

## Usage

```lean
let handle ← GceVm.createInstance "my-project" "us-central1-a" "test-vm" "e2-micro"
GceVm.stopInstance handle
GceVm.startInstance handle
GceVm.deleteInstance handle
```

## Prerequisites

- `gcloud` CLI installed and on PATH
- Authenticated: `gcloud auth login` or service account configured
-/

namespace SWELibImpl.Cloud.GceVm

open SWELibImpl.Cloud.GceVmJson
open Lean (Json)

/-! ## Executable Step Function -/

/-- Executable decision procedure mirroring `gceVMNodeLTS.Tr`.
    Returns the destination state if the transition is legal, `none` otherwise.
    Covers both user-initiated and platform-driven transitions. -/
def stepVM (current : SWELib.OS.Isolation.VMStatus)
    (action : SWELib.OS.Isolation.VMLifecycleAction)
    : Option SWELib.OS.Isolation.VMStatus :=
  match action, current with
  -- User-initiated
  | .create,             .pending     => some .pending
  | .start,              .terminated  => some .provisioning
  | .stop,               .running     => some .pendingStop
  | .suspend,            .running     => some .suspending
  | .resume,             .suspended   => some .provisioning
  | .delete,             .terminated  => some .terminated
  | .delete,             .stopping    => some .terminated
  | .reset,              .running     => some .running
  -- Platform-driven
  | .resourcesAcquired,  .pending       => some .provisioning
  | .resourcesAllocated, .provisioning  => some .staging
  | .bootComplete,       .staging       => some .running
  | .gracefulPeriodEnded, .pendingStop  => some .stopping
  | .stopComplete,       .stopping      => some .terminated
  | .suspendComplete,    .suspending    => some .suspended
  | .repairStarted,      .running       => some .repairing
  | .repairComplete,     .repairing     => some .running
  | _,                   _              => none

/-- Human-readable name for a lifecycle action. -/
def actionName : SWELib.OS.Isolation.VMLifecycleAction → String
  | .create             => "create"
  | .start              => "start"
  | .stop               => "stop"
  | .suspend            => "suspend"
  | .resume             => "resume"
  | .delete             => "delete"
  | .reset              => "reset"
  | .resourcesAcquired  => "resources-acquired"
  | .resourcesAllocated => "resources-allocated"
  | .bootComplete       => "boot-complete"
  | .gracefulPeriodEnded => "graceful-period-ended"
  | .stopComplete       => "stop-complete"
  | .suspendComplete    => "suspend-complete"
  | .repairStarted      => "repair-started"
  | .repairComplete     => "repair-complete"

/-! ## VM Handle -/

/-- A handle to a GCE VM instance, tracking its current lifecycle state. -/
structure VMHandle where
  /-- GCP project ID. -/
  project : String
  /-- GCE zone (e.g., "us-central1-a"). -/
  zone : String
  /-- Instance name. -/
  name : String
  /-- Current lifecycle state (tracked locally, confirmed via API). -/
  status : IO.Ref SWELib.OS.Isolation.VMStatus

/-- Get the current status from the handle. -/
def VMHandle.getStatus (h : VMHandle) : IO SWELib.OS.Isolation.VMStatus :=
  h.status.get

/-! ## gcloud CLI Helpers -/

/-- Run a gcloud command and return its stdout.
    Throws on non-zero exit code. -/
def runGcloud (args : List String) : IO String := do
  let result ← IO.Process.output {
    cmd := "gcloud"
    args := args.toArray
  }
  if result.exitCode != 0 then
    throw <| IO.userError s!"gcloud failed (exit {result.exitCode}): {result.stderr}"
  return result.stdout

/-- Run a gcloud command and parse the JSON output. -/
def runGcloudJson (args : List String) : IO Json := do
  let stdout ← runGcloud (args ++ ["--format=json"])
  match Lean.Json.parse stdout with
  | .ok json => return json
  | .error e => throw <| IO.userError s!"Failed to parse gcloud JSON output: {e}"

/-- Fetch the current VM status from GCE. -/
private def fetchStatus (project zone name : String) :
    IO SWELib.OS.Isolation.VMStatus := do
  let json ← runGcloudJson [
    "compute", "instances", "describe", name,
    "--project", project,
    "--zone", zone
  ]
  match extractStatus json with
  | some status => return status
  | none => throw <| IO.userError "Could not parse VM status from gcloud output"

/-- Validate a transition, execute a gcloud command, confirm the resulting state. -/
private def executeTransition (h : VMHandle)
    (action : SWELib.OS.Isolation.VMLifecycleAction)
    (gcloudArgs : List String) : IO Unit := do
  let current ← h.status.get
  match stepVM current action with
  | none =>
    throw <| IO.userError
      s!"Illegal transition: cannot {actionName action} from {vmStatusToString current}"
  | some _expected => do
    let _ ← runGcloud gcloudArgs
    let actualStatus ← fetchStatus h.project h.zone h.name
    h.status.set actualStatus

/-! ## Public API -/

/-- Create a new GCE VM instance.
    Returns a `VMHandle` tracking the instance. The `gcloud` command blocks
    until the instance is running.
    `metadata` is an array of key-value pairs passed via `--metadata`. -/
def createInstance (project zone name machineType : String)
    (imageFamily : String := "debian-12")
    (imageProject : String := "debian-cloud")
    (diskSizeGb : Nat := 10)
    (metadata : Array (String × String) := #[]) : IO VMHandle := do
  let statusRef ← IO.mkRef SWELib.OS.Isolation.VMStatus.pending
  let h : VMHandle := { project, zone, name, status := statusRef }
  let metadataArgs :=
    if metadata.isEmpty then []
    else
      let pairs := metadata.toList.map fun (k, v) => s!"{k}={v}"
      ["--metadata", ",".intercalate pairs]
  let _ ← runGcloud ([
    "compute", "instances", "create", name,
    "--project", project,
    "--zone", zone,
    "--machine-type", machineType,
    "--image-family", imageFamily,
    "--image-project", imageProject,
    "--boot-disk-size", s!"{diskSizeGb}GB",
    "--format=json"
  ] ++ metadataArgs)
  -- gcloud blocks until RUNNING
  h.status.set .running
  return h

/-- Attach to an existing GCE VM instance by querying its current status. -/
def attachInstance (project zone name : String) : IO VMHandle := do
  let status ← fetchStatus project zone name
  let statusRef ← IO.mkRef status
  return { project, zone, name, status := statusRef }

/-- Start a stopped/terminated VM instance. -/
def startInstance (h : VMHandle) : IO Unit :=
  executeTransition h .start [
    "compute", "instances", "start", h.name,
    "--project", h.project,
    "--zone", h.zone
  ]

/-- Stop a running VM instance. -/
def stopInstance (h : VMHandle) : IO Unit :=
  executeTransition h .stop [
    "compute", "instances", "stop", h.name,
    "--project", h.project,
    "--zone", h.zone
  ]

/-- Suspend a running VM instance (memory preserved). -/
def suspendInstance (h : VMHandle) : IO Unit :=
  executeTransition h .suspend [
    "compute", "instances", "suspend", h.name,
    "--project", h.project,
    "--zone", h.zone
  ]

/-- Resume a suspended VM instance. -/
def resumeInstance (h : VMHandle) : IO Unit :=
  executeTransition h .resume [
    "compute", "instances", "resume", h.name,
    "--project", h.project,
    "--zone", h.zone
  ]

/-- Delete a VM instance. -/
def deleteInstance (h : VMHandle) : IO Unit := do
  let current ← h.status.get
  match stepVM current .delete with
  | none =>
    throw <| IO.userError
      s!"Illegal transition: cannot delete from {vmStatusToString current}"
  | some _ => do
    let _ ← runGcloud [
      "compute", "instances", "delete", h.name,
      "--project", h.project,
      "--zone", h.zone,
      "--quiet"
    ]
    h.status.set .terminated

/-- Reset (hard reboot) a running VM instance. -/
def resetInstance (h : VMHandle) : IO Unit :=
  executeTransition h .reset [
    "compute", "instances", "reset", h.name,
    "--project", h.project,
    "--zone", h.zone
  ]

/-- Refresh the handle's status by querying GCE. -/
def refreshStatus (h : VMHandle) : IO SWELib.OS.Isolation.VMStatus := do
  let status ← fetchStatus h.project h.zone h.name
  h.status.set status
  return status

/-! ## SSH -/

/-- SSH into a running VM and execute a command, returning the result.
    Validates the VM is in `running` state (the `sshPrecondition` from the spec)
    before executing.

    Maps to `gcloud compute ssh INSTANCE --project=PROJECT --zone=ZONE --command=CMD`.

    Note: Interactive SSH (no command) is not supported from Lean; always provide
    a command to run. -/
def sshInstance (h : VMHandle)
    (command : String)
    (config : SWELib.OS.Isolation.SshConfig := {})
    : IO SWELib.OS.Isolation.SshResult := do
  let current ← h.status.get
  unless current == .running do
    throw <| IO.userError
      s!"SSH requires VM to be running, but current status is {vmStatusToString current}"
  let mut args : List String := [
    "compute", "ssh", h.name,
    "--project", h.project,
    "--zone", h.zone,
    "--command", command
  ]
  if config.internalIp then
    args := args ++ ["--internal-ip"]
  if config.tunnelThroughIap then
    args := args ++ ["--tunnel-through-iap"]
  if let some keyFile := config.sshKeyFile then
    args := args ++ ["--ssh-key-file", keyFile]
  if !config.strictHostKeyChecking then
    args := args ++ ["--strict-host-key-checking=no"]
  let result ← IO.Process.output {
    cmd := "gcloud"
    args := args.toArray
  }
  return {
    stdout := result.stdout
    stderr := result.stderr
    exitCode := result.exitCode
  }

end SWELibImpl.Cloud.GceVm
