# Validators

Standalone validation logic for infrastructure artifacts and protocol conformance.

## Modules

| File | Description |
|------|-------------|
| `TerraformPlanValidator.lean` | Terraform plan JSON validation; `PlanFinding` type (warning/error); validates resource actions and configurations |
| `K8sManifestValidator.lean` | Kubernetes manifest validation: structural and semantic constraints from the K8s API spec |
| `HttpContractValidator.lean` | HTTP request/response validation per RFC 9110: checks Host header, TRACE body, Expect, Content-Length consistency |
