# Sketch: Migration Constraints & Compliance

## What This Sketch Defines

Two things SWELib provides that developers wouldn't naturally arrive at on their own:

1. **MigrationConstraint** — predicates over the *transition* between two system versions (not expressible as a theorem about either version alone)
2. **ComplianceFramework** — formalization of compliance requirements (SOC2, HIPAA, etc.) so that "we comply" becomes a machine-checked theorem

Everything else (organizing theorems into policies, lint rules, CI plumbing) is left to developers — Lean's type checker is the enforcement layer, not a custom policy framework.

## Migration Constraints

### The Core Type

A migration constraint is a property about the transition from one System to another. It references both versions and the structured diff between them:

```
def MigrationConstraint := (old new : System) → Migration old new → Prop
```

This can't be expressed as a standalone theorem about the new system — it's inherently relational.

### Why This Is Non-Obvious

A developer writing Lean theorems about their system would naturally write things like:

```
theorem v2_has_auth : ∀ e ∈ v2.endpoints, hasAuth e := by ...
```

This proves v2 is correct. But it says nothing about whether the *transition* from v1 to v2 is safe. Migration constraints capture:

- Is the mixed-version state safe during rollout? (Some Nodes on v1, some on v2)
- Can v1 clients talk to v2 servers? (Backward compatibility)
- Can you roll back if v2 breaks? (Rollback safety)
- Does the deployment order respect dependencies? (Phase ordering)

Without the `MigrationConstraint` type and the `MixedVersionState` / `DeploymentPlan` types from sketch 03, developers would have to reinvent this framing each time.

### Standard Migration Constraints

These are constraints that apply broadly across systems. SWELib provides them as reusable predicates:

**Backward compatibility**: for every modified Node, the new version simulates the old version (every old behavior is preserved).

```
def backwardCompatible : MigrationConstraint := fun old new m =>
  ∀ (id, node_old, node_new) ∈ m.nodesModified,
    ForwardSimulation node_new.lts node_old.lts (some R)
```

**Mixed-state safety**: for every reachable MixedVersionState during the deployment plan, the composed system satisfies the required invariants.

```
def mixedStateSafe (invariants : List (System → Prop)) : MigrationConstraint :=
  fun old new m =>
    ∀ mixed : MixedVersionState old new,
      ∀ inv ∈ invariants, inv mixed.mixedSystem
```

**Additive-only**: all changes in the migration are additive (new optional fields, new endpoints, new Nodes). Fully decidable — just inspect the migration diff.

```
def additiveOnly : MigrationConstraint := fun _ _ m =>
  ∀ ck ∈ m.changeKinds, ck = .additive
```

**Rollback exists**: a valid reverse migration exists.

```
def rollbackExists : MigrationConstraint := fun old new m =>
  ∃ rollback : Migration new old, rollback.consistent
```

**Deployment order respects dependencies**: if Node A depends on Node B, B transitions in an earlier (or equal) phase. Connects to the DeploymentPlan from sketch 03.

```
def orderedDeployment (deps : NodeId → NodeId → Prop) : MigrationConstraint :=
  fun old new m =>
    ∀ plan : DeploymentPlan old new,
      ∀ a b, deps a b → phaseOf plan b ≤ phaseOf plan a
```

### Key Theorems

- **Bisimilar migration is trivially safe**: if every modified Node is bisimilar to its old version, all migration constraints that depend on simulation/compatibility hold automatically (CCS congruence)
- **Additive migrations preserve backward compatibility**: if all changes are additive, backward compatibility holds (new actions don't interfere with existing synchronization)
- **Transitivity**: if migration A→B and B→C both satisfy a constraint, then A→B→C satisfies it (for simulation-based constraints — follows from transitivity of simulation)
- **Atomic deploys skip mixed-state constraints**: blue-green deployments (single phase, instant cutover) trivially satisfy mixed-state safety because no mixed state exists

## Compliance Frameworks

### The Core Type

A compliance framework is a named collection of requirements, formalized as system invariants and migration constraints:

```
structure ComplianceFramework where
  name : String                                    -- "SOC2", "HIPAA", "PCI-DSS"
  requirements : List (System → Prop)              -- properties of the system
  migrationRequirements : List MigrationConstraint  -- properties of transitions
```

### Coverage

Coverage says: for every requirement in the framework, there exists a theorem about your system that implies it.

```
def covers
    (systemInvariants : List (System → Prop))
    (migrationConstraints : List MigrationConstraint)
    (framework : ComplianceFramework) : Prop :=
  (∀ req ∈ framework.requirements,
    ∃ inv ∈ systemInvariants, ∀ s, inv s → req s) ∧
  (∀ req ∈ framework.migrationRequirements,
    ∃ mc ∈ migrationConstraints, ∀ old new m, mc old new m → req old new m)
```

Note: `covers` doesn't bundle invariants into a `SystemPolicy` type. Your invariants are just Lean theorems in your codebase. `covers` checks that the theorems you've proved are *strong enough* to imply the compliance requirements.

### Why Formalize This

Without formalization, "we comply with SOC2" is a claim in a slide deck, verified by an auditor reading docs once a year. With formalization:

1. The compliance requirements are written as formal predicates (a one-time effort, could be community-maintained)
2. Your system's invariants are proved in Lean (you're doing this anyway)
3. `covers` is a theorem that your invariants imply the requirements — machine-checked
4. If you change your system in a way that breaks a requirement, the `covers` theorem stops compiling

The auditor's job shrinks from "verify the whole system" to "verify the formalization of SOC2 requirements is faithful to the actual SOC2 spec." That's a much smaller, one-time review.

### Key Theorems

- **Coverage preservation under tightening**: if you add an invariant to your system, coverage is preserved (you only ever gain coverage, never lose it)
- **Coverage is monotone in requirements**: if framework A's requirements are a subset of framework B's, covering B implies covering A
- **Migration coverage composes**: if you cover framework F's migration requirements with constraints C₁...Cₙ, and a migration satisfies all of C₁...Cₙ, it satisfies all of F's migration requirements

## Relationship to Other Sketches

- Migration constraints operate on **Migration** and **MixedVersionState** types from sketch 03
- **DeploymentPlan** (sketch 03) connects to `orderedDeployment` and `mixedStateSafe` constraints
- The formal tools (bisimulation, simulation, HML) come from CSLib
- System invariants are just `System → Prop` where `System` is from sketch 02

## Source Specs / Prior Art

- **CSLib**: bisimulation for equivalence checking, simulation for refinement, HML for behavioral properties
- **buf**: protobuf breaking change detection — an informal version of `backwardCompatible` + `additiveOnly`
- **SOC2 / HIPAA / PCI-DSS**: compliance frameworks as informal property sets
- **Google "Prodspec"**: formal system descriptions checked in CI (described in SRE book)
- **Alpern & Schneider, "Defining Liveness"** (1985): safety/liveness decomposition
