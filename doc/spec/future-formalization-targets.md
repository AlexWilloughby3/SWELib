# Future Formalization Targets

Candidate concepts for formalization in SWELib, organized by whether they're best modeled as Nodes/Systems (compositional, interacting, failure-prone) or as standalone spec modules (isolated, algorithmic, structural).

## Node/System Targets (High Priority)

Things where the composition and failure story is the main point. These benefit from LTS, CCS, bisimulation, and migration reasoning.

### Infrastructure Components (common in K8s deployments)

- **Load balancer / reverse proxy** (nginx, HAProxy, Envoy, AWS ALB/NLB) — a Node that routes traffic between backend Nodes. Traffic splitting during migration is exactly MixedVersionState. Health-check-based routing is an LTS property. L4 vs L7 balancing changes the action alphabet.

- **Ingress controller** (nginx-ingress, Traefik, Istio gateway) — the entry point Node for external traffic into a K8s cluster. Manages TLS termination, path-based routing, rate limiting. A System-level concern because it determines which backend Nodes are reachable from outside.

- **Service mesh sidecar** (Envoy in Istio/Linkerd) — a proxy Node composed alongside the app Node in a Pod. Modifies channel properties: adds mTLS, retry logic, circuit breaking, observability. The sidecar + app composition is a natural CCS parallel term with shared localhost channels.

- **API gateway** (Kong, Ambassador, AWS API Gateway) — similar to ingress but with richer policy: auth, rate limiting, request transformation, API versioning. The versioning story connects directly to Migration.

- **Message broker** (Kafka, RabbitMQ, NATS, AWS SQS) — broker as a Node, producers and consumers as Nodes, topics/queues as channels. Durability, ordering, and delivery guarantees are channel properties. Consumer groups and partition assignment are System-level concerns.

- **Cache** (Redis, Memcached, Varnish) — a Node with get/set/evict actions. Cache invalidation during migration is a MixedVersionState problem. Cache-aside vs write-through vs write-behind are different Node LTS definitions. Typically crash-stop (data loss on crash is acceptable).

- **Service discovery / registry** (CoreDNS, Consul, etcd, Eureka) — a Node that other Nodes query to find each other. With Pi-calculus (future), this becomes dynamic topology: the registry sends channel names to clients. For now, modeled as a Node whose outputs inform System topology.

- **Config server** (etcd, Consul KV, AWS Parameter Store, K8s ConfigMaps/Secrets) — a Node that provides configuration to other Nodes. Config changes propagate as messages. Hot reload vs restart-required is a Node LTS property.

- **Sidecar containers** (log shippers like Fluentd/Filebeat, secret injectors like Vault agent, cert rotators) — Nodes composed in a Pod alongside the main app. Each sidecar has its own LTS but shares the Pod's network namespace. Adding a sidecar is a System evolution (sketch 03).

- **CronJob / scheduled task runner** (K8s CronJob, Airflow, Temporal) — a Node that spawns ephemeral worker Nodes on a schedule. The scheduler is crash-recovery; workers are crash-stop. Job completion and retry logic are LTS transitions.

- **Autoscaler** (K8s HPA/VPA/KEDA, AWS Auto Scaling) — a controller Node that observes metrics and adjusts the NodeSet size. Scaling up = adding Nodes to the System. Scaling down = removing Nodes (must respect drain/shutdown policy from sketch 01).

- **Admission controller / policy engine** (OPA/Gatekeeper, Kyverno) — a Node in the deploy pipeline that validates or mutates resources before they enter the cluster. This is the runtime enforcement of Policy (sketch 04).

- **Database** (PostgreSQL, MySQL, MongoDB, CockroachDB) — a Node with query/response actions. Replication (primary + replicas) is a System of database Nodes with specific consistency channel properties. Failover is a System-level state transition. Already partially formalized in `Db/`.

- **Object storage** (S3, MinIO, GCS) — a Node with put/get/delete/list actions. Eventually consistent reads are a channel property. Bucket policies are action alphabet restrictions.

### Operational Infrastructure

- **CI/CD pipeline** (GitHub Actions, GitLab CI, ArgoCD, Flux) — pipeline stages as Nodes, artifacts as messages. A deploy pipeline IS a System that produces a MixedVersionState. Connects directly to sketch 03/04 (migration + policy enforcement).

- **GitOps controller** (ArgoCD, Flux) — a Node that watches a git repo and reconciles cluster state. The reconciliation loop is an LTS. Drift detection is a System-level invariant check.

- **Monitoring / alerting** (Prometheus, Grafana, Datadog, PagerDuty) — collector Nodes scrape metric Nodes. Alert rules are HML-like properties over the System's observable traces. Alert routing is a channel topology concern.

- **Log aggregation** (ELK stack, Loki, Datadog) — log shipper sidecars → aggregator Node → storage Node. The pipeline is a System with specific ordering and reliability channel properties.

- **Secret management** (Vault, AWS Secrets Manager, K8s Secrets) — a Node that dispenses secrets to other Nodes. Rotation is a migration (old secret → new secret with mixed-version window). Access policies are action alphabet restrictions.

### Distributed Systems Primitives

- **Consensus** (Paxos, Raft, PBFT) — already partially in `Distributed/`. Become Protocol instances running in specific System configurations with explicit Network assumptions.

- **Distributed lock / lease** (etcd lease, ZooKeeper, Redis Redlock) — a coordination Node that grants exclusive access. The lock state machine is an LTS. Split-brain during partition is a System-level failure mode.

- **Gossip protocol** (Serf, SWIM, blockchain P2P) — Nodes that propagate state via probabilistic broadcast. The gossip mechanism is a channel type (lossy, duplicating, unordered). Convergence is a liveness property.

## Node/System Targets (Lower Priority)

Natural fits but less urgent — the composition story exists but is less central.

- **DNS resolution chain** — recursive resolver, authoritative server, cache as Nodes. Already have `Networking.Dns`. The resolution chain is a System with specific caching and TTL channel properties.

- **Git** — repo as a Node with state (commit graph) and actions (commit, merge, push, pull). Multi-repo or monorepo is a System. Merge conflict resolution is a System-level concern. Could be interesting for reasoning about merge safety during concurrent development.

- **Distributed file system** (HDFS, Ceph, GlusterFS, NFS) — storage Nodes with replication and consistency channels. Local file systems stay standalone; distributed ones are natural Systems.

- **CDN** (CloudFront, Fastly, Cloudflare) — edge cache Nodes with origin pull channels. Cache invalidation propagation is a System-level concern with latency properties.

- **Email** (SMTP relay chain) — MTA Nodes with store-and-forward channels. Delivery semantics (at-least-once, bounce handling) are channel/Node properties.

## Standalone Spec Targets (Not Node/System)

Things better formalized as self-contained modules. No composition story — you reason about them in isolation.

- **Package managers** (apt, npm, cargo, pip) — dependency resolution is constraint satisfaction, not concurrent composition. Version constraints, resolution algorithms, lockfile semantics. *Exception*: if reasoning about package install as a CI pipeline stage, it becomes a Node in that context.

- **File systems** (POSIX semantics) — local FS operations (read/write/create/mkdir) as a state machine with POSIX guarantees. inode model, permissions, hard/soft links. Not concurrent unless distributed (see above).

- **Build systems** (make, bazel, gradle) — build DAG, caching, incrementality. Dependency graph, not concurrent System. *Exception*: distributed build (Bazel remote execution) is a System.

- **Compilers / type checkers** — sequential transformation pipeline. Formalize type rules, optimization passes, IR semantics. No failure/interaction story.

- **Serialization formats** (protobuf, Avro, MessagePack, CBOR) — schema definition, encoding/decoding, schema evolution rules. Pure functions on data. Useful as action payload types in Node/System contexts.

- **Compression** (gzip, zstd, lz4) — pure algorithmic. Correctness = roundtrip property.

- **Encoding** (base64, hex, URL encoding, UTF-8) — pure functions. Already partially in `Basics/`.

- **Cryptographic primitives** (hashing, signing, encryption) — pure functions with security properties. Already partially in `Security/`. Used as building blocks in TLS channel processes and JWT Nodes.

- **Schema languages** (JSON Schema, OpenAPI, GraphQL SDL, SQL DDL) — structural validation. Already partially in `Basics/JsonSchema`. Used by Migration (sketch 03) for schema evolution analysis.

- **Regular expressions / grammars** — already decided (D-009). Pure syntax + matching semantics.

## Crosscutting Concerns

Things that aren't Nodes themselves but show up as properties/aspects across many Nodes:

- **Rate limiting** — a channel property or Node-level action constraint. Shows up in API gateways, load balancers, sidecars.
- **Circuit breaking** — a channel state machine (closed → open → half-open). Shows up in service mesh sidecars and client libraries.
- **Retry logic** — a channel wrapper that transforms a lossy channel into a fair-lossy one. Shows up everywhere.
- **Backpressure** — a channel property where the receiver can slow the sender. Shows up in message brokers, streaming systems.
- **Health checking** — a Node action that all Nodes should support. Liveness vs readiness vs startup probes (K8s distinction).
- **Graceful shutdown** — a Node LTS pattern (stop accepting → drain → terminate). Shows up in every server Node.
- **Leader election** — a Protocol that runs within a System of Nodes. Shows up in database replication, distributed locks, controller HA.
- **Observability** (metrics, traces, logs) — side-channel outputs from Nodes. Tracing is a System-level concern (distributed trace = causal ordering of Node actions across a request path).
