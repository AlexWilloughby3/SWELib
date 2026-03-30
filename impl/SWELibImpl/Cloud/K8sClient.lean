import SWELib
import SWELibImpl.Bridge

/-!
# K8sClient

Executable K8sClient implementation.
-/


namespace SWELibImpl.Cloud.K8sClient

open SWELib.Cloud.K8s

/-!
# K8s Client

Executable client for the Kubernetes API server (REST/JSON over HTTPS).
Implements the operations from `SWELib.Cloud.K8s.Operations`:
get, list, create, update, delete, patch.

Requests are made via the libcurl bridge using a bearer token from the
in-cluster service account or a provided kubeconfig token.
-/

/-- Configuration for connecting to a Kubernetes API server. -/
structure K8sConfig where
  /-- API server base URL, e.g. "https://kubernetes.default.svc". -/
  apiServer  : String
  /-- Bearer token for authentication (service account or user token). -/
  token      : String
  /-- CA certificate bundle for TLS verification (PEM). -/
  caBundlePath : String := "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  /-- Request timeout in milliseconds. -/
  timeoutMs  : Nat := 30000
  deriving Repr

/-- Result of a K8s API call: either a JSON body string or an error with status code. -/
abbrev K8sResult := Except (Nat × String) String

/-- Low-level HTTP GET to the K8s API server. Returns the response body as JSON. -/
@[extern "swelib_k8s_get"]
opaque k8sGet (apiServer token caBundle path : @& String) (timeoutMs : Nat) : IO K8sResult

/-- Low-level HTTP POST (create) to the K8s API server. -/
@[extern "swelib_k8s_post"]
opaque k8sPost (apiServer token caBundle path body : @& String) (timeoutMs : Nat) : IO K8sResult

/-- Low-level HTTP PUT (update) to the K8s API server. -/
@[extern "swelib_k8s_put"]
opaque k8sPut (apiServer token caBundle path body : @& String) (timeoutMs : Nat) : IO K8sResult

/-- Low-level HTTP PATCH to the K8s API server. -/
@[extern "swelib_k8s_patch"]
opaque k8sPatch (apiServer token caBundle path body contentType : @& String) (timeoutMs : Nat) : IO K8sResult

/-- Low-level HTTP DELETE to the K8s API server. -/
@[extern "swelib_k8s_delete"]
opaque k8sDelete (apiServer token caBundle path : @& String) (timeoutMs : Nat) : IO K8sResult

/-- Get a resource by namespace and name. Returns raw JSON. -/
def getResource (cfg : K8sConfig) (apiVersion resource ns name : String) : IO K8sResult :=
  let path := if ns.isEmpty
    then s!"/apis/{apiVersion}/{resource}/{name}"
    else s!"/apis/{apiVersion}/namespaces/{ns}/{resource}/{name}"
  k8sGet cfg.apiServer cfg.token cfg.caBundlePath path cfg.timeoutMs

/-- List resources, optionally filtered by namespace. Returns raw JSON list. -/
def listResources (cfg : K8sConfig) (apiVersion resource ns : String)
    (labelSelector : String := "") : IO K8sResult := do
  let basePath := if ns.isEmpty
    then s!"/apis/{apiVersion}/{resource}"
    else s!"/apis/{apiVersion}/namespaces/{ns}/{resource}"
  let path := if labelSelector.isEmpty then basePath
              else basePath ++ "?labelSelector=" ++ labelSelector
  k8sGet cfg.apiServer cfg.token cfg.caBundlePath path cfg.timeoutMs

/-- Create a resource from its JSON manifest. -/
def createResource (cfg : K8sConfig) (apiVersion resource ns body : String) : IO K8sResult :=
  let path := if ns.isEmpty
    then s!"/apis/{apiVersion}/{resource}"
    else s!"/apis/{apiVersion}/namespaces/{ns}/{resource}"
  k8sPost cfg.apiServer cfg.token cfg.caBundlePath path body cfg.timeoutMs

/-- Replace a resource (full update). -/
def updateResource (cfg : K8sConfig) (apiVersion resource ns name body : String) : IO K8sResult :=
  let path := if ns.isEmpty
    then s!"/apis/{apiVersion}/{resource}/{name}"
    else s!"/apis/{apiVersion}/namespaces/{ns}/{resource}/{name}"
  k8sPut cfg.apiServer cfg.token cfg.caBundlePath path body cfg.timeoutMs

/-- Apply a strategic merge patch to a resource. -/
def patchResource (cfg : K8sConfig) (apiVersion resource ns name patch : String) : IO K8sResult :=
  let path := if ns.isEmpty
    then s!"/apis/{apiVersion}/{resource}/{name}"
    else s!"/apis/{apiVersion}/namespaces/{ns}/{resource}/{name}"
  k8sPatch cfg.apiServer cfg.token cfg.caBundlePath path patch
           "application/strategic-merge-patch+json" cfg.timeoutMs

/-- Delete a resource by name. -/
def deleteResource (cfg : K8sConfig) (apiVersion resource ns name : String) : IO K8sResult :=
  let path := if ns.isEmpty
    then s!"/apis/{apiVersion}/{resource}/{name}"
    else s!"/apis/{apiVersion}/namespaces/{ns}/{resource}/{name}"
  k8sDelete cfg.apiServer cfg.token cfg.caBundlePath path cfg.timeoutMs

/-- Convenience: get a Pod by namespace and name. -/
def getPod (cfg : K8sConfig) (ns name : String) : IO K8sResult :=
  getResource cfg "v1" "pods" ns name

/-- Convenience: list all Pods in a namespace. -/
def listPods (cfg : K8sConfig) (ns : String) (labelSelector : String := "") : IO K8sResult :=
  listResources cfg "v1" "pods" ns labelSelector

/-- Convenience: apply a manifest (create or update via server-side apply). -/
def applyManifest (cfg : K8sConfig) (ns body fieldManager : String) : IO K8sResult :=
  let path := s!"/apis/v1/namespaces/{ns}/pods?fieldManager={fieldManager}&force=true"
  k8sPatch cfg.apiServer cfg.token cfg.caBundlePath path body
           "application/apply-patch+yaml" cfg.timeoutMs

/-- Load config from in-cluster service account files (standard K8s pod environment). -/
def inClusterConfig : IO K8sConfig := do
  let token ← IO.FS.readFile "/var/run/secrets/kubernetes.io/serviceaccount/token"
  pure {
    apiServer    := "https://kubernetes.default.svc"
    token        := token.trimAscii.toString
    caBundlePath := "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  }

end SWELibImpl.Cloud.K8sClient
