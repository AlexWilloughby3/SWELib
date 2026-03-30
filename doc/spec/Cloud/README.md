# Cloud

Cloud infrastructure formalizations: Kubernetes API, OCI container specifications.

## Modules

### Kubernetes (54 files)

Comprehensive Kubernetes API formalization organized by resource concern.

| Submodule | Files | Key Content |
|-----------|-------|-------------|
| `Primitives/` | 7 | Validated string types: `DnsLabel`, `DnsSubdomain`, `LabelKey`, `LabelValue`, `ApiVersion`, `RFC3339Time`, `ResourceVersion` |
| `Metadata/` | 3 | `TypeMeta`, `ObjectMeta`, `OwnerReference` — common metadata for all resources |
| `Selection/` | 3 | `LabelSelector`, `SelectorOperator` — label-based resource selection and matching |
| `Workloads/` | 3 | `Pod`, `PodSpec`, `PodStatus`, `Container`, `RestartPolicy` — pod specs and lifecycle |
| `Networking/` | 3 | `Service`, `ServiceSpec`, `ServicePort`, `IntOrString` — service definitions |
| `Operations/` | 9 | `Create`, `Get`, `List`, `Watch`, `Patch`, `Update`, `Delete` — CRUD with optimistic concurrency |
| `Invariants/` | 6 | `Pod`, `Service`, `Lifecycle`, `Concurrency`, `Identity` — system-wide consistency guarantees |

### OCI Image (15 files)

OCI Image Format Specification: content-addressable storage with cryptographic digests.

| File | Key Content |
|------|-------------|
| `Algorithm.lean` | Hash algorithms (SHA256, etc.) |
| `MediaType.lean` | Media type definitions |
| `Platform.lean` | Architecture and OS specifications |
| `Digest.lean` | Content-addressable digests |
| `Descriptor.lean` | Image descriptors |
| `Layer.lean` | Layer definitions |
| `ImageConfig.lean` | Image configuration |
| `ImageManifest.lean` | Manifest structure |
| `ImageIndex.lean` | Multi-platform image indexes |
| `Validation.lean` | Image validation |
| `Invariants.lean` | Image invariants |

### OCI Runtime (5 files)

OCI Runtime Spec v1.0: filesystem bundles and container lifecycle.

| File | Key Content |
|------|-------------|
| `Types.lean` | Core types |
| `State.lean` | Container state |
| `Operations.lean` | 6 core ops: state, create, start, kill, delete, exec |
| `Invariants.lean` | Lifecycle invariants |

### Stubs

| File | Status |
|------|--------|
| `Gcp.lean` | TODO |
| `Terraform.lean` | TODO |
| `Workflow.lean` | TODO |
