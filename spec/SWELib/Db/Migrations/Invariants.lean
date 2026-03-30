import SWELib.Db.Migrations.Types
import SWELib.Db.Migrations.State

/-!
# Database Migration Invariants

Key invariants that a well-behaved migration system must satisfy:
version ordering, schema well-formedness, history faithfulness,
idempotent application, rollback consistency, conflict freedom,
and monotonic history growth.

These are stated as `Prop` definitions so that downstream theorems
can quantify over them or use them as preconditions.

## Specification References
- Migration lifecycle: ordered versions, faithful history
- Schema integrity: no duplicate tables/columns, valid foreign keys
- Rollback safety: up then down yields original schema
-/

namespace SWELib.Db.Migrations

-- ═══════════════════════════════════════════════════════════
-- Helper: tables touched by a SchemaDiff
-- ═══════════════════════════════════════════════════════════

/-- Extract the set of table names that a single schema change touches. -/
def SchemaChange.touchedTables : SchemaChange → List String
  | .addTable t          => [t.name]
  | .dropTable n         => [n]
  | .addColumn t _       => [t]
  | .dropColumn t _      => [t]
  | .alterColumnType t _ _ => [t]
  | .addIndex idx        => [idx.tableName]
  | .dropIndex _         => []   -- index name alone does not identify a table
  | .addConstraint t _   => [t]
  | .dropConstraint t _  => [t]

/-- All table names touched by a schema diff. -/
def SchemaDiff.touchedTables (diff : SchemaDiff) : List String :=
  diff.flatMap SchemaChange.touchedTables

-- ═══════════════════════════════════════════════════════════
-- 1. VersionStrictlyOrdered
-- ═══════════════════════════════════════════════════════════

/-- All versions in a migration history are strictly increasing.
    This is already encoded structurally in `DatabaseState.h_ordered`
    but is useful as a standalone predicate on raw history lists. -/
def VersionStrictlyOrdered (h : MigrationHistory) : Prop :=
  List.Pairwise (fun a b => a.version < b.version) h

-- ═══════════════════════════════════════════════════════════
-- 2. SchemaWellFormed
-- ═══════════════════════════════════════════════════════════

/-- A schema is well-formed when:
    - No two tables share the same name.
    - Within each table, no two columns share the same name.
    - Every foreign-key constraint references a table that exists
      within the schema. -/
def SchemaWellFormed (s : Schema) : Prop :=
  -- (a) No duplicate table names
  List.Pairwise (fun t1 t2 => t1.name ≠ t2.name) s.tables
  -- (b) No duplicate column names within each table
  ∧ (∀ t, t ∈ s.tables →
       List.Pairwise (fun c1 c2 => c1.name ≠ c2.name) t.columns)
  -- (c) Foreign-key targets reference existing tables
  ∧ (∀ t, t ∈ s.tables →
       ∀ c, c ∈ t.constraints →
         match c with
         | .foreignKey _ refTable _ => refTable ∈ s.tableNames
         | _ => True)

-- ═══════════════════════════════════════════════════════════
-- 3. MigrationSetWellFormed
-- ═══════════════════════════════════════════════════════════

/-- A migration set is well-formed when its versions are strictly
    increasing and there are no duplicate versions.
    The `MigrationSet` structure already carries `h_ordered`, so
    this predicate simply re-exposes that guarantee plus an
    explicit no-duplicates clause (which is implied by strict
    ordering but stated for clarity). -/
def MigrationSetWellFormed (ms : MigrationSet) : Prop :=
  -- Versions strictly increasing (structural from ms.h_ordered)
  List.Pairwise (fun a b => a.version < b.version) ms.migrations
  -- No duplicate versions (implied by strict ordering)
  ∧ List.Pairwise (fun a b => a.version ≠ b.version) ms.migrations

-- ═══════════════════════════════════════════════════════════
-- 4. HistoryFaithful
-- ═══════════════════════════════════════════════════════════

/-- The applied history is faithful to the migration set: every
    version recorded in the database state's history also appears
    in the migration set.  This ensures no "phantom" migrations
    that are not tracked in the canonical set. -/
def HistoryFaithful (db : DatabaseState) (ms : MigrationSet) : Prop :=
  ∀ rec, rec ∈ db.history →
    ∃ m, m ∈ ms.migrations ∧ m.version = rec.version

-- ═══════════════════════════════════════════════════════════
-- 5. IdempotentApplication
-- ═══════════════════════════════════════════════════════════

/-- Attempting to apply a migration whose version is already recorded
    in the database state is an error, not a silent success.
    This prevents accidental double-application. -/
def IdempotentApplication (db : DatabaseState) (m : Migration) : Prop :=
  (∃ rec, rec ∈ db.history ∧ rec.version = m.version) →
    -- Re-application is forbidden; any apply function must return an error.
    -- We model this abstractly: the version is already present.
    db.isApplied m.version = true

-- ═══════════════════════════════════════════════════════════
-- 6. RollbackConsistent
-- ═══════════════════════════════════════════════════════════

/-- Apply a single `SchemaChange` to a `Schema`, returning the
    modified schema.  This is a local helper used only to state
    `RollbackConsistent` without importing Operations. -/
private def applyChange (s : Schema) (c : SchemaChange) : Schema :=
  match c with
  | .addTable t => { tables := s.tables ++ [t] }
  | .dropTable n => { tables := s.tables.filter (·.name != n) }
  | .addColumn tn col =>
      { tables := s.tables.map fun t =>
          if t.name == tn then { t with columns := t.columns ++ [col] } else t }
  | .dropColumn tn cn =>
      { tables := s.tables.map fun t =>
          if t.name == tn then { t with columns := t.columns.filter (·.name != cn) } else t }
  | .alterColumnType tn cn newTy =>
      { tables := s.tables.map fun t =>
          if t.name == tn then
            { t with columns := t.columns.map fun c =>
                if c.name == cn then { c with colType := newTy } else c }
          else t }
  | .addIndex idx =>
      { tables := s.tables.map fun t =>
          if t.name == idx.tableName then { t with indexes := t.indexes ++ [idx] } else t }
  | .dropIndex iname =>
      { tables := s.tables.map fun t =>
          { t with indexes := t.indexes.filter (·.name != iname) } }
  | .addConstraint tn ck =>
      { tables := s.tables.map fun t =>
          if t.name == tn then { t with constraints := t.constraints ++ [ck] } else t }
  | .dropConstraint tn idx =>
      { tables := s.tables.map fun t =>
          if t.name == tn then { t with constraints := t.constraints.eraseIdx idx } else t }

/-- Apply a full `SchemaDiff` to a `Schema` by folding `applyChange`. -/
private def applyDiff (s : Schema) (d : SchemaDiff) : Schema :=
  d.foldl applyChange s

/-- A migration has a consistent rollback if its `down` script, when
    present, reverses its `up` script: for any well-formed schema,
    applying `up` then `down` yields the original schema. -/
def RollbackConsistent (m : Migration) : Prop :=
  match m.down with
  | none => True
  | some d => ∀ s : Schema, SchemaWellFormed s →
      applyDiff (applyDiff s m.up) d = s

-- ═══════════════════════════════════════════════════════════
-- 7. ConflictFree
-- ═══════════════════════════════════════════════════════════

/-- Two migrations are conflict-free if their `up` diffs touch
    disjoint sets of table names.  Conflict-free migrations can
    safely be applied in either order. -/
def ConflictFree (m1 m2 : Migration) : Prop :=
  ∀ tbl,
    tbl ∈ m1.up.touchedTables →
    tbl ∉ m2.up.touchedTables

-- ═══════════════════════════════════════════════════════════
-- 8. MonotonicHistory
-- ═══════════════════════════════════════════════════════════

/-- If `state2` is derived from `state1` by applying (not rolling
    back) migrations, then `state1`'s history is a prefix of
    `state2`'s history.  This captures forward-only evolution. -/
def MonotonicHistory (state1 state2 : DatabaseState) : Prop :=
  state1.history.isPrefixOf state2.history

end SWELib.Db.Migrations
