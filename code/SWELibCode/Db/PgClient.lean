import SWELib
import SWELibBridge

/-!
# PgClient

Executable PostgreSQL client implementation.

Bridges the spec layer (`SWELib.Db.Sql.SelectQuery`) to the `pq_exec` bridge
axiom by serializing queries to SQL text and executing them via libpq.

## Design

The execution path is:
  `SelectQuery Const` → `toSql` (serialization) → `pq_exec` (bridge) → `QueryResult`

Query serialization produces standard SQL text from the typed AST defined in
`SWELib.Db.Sql.Syntax`. This is the verified path connecting the formal spec
to the concrete FFI.
-/

namespace SWELibCode.Db

open SWELibBridge.Libpq
open SWELib.Db.Sql

/-!
The serializers are mutually recursive because `SqlExpr` contains
`scalarSubquery : SelectQuery Const` and `caseExpr` whose WHEN clauses
contain `SqlCondition`, while `SqlCondition` contains subqueries and
`SqlExpr`. We use `partial` because the mutual inductive is potentially
unbounded in depth.
-/

mutual

/-- Serialize a SQL expression to a string fragment. -/
partial def exprToSql {Const : Type} [ToString Const] : SqlExpr Const → String
  | .lit v       => toString v
  | .null        => "NULL"
  | .col name    => name
  | .qualCol t c => t ++ "." ++ c
  | .countStar   => "COUNT(*)"
  | .binOp op l r =>
    let opStr := match op with
      | .add => "+" | .sub => "-" | .mul => "*" | .div => "/" | .modOp => "%" | .concat => "||"
    "(" ++ exprToSql l ++ " " ++ opStr ++ " " ++ exprToSql r ++ ")"
  | .unOp op e =>
    let opStr := match op with | .neg => "-" | .abs => "ABS"
    opStr ++ "(" ++ exprToSql e ++ ")"
  | .agg f q e =>
    let fStr := match f with
      | .count => "COUNT" | .sum => "SUM" | .avg => "AVG" | .min => "MIN" | .max => "MAX"
    let qStr := match q with | .all => "" | .distinct => "DISTINCT "
    fStr ++ "(" ++ qStr ++ exprToSql e ++ ")"
  | .coalesce args => "COALESCE(" ++ String.intercalate ", " (args.map exprToSql) ++ ")"
  | .cast e ty   => "CAST(" ++ exprToSql e ++ " AS " ++ ty ++ ")"
  | .caseExpr whens elseExpr =>
    let whenClauses := whens.map fun (cond, result) =>
      "WHEN " ++ condToSql cond ++ " THEN " ++ exprToSql result
    let elseClause := match elseExpr with
      | none => "" | some e => " ELSE " ++ exprToSql e
    "CASE " ++ String.intercalate " " whenClauses ++ elseClause ++ " END"
  | .scalarSubquery q => "(" ++ toSql q ++ ")"

/-- Serialize a SQL condition to a string fragment. -/
partial def condToSql {Const : Type} [ToString Const] : SqlCondition Const → String
  | .cmp op l r =>
    let opStr := match op with
      | .eq => "=" | .ne => "<>" | .lt => "<" | .le => "<=" | .gt => ">" | .ge => ">="
    exprToSql l ++ " " ++ opStr ++ " " ++ exprToSql r
  | .andCond l r => "(" ++ condToSql l ++ " AND " ++ condToSql r ++ ")"
  | .orCond l r  => "(" ++ condToSql l ++ " OR "  ++ condToSql r ++ ")"
  | .notCond c   => "NOT (" ++ condToSql c ++ ")"
  | .isNull e    => exprToSql e ++ " IS NULL"
  | .isNotNull e => exprToSql e ++ " IS NOT NULL"
  | .between e lo hi => exprToSql e ++ " BETWEEN " ++ exprToSql lo ++ " AND " ++ exprToSql hi
  | .like e p    => exprToSql e ++ " LIKE " ++ exprToSql p
  | .exists_ q   => "EXISTS (" ++ toSql q ++ ")"
  | .inSubquery e q => exprToSql e ++ " IN (" ++ toSql q ++ ")"
  | .boolLit t   => match t with | .ttrue => "TRUE" | .tfalse => "FALSE" | .tunknown => "NULL"

/-- Serialize a FROM item to a string fragment. -/
partial def fromItemToSql {Const : Type} [ToString Const] : FromItem Const → String
  | .table name none     => name
  | .table name (some a) => name ++ " AS " ++ a
  | .subquery q alias_   => "(" ++ toSql q ++ ") AS " ++ alias_
  | .join kind lhs rhs on_ =>
    let kindStr := match kind with
      | .inner      => "INNER JOIN"
      | .leftOuter  => "LEFT OUTER JOIN"
      | .rightOuter => "RIGHT OUTER JOIN"
      | .fullOuter  => "FULL OUTER JOIN"
      | .cross      => "CROSS JOIN"
    let onStr := match on_ with
      | none => "" | some cond => " ON " ++ condToSql cond
    fromItemToSql lhs ++ " " ++ kindStr ++ " " ++ fromItemToSql rhs ++ onStr

/-- Serialize a `SelectQuery` to a SQL string.
    This is the verified bridge from the typed spec AST to the text protocol. -/
partial def toSql {Const : Type} [ToString Const] : SelectQuery Const → String
  | .select quant items from_ where_ groupBy having orderBy limit offset =>
    let quantStr := match quant with | .all => "" | .distinct => "DISTINCT "
    let itemsStr := if items.isEmpty then "*" else
      String.intercalate ", " (items.map fun item => match item with
        | .star        => "*"
        | .qualStar t  => t ++ ".*"
        | .expr e none => exprToSql e
        | .expr e (some a) => exprToSql e ++ " AS " ++ a)
    let fromStr := if from_.isEmpty then "" else
      " FROM " ++ String.intercalate ", " (from_.map fromItemToSql)
    let whereStr := match where_ with
      | none => "" | some cond => " WHERE " ++ condToSql cond
    let groupByStr := if groupBy.isEmpty then "" else
      " GROUP BY " ++ String.intercalate ", " (groupBy.map exprToSql)
    let havingStr := match having with
      | none => "" | some cond => " HAVING " ++ condToSql cond
    let orderByStr := if orderBy.isEmpty then "" else
      " ORDER BY " ++ String.intercalate ", " (orderBy.map fun item => match item with
        | .item e dir nulls =>
          let dirStr := match dir with | .asc => " ASC" | .desc => " DESC"
          let nullsStr := match nulls with
            | none => "" | some .nullsFirst => " NULLS FIRST" | some .nullsLast => " NULLS LAST"
          exprToSql e ++ dirStr ++ nullsStr)
    let limitStr  := match limit  with | none => "" | some n => " LIMIT "  ++ toString n
    let offsetStr := match offset with | none => "" | some n => " OFFSET " ++ toString n
    "SELECT " ++ quantStr ++ itemsStr ++ fromStr ++ whereStr ++
      groupByStr ++ havingStr ++ orderByStr ++ limitStr ++ offsetStr
  | .setOp op quant l r =>
    let opStr := match op with
      | .unionOp => "UNION" | .intersectOp => "INTERSECT" | .exceptOp => "EXCEPT"
    let quantStr := match quant with | .all => " ALL" | .distinct => ""
    "(" ++ toSql l ++ ") " ++ opStr ++ quantStr ++ " (" ++ toSql r ++ ")"

end

/-- Execute a typed SQL query against an open PostgreSQL connection.
    Serializes the `SelectQuery` AST to SQL text, then calls `pq_exec`. -/
def execQuery {Const : Type} [ToString Const]
    (conn : ConnectionHandle) (q : SelectQuery Const) : IO (Option QueryResult) :=
  pq_exec conn (toSql q)

end SWELibCode.Db
