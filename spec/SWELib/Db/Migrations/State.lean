import SWELib.Db.Migrations.Types

/-!
# Database Migrations -- State

The migration state machine and database state model.  `DatabaseState`
captures the current schema together with an ordered history of applied
migrations.  Helper functions extract versions, check membership, and
look up tables in the schema.

## Specification References
- Migration lifecycle: pending -> applied | skipped | rolledBack
- Database state = current schema + ordered migration history
-/

namespace SWELib.Db.Migrations

-- ═══════════════════════════════════════════════════════════
-- Migration Status
-- ═══════════════════════════════════════════════════════════

/-- The lifecycle status of a migration with respect to a database. -/
inductive MigrationStatus where
  /-- The migration has not yet been applied. -/
  | pending
  /-- The migration has been successfully applied. -/
  | applied
  /-- The migration was intentionally skipped (e.g., out-of-order baseline). -/
  | skipped
  /-- The migration was applied and subsequently rolled back. -/
  | rolledBack
  deriving DecidableEq, Repr

-- ═══════════════════════════════════════════════════════════
-- Database State
-- ═══════════════════════════════════════════════════════════

/-- The state of a database at a point in time: its current schema plus
    an ordered history of every migration that has been applied.

    The `h_ordered` invariant guarantees that the history is strictly
    increasing by version, which mirrors the real-world rule that
    migrations are applied in version order without duplicates. -/
structure DatabaseState where
  /-- The current database schema. -/
  schema : Schema
  /-- Applied migrations, ordered by version. -/
  history : MigrationHistory
  /-- History is strictly ordered by version. -/
  h_ordered : List.Pairwise (fun a b => a.version < b.version) history

-- ═══════════════════════════════════════════════════════════
-- Empty Database
-- ═══════════════════════════════════════════════════════════

/-- An empty database with no tables and no migration history. -/
def emptyDatabase : DatabaseState where
  schema := { tables := [] }
  history := []
  h_ordered := List.Pairwise.nil

-- ═══════════════════════════════════════════════════════════
-- Queries on DatabaseState
-- ═══════════════════════════════════════════════════════════

/-- Extract the list of migration versions from the history. -/
def DatabaseState.appliedVersions (db : DatabaseState) : List MigrationVersion :=
  db.history.map (·.version)

/-- Check whether a given version appears in the migration history. -/
def DatabaseState.isApplied (db : DatabaseState) (v : MigrationVersion) : Bool :=
  db.history.any (fun r => r.version == v)

/-- Return the version of the most recently applied migration, if any. -/
def DatabaseState.lastApplied (db : DatabaseState) : Option MigrationVersion :=
  db.history.getLast? |>.map (·.version)

/-- Check whether the schema contains a table with the given name. -/
def DatabaseState.hasTable (db : DatabaseState) (name : String) : Bool :=
  db.schema.tables.any (fun t => t.name == name)

/-- Look up a table definition by name. Returns `none` if no table
    with the given name exists in the schema. -/
def DatabaseState.getTable (db : DatabaseState) (name : String) : Option TableDef :=
  db.schema.tables.find? (fun t => t.name == name)

end SWELib.Db.Migrations
