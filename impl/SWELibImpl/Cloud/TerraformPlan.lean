import SWELib
import SWELibImpl.Bridge

/-!
# TerraformPlan

Executable interface to Terraform CLI operations.

Wraps the Terraform plan/apply/show cycle, connecting the
`SWELibImpl.Bridge.Oracles.Terraform` trust assumptions to actual
`terraform` subprocess invocations.
-/


namespace SWELibImpl.Cloud

open SWELibImpl.Bridge.Oracles

/-- Configuration for Terraform operations. -/
structure TerraformConfig where
  /-- Directory containing the Terraform configuration (*.tf files). -/
  configDir  : String
  /-- Path to the state file (or empty for default backend). -/
  stateFile  : String := ""
  /-- Extra variables to pass as -var arguments. -/
  vars       : List (String × String) := []
  /-- Extra -var-file paths. -/
  varFiles   : List String := []
  /-- Working directory from which to invoke terraform. -/
  workDir    : String := ""
  deriving Repr

/-- Low-level invocation: run `terraform` with the given arguments and return stdout. -/
@[extern "swelib_terraform_exec"]
opaque terraformExec (workDir : @& String) (args : @& Array String) : IO (Except String String)

/-- Build the common flags shared across plan/apply (vars, var-files). -/
private def commonFlags (cfg : TerraformConfig) : Array String :=
  let varFlags := cfg.vars.toArray.flatMap fun (k, v) => #["-var", s!"{k}={v}"]
  let fileFlags := cfg.varFiles.toArray.flatMap fun f => #["-var-file", f]
  let stateFlag := if cfg.stateFile.isEmpty then #[] else #["-state", cfg.stateFile]
  varFlags ++ fileFlags ++ stateFlag

/-- Run `terraform init` in the config directory. -/
def init (cfg : TerraformConfig) : IO (Except String String) :=
  terraformExec cfg.workDir #["init", "-input=false", cfg.configDir]

/-- Run `terraform plan -out=<planFile>` and return the path to the plan file.
    Returns `Except.ok planPath` or `Except.error message`. -/
def plan (cfg : TerraformConfig) (planPath : String := "/tmp/tfplan") :
    IO (Except String String) := do
  let args := #["plan", "-input=false", "-out", planPath, cfg.configDir] ++ commonFlags cfg
  match ← terraformExec cfg.workDir args with
  | .ok _   => pure (.ok planPath)
  | .error e => pure (.error e)

/-- Run `terraform show -json <planFile>` and return the plan as JSON. -/
def showPlan (cfg : TerraformConfig) (planPath : String) : IO (Except String String) :=
  terraformExec cfg.workDir #["show", "-json", planPath]

/-- Run `terraform apply -auto-approve` on a saved plan file.
    Returns `ApplyResult.success` or `ApplyResult.failure msg`. -/
def apply (cfg : TerraformConfig) (planPath : String) : IO ApplyResult := do
  let args := #["apply", "-input=false", "-auto-approve", planPath] ++ commonFlags cfg
  match ← terraformExec cfg.workDir args with
  | .ok _    => pure .success
  | .error e => pure (.failure e)

/-- Run `terraform destroy -auto-approve` in the config directory. -/
def destroy (cfg : TerraformConfig) : IO ApplyResult := do
  let args := #["destroy", "-input=false", "-auto-approve", cfg.configDir] ++ commonFlags cfg
  match ← terraformExec cfg.workDir args with
  | .ok _    => pure .success
  | .error e => pure (.failure e)

/-- Run `terraform output -json` and return all outputs as a JSON object. -/
def outputs (cfg : TerraformConfig) : IO (Except String String) := do
  let stateFlag := if cfg.stateFile.isEmpty then #[] else #["-state", cfg.stateFile]
  terraformExec cfg.workDir (#["output", "-json"] ++ stateFlag)

/-- High-level: plan, then apply if plan succeeds.
    Returns the JSON plan representation and the apply result. -/
def planAndApply (cfg : TerraformConfig) (planPath : String := "/tmp/tfplan") :
    IO (Except String (String × ApplyResult)) := do
  match ← plan cfg planPath with
  | .error e => pure (.error e)
  | .ok _ =>
    match ← showPlan cfg planPath with
    | .error e => pure (.error e)
    | .ok planJson =>
      let result ← apply cfg planPath
      pure (.ok (planJson, result))

/-- Parse an action list from plan JSON to check if there are changes.
    A plan is a "no-op" if all resources have the "no-op" action. -/
def planIsNoOp (planJson : String) : Bool :=
  -- Simplified heuristic: look for the sentinel pattern used in our oracle axiom
  planJson.contains "\"no-op\""

end SWELibImpl.Cloud
