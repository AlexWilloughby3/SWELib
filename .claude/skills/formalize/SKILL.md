---
name: formalize
description: End-to-end formalization of a SWELib module from spec sources. Use when the user wants to formalize a new module through the spec-fetcher → lean-planner → lean-codegen → formalization-auditor pipeline.
---

Formalize the module: $ARGUMENTS

Execute this pipeline:
1. Spawn spec-fetcher subagent with the module's source URLs
2. Review the extraction output (show to user for approval)
3. Spawn lean-planner subagent with the extraction
4. Review the plan (show to user for approval of representation decisions)
5. Spawn lean-codegen subagent with the approved plan
6. Spawn formalization-auditor subagent to check the result
7. Present the audit report and final files
