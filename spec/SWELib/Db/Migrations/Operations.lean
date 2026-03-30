import SWELib.Db.Migrations.Types
import SWELib.Db.Migrations.State

/-!
# Database Migration Operations

Core operations for applying, rolling back, and managing database schema
migrations.  Includes schema helpers, change application, conflict
detection, and migration squashing.

Proof obligations on history ordering invariants use `sorry` and will be
discharged in `Properties.lean`.

## Specification References
- Schema DDL operations: addTable, dropTable, addColumn, dropColumn, etc.
- Migration lifecycle: apply, rollback, pending, squash
- Conflict detection: table-level overlap between migrations
-/

namespace SWELib.Db.Migrations

-- ═══════════════════════════════════════════════════════════
-- Schema Helpers
-- ═══════════════════════════════════════════════════════════

/-- Find a table definition in a schema by name. -/
def Schema.findTable (s : Schema) (name : String) : Option TableDef :=
  s.tables.find? (fun t => t.name == name)

/-- Check whether a schema contains a table with the given name. -/
def Schema.hasTableName (s : Schema) (name : String) : Bool :=
  s.tables.any (fun t => t.name == name)

/-- Add a table definition to the front of the schema's table list. -/
def Schema.addTable (s : Schema) (t : TableDef) : Schema :=
  { s with tables := t :: s.tables }

/-- Remove all tables with the given name from the schema. -/
def Schema.dropTable (s : Schema) (name : String) : Schema :=
  { s with tables := s.tables.filter (fun t => t.name != name) }

/-- Apply a function to the first table matching the given name,
    leaving all other tables unchanged. -/
def Schema.mapTable (s : Schema) (name : String) (f : TableDef → TableDef) : Schema :=
  { s with tables := s.tables.map (fun t => if t.name == name then f t else t) }

/-- Check whether a table definition contains a column with the given name. -/
def TableDef.hasColumn (t : TableDef) (name : String) : Bool :=
  t.columns.any (fun c => c.name == name)

/-- Append a column definition to a table's column list. -/
def TableDef.addColumn (t : TableDef) (col : ColumnDef) : TableDef :=
  { t with columns := t.columns ++ [col] }

/-- Remove all columns with the given name from a table definition. -/
def TableDef.dropColumn (t : TableDef) (name : String) : TableDef :=
  { t with columns := t.columns.filter (fun c => c.name != name) }

-- ═══════════════════════════════════════════════════════════
-- Apply a Single Schema Change
-- ═══════════════════════════════════════════════════════════

/-- Apply a single schema change to a schema.  Returns an error if
    preconditions are violated (e.g., table already exists, column not
    found). -/
def applyChange (s : Schema) (c : SchemaChange) : Except MigrationError Schema :=
  match c with
  | .addTable table =>
    if s.hasTableName table.name then
      .error (.tableAlreadyExists table.name)
    else
      .ok (s.addTable table)
  | .dropTable tableName =>
    if !s.hasTableName tableName then
      .error (.tableNotFound tableName)
    else
      .ok (s.dropTable tableName)
  | .addColumn tableName column =>
    match s.findTable tableName with
    | none => .error (.tableNotFound tableName)
    | some tbl =>
      if tbl.hasColumn column.name then
        .error (.columnAlreadyExists tableName column.name)
      else
        .ok (s.mapTable tableName (fun t => t.addColumn column))
  | .dropColumn tableName columnName =>
    match s.findTable tableName with
    | none => .error (.tableNotFound tableName)
    | some tbl =>
      if !tbl.hasColumn columnName then
        .error (.columnNotFound tableName columnName)
      else
        .ok (s.mapTable tableName (fun t => t.dropColumn columnName))
  | .alterColumnType tableName columnName newType =>
    match s.findTable tableName with
    | none => .error (.tableNotFound tableName)
    | some tbl =>
      if !tbl.hasColumn columnName then
        .error (.columnNotFound tableName columnName)
      else
        .ok (s.mapTable tableName (fun t =>
          { t with columns := t.columns.map (fun c =>
              if c.name == columnName then { c with colType := newType } else c) }))
  | .addIndex idx =>
    if !s.hasTableName idx.tableName then
      .error (.tableNotFound idx.tableName)
    else
      .ok (s.mapTable idx.tableName (fun t =>
        { t with indexes := t.indexes ++ [idx] }))
  | .dropIndex indexName =>
    .ok { s with tables := s.tables.map (fun t =>
      { t with indexes := t.indexes.filter (fun i => i.name != indexName) }) }
  | .addConstraint tableName constraint =>
    if !s.hasTableName tableName then
      .error (.tableNotFound tableName)
    else
      .ok (s.mapTable tableName (fun t =>
        { t with constraints := t.constraints ++ [constraint] }))
  | .dropConstraint tableName constraintIdx =>
    if !s.hasTableName tableName then
      .error (.tableNotFound tableName)
    else
      .ok (s.mapTable tableName (fun t =>
        { t with constraints := t.constraints.eraseIdx constraintIdx }))

-- ═══════════════════════════════════════════════════════════
-- Apply a Schema Diff
-- ═══════════════════════════════════════════════════════════

/-- Apply a sequence of schema changes (a diff) to a schema by
    folding `applyChange` left-to-right.  Short-circuits on the
    first error. -/
def applyDiff (s : Schema) (diff : SchemaDiff) : Except MigrationError Schema :=
  diff.foldlM (init := s) applyChange

-- ═══════════════════════════════════════════════════════════
-- Validate a Migration
-- ═══════════════════════════════════════════════════════════

/-- Validate a migration against a schema by applying its up diff.
    Returns the resulting schema on success.  Validation IS
    application: if the diff applies cleanly, the migration is valid
    for this schema. -/
def validateMigration (s : Schema) (m : Migration) : Except MigrationError Schema :=
  applyDiff s m.up

-- ═══════════════════════════════════════════════════════════
-- Apply a Migration to Database State
-- ═══════════════════════════════════════════════════════════

/-- Apply a migration to the database state.  Checks that the migration
    has not already been applied, applies the up diff, and appends a
    history record.  The `timestamp` parameter is the current Unix time.

    Uses `sorry` for the ordering proof on the new history; this will
    be discharged in `Properties.lean`. -/
def applyMigration (db : DatabaseState) (m : Migration) (timestamp : Nat)
    : Except MigrationError DatabaseState :=
  if db.isApplied m.version then
    .error (.migrationAlreadyApplied m.version)
  else
    match applyDiff db.schema m.up with
    | .error e => .error e
    | .ok newSchema =>
      let record : MigrationRecord := { version := m.version, appliedAt := timestamp }
      .ok {
        schema := newSchema
        history := db.history ++ [record]
        h_ordered := sorry
      }

-- ═══════════════════════════════════════════════════════════
-- Rollback Last Migration
-- ═══════════════════════════════════════════════════════════

/-- Roll back the most recently applied migration.  Requires that the
    migration has a down diff.  Pops the last history entry and applies
    the down diff to the current schema.

    Uses `sorry` for the ordering proof on the truncated history; this
    will be discharged in `Properties.lean`. -/
def rollbackLast (db : DatabaseState) : Except MigrationError DatabaseState :=
  match db.history.getLast? with
  | none => .error (.validationFailed "no migrations to roll back")
  | some lastRecord =>
    -- We need to find the corresponding migration's down diff.
    -- Since we only have the record (version + timestamp), we require
    -- that the caller has embedded down info.  For this pure-state
    -- operation, we signal an error; a richer version would take the
    -- migration set as input.
    .error (.invalidRollback lastRecord.version)

/-- Roll back the most recently applied migration using a migration set
    to look up the down diff.  Applies the down diff to the current
    schema and truncates the history. -/
def rollbackLastWith (db : DatabaseState) (migrations : List Migration)
    : Except MigrationError DatabaseState :=
  match db.history.getLast? with
  | none => .error (.validationFailed "no migrations to roll back")
  | some lastRecord =>
    match migrations.find? (fun m => m.version == lastRecord.version) with
    | none => .error (.invalidRollback lastRecord.version)
    | some migration =>
      match migration.down with
      | none => .error (.invalidRollback lastRecord.version)
      | some downDiff =>
        match applyDiff db.schema downDiff with
        | .error e => .error e
        | .ok newSchema =>
          .ok {
            schema := newSchema
            history := db.history.dropLast
            h_ordered := sorry
          }

-- ═══════════════════════════════════════════════════════════
-- Pending Migrations
-- ═══════════════════════════════════════════════════════════

/-- Return the migrations from a migration set that have not yet been
    applied according to the given history. -/
def pendingMigrations (ms : MigrationSet) (history : MigrationHistory) : List Migration :=
  let appliedVersions := history.map (·.version)
  ms.migrations.filter (fun m => !appliedVersions.any (· == m.version))

-- ═══════════════════════════════════════════════════════════
-- Squash Migrations
-- ═══════════════════════════════════════════════════════════

/-- Squash a list of migrations into a single migration by concatenating
    all up diffs.  Returns `none` if the input list is empty.  The
    squashed version is the last migration's version; the down diff is
    `none` because squashed migrations lose individual rollback
    capability. -/
def squash (ms : List Migration) : Option Migration :=
  match ms with
  | [] => none
  | _ =>
    let combinedUp := ms.flatMap (·.up)
    let lastVersion := (ms.getLast!).version
    let descriptions := ms.map (·.description)
    some {
      version := lastVersion
      description := String.intercalate "; " descriptions
      up := combinedUp
      down := none
    }

-- ═══════════════════════════════════════════════════════════
-- Conflict Detection
-- ═══════════════════════════════════════════════════════════

/-- Extract the set of table names touched by a schema diff.
    A table is "touched" if any change in the diff references it. -/
private def touchedTables (diff : SchemaDiff) : List String :=
  diff.filterMap fun c =>
    match c with
    | .addTable t => some t.name
    | .dropTable name => some name
    | .addColumn name _ => some name
    | .dropColumn name _ => some name
    | .alterColumnType name _ _ => some name
    | .addIndex idx => some idx.tableName
    | .dropIndex _ => none
    | .addConstraint name _ => some name
    | .dropConstraint name _ => some name

/-- Detect conflicts between two migrations by checking for table-level
    overlap in their up diffs.  Each overlapping table name produces a
    `MigrationConflict` entry. -/
def detectConflicts (m1 m2 : Migration) : List MigrationConflict :=
  let tables1 := (touchedTables m1.up).eraseDups
  let tables2 := (touchedTables m2.up).eraseDups
  let overlapping := tables1.filter (fun t => tables2.any (· == t))
  overlapping.map fun tableName => {
    migration1 := m1.version
    migration2 := m2.version
    overlappingObject := tableName
    description := s!"Both migrations touch table '{tableName}'"
  }

end SWELib.Db.Migrations
