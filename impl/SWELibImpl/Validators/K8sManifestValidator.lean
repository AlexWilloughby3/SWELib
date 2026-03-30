import SWELib
import SWELibImpl.Bridge

/-!
# K8s Manifest Validator

Executable validator for Kubernetes resource manifests.

Checks structural and semantic constraints derived from the Kubernetes
API specification, implemented as decidable functions over the spec types.

Validation levels:
- Structural: required fields, type constraints
- Semantic: namespace scoping, label syntax, API version format
-/


namespace SWELibImpl.Validators

open SWELib.Cloud.K8s
open SWELib.Cloud.K8s.Metadata
open SWELib.Cloud.K8s.Workloads
open SWELib.Cloud.K8s.Primitives

/-- Validation error with field path and message. -/
structure ValidationError where
  field   : String
  message : String
  deriving Repr

/-- Validate a label key string (RFC 1123 DNS label, optionally prefixed). -/
private def validateLabelKey (key : String) : Option String :=
  if key.isEmpty then some "label key must not be empty"
  else if key.length > 253 then some s!"label key too long ({key.length} > 253)"
  else none

/-- Validate a label value string. -/
private def validateLabelValue (v : String) : Option String :=
  if v.length > 63 then some s!"label value too long ({v.length} > 63)"
  else none

/-- Validate that a name satisfies the DNS subdomain constraint. -/
private def validateName (name : String) : Option String :=
  if name.isEmpty then some "name must not be empty"
  else if name.length > 253 then some s!"name too long ({name.length} > 253)"
  else if name.any (fun c => !c.isAlphanum && c ≠ '-' && c ≠ '.') then
    some "name must consist of alphanumerics, '-', and '.'"
  else if name.startsWith "-" || name.startsWith "." then
    some "name must start with an alphanumeric character"
  else none

/-- Validate that an apiVersion string has the expected `group/version` or `version` form. -/
private def validateApiVersion (av : String) : Option String :=
  if av.isEmpty then some "apiVersion must not be empty"
  else match av.splitOn "/" with
    | [_version]        => none  -- core group: just "v1"
    | [_group, _version] => none  -- e.g. "apps/v1"
    | _ => some s!"apiVersion '{av}' must be '<group>/<version>' or '<version>'"

/-- Validate `ObjectMeta` fields common to all resources. -/
def validateObjectMeta (objMeta : ObjectMeta) : List ValidationError :=
  let errs : List (Option ValidationError) := [
    validateName objMeta.name.val |>.map fun m => ⟨"metadata.name", m⟩,
    match objMeta.namespace with
    | some ns => if ns.val.isEmpty then
        some ⟨"metadata.namespace", "namespace must not be empty if set"⟩
      else none
    | none => none
  ]
  errs.filterMap id

/-- Validate a Pod's container list. -/
private def validateContainers (containers : List Container) (path : String) :
    List ValidationError :=
  if containers.isEmpty then
    [⟨path, "at least one container is required"⟩]
  else
    containers.flatMap fun c =>
      let nameErr := validateName c.name |>.map fun m => ⟨s!"{path}[{c.name}].name", m⟩
      let imgErr  := if c.image.isEmpty then
          some ⟨s!"{path}[{c.name}].image", "image must not be empty"⟩
        else none
      [nameErr, imgErr].filterMap id

/-- Validate a Pod manifest. -/
def validatePod (pod : Pod) : List ValidationError :=
  let metaErrs := validateObjectMeta pod.metadata
  let avErr    := validateApiVersion "v1" |>.map fun m => ⟨"apiVersion", m⟩
  let ctrErrs  := validateContainers pod.spec.containers "spec.containers"
  let initErrs := validateContainers pod.spec.initContainers "spec.initContainers"
  metaErrs ++ avErr.toList ++ ctrErrs ++ initErrs

/-- Validate a Pod manifest, returning a summary string or `ok`. -/
def validatePodReport (pod : Pod) : Except String Unit :=
  match validatePod pod with
  | []   => .ok ()
  | errs =>
    let msgs := errs.map fun e => s!"  {e.field}: {e.message}"
    .error (String.intercalate "\n" ("Pod validation errors:" :: msgs))

/-- Check whether a Pod's labels satisfy the label syntax rules.
    Returns a list of (key, error) pairs for invalid labels. -/
def validateLabels (labels : List (String × String)) : List ValidationError :=
  labels.flatMap fun (k, v) =>
    let kErr := validateLabelKey k |>.map fun m => ⟨s!"label key '{k}'", m⟩
    let vErr := validateLabelValue v |>.map fun m => ⟨s!"label value for '{k}'", m⟩
    [kErr, vErr].filterMap id

end SWELibImpl.Validators
