/-!
# Database Schema Migration Types

Core types for representing database schemas, schema changes, and
migration metadata.  These form the vocabulary used by the migration
operations and invariant modules.

## Specification References
- Database schema migration lifecycle (version-ordered, up/down diffs)
- Schema representation: tables, columns, constraints, indexes
-/

namespace SWELib.Db.Migrations

-- ═══════════════════════════════════════════════════════════
-- Migration Version
-- ═══════════════════════════════════════════════════════════

/-- A migration version identifier, backed by a natural number.
    Versions are totally ordered and used to sequence migrations. -/
structure MigrationVersion where
  /-- The numeric version identifier -/
  val : Nat
  deriving DecidableEq, Repr, Hashable, Inhabited

instance : LT MigrationVersion where
  lt a b := a.val < b.val

instance : LE MigrationVersion where
  le a b := a.val ≤ b.val

instance : Ord MigrationVersion where
  compare a b := compare a.val b.val

instance (a b : MigrationVersion) : Decidable (a < b) :=
  inferInstanceAs (Decidable (a.val < b.val))

instance (a b : MigrationVersion) : Decidable (a ≤ b) :=
  inferInstanceAs (Decidable (a.val ≤ b.val))

instance : ToString MigrationVersion where
  toString v := s!"v{v.val}"

-- ═══════════════════════════════════════════════════════════
-- Column Types
-- ═══════════════════════════════════════════════════════════

/-- SQL column types supported in schema definitions. -/
inductive ColumnType where
  /-- Integer column (e.g., INT, BIGINT) -/
  | integer
  /-- Text/varchar column -/
  | text
  /-- Boolean column -/
  | boolean
  /-- Floating-point column (e.g., FLOAT, DOUBLE) -/
  | float
  /-- Timestamp column -/
  | timestamp
  /-- Binary large object column -/
  | blob
  /-- Nullable wrapper around another column type -/
  | nullable (inner : ColumnType)
  deriving DecidableEq, Repr, Inhabited

-- ═══════════════════════════════════════════════════════════
-- Column Definition
-- ═══════════════════════════════════════════════════════════

/-- A column definition within a table. -/
structure ColumnDef where
  /-- Column name -/
  name : String
  /-- Column data type -/
  colType : ColumnType
  deriving DecidableEq, Repr, Inhabited

-- ═══════════════════════════════════════════════════════════
-- Constraints
-- ═══════════════════════════════════════════════════════════

/-- Kinds of table-level constraints. -/
inductive ConstraintKind where
  /-- Primary key on the given columns -/
  | primaryKey (columns : List String)
  /-- Unique constraint on the given columns -/
  | unique (columns : List String)
  /-- Foreign key: local columns reference refTable(refColumns) -/
  | foreignKey (columns : List String) (refTable : String) (refColumns : List String)
  /-- Named check constraint -/
  | check (name : String)
  /-- NOT NULL constraint on a single column -/
  | notNull (column : String)
  deriving DecidableEq, Repr, Inhabited

-- ═══════════════════════════════════════════════════════════
-- Index Definition
-- ═══════════════════════════════════════════════════════════

/-- An index definition on a table. -/
structure IndexDef where
  /-- Index name -/
  name : String
  /-- Table the index belongs to -/
  tableName : String
  /-- Columns included in the index -/
  columns : List String
  /-- Whether the index enforces uniqueness -/
  unique : Bool
  deriving DecidableEq, Repr, Inhabited

-- ═══════════════════════════════════════════════════════════
-- Table Definition
-- ═══════════════════════════════════════════════════════════

/-- A table definition comprising columns, constraints, and indexes. -/
structure TableDef where
  /-- Table name -/
  name : String
  /-- Ordered list of column definitions -/
  columns : List ColumnDef
  /-- Table-level constraints -/
  constraints : List ConstraintKind
  /-- Indexes associated with the table -/
  indexes : List IndexDef
  deriving DecidableEq, Repr, Inhabited

-- ═══════════════════════════════════════════════════════════
-- Schema
-- ═══════════════════════════════════════════════════════════

/-- A database schema: a collection of table definitions. -/
structure Schema where
  /-- The tables in this schema -/
  tables : List TableDef
  deriving DecidableEq, Repr, Inhabited

/-- Extract the names of all tables in the schema. -/
def Schema.tableNames (s : Schema) : List String :=
  s.tables.map (·.name)

-- ═══════════════════════════════════════════════════════════
-- Schema Changes
-- ═══════════════════════════════════════════════════════════

/-- An individual schema change (DDL operation). -/
inductive SchemaChange where
  /-- Add a new table -/
  | addTable (table : TableDef)
  /-- Drop a table by name -/
  | dropTable (tableName : String)
  /-- Add a column to an existing table -/
  | addColumn (tableName : String) (column : ColumnDef)
  /-- Drop a column from an existing table -/
  | dropColumn (tableName : String) (columnName : String)
  /-- Change the type of an existing column -/
  | alterColumnType (tableName : String) (columnName : String) (newType : ColumnType)
  /-- Add an index -/
  | addIndex (index : IndexDef)
  /-- Drop an index by name -/
  | dropIndex (indexName : String)
  /-- Add a constraint to a table -/
  | addConstraint (tableName : String) (constraint : ConstraintKind)
  /-- Drop a constraint from a table by index position -/
  | dropConstraint (tableName : String) (constraintIdx : Nat)
  deriving DecidableEq, Repr, Inhabited

/-- A schema diff is an ordered list of schema changes. -/
abbrev SchemaDiff := List SchemaChange

-- ═══════════════════════════════════════════════════════════
-- Migration
-- ═══════════════════════════════════════════════════════════

/-- A single migration: a versioned, described schema transformation
    with an optional rollback (down) script. -/
structure Migration where
  /-- Version identifier for ordering -/
  version : MigrationVersion
  /-- Human-readable description -/
  description : String
  /-- Forward (up) schema changes -/
  up : SchemaDiff
  /-- Optional rollback (down) schema changes -/
  down : Option SchemaDiff
  deriving DecidableEq, Repr, Inhabited

-- ═══════════════════════════════════════════════════════════
-- Migration Record & History
-- ═══════════════════════════════════════════════════════════

/-- A record of a migration that has been applied. -/
structure MigrationRecord where
  /-- The version that was applied -/
  version : MigrationVersion
  /-- Unix timestamp when the migration was applied -/
  appliedAt : Nat
  deriving DecidableEq, Repr, Inhabited

/-- A migration history is an ordered list of applied migration records. -/
abbrev MigrationHistory := List MigrationRecord

-- ═══════════════════════════════════════════════════════════
-- Migration Set (ordered collection)
-- ═══════════════════════════════════════════════════════════

/-- A set of migrations guaranteed to be in strictly ascending version order. -/
structure MigrationSet where
  /-- The migrations in this set -/
  migrations : List Migration
  /-- Proof that migrations are strictly ordered by version -/
  h_ordered : List.Pairwise (fun a b => a.version < b.version) migrations
  deriving Repr

-- ═══════════════════════════════════════════════════════════
-- Migration Errors
-- ═══════════════════════════════════════════════════════════

/-- Errors that can occur during migration operations. -/
inductive MigrationError where
  /-- Attempted to create a table that already exists -/
  | tableAlreadyExists (tableName : String)
  /-- Referenced table was not found in the schema -/
  | tableNotFound (tableName : String)
  /-- Attempted to add a column that already exists -/
  | columnAlreadyExists (tableName : String) (columnName : String)
  /-- Referenced column was not found -/
  | columnNotFound (tableName : String) (columnName : String)
  /-- Attempted to create an index that already exists -/
  | indexAlreadyExists (indexName : String)
  /-- Attempted to apply a migration that is already recorded -/
  | migrationAlreadyApplied (version : MigrationVersion)
  /-- Rollback requested but no down script is available -/
  | invalidRollback (version : MigrationVersion)
  /-- A validation check failed with the given message -/
  | validationFailed (message : String)
  deriving DecidableEq, Repr

-- ═══════════════════════════════════════════════════════════
-- Migration Conflict
-- ═══════════════════════════════════════════════════════════

/-- A detected conflict between two migrations that modify the same
    database object. -/
structure MigrationConflict where
  /-- First conflicting migration version -/
  migration1 : MigrationVersion
  /-- Second conflicting migration version -/
  migration2 : MigrationVersion
  /-- The database object both migrations touch -/
  overlappingObject : String
  /-- Human-readable description of the conflict -/
  description : String
  deriving DecidableEq, Repr

end SWELib.Db.Migrations
