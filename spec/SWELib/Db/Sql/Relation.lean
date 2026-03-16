import SWELib.Db.Sql.Schema

/-!
# SQL Relations (Bag Semantics)

A relation is a bag (multiset) of tuples, represented as a `List`.
Bag equality is defined up to permutation. This module provides the
fundamental relational operations: union, filter, projection, cross
product, and set operations under bag semantics (SQL:2023 Section 7.12).
-/

namespace SWELib.Db.Sql

/-- A relation is a bag of tuples over a given schema, represented as a list.
    Semantic equality is up to permutation of elements. -/
abbrev Relation (Const : Type) (σ : Schema) := List (Tuple Const σ)

namespace Relation

/-- The empty relation containing no tuples. -/
def empty : Relation Const σ := []

/-- Bag union: concatenate two relations (SQL UNION ALL). -/
def union (r1 r2 : Relation Const σ) : Relation Const σ := r1 ++ r2

/-- Filter tuples satisfying a boolean predicate (SQL WHERE). -/
def filterRel (p : Tuple Const σ -> Bool) (r : Relation Const σ) : Relation Const σ :=
  List.filter p r

/-- Map a function over all tuples (used for projection). -/
def mapRel (f : Tuple Const σ -> Tuple Const τ) (r : Relation Const σ) : Relation Const τ :=
  List.map f r

/-- Flat-map: apply a function returning a relation to each tuple and concatenate results. -/
def flatMap (f : Tuple Const σ -> Relation Const τ) (r : Relation Const σ) : Relation Const τ :=
  List.flatMap f r

/-- Cardinality (number of tuples including duplicates). -/
def card (r : Relation Const σ) : Nat := r.length

/-- Cross product of two relations (SQL:2023 Section 7.7). -/
def prod (r1 : Relation Const σ1) (r2 : Relation Const σ2) : Relation Const (σ1 ++ σ2) :=
  List.flatMap (fun t1 => List.map (fun t2 => t1.concat t2) r2) r1

/-- Remove duplicate tuples (SQL DISTINCT / UNION). Requires `BEq` on tuples. -/
def dedup [BEq (Tuple Const σ)] (r : Relation Const σ) : Relation Const σ :=
  r.eraseDups

/-- Bag difference: for each tuple in `r2`, remove one occurrence from `r1` (SQL EXCEPT ALL). -/
def diff [BEq (Tuple Const σ)] (r1 : Relation Const σ) (r2 : Relation Const σ) : Relation Const σ :=
  r2.foldl (fun acc t => acc.erase t) r1

/-- Bag intersection (simplified): keep tuples from `r1` that appear in `r2` (SQL INTERSECT ALL).
    Note: this simplified version does not perfectly handle multiplicities. -/
def inter [BEq (Tuple Const σ)] (r1 : Relation Const σ) (r2 : Relation Const σ) : Relation Const σ :=
  List.filter (fun t => r2.any (· == t)) r1

end Relation

/-- Union with the empty relation on the left is identity. -/
theorem Relation.union_empty_left (r : Relation Const σ) :
    Relation.union Relation.empty r = r := by
  simp [Relation.union, Relation.empty]

/-- Cardinality of a union is the sum of cardinalities (bag semantics). -/
theorem Relation.card_union (r1 r2 : Relation Const σ) :
    (Relation.union r1 r2).card = r1.card + r2.card := by
  simp [Relation.union, Relation.card, List.length_append]

end SWELib.Db.Sql
