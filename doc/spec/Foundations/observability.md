# Sketch: Observability

## What This Sketch Defines

Observability is the formalization of **runtime property checking, assumption validation, and quantitative measurement** within the Node/System framework. It bridges the gap between what formal verification proves at compile time ("all traces satisfying these axioms have this property") and what actually happens at runtime ("is this specific trace satisfying those axioms?").

The core thesis: **everything traditionally left outside the formalization — load, latency, resource consumption, error rates, SLA compliance — belongs inside it.** The model should be able to prove "if request rate ≤ 1000/s, then CPU utilization ≤ 90%" as a theorem, not leave it as an informal hope. The assumptions ("request rate ≤ 1000/s") are explicit axioms, and runtime monitoring validates them.

## Three Layers of Observability

### Layer 1: Assumption Monitoring (Are My Axioms Holding?)

Every formal proof is conditional: "IF these assumptions hold, THEN this property holds." The trust boundary (`trust-boundary.md`) lists axioms about TLS, PostgreSQL, syscalls, etc. But there's a broader class of assumptions that live above the trust boundary — assumptions about the **environment** the system operates in:

- Request rate from the public internet ≤ R
- External API (Stripe, Twilio) responds within T ms with probability ≥ p
- Database query execution time for query Q is ≤ D ms
- Memory allocation succeeds (system has available RAM)
- DNS resolution returns within 5s

These are **environment axioms** — they bound the behavior of things outside your system. Every System-level proof that depends on them should carry them as explicit hypotheses. Runtime monitoring checks whether reality matches these hypotheses.

```
-- Environment assumption: request rate is bounded
axiom request_rate_bounded : ∀ window : TimeWindow,
  window.duration = 1.second →
  count_requests window ≤ max_request_rate

-- System theorem conditional on the assumption:
theorem cpu_utilization_bounded
    (h_rate : request_rate_bounded)
    (h_handler : handler_cost_bounded)
    : cpu_utilization ≤ 0.90
```

When runtime monitoring detects `count_requests > max_request_rate`, it's not reporting a bug — it's reporting an **axiom violation**. The system's guarantees no longer hold. This is categorically different from a bug: the system may be working perfectly, but its operating conditions have exceeded spec.

### Layer 2: Quantitative Properties (Performance, Resources, SLAs)

The formal model should reason about time, throughput, and resource consumption — not abstract them away. This requires extending the LTS model with quantitative annotations:

```
-- A QuantitativeNode adds resource consumption to transitions
structure QuantitativeNode (S α : Type) extends LTS S α where
  -- Each transition consumes resources
  cost : S → α → S → ResourceCost
  -- Each state has a resource footprint
  footprint : S → ResourceFootprint

structure ResourceCost where
  cpuCycles : Nat      -- CPU work
  memoryDelta : Int    -- bytes allocated (+) or freed (-)
  ioCalls : Nat        -- syscalls / I/O operations
  networkBytes : Nat   -- bytes sent/received

structure ResourceFootprint where
  memoryUsed : Nat
  openFDs : Nat
  activeConnections : Nat
  goroutines : Nat     -- or threads, or async tasks
```

With this, you can state and prove quantitative theorems:

```
-- "Processing a request costs at most C CPU cycles"
theorem handler_cost_bounded :
  ∀ s req s', node.Tr s (handle req) s' →
    (node.cost s (handle req) s').cpuCycles ≤ C

-- "If request rate ≤ R and each request costs ≤ C,
--  then CPU utilization ≤ R * C / total_cycles"
theorem cpu_utilization_bounded
    (h_rate : request_rate ≤ R)
    (h_cost : ∀ req, handler_cost req ≤ C)
    : cpu_utilization ≤ R * C / cycles_per_second

-- "Memory usage is bounded if every allocation has a matching deallocation"
theorem memory_bounded
    (h_linear : ∀ alloc, eventually_freed alloc)
    : ∀ s, (node.footprint s).memoryUsed ≤ maxMemory

-- "Connection pool size never exceeds limit"
-- (Already close to what Db.ConnectionPool formalizes)
theorem pool_bounded :
  ∀ s, (node.footprint s).activeConnections ≤ poolSize
```

### Layer 3: Trace Analysis (What's Actually Happening?)

A **trace** is a sequence of transitions the system actually takes at runtime. Formally, it's a path through the LTS. Observability is about collecting traces and evaluating properties against them.

```
-- A runtime trace is a finite path through the LTS
structure Trace (S α : Type) where
  states : List S
  actions : List α
  valid : ∀ i, node.Tr (states[i]) (actions[i]) (states[i+1])

-- A trace event is a single observed transition with metadata
structure TraceEvent (α : Type) where
  action : α
  timestamp : Timestamp
  duration : Duration
  resourceCost : ResourceCost
  sourceNode : NodeId
  traceId : TraceId       -- for distributed tracing (correlating across Nodes)
  spanId : SpanId         -- for nested operations within a Node
```

## Runtime Monitoring as a Node

A monitoring system (Datadog, Sentry, Prometheus) is a Node in the System. It receives trace events over channels from other Nodes and evaluates properties:

```
System = (App | Database | Cache | Monitor) \ internal_channels

-- Monitor receives trace events and evaluates predicates
Monitor = recv_trace_event . evaluate . (emit_alert + τ) . Monitor
```

### What the Monitor Evaluates

The Monitor evaluates three categories of properties at runtime:

**1. Assumption checks** — are the environment axioms holding?

```
-- "Request rate hasn't exceeded our assumption"
def check_rate_assumption (events : Window TraceEvent) : AssumptionStatus :=
  if count_requests events ≤ max_request_rate
  then .holding
  else .violated { actual := count_requests events, assumed := max_request_rate }

-- "External API is responding within assumed bounds"
def check_api_latency (events : Window TraceEvent) : AssumptionStatus :=
  let p99 := percentile 0.99 (latencies events)
  if p99 ≤ assumed_api_latency
  then .holding
  else .violated { actual := p99, assumed := assumed_api_latency }
```

**2. Quantitative property checks** — are the proved bounds holding in practice?

```
-- "CPU utilization is within proved bound"
-- (This should always pass if assumptions hold — if it doesn't,
--  either an assumption is violated or the cost model is wrong)
def check_cpu_bound (metrics : Metrics) : PropertyStatus :=
  if metrics.cpuUtilization ≤ proved_cpu_bound
  then .satisfied
  else .violated  -- This is serious: the proof may be wrong

-- "Memory usage within proved bound"
def check_memory_bound (metrics : Metrics) : PropertyStatus :=
  if metrics.memoryUsed ≤ proved_memory_bound
  then .satisfied
  else .violated
```

**3. State frequency analysis** — how often are we hitting certain states?

```
-- "How often do users reach the error state?"
-- This isn't about bugs (the error handling is proven correct)
-- It's about UX/spec quality
def state_frequency (events : Window TraceEvent) (state : S) : Rate :=
  count_transitions_to state events / events.duration

-- "Users are hitting the 'invalid_input' state 500 times/minute"
-- → The spec correctly rejects invalid input
-- → But maybe the API design sucks and users don't understand the contract
-- → Surface this as a product issue, not a bug
```

## External API Assumptions

When your system calls an external API that doesn't have a Lean formalization, you make assumptions about its behavior. These should be explicit axioms in the trust boundary, and runtime monitoring should validate them.

```
-- Axioms about Stripe's behavior (we can't verify Stripe's code)
namespace ExternalApi.Stripe

  -- "Stripe charges are idempotent with idempotency keys"
  axiom charge_idempotent :
    ∀ key amount, charge key amount >> charge key amount ≈ charge key amount

  -- "Stripe responds within 30 seconds"
  axiom response_bounded : ∀ req, response_time req ≤ 30.seconds

  -- "Stripe returns well-formed JSON matching their published schema"
  axiom response_schema_valid : ∀ resp, valid_schema stripe_charge_schema resp

  -- "Stripe's error codes are a known finite set"
  axiom error_codes_known : ∀ err, err ∈ known_stripe_errors

end ExternalApi.Stripe
```

Runtime monitoring validates these:

```
-- Monitor detects: Stripe returned a 500 and took 45 seconds
-- → axiom `response_bounded` is violated
-- → all theorems depending on Stripe latency bounds are suspect
-- → alert: "External assumption violated: Stripe latency exceeds 30s"

-- Monitor detects: Stripe returned an error code we've never seen
-- → axiom `error_codes_known` may be violated
-- → our error handling may have an unhandled case
-- → alert: "Unknown Stripe error code: new_error_xyz"
```

### External API Contract Versioning

External APIs change. The axioms about them have a **validity window**:

```
structure ExternalApiContract where
  provider : String
  version : ApiVersion          -- e.g., "2024-03-01" for Stripe API version
  axioms : List Axiom
  lastValidated : Timestamp     -- when we last confirmed these hold
  validationMethod : ValidationMethod  -- how we check (runtime monitoring, integration tests, manual review)

-- When Stripe publishes a new API version, contracts need re-validation
-- Runtime monitoring continuously validates — if violations spike after
-- a provider change, surface it immediately
```

## Probabilistic Model Validation

When the model uses probabilistic reasoning ("this fails with probability ≤ 0.001"), runtime data should validate the model's accuracy. This is where the "99.9% thing happens a lot and you realize the model is wrong" scenario lives.

### Model-vs-Reality Divergence Detection

```
-- The model claims: P(request failure) ≤ 0.001
-- Runtime observes: 50 failures in 10,000 requests = 0.005

structure ProbabilisticAssumption where
  event : String
  modelProbability : Float      -- what the model says
  confidenceInterval : Float    -- acceptable deviation

structure ModelValidation where
  assumption : ProbabilisticAssumption
  observedRate : Float
  sampleSize : Nat
  pValue : Float                -- statistical significance of divergence

-- Formally: chi-squared test or similar against the model distribution
-- If p-value < threshold, the model is wrong — not just unlucky
def model_divergence_significant (v : ModelValidation) : Prop :=
  v.pValue < significance_threshold ∧ v.sampleSize ≥ min_sample_size
```

### Categories of Model Failure

When runtime data contradicts the probabilistic model, there are distinct failure modes:

**1. Assumption drift** — the world changed, but the model hasn't been updated.
- Example: "Failure probability was 0.001 when we had 3 replicas. We scaled down to 2 replicas and didn't update the model. Now failure probability is 0.01."
- Detection: monotonic increase in observed rate relative to model.
- Response: update the model parameters, re-derive affected theorems.

**2. Correlation the model ignores** — events the model treats as independent aren't.
- Example: "The model says P(Node₁ fails) * P(Node₂ fails) = 0.001 * 0.001 = 0.000001. But both Nodes are on the same physical host, so failures are correlated."
- Detection: joint failure rate >> product of individual rates.
- Response: the model's independence assumption is wrong. Need correlated failure model.

**3. Fat tails** — the model assumes a distribution that doesn't match reality.
- Example: "The model assumes latency is normally distributed with mean 50ms, σ=10ms. But real latency has occasional 5-second spikes (fat tail). The model says p99 = 73ms, reality says p99 = 800ms."
- Detection: observed distribution fails goodness-of-fit test against assumed distribution.
- Response: switch to a heavy-tailed distribution (log-normal, Pareto) or model the spike mechanism explicitly.

**4. Rare event underestimation** — the model assigns too-low probability to catastrophic events.
- Example: "The model says 'cascading failure across all replicas' has probability 10⁻⁹. In practice, correlated deployment bugs cause this quarterly."
- Detection: catastrophic events observed more frequently than model predicts.
- Response: the model is likely missing a failure mode. Add it.

## State Frequency Tracking (Spec Quality Signal)

This is distinct from error monitoring. The system is working correctly — the proof guarantees that. But some correct behaviors reveal **spec quality problems**:

```
-- States we want to track frequency for
inductive TrackedState where
  | userInputRejected (reason : RejectionReason)    -- spec says "reject this" — but how often?
  | retryExhausted (operation : String)              -- retries ran out — is the retry policy too aggressive?
  | gracefulDegradation (feature : String)            -- fallback activated — is the primary too fragile?
  | rateLimited (client : ClientId)                  -- client hit rate limit — is the limit too low?
  | timeoutExpired (operation : String)               -- operation timed out — is the timeout too tight?

structure StateFrequencyReport where
  state : TrackedState
  rate : Rate                    -- occurrences per time window
  trend : Trend                  -- increasing, decreasing, stable
  affectedUsers : Nat            -- unique users hitting this state
  exampleTraces : List TraceId   -- representative traces for debugging
```

### Closing the Loop: Runtime → Spec Improvement

The key insight is that state frequency data feeds back into the formal model:

```
-- Observation: users hit `userInputRejected(InvalidDateFormat)` 10,000 times/day
-- The spec is correct: invalid dates SHOULD be rejected
-- But this signals: the date format contract is confusing to users
-- Action: either improve docs/UX, or relax the spec to accept more formats

-- Observation: `retryExhausted(DatabaseQuery)` happens 50 times/hour
-- The retry policy is proven correct: it retries N times with backoff
-- But if retries exhaust this often, either:
--   (a) the retry count N is too low (spec parameter needs tuning), or
--   (b) the database is consistently overloaded (environment assumption violated)
-- Action: check if database latency assumptions still hold

-- Observation: `gracefulDegradation(RecommendationEngine)` is active 30% of the time
-- The fallback is proven correct: when the ML service is down, serve cached results
-- But 30% degradation rate suggests the ML service is unreliable
-- Action: either improve ML service reliability or reconsider the dependency
```

This makes observability a **spec refinement tool**, not just an ops tool.

## Formalization of Monitoring Properties

The monitoring system itself should satisfy formal properties:

### Completeness

Every axiom violation produces an alert:

```
-- If an environment assumption is violated in a time window,
-- the monitor emits an alert within detection_latency
theorem monitor_complete :
  ∀ assumption window,
    assumption.violated_in window →
    ∃ alert, alert.timestamp ≤ window.end + detection_latency ∧
             alert.assumption = assumption
```

### Soundness

No false positives from expected transitions:

```
-- If all assumptions hold and the system is in a proved-safe state,
-- the monitor does not emit violation alerts
theorem monitor_sound :
  ∀ window,
    (∀ assumption, assumption.holds_in window) →
    ¬ ∃ alert, alert.type = .assumption_violated ∧ alert.in window
```

### Non-Interference

The monitoring system doesn't perturb the monitored system beyond acceptable bounds:

```
-- Monitoring overhead is bounded
-- (the observer effect — monitoring shouldn't cause the problems it detects)
theorem monitor_overhead_bounded :
  ∀ system,
    cpu_overhead (system.with_monitor) ≤ monitoring_cpu_budget ∧
    memory_overhead (system.with_monitor) ≤ monitoring_memory_budget ∧
    latency_overhead (system.with_monitor) ≤ monitoring_latency_budget

-- Removing the monitor doesn't change system correctness
-- (monitoring is observational, not behavioral)
theorem monitor_non_interfering :
  ∀ system property,
    system.satisfies property ↔ (system.with_monitor).satisfies property
```

### Consistency

Alert rules don't contradict each other:

```
-- No configuration where alert A fires and alert B fires,
-- but A says "system healthy" and B says "system degraded"
theorem alert_consistency :
  ∀ a b : AlertRule,
    a.contradicts b →
    ¬ ∃ state, a.fires state ∧ b.fires state
```

## Interaction with Timed CCS

Most quantitative observability properties require **timed CCS** (mentioned as a future extension in sketches 01 and 05). Until timed CCS arrives, we handle this in two ways:

### What We Can Do Now (Without Time)

- **State reachability**: "Is this bad state reachable?" (safety, via DFA/HML)
- **Trace patterns**: "Does this sequence of transitions ever occur?" (regular property)
- **Resource bounds**: "Memory/connections never exceed limit" (state invariant)
- **Logical correctness**: "Every request gets a correct response" (not how fast, just that it happens)
- **Assumption structure**: declare which assumptions exist and what depends on them, even if we can't yet prove the quantitative bounds

### What Requires Timed CCS (Formalized But Not Yet Provable)

- **Latency bounds**: "Response within 500ms" (needs time on transitions)
- **Throughput**: "Process 1000 requests/second" (needs rate = count/time)
- **SLA compliance**: "99.9% availability" (needs time-weighted state occupancy)
- **Timeout correctness**: "If no response in T, retry" (needs timed transitions)

These are **stated as axioms now** and converted to theorems when timed CCS arrives:

```
-- Today: axiom (we believe it but can't prove it from the model)
axiom response_latency_bounded : ∀ req, latency req ≤ 500.ms

-- Future (with timed CCS): theorem (proved from the timed LTS)
theorem response_latency_bounded : ∀ req s s' t t',
  timedNode.Tr (s, t) (handle req) (s', t') →
  t' - t ≤ 500.ms
```

### What Requires Probabilistic LTS

- **Availability**: "99.9% uptime" (needs probability of being in healthy state)
- **Error rates**: "Failure probability ≤ 0.001" (needs probabilistic transitions)
- **Tail latencies**: "p99 latency ≤ 200ms" (needs probability distribution over timed transitions)
- **Model validation**: statistical tests comparing observed vs modeled distributions

## Distributed Tracing as Trace Composition

In a distributed system, a single user request generates a **distributed trace** — a tree of spans across multiple Nodes. This is formalized as composition of per-Node traces:

```
-- A span is a segment of work within a single Node
structure Span where
  spanId : SpanId
  parentSpanId : Option SpanId
  nodeId : NodeId
  operation : String
  startTime : Timestamp
  endTime : Timestamp
  events : List TraceEvent
  status : SpanStatus

-- A distributed trace is a tree of spans rooted at the entry point
structure DistributedTrace where
  traceId : TraceId
  rootSpan : Span
  spans : List Span
  -- Structural property: spans form a tree
  tree_valid : ∀ span ∈ spans,
    span.parentSpanId = none → span = rootSpan ∨
    ∃ parent ∈ spans, span.parentSpanId = some parent.spanId

-- The distributed trace is a projection of the System's LTS trace
-- onto individual Nodes, correlated by traceId
theorem distributed_trace_is_projection :
  ∀ systemTrace : Trace System,
    ∀ nodeId,
      project systemTrace nodeId = node_local_trace nodeId
```

## Alerting as Temporal Logic

Alert rules are temporal logic formulas evaluated over the trace stream. This directly connects to HML and the automata theory in CSLib:

```
-- "If error rate exceeds 5% for 5 minutes, alert"
-- This is an LTL formula: G(error_rate > 0.05 ∧ duration ≥ 5min → alert)

-- "If latency increases monotonically for 10 minutes, alert"
-- LTL: G(monotonic_increase(latency, 10min) → alert)

-- "If three different assumptions are violated simultaneously, page oncall"
-- HML: [violation₁] [violation₂] [violation₃] ⟨page⟩ true

-- Alert rules are DFA/Büchi automata over the trace event stream
-- (CSLib provides the automata theory)
structure AlertRule where
  name : String
  formula : TemporalFormula TraceEvent   -- what to check
  severity : Severity                     -- info, warning, critical
  automaton : DFA TraceEvent AlertState   -- compiled formula for efficient evaluation
  -- Proof that the automaton accepts exactly the traces matching the formula
  correct : ∀ trace, automaton.accepts trace ↔ formula.satisfied_by trace
```

## Meta-Observability: Monitoring the Monitor

The monitoring system itself needs monitoring (who watches the watchers?). This is a real concern:

```
-- The monitor is a Node, so it has its own resource constraints
-- If the trace event rate exceeds the monitor's processing capacity,
-- it drops events — and may miss violations

-- Key property: monitor capacity ≥ system event rate
-- This is itself an assumption that needs runtime validation

-- Backpressure: if the monitor can't keep up, what happens?
-- Option 1: drop events (lossy monitoring — may miss violations)
-- Option 2: slow down the system (monitoring interferes — violates non-interference)
-- Option 3: sample (probabilistic monitoring — weaker guarantees)

-- The choice is a design decision with formal consequences:
-- Sampling at rate r means violations are detected with probability ≥ 1-(1-r)^k
-- where k is the number of violating events in the window
```

## Module Structure

```
SWELib/Observability/
  Types.lean                -- TraceEvent, Span, DistributedTrace, ResourceCost, ResourceFootprint
  Assumptions.lean          -- EnvironmentAxiom, AssumptionStatus, ExternalApiContract
  QuantitativeNode.lean     -- QuantitativeNode extending LTS with costs/footprints
  Traces.lean               -- Trace, trace projection, trace composition
  Monitor.lean              -- Monitor as Node, completeness/soundness/non-interference
  Alerts.lean               -- AlertRule, temporal formula compilation, alert consistency
  StateTracking.lean        -- TrackedState, StateFrequencyReport, trend detection
  Probabilistic/
    ModelValidation.lean    -- ProbabilisticAssumption, divergence detection, statistical tests
    DistributionFit.lean    -- Goodness-of-fit, fat tail detection, correlation detection
  ExternalApis/
    Contract.lean           -- ExternalApiContract, versioning, validation
    Axioms.lean             -- Standard axiom patterns for common external services
  Performance/
    ResourceModel.lean      -- CPU, memory, I/O cost modeling
    CapacityPlanning.lean   -- Throughput bounds, scaling properties
    SLA.lean                -- Availability, latency percentiles, error budgets
```

## Relationship to Other Sketches

- **Node (sketch 01)**: QuantitativeNode extends Node with resource costs per transition. TraceEvent is a recorded Node transition with metadata. State frequency tracking observes the Node's LTS path.
- **System (sketch 02)**: DistributedTrace is a projection of the System-level LTS trace. Monitor is a Node in the System's CCS composition.
- **Migration (sketch 03)**: When a migration changes the Node's LTS, the monitoring assumptions may need updating. State frequency comparison before/after migration detects behavioral regressions.
- **Policy (sketch 04)**: Alert rules ARE policy — temporal logic formulas over system behavior. ComplianceFramework requirements often include monitoring requirements (SOC2 requires audit logging, HIPAA requires access monitoring).
- **Network (sketch 05)**: Network channel properties (latency, reliability) are observable. External API contracts are assumptions about channels to external Nodes. Distributed tracing requires causal ordering across channels.
- **Isolation (sketch 06)**: Resource limits (cgroups, memory limits) are QuantitativeNode constraints. Monitoring resource consumption validates isolation boundaries.
- **Security (sketch 08)**: Security monitoring (anomaly detection, auth failure rates) is state frequency tracking on security-relevant states. Audit logging is a form of trace collection with non-repudiation requirements.

## Relationship to Existing SWELib Modules

- `Networking/Http/StatusCode` — HTTP status codes appear in trace events. 5xx rate is a tracked state frequency. 4xx rate is a spec quality signal (users misusing the API).
- `Db/ConnectionPool` — Pool utilization is a quantitative property with proved bounds. Runtime monitoring validates the pool sizing assumptions.
- `Networking/Tls` — TLS handshake failures are tracked states. Certificate expiry monitoring is an assumption check (axiom: "certificate is valid" has a time bound).
- `Security/Jwt` — JWT validation failure rate is a state frequency metric. Anomalous patterns (sudden spike in invalid tokens) suggest an attack, not a spec bug.
- `OS/Memory` — Memory allocation/deallocation is a quantitative property. Leak detection is model validation: if the proof says memory is bounded but runtime shows growth, either the proof has a wrong assumption or the bridge axioms don't hold.
- `Cloud/K8s` — Pod health checks, readiness probes, and liveness probes are assumption monitoring for the container orchestration layer.
- `OS/Epoll` — Event loop saturation is a quantitative property. If epoll_wait returns more events than the model assumes, throughput bounds may not hold.

## Key Theorems Sketch

### Assumption Monitoring
- If all environment axioms hold, the system satisfies all proved properties (soundness of conditional proofs — this is the fundamental theorem)
- If an environment axiom is violated, the monitor detects it within bounded time (monitor completeness)
- The set of environment axioms is sufficient — no "hidden" assumptions (axiom coverage)

### Quantitative Properties
- If request rate ≤ R and handler cost ≤ C, then CPU utilization ≤ R*C/capacity (resource bound)
- If all allocations are freed and allocation rate ≤ A, then memory usage ≤ A * max_lifetime (memory bound)
- Connection pool utilization ≤ pool_size under stated load assumptions (pool bound)

### Monitor Properties
- Monitor is complete: every axiom violation generates an alert (no silent failures)
- Monitor is sound: no alerts when all axioms hold (no false positives)
- Monitor is non-interfering: removing the monitor doesn't change system behavior (observation doesn't perturb)
- Monitor overhead is bounded: monitoring costs ≤ budget (the monitor doesn't become the bottleneck)
- Alert rules are consistent: no contradictory alerts from the same system state

### Model Validation
- If observed failure rate diverges significantly from modeled rate, the model is flagged for review (statistical test)
- If correlated failures exceed independent-failure prediction, the independence assumption is flagged (correlation detection)
- Distribution fit test detects fat tails that the model underestimates (tail risk)

### Trace Properties
- Distributed trace is a valid projection of the system trace (trace composition correctness)
- Trace collection preserves causal ordering (if event A caused event B, A appears before B in the trace)
- Sampled traces provide probabilistic guarantees on violation detection (sampling theory)

## Extension Points

### Cost Model Refinement (future)

The initial cost model (cpuCycles, memoryDelta, etc.) is coarse. Future refinements:

- **Cache-aware costs**: L1 hit vs L3 miss vs RAM access have 100x cost differences
- **I/O-aware costs**: SSD read vs HDD read vs network read
- **Contention-aware costs**: cost under lock contention vs uncontended
- **GC-aware costs**: allocation cost includes amortized GC pressure

Each refinement makes the quantitative proofs tighter but doesn't change the framework.

### Anomaly Detection (future, needs ML formalization)

Beyond threshold-based alerting, anomaly detection learns "normal" behavior and flags deviations. Formalizing this requires:

- Statistical models of "normal" trace distributions
- Formal bounds on false positive/negative rates
- Proof that the anomaly detector converges to the true distribution

### Chaos Engineering Integration (future)

Chaos engineering (intentionally injecting failures) is **axiom violation testing**: deliberately break an assumption and observe whether the monitoring detects it and the system degrades gracefully.

```
-- Chaos test: violate the "database responds within 100ms" axiom
-- Expected: monitor detects the violation, system activates circuit breaker,
--           gracefulDegradation(DatabaseQuery) state is entered
-- This validates both the monitoring completeness and the degradation path
```

### SLO/Error Budget Formalization (future)

SLOs (Service Level Objectives) are quantitative temporal properties:

```
-- "99.9% of requests complete successfully within 500ms, measured over 30 days"
-- This is a conjunction of:
--   (a) availability: P(success) ≥ 0.999 over 30-day window
--   (b) latency: P(latency ≤ 500ms | success) ≥ 0.999 over 30-day window
-- Error budget = 1 - SLO = 0.001 = allowed failure rate
-- Error budget consumption rate is a real-time metric
```

## Source Specs / Prior Art

- **CSLib** (Lean): LTS traces, HML, Büchi automata — formal foundations for trace analysis and alerting
- **OpenTelemetry specification**: industry standard for traces, metrics, logs — informs TraceEvent and Span structure
- **Prometheus data model**: time series with labels, PromQL for querying — informs metric collection and alerting
- **Google SRE Book** (2016): SLIs, SLOs, error budgets — informs SLA formalization
- **Bartocci et al., "Specification-Based Monitoring of Cyber-Physical Systems"** (2018): runtime verification of temporal properties — direct theoretical foundation
- **Leucker & Schallhart, "A Brief Account of Runtime Verification"** (2009): survey of runtime verification connecting formal methods to monitoring
- **Havelund & Rosu, "Monitoring Programs using Rewriting"** (2001): trace monitoring via automata compilation
- **Netflix Chaos Monkey / Gremlin**: chaos engineering practice — informs axiom violation testing
- **Datadog, Sentry, Honeycomb**: commercial observability platforms — inform practical requirements for trace collection, alerting, and dashboarding
