import SWELib
import SWELibImpl.Bridge
import SWELibImpl.Db.ConnectionPool.Types
import SWELibImpl.Db.ConnectionPool.FFI
import SWELibImpl.Db.ConnectionPool.Mutex
import SWELibImpl.Db.ConnectionPool.Manager
import SWELibImpl.Db.ConnectionPool.Connection

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

namespace SWELibImpl.Db

/-- Alias so callers can write `SWELibImpl.Db.Pool` instead of the full path. -/
abbrev Pool := ConnectionPool.Pool

/-- Alias for the top-level pool operations. -/
abbrev createPool      := ConnectionPool.createPool
abbrev getConnection   := ConnectionPool.getConnection
abbrev releaseConnection := ConnectionPool.releaseConnection
abbrev closePool       := ConnectionPool.closePool

end SWELibImpl.Db