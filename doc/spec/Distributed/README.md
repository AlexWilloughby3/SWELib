# Distributed

Distributed systems algorithms, consistency models, and fault tolerance patterns.

## Modules

| File | Spec Source | Key Types | Status |
|------|-----------|-----------|--------|
| `Core.lean` | - | `LogicalTime`, `Node` (UUID-identified), message types | Complete |
| `Consensus.lean` | FLP, Chandra-Toueg | `ConsensusProblem`, proposals, fault bounds | Complete |
| `Consensus/Paxos.lean` | Lamport | Paxos protocol | Complete |
| `Consensus/Raft.lean` | Ongaro & Ousterhout | Raft protocol | Complete |
| `Consistency.lean` | Adya, Viotti-Vukolic | `Operation` (read/write), consistency model definitions | Complete |
| `Cap.lean` | Brewer's theorem | `CAPChoice` (CP/AP/CA), `CAPModel`, design implications | Complete |
| `CRDTs.lean` | Shapiro et al. | `JoinSemilattice`, eventually consistent data structures | Complete |
| `Clocks.lean` | Lamport, Mattern, Fidge | `LamportClock`, vector clocks, partial ordering | Complete |
| `CircuitBreaker.lean` | Nygard, Netflix Hystrix | States: closed/open/halfOpen, threshold config | Complete |
| `Replication.lean` | - | `Replica` (primary/secondary/witness roles) | Complete |
| `Saga.lean` | Garcia-Molina & Salem | `SagaStep` with compensation | Complete |
| `MessageQueues.lean` | Vogels, Kafka | `QueueMessage`, delivery guarantees | Complete |
| `Partitioning.lean` | Stonebraker, DeWitt-Gray | `Partition`, range/hash partitioning | Complete |
| `TwoPhaseCommit.lean` | - | 2PC coordinator/participant protocol | Complete |
