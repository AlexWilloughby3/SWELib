/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives
import SWELib.Cloud.K8s.Metadata
import SWELib.Cloud.K8s.Selection
import SWELib.Cloud.K8s.Workloads
import SWELib.Cloud.K8s.Networking
import SWELib.Cloud.K8s.Operations
import SWELib.Cloud.K8s.Invariants

/-!
# Kubernetes API Fundamentals Formalization

This module provides a formal specification of core Kubernetes API concepts,
following the official Kubernetes API conventions and specifications.

## Structure

- **Primitives**: Validated string types (DNS names, labels, resource versions)
- **Metadata**: Common metadata for all resources (ObjectMeta, TypeMeta, OwnerReference)
- **Selection**: Label selectors and matching expressions
- **Workloads**: Pod specifications and lifecycle management
- **Networking**: Service definitions and network policies
- **Operations**: CRUD operations with optimistic concurrency control
- **Invariants**: System-wide consistency guarantees

## Key Design Decisions

1. **System-managed fields** are included in structures but marked read-only
2. **Resource versions** are opaque strings with lexicographic ordering
3. **Labels** are represented as `Std.HashMap LabelKey LabelValue`
4. **Container lists** include proof of non-emptiness
5. **Port ranges** include proofs of valid bounds (1-65535)

## Usage Example

```lean
import SWELib.Cloud.K8s

-- Create a simple pod specification
def myPod : Pod := {
  metadata := ObjectMeta.withName (DnsSubdomain.mk? "my-pod").get!
  spec := PodSpec.withContainer {
    name := "nginx"
    image := "nginx:latest"
  }
}
```

## References

- [Kubernetes API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
-/

namespace SWELib.Cloud

-- Kubernetes API fundamentals.
namespace K8s

-- All types are re-exported through their respective submodules
-- Users should typically import just `SWELib.Cloud.K8s`

end K8s

end SWELib.Cloud
