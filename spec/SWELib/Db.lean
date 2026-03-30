import SWELib.Db.Sql
import SWELib.Db.ConnectionPool
import SWELib.Db.Transactions
import SWELib.Db.Indexes
import SWELib.Db.KeyValue
import SWELib.Db.Document
import SWELib.Db.Migrations
import SWELib.Db.Relational

/-!
# Database Specifications

Formal specifications for database concepts in SWELib, including SQL
semantics, connection pooling, transactions, indexes, and more.

## Modules

- **`Sql`** – Complete SQL formal semantics (three‑valued logic, bag semantics,
  relational algebra translation)
- **`ConnectionPool`** – Connection pool management
- **`Transactions`** – ACID transaction semantics
- **`Indexes`** – Database index structures and operations
- **`KeyValue`** – Key‑value store semantics
- **`Document`** – Document‑oriented database operations
- **`Migrations`** – Schema migration specifications
- **`Relational`** – Core relational model concepts
-/

namespace SWELib.Db

end SWELib.Db
