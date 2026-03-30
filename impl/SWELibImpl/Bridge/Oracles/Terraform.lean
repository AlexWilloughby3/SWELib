import SWELib

/-!
# Terraform Oracle

The oracle axiom connecting Terraform plan execution to real-world infrastructure
state. This is the trust assumption that bridges the gap between the formal
model of desired state and what actually runs in the cloud provider.

## The Oracle Property

If `terraform apply` succeeds on a plan `P`, then the real-world infrastructure
state matches the desired state described in `P`.

This cannot be formally proved — it is a *trust assumption* about Terraform's
correctness and the cloud provider API's faithfulness. It is documented here
so that:
1. The assumption is explicit and auditable
2. Proofs that rely on "infrastructure is configured correctly" can cite this axiom
3. The scope of trust is clear (only successful applies, only the described resources)

## Specification References
- Terraform Apply: https://developer.hashicorp.com/terraform/cli/commands/apply
- Terraform Plan format: https://developer.hashicorp.com/terraform/internals/json-format
-/

namespace SWELibImpl.Bridge.Oracles

-- TRUST: <issue-url>

/-- Apply outcome: whether `terraform apply` succeeded or failed. -/
inductive ApplyResult where
  /-- Apply completed without errors; all resources were created/updated/deleted
      as specified. -/
  | success
  /-- Apply failed; some resources may be in an inconsistent state. -/
  | failure (message : String)
  deriving DecidableEq, Repr

/-- Oracle axiom: If `terraform apply` on plan `P` (represented as its JSON
    serialization) returns `ApplyResult.success`, then for every resource
    declared in `P`, the real-world cloud state matches the desired state.

    This is the core trust assumption of the Terraform oracle. It does NOT claim:
    - That `failure` applies leave state consistent (they may not)
    - That apply is atomic (it is not — partial applies can occur before failure)
    - That drift cannot occur after a successful apply

    TRUST: We trust Terraform + the cloud provider API to faithfully implement
    the desired state when apply reports success. Empirical evidence from
    integration tests supports this assumption for the resource types we use.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom terraform_apply_correct :
    ∀ (_planJson : String),
      ApplyResult.success = .success →
      -- The desired state in the plan matches real-world state after apply
      True  -- Placeholder: requires a formal model of cloud resource state

/-- Oracle axiom: `terraform plan` is deterministic — running plan twice on
    the same configuration and state produces the same diff. This justifies
    caching plan outputs for audit purposes.

    TRUST: Terraform's plan command is deterministic given the same inputs.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom terraform_plan_deterministic :
    ∀ (_configDir _stateFile : String),
      ∃ (_planJson : String),
        -- Two invocations with the same inputs produce the same plan
        True  -- Placeholder: requires formal plan equality semantics

/-- Oracle axiom: A plan that shows no changes (empty diff) means the current
    real-world state already matches the desired configuration.
    This is used to verify drift detection: if plan shows no changes, no
    remediation apply is needed.

    TRUST: Terraform's drift detection is complete — it detects all
    configuration deviations that it manages.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom terraform_no_changes_means_converged :
    ∀ (planJson : String),
      planJson = "{\"changes\": {\"actions\": [\"no-op\"]}}" →
      -- Real-world state matches configuration
      True  -- Placeholder: requires formal resource state model

end SWELibImpl.Bridge.Oracles
