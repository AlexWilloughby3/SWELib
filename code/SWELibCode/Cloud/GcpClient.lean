import SWELib
import SWELibBridge

/-!
# GcpClient

Executable GCP REST client.

Makes authenticated HTTP requests to Google Cloud APIs using
OAuth2 bearer tokens (service account or metadata server).
-/


namespace SWELibCode.Cloud

/-- Configuration for connecting to GCP APIs. -/
structure GcpConfig where
  /-- OAuth2 bearer token for authentication. -/
  accessToken : String
  /-- GCP project ID. -/
  projectId   : String
  /-- Base URL for the GCP API, e.g. "https://compute.googleapis.com". -/
  apiBase     : String := "https://www.googleapis.com"
  /-- Request timeout in milliseconds. -/
  timeoutMs   : Nat := 30000
  deriving Repr

/-- Result of a GCP API call: either a JSON body or an error with HTTP status code. -/
abbrev GcpResult := Except (Nat × String) String

/-- Low-level authenticated HTTP GET to a GCP API endpoint. -/
@[extern "swelib_gcp_get"]
opaque gcpGet (apiBase token path : @& String) (timeoutMs : Nat) : IO GcpResult

/-- Low-level authenticated HTTP POST to a GCP API endpoint. -/
@[extern "swelib_gcp_post"]
opaque gcpPost (apiBase token path body : @& String) (timeoutMs : Nat) : IO GcpResult

/-- Low-level authenticated HTTP PUT to a GCP API endpoint. -/
@[extern "swelib_gcp_put"]
opaque gcpPut (apiBase token path body : @& String) (timeoutMs : Nat) : IO GcpResult

/-- Low-level authenticated HTTP DELETE to a GCP API endpoint. -/
@[extern "swelib_gcp_delete"]
opaque gcpDelete (apiBase token path : @& String) (timeoutMs : Nat) : IO GcpResult

/-- Low-level authenticated HTTP PATCH to a GCP API endpoint. -/
@[extern "swelib_gcp_patch"]
opaque gcpPatch (apiBase token path body : @& String) (timeoutMs : Nat) : IO GcpResult

/-- GET a GCP resource at the given API path. Returns raw JSON. -/
def getResource (cfg : GcpConfig) (path : String) : IO GcpResult :=
  gcpGet cfg.apiBase cfg.accessToken path cfg.timeoutMs

/-- POST to a GCP API path with a JSON body. -/
def postResource (cfg : GcpConfig) (path body : String) : IO GcpResult :=
  gcpPost cfg.apiBase cfg.accessToken path body cfg.timeoutMs

/-- PUT to a GCP API path with a JSON body. -/
def putResource (cfg : GcpConfig) (path body : String) : IO GcpResult :=
  gcpPut cfg.apiBase cfg.accessToken path body cfg.timeoutMs

/-- DELETE a GCP resource at the given API path. -/
def deleteResource (cfg : GcpConfig) (path : String) : IO GcpResult :=
  gcpDelete cfg.apiBase cfg.accessToken path cfg.timeoutMs

/-- PATCH a GCP resource at the given API path with a JSON body. -/
def patchResource (cfg : GcpConfig) (path body : String) : IO GcpResult :=
  gcpPatch cfg.apiBase cfg.accessToken path body cfg.timeoutMs

-- ---------------------------------------------------------------------------
-- Compute Engine convenience helpers
-- ---------------------------------------------------------------------------

/-- List GCE instances in a project and zone. -/
def listInstances (cfg : GcpConfig) (zone : String) : IO GcpResult :=
  gcpGet cfg.apiBase cfg.accessToken
    s!"/compute/v1/projects/{cfg.projectId}/zones/{zone}/instances"
    cfg.timeoutMs

/-- Get a specific GCE instance. -/
def getInstance (cfg : GcpConfig) (zone instance : String) : IO GcpResult :=
  gcpGet cfg.apiBase cfg.accessToken
    s!"/compute/v1/projects/{cfg.projectId}/zones/{zone}/instances/{instance}"
    cfg.timeoutMs

/-- List GCS objects in a bucket, optionally filtering by prefix. -/
def listObjects (cfg : GcpConfig) (bucket : String) (prefix : String := "") : IO GcpResult :=
  let path := if prefix.isEmpty
    then s!"/storage/v1/b/{bucket}/o"
    else s!"/storage/v1/b/{bucket}/o?prefix={prefix}"
  gcpGet cfg.apiBase cfg.accessToken path cfg.timeoutMs

/-- Get metadata for a GCS object. -/
def getObject (cfg : GcpConfig) (bucket object : String) : IO GcpResult :=
  gcpGet cfg.apiBase cfg.accessToken
    s!"/storage/v1/b/{bucket}/o/{object}"
    cfg.timeoutMs

/-- Fetch an access token from the GCE metadata server (in-cluster). -/
def metadataServerToken : IO (Except String String) := do
  -- The metadata server URL is fixed; we use a low-level GET without auth.
  let result ← gcpGet
    "http://metadata.google.internal"
    ""  -- no bearer token needed for metadata server
    "/computeMetadata/v1/instance/service-accounts/default/token"
    5000
  match result with
  | .ok body => pure (.ok body)
  | .error (code, msg) => pure (.error s!"metadata server error {code}: {msg}")

end SWELibCode.Cloud
