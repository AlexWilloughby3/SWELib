# Plan: Autoformalized Blueprint from Technical Documentation

## Core Idea

Instead of manually writing the Lean Blueprint's LaTeX layer, use an autoformalizer pipeline to:
1. Read source technical documentation (RFCs, man pages, API specs)
2. Extract structured requirements and concepts
3. Map them to existing SWELib Lean declarations
4. Generate the blueprint layer (dependency graph + human-readable descriptions)

This inverts the traditional blueprint workflow: instead of "write math paper, annotate with
Lean names", we do "read spec, match to existing Lean code, generate blueprint".

## Why This Makes Sense for SWELib

Traditional Lean Blueprint projects formalize a math paper that already exists. SWELib
formalizes technical specs that are:
- Written in prose + pseudocode + formal grammars (RFCs)
- Written as API schemas (Kubernetes OpenAPI, PostgreSQL wire protocol)
- Written as man pages (Linux syscalls, POSIX interfaces)
- Scattered across multiple documents with cross-references

Nobody is going to manually write a LaTeX re-explanation of RFC 8446 (TLS 1.3, 160 pages)
just to get a dependency graph. But an autoformalizer can read that RFC and tell you:
- "Section 4.1.2 (ClientHello) maps to `SWELib.Networking.Tls.HandshakeMessages.ClientHello`"
- "Section 4.2.8 (key_share) depends on Section 4.2.7 (supported_groups)"
- "Your formalization covers 73% of the mandatory requirements in Section 9.2"

## Architecture

### Phase 1: Spec → Structured Requirements (exists today)

The `spec-fetcher` agent already does this:
- Fetches RFC/man page/API spec via web
- Extracts requirements, constraints, state machines, and type definitions
- Outputs structured JSON/markdown with labeled requirements

No new work needed. Just needs a stable output schema.

### Phase 2: Requirements → Declaration Mapping (new)

A new agent (`blueprint-mapper`) that:
1. Takes structured requirements from Phase 1
2. Reads the existing Lean source files in `spec/`
3. Matches each requirement to zero or more Lean declarations

**Matching strategies:**
- **Name matching**: RFC 8446 "ClientHello" → grep for `ClientHello` in spec/ →
  find `SWELib.Networking.Tls.HandshakeMessages.ClientHello`
- **Docstring matching**: Lean docstrings already reference RFC sections
  (e.g., `(RFC 8446 Section 4.1.2)`) → parse and match
- **Structural matching**: RFC defines a record with fields → Lean has a `structure` with
  corresponding fields → match field-by-field
- **Semantic matching** (LLM-assisted): "The server MUST verify the client's certificate"
  → LLM identifies this maps to `SWELib.Networking.Tls.Invariants.serverVerifiesClientCert`

**Output per requirement:**
```json
{
  "spec_ref": "RFC 8446 Section 4.1.2",
  "requirement": "ClientHello message structure",
  "requirement_type": "definition",
  "lean_decls": ["SWELib.Networking.Tls.HandshakeMessages.ClientHello"],
  "coverage": "partial",
  "missing_fields": ["cookie", "psk_key_exchange_modes"],
  "depends_on": ["RFC 8446 Section 4.2 (Extensions)"]
}
```

### Phase 3: Mapping → Blueprint (new)

Generate the Lean Blueprint LaTeX from the mapping:

```latex
% Auto-generated from RFC 8446 Section 4.1.2
\begin{definition}[ClientHello Message]
  \label{tls-client-hello}
  \lean{SWELib.Networking.Tls.HandshakeMessages.ClientHello}
  \leanok
  \uses{tls-protocol-version, tls-cipher-suite, tls-extensions}
  The ClientHello message (RFC 8446 §4.1.2) initiates the TLS handshake.
  Contains protocol version, random nonce, session ID, cipher suites,
  and extensions.

  \textbf{Coverage:} 8/11 fields formalized. Missing: cookie,
  psk\_key\_exchange\_modes, early\_data.
\end{definition}
```

The `\uses{}` edges come from the dependency information in Phase 1 (RFC cross-references)
combined with the Lean import graph.

### Phase 4: Coverage Dashboard (new)

Beyond the standard blueprint dependency graph, generate a **coverage report**:

| Module | Source Spec | Requirements | Formalized | Coverage |
|--------|-----------|-------------|-----------|---------|
| TLS 1.3 | RFC 8446 | 147 | 89 | 61% |
| K8s Pod | API v1.29 | 63 | 31 | 49% |
| SQL Joins | SQL:2023 | 28 | 24 | 86% |
| TCP States | RFC 793 | 19 | 19 | 100% |
| mmap | mmap(2) | 12 | 8 | 67% |

This is the real payoff: you can see at a glance which specs are well-covered and which
have gaps, driven by the actual source documentation rather than self-assessment.

## Pipeline Summary

```
┌──────────────────┐
│ Source Specs      │  RFC 8446, K8s API, mmap(2), etc.
│ (web/local)      │
└────────┬─────────┘
         │ spec-fetcher (exists)
         ▼
┌──────────────────┐
│ Structured       │  Requirements, constraints, state machines
│ Requirements     │
└────────┬─────────┘
         │ blueprint-mapper (new)
         │ reads spec/ Lean files
         ▼
┌──────────────────┐
│ Requirement →    │  Each requirement matched to Lean decl(s)
│ Declaration Map  │  with coverage assessment
└────────┬─────────┘
         │ blueprint-generator (new)
         ▼
┌──────────────────┐
│ Blueprint LaTeX  │  \lean{}, \leanok, \uses{}, prose
│ + Coverage Data  │
└────────┬─────────┘
         │ leanblueprint (exists)
         ▼
┌──────────────────┐
│ Interactive Site  │  Dependency graph + coverage dashboard
│ (GitHub Pages)   │
└──────────────────┘
```

## What This Gets You

1. **Navigable documentation for free.** Someone looking at the TLS module can see which
   RFC sections are covered, which aren't, and how the pieces depend on each other — without
   anyone writing documentation manually.

2. **Guided contribution.** The blueprint graph shows blue nodes (ready to formalize) based
   on dependency analysis of the *source spec*, not just the Lean code. A contributor sees
   "RFC 8446 Section 4.2.8 (key_share) is ready because 4.2.7 (supported_groups) is done."

3. **Coverage tracking that means something.** Instead of "47 sorry's in spec/", you get
   "61% of TLS 1.3 mandatory requirements are formalized." This connects the Lean code back
   to the real-world spec it claims to model.

4. **Drift detection.** If a spec updates (K8s 1.30 adds a new Pod field), re-running the
   pipeline detects the new requirement and flags it as unmapped. The blueprint shows it as
   a new orange node.

5. **Representation decision documentation.** When the mapper finds that SWELib models
   HTTP headers as `List (String × String)` while the RFC defines them as a more complex
   structure, it can flag this as a deliberate representation decision and link to
   `representation-decisions.md`.

## Key Design Decisions

### What granularity for "requirement"?

Too coarse (one per RFC section) → the graph is useless.
Too fine (one per RFC sentence) → hundreds of nodes, noise.

**Recommended:** One requirement per definition, constraint, or state transition in the spec.
- "ClientHello has field X of type Y" → one requirement (definition)
- "Server MUST reject ClientHello with version < TLS 1.2" → one requirement (constraint)
- "On receiving ClientHello, server transitions to WAIT_FLIGHT2" → one requirement (transition)

This roughly matches the granularity of Lean declarations (one structure, one theorem, one
def per requirement).

### How to handle representation decisions?

The mapper will often find that the Lean code doesn't match the spec 1:1. This is expected
and correct — SWELib makes deliberate abstraction choices. The mapper should:
1. Flag the divergence
2. Check if there's a corresponding entry in `representation-decisions.md`
3. If not, suggest adding one
4. In the blueprint, note the decision: "Modeled as List (not Map) per D-001"

### How to handle cross-spec dependencies?

Many SWELib modules span multiple specs:
- TLS depends on X.509 (RFC 5280) for certificates
- K8s depends on OCI (image spec) for container images
- HTTP/2 depends on HPACK (RFC 7541) for header compression

The mapper should follow these cross-references and create cross-module dependency edges
in the blueprint. This is where the graph becomes really valuable — it shows the full
dependency web across specs, not just within one module.

### Refresh cadence

- **On PR:** Re-run mapper for changed modules only. Flag coverage regressions.
- **Weekly:** Full re-run across all modules. Update coverage dashboard.
- **On spec update:** Manual trigger when an RFC is updated or a new K8s version ships.

## Pilot Module

Start with `SWELib.Networking.Tls` because:
- Source spec is a single, well-structured RFC (8446)
- Already has RFC section references in docstrings
- Has a mix of definitions, state machines, and invariants
- Has known gaps (not all extensions are modeled)
- Cross-references other specs (X.509, HPACK) for testing cross-module edges

## Open Questions

1. **Should the LaTeX layer exist at all?** The blueprint tool requires LaTeX, but the
   information could also be rendered directly as a static site (markdown + D3.js graph).
   LaTeX adds a build dependency and a format most SWE contributors won't want to edit.
   Counter-argument: leanblueprint already handles the graph rendering and doc-gen4 integration.

2. **How much LLM involvement in the mapping?** Pure heuristic matching (name/docstring grep)
   gets you 60-70% of mappings. LLM-assisted semantic matching gets the rest but introduces
   non-determinism. Could do heuristic first, LLM for unmatched, human review for conflicts.

3. **Should the coverage report be normative?** If the pipeline says "67% coverage of mmap(2)",
   is that a goal to reach 100%? Or are some requirements deliberately out of scope? Need a
   way to mark requirements as "won't formalize" (e.g., "mmap with MAP_HUGETLB" might be
   out of scope for SWELib).
