import SWELib.Db.ConnectionPool.Types
import SWELib.Db.ConnectionPool.State
import SWELib.Db.ConnectionPool.Operations
import SWELib.Db.ConnectionPool.Properties

/-!
# Connection Pool Specification

Formal specification for database connection pooling.

## Modules

- **`Types`** – Core type definitions (ConnectionParameters, PoolConfig, ConnectionStatus, Connection)
- **`State`** – PoolState with invariants
- **`Operations`** – Operation specifications (createPool, getConnection, releaseConnection, etc.)
- **`Properties`** – Theorems about pool behavior
-/

namespace SWELib.Db

end SWELib.Db
