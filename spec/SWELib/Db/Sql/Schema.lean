import SWELib.Db.Sql.Value

/-!
# SQL Schema and Tuples

Defines attribute names, schemas (lists of attribute names), and
length-indexed tuples for type-safe SQL relation manipulation.
-/

namespace SWELib.Db.Sql

/-- An attribute name is a string identifier for a column. -/
abbrev AttrName := String

/-- A schema is an ordered list of attribute names. -/
abbrev Schema := List AttrName

/-- A table name is a string identifier. -/
abbrev TableName := String

/-- A tuple is a list of SQL values whose length matches the schema length.
    This ensures structural consistency between tuples and their schemas. -/
structure Tuple (Const : Type) (σ : Schema) where
  /-- The raw list of values in the tuple. -/
  vals : List (SqlValue Const)
  /-- Proof that the value list length matches the schema length. -/
  wf : vals.length = σ.length

/-- Access a tuple value by positional index within the schema. -/
def Tuple.get (t : Tuple Const σ) (i : Fin σ.length) : SqlValue Const :=
  t.vals.get (t.wf ▸ i)

/-- Look up the index of an attribute name within a schema. -/
def Schema.indexOf? (σ : Schema) (a : AttrName) : Option (Fin σ.length) :=
  match σ.findIdx? (· == a) with
  | some idx =>
    if h : idx < σ.length then some ⟨idx, h⟩ else none
  | none => none

/-- Look up the value of a named attribute in a tuple. -/
def Tuple.attrLookup (t : Tuple Const σ) (a : AttrName) : Option (SqlValue Const) :=
  (Schema.indexOf? σ a).map t.get

/-- Concatenate two tuples, producing a tuple over the concatenated schema. -/
def Tuple.concat (t1 : Tuple Const σ1) (t2 : Tuple Const σ2) : Tuple Const (σ1 ++ σ2) :=
  ⟨t1.vals ++ t2.vals, by simp [List.length_append, t1.wf, t2.wf]⟩

/-- Create a tuple of all NULLs for a given schema (used in outer joins). -/
def Tuple.nullPad (Const : Type) (σ : Schema) : Tuple Const σ :=
  ⟨List.replicate σ.length none, by simp⟩

end SWELib.Db.Sql
