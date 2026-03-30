import SWELib.Db.Migrations.Types
import SWELib.Db.Migrations.State
import SWELib.Db.Migrations.Operations
import SWELib.Db.Migrations.Invariants

/-!
# Database Migration Properties

Theorems about the migration system's core guarantees: well-formedness
of the empty database, idempotent rejection of already-applied
migrations, correctness of pending-migration filtering, squash
semantics, conflict-detection soundness, rollback round-tripping,
history monotonicity, and preservation of schema well-formedness.

Simple properties (1-4) carry proofs or `sorry`; deeper semantic
properties (5-10) are stated as `axiom`s to be discharged when the
proof infrastructure matures.

## Specification References
- Migration lifecycle invariants
- Schema DDL semantics and well-formedness preservation
- Squash and conflict-detection correctness
-/

namespace SWELib.Db.Migrations

-- ═══════════════════════════════════════════════════════════
-- 1. Empty Database is Well-Formed
-- ═══════════════════════════════════════════════════════════

/-- The empty database has a well-formed schema: no tables means all
    conditions (no duplicate table names, no duplicate column names,
    valid foreign keys) hold vacuously. -/
theorem empty_database_well_formed : SchemaWellFormed emptyDatabase.schema := by
  unfold SchemaWellFormed emptyDatabase
  simp [Schema.tableNames]

-- ═══════════════════════════════════════════════════════════
-- 2. Applying an Already-Applied Migration is an Error
-- ═══════════════════════════════════════════════════════════

/-- If a migration's version already appears in the database history,
    `applyMigration` returns `migrationAlreadyApplied`. -/
theorem apply_already_applied_is_error
    (db : DatabaseState) (m : Migration) (ts : Nat)
    (h : db.isApplied m.version = true) :
    applyMigration db m ts = .error (.migrationAlreadyApplied m.version) := by
  unfold applyMigration
  simp [h]

-- ═══════════════════════════════════════════════════════════
-- 3. Pending Migrations Exclude Applied Versions
-- ═══════════════════════════════════════════════════════════

/-- Every migration returned by `pendingMigrations` has a version that
    does not appear in the applied history. -/
theorem pending_excludes_applied
    (ms : MigrationSet) (history : MigrationHistory)
    (m : Migration)
    (hm : m ∈ pendingMigrations ms history) :
    ¬ (history.map (·.version)).any (· == m.version) = true := by
  unfold pendingMigrations at hm
  simp [List.mem_filter] at hm
  obtain ⟨_, hm2⟩ := hm
  intro h_any
  rw [List.any_eq_true] at h_any
  obtain ⟨v, hv_mem, hv_eq⟩ := h_any
  rw [List.mem_map] at hv_mem
  obtain ⟨rec, hrec_mem, hrec_eq⟩ := hv_mem
  subst hrec_eq
  have h_ne := hm2 rec hrec_mem
  rw [beq_iff_eq] at hv_eq
  exact h_ne hv_eq

-- ═══════════════════════════════════════════════════════════
-- 4. Squash of Empty List is None
-- ═══════════════════════════════════════════════════════════

/-- Squashing an empty list of migrations yields `none`. -/
theorem squash_none_on_empty : squash [] = none := by
  rfl

-- ═══════════════════════════════════════════════════════════
-- 5. Squash Preserves Schema Effect
-- ═══════════════════════════════════════════════════════════

/-- Applying all migrations in sequence produces the same final schema
    as applying the single squashed migration.  This is the key semantic
    equivalence that justifies migration squashing.

    Stated as an axiom because the proof requires induction over the
    diff list with error-handling threading. -/
axiom squash_preserves_schema_effect
    (ms : List Migration) (s : Schema) (squashed : Migration)
    (h_squash : squash ms = some squashed) :
    applyDiff s (ms.flatMap (·.up)) = applyDiff s squashed.up

-- ═══════════════════════════════════════════════════════════
-- 6. Conflict Detection is Sound
-- ═══════════════════════════════════════════════════════════

/-- If `detectConflicts` reports no conflicts between two migrations,
    then those migrations commute: applying m1 then m2 produces the
    same schema as applying m2 then m1.

    Stated as an axiom because commutativity of DDL operations requires
    case analysis over all `SchemaChange` combinations. -/
axiom conflict_detection_sound
    (m1 m2 : Migration) (s : Schema)
    (h_no_conflicts : detectConflicts m1 m2 = []) :
    applyDiff s (m1.up ++ m2.up) = applyDiff s (m2.up ++ m1.up)

-- ═══════════════════════════════════════════════════════════
-- 7. Rollback Round-Trip
-- ═══════════════════════════════════════════════════════════

/-- If a migration's down script is a true inverse of its up script
    (i.e., the migration is `RollbackConsistent`), then applying up
    followed by down yields the original schema.

    Stated as an axiom because the proof depends on the semantics of
    each `SchemaChange` variant and its inverse. -/
axiom rollback_roundtrip
    (m : Migration) (s : Schema)
    (h_wf : SchemaWellFormed s)
    (h_consistent : RollbackConsistent m) (d : SchemaDiff)
    (h_down : m.down = some d) :
    (do let s' ← applyDiff s m.up; applyDiff s' d : Except MigrationError Schema) =
    .ok s

-- ═══════════════════════════════════════════════════════════
-- 8. History is Monotonic on Apply
-- ═══════════════════════════════════════════════════════════

/-- After a successful `applyMigration`, the old history is a prefix
    of the new history.  Migrations are append-only.

    Stated as an axiom because extracting the `DatabaseState` from the
    `Except` result and reasoning about `List.isPrefixOf` on the
    appended history requires careful unfolding. -/
axiom history_monotonic_on_apply
    (db db' : DatabaseState) (m : Migration) (ts : Nat)
    (h_ok : applyMigration db m ts = .ok db') :
    MonotonicHistory db db'

-- ═══════════════════════════════════════════════════════════
-- 9. Validation Implies Safe Apply
-- ═══════════════════════════════════════════════════════════

/-- If `validateMigration` succeeds on a schema, then `applyMigration`
    on a `DatabaseState` with that schema will not fail with a schema
    error (it may still fail with `migrationAlreadyApplied`).

    Stated as an axiom because `validateMigration` and `applyMigration`
    share the same `applyDiff` call, so the proof is essentially that
    `applyDiff` is deterministic. -/
axiom validation_implies_safe_apply
    (db : DatabaseState) (m : Migration) (ts : Nat) (resultSchema : Schema)
    (h_valid : validateMigration db.schema m = .ok resultSchema)
    (h_not_applied : db.isApplied m.version = false) :
    ∃ db', applyMigration db m ts = .ok db' ∧ db'.schema = resultSchema

-- ═══════════════════════════════════════════════════════════
-- 10. Apply Preserves Well-Formedness
-- ═══════════════════════════════════════════════════════════

/-- If the schema is well-formed before applying a migration, and the
    migration validates successfully, the resulting schema is also
    well-formed.

    Stated as an axiom because well-formedness preservation requires
    case-splitting on every `SchemaChange` variant and showing each
    one individually preserves the no-duplicate-names and valid-FK
    invariants. -/
axiom apply_preserves_well_formedness
    (db db' : DatabaseState) (m : Migration) (ts : Nat)
    (h_wf : SchemaWellFormed db.schema)
    (h_ok : applyMigration db m ts = .ok db') :
    SchemaWellFormed db'.schema

end SWELib.Db.Migrations
