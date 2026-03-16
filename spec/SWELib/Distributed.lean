import SWELib.Distributed.Core
import SWELib.Distributed.Clocks
import SWELib.Distributed.Consistency
import SWELib.Distributed.Consensus
import SWELib.Distributed.Consensus.Raft
import SWELib.Distributed.Consensus.Paxos
import SWELib.Distributed.CRDTs
import SWELib.Distributed.Cap
import SWELib.Distributed.Transactions.TwoPhaseCommit
import SWELib.Distributed.Saga
import SWELib.Distributed.Replication
import SWELib.Distributed.Partitioning
import SWELib.Distributed.MessageQueues
import SWELib.Distributed.CircuitBreaker

/-!
# Distributed Systems

Formal specification of distributed systems concepts, algorithms, and patterns.

This module includes:
1. Core distributed system model (Verdi-style LTS)
2. Logical clocks (Lamport, vector clocks)
3. Consistency models (linearizability, causal, eventual)
4. Consensus algorithms (abstract, Raft, Paxos)
5. CRDTs (conflict-free replicated data types)
6. CAP theorem formalization
7. Distributed transactions (2PC, Saga)
8. Replication strategies
9. Data partitioning (sharding)
10. Message queue semantics
11. Circuit breaker pattern

References:
- Lamport, "Time, Clocks, and the Ordering of Events in a Distributed System" (1978)
- Fischer, Lynch, and Paterson, "Impossibility of Distributed Consensus with One Faulty Process" (1985)
- Brewer, "Towards Robust Distributed Systems" (2000) - CAP theorem
- Shapiro et al., "Conflict-Free Replicated Data Types" (2011)
- Ongaro and Ousterhout, "In Search of an Understandable Consensus Algorithm" (2014) - Raft
-/

namespace SWELib.Distributed
end SWELib.Distributed
