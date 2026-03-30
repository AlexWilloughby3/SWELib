# Sketch: Security Foundations

## What This Sketch Defines

The abstract security layer that sits between the low-level protocol modules (TLS, JWT, PKI, crypto) and the systems framework (CCS, LTS, adversary models from sketch 08). This sketch formalizes three things:

1. **Access control models** — abstract framework for RBAC, ABAC, and capability-based security, with existing GCP IAM as an instance
2. **Information flow and isolation** — noninterference and confinement as properties of Systems, using bisimulation from the CCS framework
3. **Compliance as formal invariant sets** — SOC2, HIPAA, PCI-DSS as concrete sets of SystemInvariants, making "we are compliant" a theorem

These are not protocol-level concerns (sketch 08 covers those). These are *policy-level* and *architectural-level* security properties — the kind of thing where you want to prove "this node can't access that node's DB tables" or "our system satisfies SOC2 access control requirements."

## Relationship to Other Sketches

- **Sketch 01 (Node):** Nodes have identities and roles; access control decides what a Node with a given role can do
- **Sketch 02 (System):** Security properties are SystemInvariants; compliance = satisfying a set of them
- **Sketch 04 (Policy & CI):** Compliance frameworks map to policy levels; this sketch makes them concrete
- **Sketch 05 (Network):** Information flow is about which channels carry what data; isolation = channel restriction
- **Sketch 08 (Security):** Sketch 08 covers channel-level security (TLS, adversaries, confidentiality). This sketch covers policy-level security (who can do what, who can see what, are we compliant)

The dividing line: sketch 08 asks "is this channel secure?" This sketch asks "should this channel exist at all?"

## Part 1: Abstract Access Control

### The Core Model

Every access control system answers the same question: given a subject, a resource, and an action, is access granted or denied? The differences between RBAC, ABAC, capability-based, and vendor-specific systems (GCP IAM, AWS IAM, K8s RBAC) are in *how* that question is answered — not *what* the question is.

```
/-- The universal access control decision. -/
inductive AccessDecision
  | allow
  | deny
  deriving DecidableEq

/-- An access control request: who wants to do what to which resource. -/
structure AccessRequest (Subject Resource Action : Type) where
  subject : Subject
  resource : Resource
  action : Action

/-- An access control system is a function from requests to decisions,
    with an environment for context (time, IP, attributes, etc). -/
structure AccessControlSystem (Subject Resource Action Env : Type) where
  /-- The policy evaluation function. -/
  evaluate : AccessRequest Subject Resource Action → Env → AccessDecision
```

This is the abstraction that everything else instantiates. The key insight: we can state and prove properties at this level that hold for *all* access control systems, regardless of implementation.

### Universal Properties

Properties that any well-behaved access control system should satisfy (or that we want to state as requirements):

```
/-- Default deny: if no rule explicitly allows, the decision is deny. -/
def DefaultDeny (acs : AccessControlSystem S R A E) : Prop :=
  ∀ req env, acs.evaluate req env = .deny ∨
    ∃ rule ∈ acs.rules, rule.grants req env

/-- Deny overrides allow: if any applicable rule denies, access is denied
    regardless of allow rules. Sometimes called "deny takes precedence." -/
def DenyOverridesAllow (acs : AccessControlSystem S R A E) : Prop :=
  ∀ req env,
    (∃ rule, rule.denies req env) →
    acs.evaluate req env = .deny

/-- Completeness: every request gets a definite answer (no undefined behavior). -/
def Complete (acs : AccessControlSystem S R A E) : Prop :=
  ∀ req env, acs.evaluate req env = .allow ∨ acs.evaluate req env = .deny

/-- Monotonicity: adding permissions never removes access.
    (Not always desirable — deny rules break this.) -/
def Monotonic (acs acs' : AccessControlSystem S R A E) : Prop :=
  (∀ req env, acs.evaluate req env = .allow → acs'.evaluate req env = .allow)

/-- Least privilege: a subject has only the permissions it needs.
    Stated as: for every permission the subject has, there exists
    a task that requires it. -/
def LeastPrivilege (acs : AccessControlSystem S R A E)
    (requiredPerms : S → Set (R × A)) : Prop :=
  ∀ subject resource action env,
    acs.evaluate ⟨subject, resource, action⟩ env = .allow →
    (resource, action) ∈ requiredPerms subject

/-- Separation of duties: no single subject can perform all actions
    in a critical set. -/
def SeparationOfDuties (acs : AccessControlSystem S R A E)
    (criticalSet : Set A) (env : E) : Prop :=
  ¬ ∃ subject : S, ∀ action ∈ criticalSet,
    ∀ resource, acs.evaluate ⟨subject, resource, action⟩ env = .allow
```

### RBAC as an Instance

```
/-- A role collects a set of permissions. -/
structure Role (R A : Type) where
  name : String
  permissions : Set (R × A)

/-- RBAC: subjects are assigned roles; roles have permissions. -/
structure RBACSystem (Subject Resource Action : Type) where
  roles : List (Role Resource Action)
  assignments : Subject → Set (Role Resource Action)
  /-- Optional: role hierarchy (senior role inherits junior role's permissions). -/
  hierarchy : Role Resource Action → Set (Role Resource Action)

/-- RBAC induces an AccessControlSystem. -/
def RBACSystem.toAccessControl (rbac : RBACSystem S R A)
    : AccessControlSystem S R A Unit where
  evaluate req _ :=
    let effectiveRoles := rbac.effectiveRoles req.subject  -- includes inherited
    if effectiveRoles.any (fun role => (req.resource, req.action) ∈ role.permissions)
    then .allow else .deny

/-- RBAC role hierarchy is transitive: if role A inherits B and B inherits C,
    then A has C's permissions. -/
theorem rbac_hierarchy_transitive (rbac : RBACSystem S R A)
    (rA rB rC : Role R A)
    (h_ab : rB ∈ rbac.hierarchy rA)
    (h_bc : rC ∈ rbac.hierarchy rB) :
    rC.permissions ⊆ rbac.effectivePermissions rA := by sorry

/-- RBAC with no deny rules is monotonic: adding a role assignment
    never removes access. -/
theorem rbac_monotonic (rbac rbac' : RBACSystem S R A)
    (h_superset : ∀ s, rbac.assignments s ⊆ rbac'.assignments s) :
    Monotonic rbac.toAccessControl rbac'.toAccessControl := by sorry
```

### ABAC as an Instance

```
/-- ABAC: access decisions based on attributes of subject, resource, action, and environment. -/
structure ABACPolicy (Subject Resource Action Env : Type) where
  /-- Subject attributes (e.g., department, clearance level, location). -/
  subjectAttrs : Subject → List (String × String)
  /-- Resource attributes (e.g., classification, owner, sensitivity). -/
  resourceAttrs : Resource → List (String × String)
  /-- Policy rules: condition on attributes → effect. -/
  rules : List (ABACRule Subject Resource Action Env)
  /-- Combining algorithm: how to resolve multiple applicable rules. -/
  combiner : List AccessDecision → AccessDecision

/-- ABAC induces an AccessControlSystem. -/
def ABACPolicy.toAccessControl (abac : ABACPolicy S R A E)
    : AccessControlSystem S R A E where
  evaluate req env :=
    let applicable := abac.rules.filter (fun r => r.matches req env abac)
    let decisions := applicable.map (fun r => r.effect)
    abac.combiner decisions
```

### GCP IAM as an Instance of ABAC

The existing `Security/Iam/Gcp` module is an instance of the abstract ABAC framework:

```
/-- GCP IAM maps to ABAC. -/
def gcpIamAsAbac (store : GcpPolicyStore) : ABACPolicy GcpPrincipal GcpResourceNode GcpPermission (List (String × String)) where
  subjectAttrs := fun p => [("type", gcpPrincipalType p)]
  resourceAttrs := fun r => [("node", gcpResourceNodeId r)]
  rules := gcpPoliciesToAbacRules store
  combiner := gcpCombiner  -- deny-overrides, then allow, then implicit deny

/-- The GCP IAM ABAC instance satisfies deny-overrides-allow
    (this follows from gcpEvaluateRequest's structure). -/
theorem gcp_iam_deny_overrides :
    DenyOverridesAllow (gcpIamAsAbac store).toAccessControl := by sorry
```

### Capability-Based Security

Different from RBAC/ABAC: instead of a central policy, access rights are held as unforgeable tokens by subjects. Relevant for distributed systems where there's no central authority.

```
/-- A capability: an unforgeable reference to a resource with permitted actions. -/
structure Capability (Resource Action : Type) where
  resource : Resource
  actions : Set Action
  /-- Nonce ensuring uniqueness / unforgeability. -/
  token : Nat

/-- A capability system: subjects hold capabilities; access = holding the right cap. -/
structure CapabilitySystem (Subject Resource Action : Type) where
  holdings : Subject → Set (Capability Resource Action)

/-- Capability-based access control: you can do it iff you hold a cap for it. -/
def CapabilitySystem.toAccessControl (cs : CapabilitySystem S R A)
    : AccessControlSystem S R A Unit where
  evaluate req _ :=
    if (cs.holdings req.subject).any (fun cap =>
      cap.resource = req.resource ∧ req.action ∈ cap.actions)
    then .allow else .deny

/-- Capabilities support delegation: a subject can derive a weaker capability
    (subset of actions) and transfer it. -/
def Capability.attenuate (cap : Capability R A) (subset : Set A)
    (h : subset ⊆ cap.actions) : Capability R A where
  resource := cap.resource
  actions := subset
  token := cap.token  -- or derive new token

/-- Attenuation only weakens: the derived cap permits a subset of the original. -/
theorem attenuate_weakens (cap : Capability R A) (s : Set A) (h : s ⊆ cap.actions) :
    (cap.attenuate s h).actions ⊆ cap.actions := by sorry
```

### Connecting to the Systems Framework

In the CCS/LTS framework from sketches 01-02, access control maps to channel restriction:

```
-- A Node communicates on channels.
-- An AccessControlSystem determines which channels a Node may use.
-- Enforcement = CCS restriction on unauthorized channels.

-- Without access control:
System = (NodeA | NodeB | Database) \ internal

-- With access control:
-- NodeA is authorized for channels {read_db, write_db}
-- NodeB is authorized for channels {read_db} only
AuthorizedSystem = (NodeA | NodeB | Database) \ unauthorized(NodeB, write_db) \ internal

-- "NodeB can't write to the database" is a theorem:
-- In every trace of AuthorizedSystem, NodeB never performs a write_db action.
-- This follows from CCS restriction: restricted channels have no transitions.

theorem nodeB_cannot_write (sys : AuthorizedSystem) :
    ∀ trace ∈ sys.traces,
      ¬ ∃ step ∈ trace, step.actor = NodeB ∧ step.action = write_db := by sorry
```

## Part 2: Information Flow and Isolation

### Noninterference

The fundamental information flow property: high-security actions don't affect what low-security observers can see. In the CCS framework, this is naturally expressed via bisimulation.

```
/-- A security lattice: a partial order on security levels with join (least upper bound). -/
structure SecurityLattice (Level : Type) where
  le : Level → Level → Prop
  join : Level → Level → Level
  [partialOrder : PartialOrder Level]
  [semilatJoin : SemilatticeSup Level]

/-- Classification: assign security levels to channels. -/
def ChannelClassification (Channel Level : Type) := Channel → Level

/-- The projection of a system's behavior visible at a given security level:
    only actions on channels at or below that level. -/
def projectToLevel (sys : System) (classify : ChannelClassification Channel Level)
    (observer : Level) : LTS :=
  sys.lts.filterActions (fun a => classify a.channel ≤ observer)

/-- Noninterference: for an observer at level L, the system's behavior
    is the same regardless of what happens on channels above L.
    Formally: the L-projection is bisimilar whether or not high actions occur. -/
def Noninterference (sys : System) (classify : ChannelClassification Channel Level)
    (observer : Level) : Prop :=
  ∀ (highActions₁ highActions₂ : List HighAction),
    WeakBisimulation
      (projectToLevel (sys.withHighActions highActions₁) classify observer)
      (projectToLevel (sys.withHighActions highActions₂) classify observer)
```

This is the same bisimulation machinery from CSLib, applied to security. Confidentiality from sketch 08 (`Confidential`) is actually a special case of noninterference where:
- High level = Alice's plaintext
- Low level = adversary's observation
- Bisimulation = adversary can't tell what Alice sent

```
/-- Confidentiality (sketch 08) is noninterference with two levels. -/
theorem confidentiality_is_noninterference
    (sc : SecureChannel α) :
    Confidential sc ↔
      Noninterference
        (systemWith sc)
        (classify_plaintext_as_high sc)
        Level.adversary := by sorry
```

### Confinement

A component can't leak data to unauthorized recipients. Stronger than noninterference (which is about observation) — confinement is about *output*.

```
/-- Confinement: a Node only outputs on authorized channels.
    In CCS terms: the Node's output actions are a subset of its authorized channels. -/
def Confined (node : Node) (authorizedOutputs : Set Channel) : Prop :=
  ∀ trace ∈ node.traces,
    ∀ step ∈ trace,
      step.isOutput → step.channel ∈ authorizedOutputs

/-- A confined node composed into a system can't leak to unauthorized recipients. -/
theorem confinement_prevents_leak
    (sys : System) (node : Node) (h_mem : node ∈ sys.nodes)
    (h_confined : Confined node authorizedOutputs)
    (h_no_path : ¬ ∃ path, channelPath authorizedOutputs unauthorizedRecipient path) :
    ¬ ∃ trace ∈ sys.traces,
      dataFrom node reaches unauthorizedRecipient in trace := by sorry
```

### Isolation Properties for Real Systems

The abstract version of "this node can't access that node's DB tables":

```
/-- Data isolation: two nodes share no readable channels.
    Their data is completely separate. -/
def DataIsolated (sys : System) (n₁ n₂ : Node) : Prop :=
  ∀ ch : Channel,
    ¬ (ch ∈ n₁.readableChannels ∧ ch ∈ n₂.writableChannels) ∧
    ¬ (ch ∈ n₂.readableChannels ∧ ch ∈ n₁.writableChannels)

/-- Tenant isolation: in a multi-tenant system, each tenant's nodes
    are data-isolated from every other tenant's nodes. -/
def TenantIsolated (sys : System) (tenants : List (Set Node)) : Prop :=
  ∀ t₁ t₂ ∈ tenants, t₁ ≠ t₂ →
    ∀ n₁ ∈ t₁, ∀ n₂ ∈ t₂, DataIsolated sys n₁ n₂

/-- Database-level isolation: a node can only access tables it's authorized for.
    Models the "this service can't read that service's tables" property. -/
def DatabaseIsolated (sys : System) (db : Node)
    (tableAccess : Node → Set TableName) : Prop :=
  ∀ node ∈ sys.nodes, node ≠ db →
    ∀ trace ∈ sys.traces,
      ∀ query ∈ trace.queriesFrom node db,
        query.tables ⊆ tableAccess node

/-- Network segmentation: nodes in different segments can't communicate directly. -/
def NetworkSegmented (sys : System) (segments : List (Set Node)) : Prop :=
  ∀ s₁ s₂ ∈ segments, s₁ ≠ s₂ →
    ∀ n₁ ∈ s₁, ∀ n₂ ∈ s₂,
      ¬ ∃ ch, directChannel sys n₁ n₂ ch
      -- Communication must go through an explicit gateway node
```

### Mapping to Concrete Mechanisms

Each abstract isolation property is enforced by concrete mechanisms:

| Abstract Property | Concrete Enforcement | SWELib Module |
|---|---|---|
| `DataIsolated` | Network policies, K8s NetworkPolicy | `Cloud/K8s` |
| `TenantIsolated` | Separate namespaces, VPCs | `Cloud/K8s`, future `Cloud/Aws` |
| `DatabaseIsolated` | Row-level security, schema grants | `Db/Sql` |
| `NetworkSegmented` | VLANs, security groups, firewalls | `Networking` |
| `Confined` | Seccomp, AppArmor, SELinux | `OS/Capabilities` |
| `Noninterference` | TLS, encryption, access control | `Security/Crypto`, `Networking/Tls` |

## Part 3: Compliance as Formal Invariant Sets

### The Core Idea

A compliance framework (SOC2, HIPAA, PCI-DSS) is a set of requirements. Each requirement maps to one or more formal properties of a System. "We are SOC2 compliant" becomes: "our System satisfies all invariants in the SOC2 set."

```
/-- A compliance requirement: a named property that a System must satisfy. -/
structure ComplianceRequirement where
  /-- Identifier from the standard (e.g., "CC6.1", "164.312(a)(1)"). -/
  id : String
  /-- Human-readable description. -/
  description : String
  /-- The formal property this requirement demands. -/
  property : System → Prop

/-- A compliance framework: a named collection of requirements. -/
structure ComplianceFramework where
  name : String           -- "SOC2", "HIPAA", "PCI-DSS"
  version : String        -- "2022", "Final Rule", "4.0"
  requirements : List ComplianceRequirement

/-- A System is compliant with a framework iff it satisfies every requirement. -/
def Compliant (sys : System) (fw : ComplianceFramework) : Prop :=
  ∀ req ∈ fw.requirements, req.property sys

/-- Compliance is monotonic under strengthening: if sys satisfies a superset
    of properties, it's still compliant. -/
theorem compliance_monotonic (sys : System) (fw : ComplianceFramework)
    (h : Compliant sys fw)
    (fw' : ComplianceFramework)
    (h_sub : ∀ req ∈ fw'.requirements, req ∈ fw.requirements) :
    Compliant sys fw' := by sorry
```

### SOC2 Trust Services Criteria (Sketch)

SOC2 is organized around five trust service categories. Here's how the access-control-related criteria map to formal properties:

```
/-- SOC2 Common Criteria (CC) related to logical access and security. -/
def soc2_cc6 : List ComplianceRequirement := [
  {
    id := "CC6.1"
    description := "Logical access security software, infrastructure, and architectures exist"
    property := fun sys =>
      -- Every inter-node channel uses authentication
      ∀ ch ∈ sys.channels, Authenticated ch
  },
  {
    id := "CC6.2"
    description := "Prior to issuing system credentials, the entity registers and authorizes new users"
    property := fun sys =>
      -- No node can communicate without first being authenticated
      ∀ node ∈ sys.nodes,
        ∀ trace ∈ sys.traces,
          node.firstAction trace → ∃ authEvent, authEvent.before (node.firstAction trace)
  },
  {
    id := "CC6.3"
    description := "The entity authorizes, modifies, or removes access based on roles"
    property := fun sys =>
      -- Access control is role-based (there exists an RBAC system governing access)
      ∃ rbac : RBACSystem, ∀ req, sys.accessDecision req = rbac.toAccessControl.evaluate req
  },
  {
    id := "CC6.6"
    description := "The entity implements controls to prevent or detect unauthorized access"
    property := fun sys =>
      -- All external-facing channels are secured (encrypted + authenticated)
      ∀ ch ∈ sys.externalChannels,
        Confidential ch ∧ Integral ch ∧ Authenticated ch
  },
  {
    id := "CC6.7"
    description := "Access to data is restricted to authorized users"
    property := fun sys =>
      -- Noninterference: unauthorized users can't observe protected data
      ∀ (protectedData : Set Channel) (unauthorizedUser : Node),
        unauthorizedUser ∉ authorizedFor protectedData →
        Noninterference sys (classifyProtected protectedData) unauthorizedUser.level
  },
  {
    id := "CC6.8"
    description := "Controls to prevent or detect unauthorized changes to software"
    property := fun sys →
      -- Integrity of deployments: only authorized nodes can trigger deployments
      ∀ migration ∈ sys.migrations,
        migration.initiator ∈ authorizedDeployers
  }
]

/-- SOC2 availability criteria. -/
def soc2_a1 : List ComplianceRequirement := [
  {
    id := "A1.2"
    description := "Environmental protections, redundancy, and recovery"
    property := fun sys =>
      -- System tolerates single-node failure
      ∀ node ∈ sys.nodes,
        sys.removeNode node |>.satisfies sys.safetyProperties
  }
]

def soc2Framework : ComplianceFramework where
  name := "SOC2"
  version := "2022"
  requirements := soc2_cc6 ++ soc2_a1 ++ ...
```

### HIPAA Security Rule (Sketch)

```
def hipaa_accessControl : List ComplianceRequirement := [
  {
    id := "164.312(a)(1)"
    description := "Access control: unique user identification"
    property := fun sys =>
      -- Every principal is uniquely identifiable
      ∀ p₁ p₂ ∈ sys.principals, p₁.id = p₂.id → p₁ = p₂
  },
  {
    id := "164.312(a)(1)-emergency"
    description := "Access control: emergency access procedure"
    property := fun sys =>
      -- There exists a break-glass mechanism
      ∃ breakGlass : EmergencyAccess, breakGlass.grantsAccess sys ∧ breakGlass.isAudited
  },
  {
    id := "164.312(e)(1)"
    description := "Transmission security: encryption"
    property := fun sys =>
      -- All channels carrying PHI are encrypted
      ∀ ch ∈ sys.channels,
        carriesPHI ch → Confidential ch ∧ Integral ch
  }
]
```

### PCI-DSS (Sketch)

```
def pciDss_requirement1 : List ComplianceRequirement := [
  {
    id := "1.3.1"
    description := "Network segmentation between cardholder data environment and untrusted networks"
    property := fun sys =>
      NetworkSegmented sys [sys.cardholderDataEnv, sys.untrustedNetwork]
  },
  {
    id := "1.3.2"
    description := "Restrict inbound traffic to the cardholder data environment"
    property := fun sys =>
      ∀ node ∈ sys.untrustedNetwork, ∀ cde ∈ sys.cardholderDataEnv,
        ¬ directChannel sys node cde ∨ throughFirewall sys node cde
  }
]

def pciDss_requirement7 : List ComplianceRequirement := [
  {
    id := "7.1"
    description := "Limit access to cardholder data to need-to-know"
    property := fun sys =>
      LeastPrivilege sys.accessControl sys.requiredPermissions
  }
]
```

### Compliance Composition

A system might need to satisfy multiple frameworks:

```
/-- A system satisfies multiple compliance frameworks. -/
def MultiCompliant (sys : System) (frameworks : List ComplianceFramework) : Prop :=
  ∀ fw ∈ frameworks, Compliant sys fw

/-- If a requirement appears in multiple frameworks, proving it once suffices. -/
theorem shared_requirement_reuse
    (sys : System) (fw₁ fw₂ : ComplianceFramework)
    (req : ComplianceRequirement)
    (h₁ : req ∈ fw₁.requirements) (h₂ : req ∈ fw₂.requirements)
    (h_sat : req.property sys) :
    -- req is satisfied for both frameworks
    True := by trivial

/-- Compliance under system evolution (connects to sketch 03 migrations):
    if the system was compliant before migration and the migration preserves
    all compliance properties, the system is still compliant after. -/
theorem compliance_preserved_by_migration
    (sys₁ sys₂ : System) (m : Migration sys₁ sys₂) (fw : ComplianceFramework)
    (h_before : Compliant sys₁ fw)
    (h_preserves : ∀ req ∈ fw.requirements, req.property sys₁ → req.property sys₂) :
    Compliant sys₂ fw := by sorry
```

### CI Integration

From sketch 04, compliance checks fit into the verification levels:

| Level | Compliance Check | Example |
|---|---|---|
| 0: Lint | "Every service has an RBAC policy file" | File existence check |
| 1: Invariant | "No service has access to another service's DB tables" | `DatabaseIsolated` check |
| 2: Migration | "Adding this new endpoint doesn't break network segmentation" | `NetworkSegmented` preservation |
| 3: Meta | "Our policy set covers all SOC2 CC6 requirements" | `Compliant sys soc2Framework` |

Level 0-1 can be automated in CI. Level 2-3 may require interactive proofs or careful instantiation.

## Key Theorems

### Access Control

- RBAC with role hierarchy is transitive (inherited permissions propagate)
- RBAC without deny rules is monotonic (adding assignments only adds access)
- GCP IAM satisfies deny-overrides-allow (instance of the universal property)
- Separation of duties is incompatible with a single-admin role (impossibility)
- Capability attenuation only weakens (derived capability is a subset)

### Information Flow

- Confidentiality (sketch 08) is a special case of noninterference
- Confinement + no transitive channel path → no data leak
- CCS restriction enforces confinement (restricted channels have no transitions)
- Noninterference composes: if subsystems A and B are each noninterfering, their parallel composition is noninterfering (requires channel separation)

### Compliance

- Compliance is preserved by property-preserving migrations
- Shared requirements across frameworks need only one proof
- If all Level 0-2 checks pass for every PR, and the base system is compliant, the system remains compliant (inductive compliance)

### Connecting Layers

- Access control (Part 1) implements noninterference (Part 2): if the access control system is correct, then unauthorized subjects can't observe protected resources (noninterference holds)
- Noninterference (Part 2) satisfies compliance requirements (Part 3): proving noninterference discharges specific SOC2/HIPAA requirements about data access

```
/-- Access control correctness implies noninterference for unauthorized subjects. -/
theorem access_control_implies_noninterference
    (sys : System) (acs : AccessControlSystem)
    (h_enforced : sys.enforcesAccessControl acs)
    (observer : Node)
    (h_denied : ∀ protectedResource, acs.evaluate ⟨observer, protectedResource, .read⟩ = .deny) :
    Noninterference sys classifyProtected observer.level := by sorry

/-- Noninterference for PHI channels satisfies HIPAA 164.312(e)(1). -/
theorem noninterference_satisfies_hipaa_transmission
    (sys : System)
    (h_ni : ∀ ch, carriesPHI ch →
      Noninterference sys (classifyPHI ch) Level.unauthorized) :
    (hipaa_164_312_e_1).property sys := by sorry
```

## Module Structure

```
spec/SWELib/
├── Security/
│   ├── Foundations/
│   │   ├── AccessControl.lean          -- AccessControlSystem, AccessRequest, AccessDecision
│   │   ├── AccessControl/
│   │   │   ├── Properties.lean         -- DefaultDeny, Monotonic, LeastPrivilege, SepOfDuties
│   │   │   └── Theorems.lean           -- Universal theorems about access control
│   │   ├── Rbac.lean                   -- RBACSystem, role hierarchy, toAccessControl
│   │   ├── Abac.lean                   -- ABACPolicy, attribute evaluation, toAccessControl
│   │   ├── Capability.lean             -- CapabilitySystem, attenuation, delegation
│   │   ├── InformationFlow.lean        -- SecurityLattice, Noninterference, Confinement
│   │   ├── InformationFlow/
│   │   │   ├── Isolation.lean          -- DataIsolated, TenantIsolated, DatabaseIsolated
│   │   │   └── Theorems.lean           -- Noninterference composition, confinement → no-leak
│   │   ├── Compliance.lean             -- ComplianceFramework, ComplianceRequirement, Compliant
│   │   └── Compliance/
│   │       ├── Soc2.lean              -- SOC2 trust services criteria as invariants
│   │       ├── Hipaa.lean             -- HIPAA security rule as invariants
│   │       ├── PciDss.lean            -- PCI-DSS requirements as invariants
│   │       └── Theorems.lean          -- Compliance preservation, composition, migration
│   ├── Rbac.lean                       -- (existing stub, becomes re-export of Foundations/Rbac)
│   ├── Iam/
│   │   ├── Gcp/                        -- (existing, add instance proof to AccessControl)
│   │   │   ├── Types.lean
│   │   │   ├── Operations.lean
│   │   │   ├── Invariants.lean
│   │   │   └── AsAbac.lean            -- NEW: GCP IAM as ABAC instance
│   │   └── ...                         -- Future: AWS IAM, Azure RBAC, K8s RBAC as instances
│   └── ... (existing crypto, JWT, PKI unchanged)
```

### Dependency Graph

```
Foundations/AccessControl ← Foundations/Rbac ← Iam/Gcp/AsAbac
                          ← Foundations/Abac ←┘
                          ← Foundations/Capability

Foundations/InformationFlow ← Foundations/AccessControl (access control → noninterference)
                            ← CSLib (bisimulation, CCS restriction)
                            ← Sketch 08 Security/Properties (Confidential as special case)

Foundations/Compliance ← Foundations/InformationFlow
                       ← Foundations/AccessControl
                       ← Sketch 02 System (SystemInvariant)
                       ← Sketch 03 Migration (compliance preservation)
                       ← Sketch 04 Policy (CI integration levels)
```

## Source Specs

### Access Control
- **Ferraiolo & Kuhn, "Role-Based Access Controls"** (1992): original RBAC model
- **Sandhu et al., "The NIST Model for RBAC"** (2000): RBAC96/NIST standard
- **XACML 3.0** (OASIS, 2013): ABAC policy language standard
- **Dennis & Van Horn, "Programming Semantics for Multiprogrammed Computations"** (1966): capability-based security origin
- **Miller, "Robust Composition"** (2006): object-capability model

### Information Flow
- **Goguen & Meseguer, "Security Policies and Security Models"** (1982): noninterference definition
- **Denning, "A Lattice Model of Secure Information Flow"** (1976): security lattice
- **McLean, "Proving Noninterference and Functional Correctness Using Traces"** (1992): trace-based noninterference
- **Focardi & Gorrieri, "Classification of Security Properties"** (2001): CCS-based security taxonomy (directly relevant — noninterference via bisimulation in CCS)
- **Ryan & Schneider, "Process Algebra and Non-interference"** (2001): CSP-based, applicable to CCS

### Compliance
- **AICPA, "SOC2 Trust Services Criteria"** (2022)
- **HHS, "HIPAA Security Rule"** (45 CFR 164.302-318)
- **PCI SSC, "PCI-DSS v4.0"** (2022)

### Formal Foundations
- **CSLib**: bisimulation for noninterference, CCS restriction for confinement
- **Focardi & Gorrieri**: the direct precedent — noninterference as bisimulation in process algebra
