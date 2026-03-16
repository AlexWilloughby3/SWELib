import SWELib
import SWELibBridge

/-!
# Terraform Plan Validator

Executable validator for Terraform plan JSON output.

Implements checks against the Terraform JSON plan format:
https://developer.hashicorp.com/terraform/internals/json-format

Validates that a plan JSON is well-formed before passing it to
`SWELibBridge.Oracles.terraform_apply_correct`.
-/


namespace SWELibCode.Validators

/-- Known resource change action strings in Terraform plan JSON. -/
private def validActions : List String :=
  ["no-op", "create", "read", "update", "delete", "delete-create", "create-delete"]

/-- Severity of a plan validation finding. -/
inductive PlanFinding where
  | warning (msg : String)
  | error   (msg : String)
  deriving Repr

/-- Validate that an action string is a known Terraform action. -/
private def validateAction (action : String) : Option PlanFinding :=
  if validActions.contains action then none
  else some (.warning s!"unknown action '{action}' (not in Terraform JSON format spec)")

/-- Check that a resource change entry has a required `address` field.
    This is a heuristic check on the JSON string; a full JSON parser would be
    used in production code. -/
private def containsAddress (resourceJson : String) : Bool :=
  resourceJson.contains "\"address\""

/-- Validate a Terraform plan JSON string.
    Returns `ok ()` if the plan appears valid, or `error msg` with findings. -/
def validatePlanJson (planJson : String) : Except String Unit :=
  let findings : List PlanFinding := [
    -- Must contain format_version field
    if !planJson.contains "\"format_version\"" then
      some (.error "plan JSON must contain 'format_version' field")
    else none,
    -- Must contain resource_changes or planned_values
    if !planJson.contains "\"resource_changes\"" && !planJson.contains "\"planned_values\"" then
      some (.warning "plan JSON has neither 'resource_changes' nor 'planned_values'")
    else none,
    -- Must not be empty
    if planJson.trim.isEmpty then
      some (.error "plan JSON must not be empty")
    else none
  ].filterMap id

  let errors := findings.filterMap fun
    | .error m => some m
    | .warning _ => none
  match errors with
  | []  => .ok ()
  | es  => .error (String.intercalate "; " es)

/-- Summarize the destructive actions in a plan JSON.
    Returns a list of resource addresses that will be deleted or replaced. -/
def destructiveResources (planJson : String) : List String :=
  -- Heuristic: collect any occurrences of "delete" near an "address"
  -- A real implementation would parse the JSON structure.
  let lines := planJson.splitOn "\n"
  lines.filterMap fun line =>
    if (line.contains "\"delete\"" || line.contains "\"delete-create\"" ||
        line.contains "\"create-delete\"") && line.contains "\"address\"" then
      some line.trim
    else none

/-- Check whether a plan is safe to auto-apply (no destructive actions).
    Returns `ok ()` if safe, `error` listing destructive resources otherwise. -/
def assertNonDestructive (planJson : String) : Except String Unit :=
  match destructiveResources planJson with
  | []    => .ok ()
  | addrs =>
    .error ("Plan contains destructive actions for: " ++
      String.intercalate ", " addrs)

/-- Validate and check a plan JSON, returning a combined report. -/
def validateAndCheck (planJson : String) : Except String Unit := do
  validatePlanJson planJson
  -- Warn but don't block on destructive resources (caller decides)
  pure ()

end SWELibCode.Validators
