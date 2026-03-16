import SWELib.Db.Sql.Relation

/-!
# SQL Abstract Syntax Tree

Defines the abstract syntax for a core subset of SQL SELECT queries,
covering expressions, conditions, FROM items (including joins and
subqueries), and top-level SELECT statements (SQL:2023 Section 7).

Deferred features: LATERAL, WITH RECURSIVE, ROLLUP/CUBE/GROUPING SETS,
window functions.
-/

namespace SWELib.Db.Sql

/-- Binary arithmetic/string operators on SQL values. -/
inductive BinOp where
  | add | sub | mul | div | modOp | concat
  deriving DecidableEq, Repr

/-- Unary operators on SQL values. -/
inductive UnOp where
  | neg | abs
  deriving DecidableEq, Repr

/-- Comparison operators (SQL:2023 Section 8.2). -/
inductive CmpOp where
  | eq | ne | lt | le | gt | ge
  deriving DecidableEq, Repr

/-- Aggregate functions (SQL:2023 Section 10.9). -/
inductive AggFunc where
  | count | sum | avg | min | max
  deriving DecidableEq, Repr

/-- Set operations (SQL:2023 Section 7.14). -/
inductive SetOp where
  | unionOp | intersectOp | exceptOp
  deriving DecidableEq, Repr

/-- Set quantifier for DISTINCT vs ALL (SQL:2023 Section 7.12). -/
inductive SetQuantifier where
  | all | distinct
  deriving DecidableEq, Repr

/-- Join kinds (SQL:2023 Section 7.7). -/
inductive JoinKind where
  | inner | leftOuter | rightOuter | fullOuter | cross
  deriving DecidableEq, Repr

/-- Sort direction for ORDER BY (SQL:2023 Section 7.17). -/
inductive SortDir where
  | asc | desc
  deriving DecidableEq, Repr

/-- NULL ordering preference for ORDER BY. -/
inductive NullsOrder where
  | nullsFirst | nullsLast
  deriving DecidableEq, Repr

mutual

/-- SQL scalar expression (SQL:2023 Section 6). -/
inductive SqlExpr (Const : Type) : Type where
  /-- A literal constant value. -/
  | lit (v : Const)
  /-- NULL literal. -/
  | null
  /-- Column reference by name. -/
  | col (name : AttrName)
  /-- Qualified column reference (table.column). -/
  | qualCol (table : TableName) (name : AttrName)
  /-- Binary operation. -/
  | binOp (op : BinOp) (lhs rhs : SqlExpr Const)
  /-- Unary operation. -/
  | unOp (op : UnOp) (arg : SqlExpr Const)
  /-- Aggregate function applied to an expression. -/
  | agg (func : AggFunc) (quant : SetQuantifier) (arg : SqlExpr Const)
  /-- COUNT(*) aggregate. -/
  | countStar
  /-- CASE WHEN condition THEN result [ELSE result] END. -/
  | caseExpr (whens : List (SqlCondition Const × SqlExpr Const)) (elseExpr : Option (SqlExpr Const))
  /-- Scalar subquery (must return exactly one row, one column). -/
  | scalarSubquery (q : SelectQuery Const)
  /-- COALESCE(args...) -/
  | coalesce (args : List (SqlExpr Const))
  /-- CAST(expr AS type) -- type represented as string for simplicity. -/
  | cast (arg : SqlExpr Const) (ty : String)

/-- SQL search condition / boolean expression (SQL:2023 Section 8). -/
inductive SqlCondition (Const : Type) : Type where
  /-- Comparison predicate. -/
  | cmp (op : CmpOp) (lhs rhs : SqlExpr Const)
  /-- AND of two conditions. -/
  | andCond (lhs rhs : SqlCondition Const)
  /-- OR of two conditions. -/
  | orCond (lhs rhs : SqlCondition Const)
  /-- NOT of a condition. -/
  | notCond (cond : SqlCondition Const)
  /-- IS NULL predicate (SQL:2023 Section 8.7). -/
  | isNull (expr : SqlExpr Const)
  /-- IS NOT NULL predicate. -/
  | isNotNull (expr : SqlExpr Const)
  /-- IN subquery predicate (SQL:2023 Section 8.4). -/
  | inSubquery (expr : SqlExpr Const) (q : SelectQuery Const)
  /-- EXISTS subquery predicate (SQL:2023 Section 8.1). -/
  | exists_ (q : SelectQuery Const)
  /-- BETWEEN predicate. -/
  | between (expr low high : SqlExpr Const)
  /-- LIKE predicate. -/
  | like (expr pattern : SqlExpr Const)
  /-- Boolean literal in condition position. -/
  | boolLit (val : Tribool)

/-- An item in the SELECT list. -/
inductive SelectItem (Const : Type) : Type where
  /-- A single expression, optionally aliased. -/
  | expr (e : SqlExpr Const) (alias_ : Option AttrName)
  /-- Wildcard: SELECT *. -/
  | star
  /-- Qualified wildcard: SELECT t.*. -/
  | qualStar (table : TableName)

/-- A FROM clause item (SQL:2023 Section 7.6). -/
inductive FromItem (Const : Type) : Type where
  /-- A named base table. -/
  | table (name : TableName) (alias_ : Option TableName)
  /-- A subquery in the FROM clause. -/
  | subquery (q : SelectQuery Const) (alias_ : TableName)
  /-- A join between two FROM items. -/
  | join (kind : JoinKind) (lhs rhs : FromItem Const) (on_ : Option (SqlCondition Const))

/-- An ORDER BY element. -/
inductive OrderByItem (Const : Type) : Type where
  /-- An expression with sort direction and optional null ordering. -/
  | item (expr : SqlExpr Const) (dir : SortDir) (nulls : Option NullsOrder)

/-- A top-level SELECT query (SQL:2023 Section 7.12). -/
inductive SelectQuery (Const : Type) : Type where
  /-- A simple SELECT statement. -/
  | select
    (quant : SetQuantifier)
    (items : List (SelectItem Const))
    (from_ : List (FromItem Const))
    (where_ : Option (SqlCondition Const))
    (groupBy : List (SqlExpr Const))
    (having : Option (SqlCondition Const))
    (orderBy : List (OrderByItem Const))
    (limit : Option Nat)
    (offset : Option Nat)
  /-- Set operation combining two queries. -/
  | setOp (op : SetOp) (quant : SetQuantifier) (lhs rhs : SelectQuery Const)

end

end SWELib.Db.Sql
