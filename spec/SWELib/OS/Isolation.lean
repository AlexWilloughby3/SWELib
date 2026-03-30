import SWELib.OS.Isolation.Types
import SWELib.OS.Isolation.Nodes
import SWELib.OS.Isolation.Simulation
import SWELib.OS.Isolation.Refinement

/-!
# Isolation Boundaries (Containers, VMs, Bare Metal)

Connects the abstract Node (`LTS S α`) to concrete isolation mechanisms.
A container, a VM, and a bare metal machine are all Nodes — they are all `LTS S α`.
But they are different instantiations with different state types, action types,
and transition relations.

This module defines:
- **ContainerNode**: OCI lifecycle states + parameterized service actions
- **VMNode**: libvirt/KVM lifecycle states + service actions
- **BareMetalNode**: MAAS provisioning lifecycle + service actions
- **TransientNode**: Cloud Run/ECS platform-managed lifecycle
- **DistilledNode**: the minimal 2-state LTS capturing their common behavior
- **Simulation relations**: concrete → distilled (forward simulation with action mapping)
- **Isolation refinement**: links Nodes to Linux primitives (namespaces, cgroups, seccomp)
- **Invariant theorems**: namespace isolation, seccomp restriction, cgroup bounds,
  failure independence

References:
- OCI Runtime Spec v1.0
- libvirt domain lifecycle
- MAAS machine lifecycle
- Milner, "Communication and Concurrency" (1989)
- Soltesz et al., "Container-based operating system virtualization" (2007)
-/
