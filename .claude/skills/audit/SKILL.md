---
name: audit
description: Audit an existing SWELib formalization for quality, conformance, and completeness. Use when the user wants to check whether an existing module correctly and thoroughly formalizes its source specification.
---

Audit the formalization: $ARGUMENTS

The user will provide either:
- A module name (e.g., "Uri", "Http", "Tcp")
- A module path (e.g., "spec/SWELib/Basics/Uri.lean")
- A domain area (e.g., "Networking", "Basics")

Execute this pipeline:

## Step 1: Locate the module
Find all relevant .lean files for the module across spec/, bridge/, and code/ layers.
Read the doc comments to identify the source spec URLs (RFCs, man pages, etc.).
Show the user what files and specs were found, and ask them to confirm or provide spec URLs if none are documented.

## Step 2: Extract spec requirements (spec-fetcher)
Spawn the spec-fetcher subagent with the source spec URLs.
This produces structured TYPES, OPERATIONS, INVARIANTS, ERROR_CONDITIONS, EXAMPLES.
Show the extraction summary to the user.

## Step 3: Run conformance tests (conformance-tester)
Spawn the conformance-tester subagent with:
- The module file paths
- The spec-fetcher extraction output
This generates #eval test files and runs them.

## Step 4: Run formalization audit (formalization-auditor)
Spawn the formalization-auditor subagent with:
- The module file paths
- The source spec URLs
This checks for trivial theorems, coverage gaps, and signature mismatches.

## Step 5: Cross-layer consistency check
Check manually (do not delegate):
- Does code/ actually import and use spec/ types? (not just redefining them)
- Do bridge/ axioms reference the correct spec/ definitions?
- Are there spec/ definitions with no corresponding code/ implementation?
- Are there code/ implementations with no corresponding spec/ definition?

## Step 6: Present combined report
Combine all results into a single audit report:

```
# Audit Report: <Module>

## Overall Grade: [A/B/C/D/F]

## Conformance (from conformance-tester)
- X/Y spec examples pass
- Failures: [list]

## Theorem Quality (from formalization-auditor)
- Trivial/vacuous theorems flagged: [list]
- Non-trivial proven theorems: N

## Spec Coverage (from formalization-auditor)
- MUST requirements covered: X/Y
- Missing: [list]

## Cross-Layer Consistency
- spec→code coverage: X/Y definitions have implementations
- bridge axiom alignment: [status]

## Recommendations
1. [Most critical issue]
2. [Second most critical]
...
```

## Grading Rubric
- **A**: All spec examples pass, no trivial theorems, >90% MUST coverage, full cross-layer consistency
- **B**: All spec examples pass, minor gaps in coverage or cross-layer consistency
- **C**: Some spec example failures OR significant coverage gaps
- **D**: Multiple spec example failures AND coverage gaps
- **F**: Fundamental modeling errors (wrong types, wrong invariants)