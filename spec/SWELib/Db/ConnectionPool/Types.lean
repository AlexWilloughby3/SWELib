/-!
# Connection Pool Types

Core type definitions for database connection pooling, following libpq conventions.

## Specification References
- D-011: ConnectionParameters as Record with Optional Fields
- D-012: PoolConfig as Record with Range Proofs
- D-013: ConnectionStatus as Inductive Enum (12 states)
- D-015: Connection as Opaque Handle
-/

namespace SWELib.Db.ConnectionPool

/-- Connection parameters matching libpq's connection string format.

    All fields are optional to match PostgreSQL's connection string syntax.
    See D-011. -/
structure ConnectionParameters where
  /-- Database server host name or IP address -/
  host : Option String := none
  /-- Database server port number -/
  port : Option Nat := none
  /-- Database name -/
  dbname : Option String := none
  /-- Database user name -/
  user : Option String := none
  /-- Password for authentication -/
  password : Option String := none
  /-- Connection timeout in milliseconds -/
  connect_timeout : Option Nat := none
  /-- SSL mode (disable, allow, prefer, require, verify-ca, verify-full) -/
  sslmode : Option String := none
  /-- SSL root certificate file path -/
  sslrootcert : Option String := none
  /-- SSL certificate file path -/
  sslcert : Option String := none
  /-- SSL key file path -/
  sslkey : Option String := none
  /-- Target session attributes (read-write, read-only, primary, standby, prefer-standby) -/
  target_session_attrs : Option String := none

/-- Connection pool configuration with size and timeout constraints.

    See D-012 for range proofs. -/
structure PoolConfig where
  /-- Maximum number of connections in the pool -/
  maximumPoolSize : Nat
  /-- Minimum number of idle connections to maintain -/
  minimumIdle : Nat
  /-- Connection timeout in milliseconds -/
  connectionTimeout : Nat
  /-- Idle timeout in milliseconds -/
  idleTimeout : Nat
  /-- Maximum lifetime of a connection in milliseconds -/
  maxLifetime : Nat
  /-- Validation timeout in milliseconds -/
  validationTimeout : Nat
  /-- Proof that minimumIdle ≤ maximumPoolSize -/
  min_le_max : (minimumIdle : Nat) ≤ (maximumPoolSize : Nat)
  /-- Proof that validationTimeout < connectionTimeout -/
  validation_lt_connection : (validationTimeout : Nat) < (connectionTimeout : Nat)

/-- Connection status enumeration matching libpq's ConnStatusType.

    See D-013 for the 12-state enumeration. -/
inductive ConnectionStatus
  | CONNECTION_OK
  | CONNECTION_BAD
  | CONNECTION_STARTED
  | CONNECTION_MADE
  | CONNECTION_AWAITING_RESPONSE
  | CONNECTION_AUTH_OK
  | CONNECTION_SSL_STARTUP
  | CONNECTION_GSS_STARTUP
  | CONNECTION_CHECK_WRITABLE
  | CONNECTION_CHECK_STANDBY
  | CONNECTION_CONSUME
  | CONNECTION_SETENV
  deriving DecidableEq, Repr

/-- Opaque connection handle with unique ID.

    Validity is tracked by the pool state (membership in active or idle lists),
    not carried on the handle itself. See D-015 for the opaque handle design. -/
structure Connection where
  /-- Unique identifier for the connection -/
  id : UInt64
  deriving DecidableEq

/-- Connection error types for detailed error reporting. -/
inductive ConnectionError
  | PoolExhausted
  | ConnectionTimeout
  | ValidationFailed
  | ConnectionClosed
  | InvalidParameters
  | NetworkError
  | AuthenticationFailed
  | SslError
  deriving DecidableEq, Repr

end SWELib.Db.ConnectionPool