# Database

Database theory, SQL formal semantics, and connection management.

## Modules

### SQL Formal Semantics (26 files)

Comprehensive SQL formalization based on Benzaken & Contejean's Coq mechanization (CPP '19). Uses bag semantics and Kleene three-valued logic.

| File | Key Content |
|------|-------------|
| `Sql/Value.lean` | `SqlValue` = `Option Const` (None = NULL), `Tribool` per SQL:2023 Section 8.12 |
| `Sql/Schema.lean` | `AttrName`, `Schema` (List AttrName), `Tuple` |
| `Sql/Relation.lean` | Bag-semantic relations |
| `Sql/Syntax.lean` | SQL abstract syntax |
| `Sql/WellFormedness.lean` | Typing judgments |
| `Sql/Eval.lean` | Query evaluation semantics |
| `Sql/Algebra.lean` | Relational algebra operators |
| `Sql/Translation.lean` | SQL to relational algebra translation |
| `Sql/Optimization.lean` | Query optimization rules |
| `Sql/Aggregates.lean` | Aggregate functions (COUNT, SUM, AVG, MIN, MAX) |
| `Sql/GroupBy.lean` | GROUP BY and HAVING |
| `Sql/Joins.lean` | Join operations (inner, left, right, full, cross) |
| `Sql/OrderBy.lean` | ORDER BY and sorting |
| `Sql/Equivalence.lean` | Query equivalence proofs |
| `Sql/Refactor.lean` | Query refactoring transformations |

### Connection Pool (4 files)

| File | Key Content |
|------|-------------|
| `ConnectionPool/Types.lean` | `ConnectionParameters`, `PoolConfig`, `ConnectionStatus` |
| `ConnectionPool/State.lean` | `PoolState` with invariants |
| `ConnectionPool/Operations.lean` | createPool, getConnection, releaseConnection |
| `ConnectionPool/Properties.lean` | Theorems about pool behavior |

### Stubs

| File | Status |
|------|--------|
| `Relational.lean` | TODO |
| `Document.lean` | TODO |
| `KeyValue.lean` | TODO |
| `Transactions.lean` | TODO (references 2PC) |
| `Migrations.lean` | TODO |
| `Indexes.lean` | TODO |
