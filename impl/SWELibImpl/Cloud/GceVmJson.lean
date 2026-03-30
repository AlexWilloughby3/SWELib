import SWELib
import Lean.Data.Json

/-!
# GCE VM JSON Parsing

Parses `gcloud compute instances describe --format=json` output
to extract VM status and other fields.
-/

namespace SWELibImpl.Cloud.GceVmJson

open Lean (Json)

/-- Map GCE status strings to spec `VMStatus`. -/
def parseVMStatus (s : String) : Option SWELib.OS.Isolation.VMStatus :=
  match s with
  | "PENDING"      => some .pending
  | "PROVISIONING" => some .provisioning
  | "STAGING"      => some .staging
  | "RUNNING"      => some .running
  | "PENDING_STOP" => some .pendingStop
  | "STOPPING"     => some .stopping
  | "TERMINATED"   => some .terminated
  | "REPAIRING"    => some .repairing
  | "SUSPENDING"   => some .suspending
  | "SUSPENDED"    => some .suspended
  | _              => none

/-- Map spec `VMStatus` back to GCE status string. -/
def vmStatusToString : SWELib.OS.Isolation.VMStatus → String
  | .pending       => "PENDING"
  | .provisioning  => "PROVISIONING"
  | .staging       => "STAGING"
  | .running       => "RUNNING"
  | .pendingStop   => "PENDING_STOP"
  | .stopping      => "STOPPING"
  | .terminated    => "TERMINATED"
  | .repairing     => "REPAIRING"
  | .suspending    => "SUSPENDING"
  | .suspended     => "SUSPENDED"

/-- Extract the `status` field from a GCE instance JSON object. -/
def extractStatus (json : Json) : Option SWELib.OS.Isolation.VMStatus := do
  let statusStr ← json.getObjValAs? String "status" |>.toOption
  parseVMStatus statusStr

/-- Extract the instance `name` from a GCE instance JSON object. -/
def extractName (json : Json) : Option String :=
  json.getObjValAs? String "name" |>.toOption

/-- Extract the `zone` (last path component) from a GCE instance JSON object. -/
def extractZone (json : Json) : Option String := do
  let zoneUrl ← json.getObjValAs? String "zone" |>.toOption
  -- Zone is a URL like "projects/my-project/zones/us-central1-a"
  let parts := zoneUrl.splitOn "/"
  parts.getLast?

/-- Check if a GCE long-running operation is done. -/
def operationIsDone (json : Json) : Bool :=
  match json.getObjValAs? String "status" with
  | .ok "DONE" => true
  | _ => false

/-- Extract error message from a failed operation, if any. -/
def extractOperationError (json : Json) : Option String := do
  let err ← json.getObjVal? "error" |>.toOption
  let messages ← err.getObjValAs? (Array Json) "errors" |>.toOption
  let first ← messages[0]?
  Json.getObjValAs? first String "message" |>.toOption

end SWELibImpl.Cloud.GceVmJson
