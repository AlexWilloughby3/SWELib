# Plan: CI Pipeline & Dependency Navigator

Two systems to build: (1) a proper CI pipeline enforced at the PR level, and (2) an
interactive navigator that lets humans explore SWELib's objects and their dependencies
without spelunking through the file system.

These are complementary. CI ensures the codebase stays healthy. The navigator makes the
codebase legible to humans — contributors, reviewers, and anyone trying to understand
what SWELib covers and where the gaps are.

---

## Part 1: CI Pipeline

### Current State

Three workflows exist today:
- `ci.yml` — builds all layers, runs tests, audits bridge, reports sorry's, checks formatting
- `audit.yml` — weekly bridge audit with `continue-on-error: true` (failures swallowed)
- `sorry-count.yml` — counts sorry's, has dead PR-comment code (triggers on push not PR)

Problems:
- Lean version hardcoded to v4.0.0 (stale)
- No build caching (Lean builds are slow)
- Bridge audit is weekly/informational instead of a required PR gate
- Sorry count is informational only — PRs can freely add sorry's with no issue link
- No layer isolation enforcement (nothing stops spec/ from importing IO or bridge/)
- sorry-count PR comment never fires (wrong event trigger)

### Target: Required PR Checks

Every PR must pass all of these before merge:

| Check | What | Fails when |
|-------|------|-----------|
| **build-spec** | `lake build SWELib` | Spec layer has errors |
| **build-bridge** | `lake build SWELibBridge` | Bridge layer has errors |
| **build-code** | `lake build SWELibCode` | Code layer has errors |
| **tests** | `lake test` | Any test fails |
| **formatting** | `lake format --check` | Code not formatted |
| **bridge-audit** | `scripts/audit-bridge.sh` | Axiom missing `-- TRUST:` link |
| **sorry-gate** | `scripts/sorry-gate.sh` | Sorry count increased vs main without issue link |
| **layer-isolation** | `scripts/check-layer-isolation.sh` | spec/ uses `@[extern]`/IO, bridge/ imports code/ |

### Target: Informational PR Checks

These run and report but don't block merge:

| Check | What | Output |
|-------|------|--------|
| **sorry-report** | Diff sorry count vs main | PR comment: "+3 sorry's added, -1 resolved" |
| **module-size** | Check file line counts | Warn if any `.lean` file exceeds 500 lines |
| **coverage-diff** | Re-run blueprint mapper on changed modules | PR comment: coverage delta |

### Target: Scheduled Checks

| Check | Schedule | What |
|-------|----------|------|
| **sorry-debt-audit** | Weekly (Monday) | Verify every `sorry` has a `sorry-debt` issue |
| **bridge-link-check** | Weekly (Monday) | Verify `-- TRUST:` URLs resolve (issues not closed/deleted) |
| **full-coverage** | Weekly (Sunday) | Re-run blueprint mapper on all modules, update dashboard |

### Implementation Details

**Lean version:** Pin via `lean-toolchain` file in repo root, not in workflow YAML. The
workflow reads whatever `lean-toolchain` says.

**Build caching:** Cache `.lake/build/`, `.lake/packages/`, and `~/.elan/` keyed on
`lean-toolchain + lakefile.lean + lake-manifest.json`. Lean builds are slow enough that
this matters — a cached build should take seconds, not minutes.

**sorry-gate.sh logic:**
```
1. Count sorry's on the PR branch
2. Count sorry's on origin/main
3. If PR count > main count:
   a. Find the new sorry's (diff)
   b. Check each has a comment referencing a GitHub issue
   c. If any new sorry lacks an issue reference → fail
```
This allows adding sorry's as long as they're tracked, which matches the existing
`sorry-debt` convention.

**layer-isolation.sh logic:**
```
1. Grep spec/ for @[extern], IO, import SWELibBridge, import SWELibCode → fail
2. Grep bridge/ for import SWELibCode → fail
3. Grep bridge/ for @[extern] → fail (bridge has axioms, not extern decls)
```

**Branch protection rules** (configured in GitHub repo settings):
- Require status checks: all "Required" checks above
- Require branches up to date before merge
- Do not allow bypassing (even for admins)

---

## Part 2: Dependency Navigator

### The Problem

Navigating SWELib through the file system is a poor experience:

- `spec/SWELib/Cloud/K8s/Workloads/Pod.lean` tells you nothing about what Pod depends on
  or what depends on Pod without reading the imports and then finding those files
- The dependency structure is invisible — you can't see that TLS depends on Bytes, that
  K8s Pod depends on OCI Container, that SQL Joins depend on the Relation type
- Sorry's and coverage gaps are scattered — you have to grep to find them
- Source spec references (RFC sections, K8s API versions) are buried in docstrings
- A new contributor has no way to see the big picture or find where to help

### What We Want

An interactive website (deployed to GitHub Pages) where you can:

1. **See the full dependency graph** — every definition, theorem, and structure in spec/ as
   a node, with edges showing what depends on what. Zoom, pan, filter by module.

2. **See the status of each node** — formalized (green), has sorry (yellow), stated but
   unproved (blue), not started (gray). At a glance: where are the gaps?

3. **Click a node** to see: its Lean docstring, its source spec reference (RFC section,
   man page, etc.), its sorry's if any, what it depends on, what depends on it, and a
   link to the source file on GitHub.

4. **Filter by module** — show just TLS, just K8s, just SQL. Or show cross-module edges
   to see how modules connect.

5. **See coverage against source specs** — "TLS 1.3 (RFC 8446): 89/147 requirements
   formalized." This connects the Lean code back to the real-world documentation it
   models.

### Architecture

```
┌─────────────────────────────────────────────────┐
│ Data Sources                                     │
│                                                  │
│  Lean source files ──→ auto-detect decls,        │
│  (spec/*.lean)         imports, sorry's,         │
│                        docstrings, spec refs     │
│                                                  │
│  YAML overrides ────→ manual corrections,        │
│  (blueprint/*.yaml)   coverage notes,            │
│                        cross-spec deps           │
│                                                  │
│  Source specs ──────→ structured requirements     │
│  (via spec-fetcher)   for coverage mapping       │
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│ Build Script (~300 lines Python)                 │
│                                                  │
│  1. Parse all spec/*.lean files                  │
│     - Extract: declarations, imports, sorry's,   │
│       docstrings, @[spec_ref] annotations        │
│  2. Read blueprint/*.yaml overrides              │
│  3. Build dependency DAG                         │
│  4. Compute node statuses                        │
│  5. Compute coverage per source spec             │
│  6. Emit: graph.json + index.html                │
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│ Static Site (single index.html + JS)             │
│                                                  │
│  dagre-d3 for DAG layout                         │
│  Color-coded nodes by status                     │
│  Click to expand node details                    │
│  Module filter sidebar                           │
│  Coverage dashboard tab                          │
│  Search by declaration name                      │
└─────────────────────────────────────────────────┘
```

### Data Model

Each node in the graph:

```yaml
id: "SWELib.Networking.Tls.Types.ProtocolVersion"
kind: inductive | structure | def | theorem | lemma
module: "SWELib.Networking.Tls"
file: "spec/SWELib/Networking/Tls/Types.lean"
line: 12
docstring: "Protocol version identifier (RFC 8446 Appendix B.1)."
spec_ref: "RFC 8446 Appendix B.1"        # parsed from docstring
status: formalized | sorry | stated | not_started
sorry_count: 0
depends_on:                               # from imports + type references
  - "SWELib.Basics.Bytes.ByteArray"
depended_on_by:                           # reverse edges (computed)
  - "SWELib.Networking.Tls.HandshakeMessages.ClientHello"
```

### Auto-Detection from Lean Source

Most metadata is derivable without any manual YAML:

| Field | Detection method |
|-------|-----------------|
| `id` | Fully qualified name from `namespace` + `def`/`theorem`/`structure` declaration |
| `kind` | Keyword: `inductive`, `structure`, `def`, `theorem`, `lemma`, `abbrev` |
| `module` | Namespace prefix (first two segments after `SWELib`) |
| `file`, `line` | Source location |
| `docstring` | `/-- ... -/` comment preceding the declaration |
| `spec_ref` | Regex on docstring: `\(RFC \d+.*?\)`, `\(.*?Section \d+.*?\)`, etc. |
| `status` | If body contains `sorry` → sorry. If body is `:= by ...` with no sorry → formalized. If `opaque` with no body → stated. |
| `depends_on` | Parse `import` statements for module-level deps. For declaration-level deps, parse type signatures for referenced names. |

The YAML override layer handles what auto-detection can't:
- Cross-spec dependencies (TLS → X.509) that aren't captured by Lean imports
- Coverage annotations ("8/11 fields formalized, missing: cookie, psk_key_exchange_modes")
- Deliberate omissions ("MAP_HUGETLB is out of scope")
- Grouping hints (cluster related declarations into a single visual node)

### YAML Override Format

One file per module, only needed for corrections and additions:

```yaml
# blueprint/tls.yaml
module: SWELib.Networking.Tls
source_spec: RFC 8446
source_url: https://www.rfc-editor.org/rfc/rfc8446

overrides:
  # Override auto-detected status or add info
  - decl: SWELib.Networking.Tls.HandshakeMessages.ClientHello
    coverage_note: "8/11 fields. Missing: cookie, psk_key_exchange_modes, early_data"

  # Add cross-spec dependency not visible in imports
  - decl: SWELib.Networking.Tls.Invariants.serverVerifiesClientCert
    extra_depends_on:
      - SWELib.Security.PKI.X509.Certificate

  # Mark something as deliberately out of scope
  - spec_ref: "RFC 8446 §4.2.11 (pre_shared_key)"
    status: out_of_scope
    reason: "PSK mode not modeled — SWELib focuses on certificate-based TLS"

# Additional requirements from the spec that have no Lean declaration yet
unmapped:
  - spec_ref: "RFC 8446 §4.2.9 (psk_key_exchange_modes)"
    description: "PSK key exchange mode negotiation"
    status: not_started
    depends_on: [tls-extensions-base]
```

### Rendering

**Primary view: DAG with dagre-d3.**

- Top-to-bottom layout (foundations at top, complex theorems at bottom)
- Nodes colored by status: green/yellow/blue/gray
- Node size proportional to the number of things that depend on it
- Edges show dependency direction (A → B means A depends on B)
- Click node → side panel with full details
- Module filter → show/hide entire modules
- Search bar → find by declaration name or spec reference

**Secondary view: Coverage dashboard.**

A table showing per-module and per-spec coverage:

```
Module               Source Spec       Formalized  Sorry  Gap   Coverage
───────────────────  ───────────────  ──────────  ─────  ────  ────────
Networking.Tls       RFC 8446          89          12     46    61%
Networking.Http      RFC 9110          34           3     18    62%
Cloud.K8s            API v1.29         31           8     24    49%
Db.Sql               SQL:2023          24           2      2    86%
OS.Memory            mmap(2) et al.     8           1      3    67%
Distributed.Raft     Ongaro 2014       19           4      0    83%
```

Clicking a module row expands to show individual requirements and their status.

**Tertiary view: Module-level map.**

A high-level graph where each node is an entire module (not individual declarations).
Edges show cross-module dependencies. Good for the "big picture" overview that the file
system completely fails to communicate.

```
  Basics.Bytes ──────────────┐
       │                     │
       ▼                     ▼
  Networking.Tcp      Security.Crypto
       │                     │
       ▼                     ▼
  Networking.Tls ◄───── Security.PKI
       │
       ▼
  Networking.Http
       │
       ▼
  Cloud.K8s ◄───── Cloud.Oci
```

### CI Integration

The navigator is built and deployed as part of CI:

**On every PR:**
- Build script runs on changed modules
- PR comment shows: "Navigator preview: [link]. Coverage delta: TLS +2 formalized, -1 sorry."

**On merge to main:**
- Full rebuild of navigator
- Deploy to GitHub Pages at `<user>.github.io/<repo>/navigator/`

**Weekly:**
- Re-run spec-fetcher on all source specs to detect spec updates
- Re-run coverage mapping
- Flag new requirements from updated specs as unmapped

### Build Script Outline

The build script is a single Python file (`scripts/build-navigator.py`):

```
1. Walk spec/**/*.lean
   - For each file, parse with regex (not full Lean elaborator):
     - namespace declarations
     - def/theorem/lemma/structure/inductive declarations
     - import statements
     - docstrings
     - sorry occurrences
   - Build declaration list with metadata

2. Walk blueprint/*.yaml (if any exist)
   - Apply overrides to declaration list
   - Add unmapped requirements as gray nodes

3. Build DAG
   - Module-level edges from import statements
   - Declaration-level edges from type signature references (best-effort regex)
   - Cross-module edges from YAML extra_depends_on

4. Compute statuses
   - For each declaration: formalized / sorry / stated / not_started
   - For each module: aggregate percentages
   - For each source spec: coverage ratio

5. Emit graph.json
   - Nodes array with all metadata
   - Edges array with source/target
   - Module list with coverage stats

6. Copy index.html template (static, references graph.json)
   - dagre-d3 renders the graph client-side
   - No server needed — pure static files
```

### Technology Choices

| Component | Choice | Why |
|-----------|--------|-----|
| Data extraction | Python + regex | Don't need the Lean elaborator. Regex is fast and sufficient for declaration names, imports, docstrings, sorry. |
| Graph layout | dagre-d3 | Purpose-built for DAG layout. Clean, readable, handles hundreds of nodes. |
| Rendering | Static HTML + vanilla JS | No build toolchain. No React/Vue. Single file deploys to Pages. |
| Data format | JSON (emitted by Python) | dagre-d3 consumes JSON directly. Easy to inspect/debug. |
| Overrides | YAML | Human-friendly to read and write. Better than JSON for hand-edited files. |
| Hosting | GitHub Pages | Free, automatic, no infrastructure. |

### Why Not Use Lean's Elaborator Directly?

Lean's elaborator gives you the *true* dependency graph — every type reference resolved,
every implicit argument tracked. But it requires building the entire project first, which
is slow and requires the full Lean toolchain in the script.

Regex-based extraction is 95% accurate for our needs (declaration names, imports, sorry
detection) and runs in milliseconds. The 5% gap (implicit dependencies, typeclass
instances) can be patched with YAML overrides.

If accuracy becomes a problem later, we can add an optional `lake exe dump-decls` step
that uses the elaborator to emit a precise declaration list, and the build script can
prefer that over regex when available.

---

## Relationship Between the Two Systems

CI and the navigator reinforce each other:

- **CI enforces** that the metadata the navigator reads is trustworthy (layer isolation,
  sorry tracking, bridge audit)
- **The navigator surfaces** what CI checks measure (sorry count becomes a visual, coverage
  becomes a dashboard, dependencies become a graph)
- **PR checks reference the navigator** ("Coverage delta" in PR comments links to the
  preview build showing exactly which nodes changed status)

The navigator is also the natural home for the autoformalized blueprint content — when the
spec-fetcher → blueprint-mapper pipeline runs, its output feeds into the same YAML override
files that the navigator reads. The "coverage against source spec" view is literally the
blueprint, just rendered as an interactive graph instead of a LaTeX document.

---

## Implementation Order

| Phase | What | Depends on |
|-------|------|-----------|
| 1 | Fix existing CI: caching, lean-toolchain, remove dead code | Nothing |
| 2 | Add required PR checks: sorry-gate, layer-isolation, bridge-audit-on-PR | Phase 1 |
| 3 | Build script: parse Lean files → graph.json | Nothing (can parallel with 1-2) |
| 4 | Static site: index.html with dagre-d3 rendering graph.json | Phase 3 |
| 5 | CI integration: build navigator on merge, deploy to Pages | Phases 2 + 4 |
| 6 | YAML override layer: manual corrections, cross-spec deps | Phase 4 |
| 7 | Autoformalizer integration: spec-fetcher → mapper → YAML | Phase 6 |
| 8 | Coverage dashboard: per-module, per-spec coverage view | Phase 7 |
| 9 | PR preview: build navigator for PR, comment with delta | Phase 5 |

Phases 1-2 (CI fixes) and 3-4 (navigator prototype) can be done in parallel.
