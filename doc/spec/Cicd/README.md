# CI/CD

Deployment automation, pipeline structure, and system evolution specifications.

## Modules

| File | Spec Source | Key Types | Status |
|------|-----------|-----------|--------|
| `Deployment.lean` | Kubernetes | `DeploymentStrategyType` (rollingUpdate/recreate), `RollingUpdateConfig`, pod templates, probes | Complete |
| `Pipeline.lean` | Tekton | `ParamType`, `WhenOperator`, DAG validation, execution ordering, status computation | Complete |
| `GitOps.lean` | Argo CD / Flux | `DeclarativeResource`, `GitSource`, drift detection, reconciliation state machine | Complete |
| `Rollback.lean` | Kubernetes | `RevisionEntry`, `RevisionHistory`, retention limits, rollback target resolution | Complete |
| `Migration.lean` | (Internal) | `Version`, `ChangeKind`, `Migration`, `MixedVersionState`, deployment/rollback plans | Complete |

### Migration Submodules

| File | Key Content |
|------|-------------|
| `Migration/Types.lean` | Migration types and version structures |
| `Migration/Operations.lean` | Migration application and validation |
| `Migration/Invariants.lean` | Safety properties during mixed-version states |
