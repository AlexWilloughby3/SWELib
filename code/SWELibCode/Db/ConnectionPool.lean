import SWELib
import SWELibBridge
import SWELibCode.Db.ConnectionPool.Types
import SWELibCode.Db.ConnectionPool.FFI
import SWELibCode.Db.ConnectionPool.Mutex
import SWELibCode.Db.ConnectionPool.Manager
import SWELibCode.Db.ConnectionPool.Connection

/-!
# ConnectionPool

Executable ConnectionPool implementation.

## Modules

- **`Types`** – Executable type definitions
- **`FFI`** – FFI bindings to libpq
- **`Mutex`** – Thread synchronization
- **`Manager`** – Pool management logic
- **`Connection`** – Connection wrapper with finalizer
-/

namespace SWELibCode.Db

/-- Alias so callers can write `SWELibCode.Db.Pool` instead of the full path. -/
abbrev Pool := ConnectionPool.Pool

/-- Alias for the top-level pool operations. -/
abbrev createPool      := ConnectionPool.createPool
abbrev getConnection   := ConnectionPool.getConnection
abbrev releaseConnection := ConnectionPool.releaseConnection
abbrev closePool       := ConnectionPool.closePool

end SWELibCode.Db