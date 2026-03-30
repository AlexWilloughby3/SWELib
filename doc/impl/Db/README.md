# Database Implementations

PostgreSQL client, query builder, and connection pool implementation.

## Modules

### Client and Query Builder

| File | Description |
|------|-------------|
| `PgClient.lean` | PostgreSQL client: serializes `SelectQuery Const` to SQL text and executes via libpq |
| `QueryBuilder.lean` | Fluent API for constructing `SelectQuery` with chainable `.select`, `.from_`, `.where_`, `.limit`, `.build` |

### Connection Pool (`ConnectionPool/`)

| File | Description |
|------|-------------|
| `Types.lean` | `ConnectionHandle` with ID, libpq pointer, timestamps, validity state |
| `FFI.lean` | `connect` function wrapping `pq_connect` with handle creation and timestamp initialization |
| `Mutex.lean` | Thread synchronization: opaque `MutexImpl`, `SyncMap` wrapper over `IO.Ref` |
| `Manager.lean` | Pool state management with `Pool` structure (params, config, mutex, active/idle connections) |
| `Connection.lean` | Connection wrapper with reference counting and finalizer |
