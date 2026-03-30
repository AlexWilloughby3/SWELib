---
description: Audit an existing SWELib formalization for quality and spec conformance
---

Audit the formalization: $ARGUMENTS

Execute this pipeline:
1. Locate all .lean files for the module across spec/ and impl/
2. Extract source spec URLs from doc comments
3. Spawn spec-fetcher subagent to re-extract requirements and normative examples
4. Spawn conformance-tester subagent to generate and run #eval tests against spec examples
5. Spawn formalization-auditor subagent for triviality scan, coverage audit, and signature matching
6. Check cross-layer consistency (spec↔impl alignment, bridge axiom correctness)
7. Present combined audit report with grade (A-F) and recommendations
