# Foundations

Abstract mathematical foundations for reasoning about distributed systems. Built on labeled transition systems, I/O automata, and CCS-style parallel composition.

See [vision.md](vision.md) for the full design vision. Detailed sketches: [node.md](node.md), [system.md](system.md), [network.md](network.md), [isolation.md](isolation.md).

## Modules

| File | Based On | Key Types | Status |
|------|----------|-----------|--------|
| `LTS.lean` | Milner, Lynch, Aceto et al. | `LTS` (State, Label, transition relation, initial state), `Reachable` | Complete |
| `Node.lean` | Lynch's I/O Automata | `ActionKind` (input/output/internal), Node as LTS | Complete |
| `Network.lean` | CCS channel processes | `ChannelAction`, `reliableFIFOTr` (TCP-like), lossy channels | Complete |
| `System.lean` | CCS parallel composition | `NodeId`, System as `(Node₁ | Channel₁₂ | ... | Nodeₙ) \ channels` | Complete |

## Key Concepts

- **Node** is level-agnostic: a container, VM, bare-metal machine, phone, or CPU pipeline stage are all Nodes. What changes across levels is the Network, not the Node definition.
- **Network** dissolves into CCS: each directed edge is a ChannelProcess (itself an LTS) that mediates communication. Different edges can have different properties (heterogeneous networks).
- **System** is derived from CCS operational semantics, so all LTS-based tools (bisimulation, HML, trace equivalence) apply for free.
