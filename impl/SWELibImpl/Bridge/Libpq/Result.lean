import SWELib
import SWELibImpl.Bridge.Libpq.Exec

/-!
# Result

Bridge axioms for accessing data from libpq query results.

## Specification References
- `PQresultStatus`, `PQntuples`, `PQnfields`, `PQgetvalue`, etc.
-/

namespace SWELibImpl.Bridge.Libpq

/-- Status of a query result. -/
inductive ResultStatus
  | PGRES_EMPTY_QUERY
  | PGRES_COMMAND_OK
  | PGRES_TUPLES_OK
  | PGRES_COPY_OUT
  | PGRES_COPY_IN
  | PGRES_BAD_RESPONSE
  | PGRES_NONFATAL_ERROR
  | PGRES_FATAL_ERROR
  deriving DecidableEq, Repr

/-- Get the status of a query result.

    TRUST: This axiom corresponds to `PQresultStatus` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_result_status : QueryResult → IO ResultStatus

/-- Get the number of rows returned by a query.

    TRUST: This axiom corresponds to `PQntuples` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_ntuples : QueryResult → IO Nat

/-- Get the number of columns in a query result.

    TRUST: This axiom corresponds to `PQnfields` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_nfields : QueryResult → IO Nat

/-- Get the value of a field as a string.

    Row and column indices are zero-based.
    Returns `none` if the value is SQL NULL.

    TRUST: This axiom corresponds to `PQgetvalue` / `PQgetisnull` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_getvalue : QueryResult → Nat → Nat → IO (Option String)

/-- Get the column name at the given index.

    TRUST: This axiom corresponds to `PQfname` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_fname : QueryResult → Nat → IO String

/-- Get the number of rows affected by a command (INSERT/UPDATE/DELETE).

    TRUST: This axiom corresponds to `PQcmdTuples` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_cmd_tuples : QueryResult → IO Nat

/-- Get the error message associated with a failed query result.

    TRUST: This axiom corresponds to `PQresultErrorMessage` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_result_error_message : QueryResult → IO String

/-- Free the memory associated with a query result.

    TRUST: This axiom corresponds to `PQclear` in libpq.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom pq_clear : QueryResult → IO Unit

end SWELibImpl.Bridge.Libpq
