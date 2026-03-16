# CI/CD Formalization — Audit Findings

Generated after the initial CI/CD formalization (2026-03-15).

---

## RED — Fix before considering complete

### Remove trivial theorems that just restate definitions
- `Deployment.lean:252` — `scaleUpBound_eq` closes with `rfl` because it IS the definition. Remove.
- `Deployment.lean:273` — `h_valid_positive` just does `fun cfg => cfg.h_valid`. Remove.

### Bug: `computePipelineRunStatus` never returns `.cancelled`
- `Pipeline.lean:293` — The `PipelineRunStatus.cancelled` constructor exists but is dead code.
  Cancelled tasks fall through to `.running`. The spec intends cancelled tasks → cancelled pipeline status.

### `prunePreservesCurrentRevision` states the wrong direction
- `Rollback.lean:156` — Current theorem: "if entry survived pruning with revision=current, it was in original."
  The important direction is the CONVERSE: "if current revision was in original history, it survives pruning."
  Fix the theorem statement.

### No DAG acyclicity correctness theorem
- `Pipeline.lean` — `buildDag` returns `Except.error .cycle` for cyclic inputs but there is no theorem
  proving that `Except.ok adj` implies `adj` is acyclic. Critical coverage gap.

### No `resolveExecutionOrder` correctness theorem
- `Pipeline.lean` — No theorem states the output respects dependency ordering (if A depends on B,
  B appears in an earlier layer). This is the whole point of topological sorting.

### `switchBlueGreen_involution` is sorry'd and blocked
- `Deployment.lean:268` — Needs an `@[ext]` lemma on `BlueGreenConfig` before the proof can close.
  Add `@[ext] theorem BlueGreenConfig.ext ...` then close with `cases cfg.activeSlot <;> simp [switchBlueGreen]`.

---

## YELLOW — Worth addressing

### `reconcile_idempotent` is misnamed and trivially a corollary
- `GitOps.lean:242` — Says "if synced then drift is empty" which is just `isSynced_iff_noDrift.mp`.
  Either remove or rename to something accurate.

### `DeploymentCondition` types are entirely dead code
- `Deployment.lean:122–150` — `DeploymentConditionType`, `DeploymentConditionReason`, `DeploymentCondition`
  are fully defined but no function ever uses them. Either wire them into `checkProgress`/`DeploymentStatus`
  or document they are stubs for future use.

### `completeRollback` has no phase precondition
- `Rollback.lean:127` — Spec says pre: `phase = inProgress`. Current implementation happily "completes"
  a `notStarted` rollback. Add a guard or strengthen the type.

### `ns` / `content` field renames undocumented
- `GitOps.lean:21,23` — `DeclarativeResource.namespace` → `ns` and `.spec` → `content` to avoid Lean
  keyword conflicts. Add a comment on each field explaining the rename.

### `computeDrift` categories unverified
- `GitOps.lean:161` — No theorem states the three categories (added/removed/modified) match their
  definitions. Should add theorems like:
  `r ∈ desired ∧ r ∉ actual → ∃ item ∈ computeDrift ..., item.kind = .removed`

---

## GREEN — Sorries that look easy to close

| Theorem | File | Suggested tactic |
|---|---|---|
| `rollbackCreatesNewRevision` | `Rollback.lean:144` | `simp [initiateRollback, validateRollbackTarget]; omega` |
| `detectDrift_outOfSync` | `GitOps.lean:227` | `simp [detectDrift, isSynced, List.isEmpty_iff]` |
| `computeStatus_succeeded` | `Pipeline.lean:305` | `simp [computePipelineRunStatus]` + `List.all_append` |
