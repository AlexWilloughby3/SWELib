# Cloud Implementations

Cloud infrastructure API clients.

## Modules

| File | Description | Protocol |
|------|-------------|----------|
| `GcpClient.lean` | GCP REST client with OAuth2 bearer token authentication | HTTPS + JSON |
| `K8sClient.lean` | Kubernetes API client with bearer token auth | HTTPS + JSON |
| `TerraformPlan.lean` | Terraform CLI wrapper for plan/apply/show operations | CLI subprocess |
| `OciRuntime.lean` | OCI container runtime client (runc/crun) per OCI Runtime Spec v1.0 | CLI subprocess |
