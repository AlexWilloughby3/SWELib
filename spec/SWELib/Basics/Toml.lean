/-!
# TOML

TOML v1.0.0 specification.
Models tables, values (including all scalar types and collections),
and the key-uniqueness constraint.
-/

namespace SWELib.Basics

/-- A TOML dotted key represented as a list of path segments. -/
abbrev TomlKey := List String

/-- A TOML value (TOML v1.0.0 §3). -/
inductive TomlValue where
  /-- String value. -/
  | string (s : String)
  /-- Integer value (arbitrary precision; spec mandates at least 64-bit signed). -/
  | integer (n : Int)
  /-- Float value (IEEE 754 binary64). -/
  | float (f : Float)
  /-- Boolean value. -/
  | boolean (b : Bool)
  /-- Offset date-time (RFC 3339 string representation). -/
  | offsetDateTime (s : String)
  /-- Local date-time (no timezone). -/
  | localDateTime (s : String)
  /-- Local date. -/
  | localDate (s : String)
  /-- Local time. -/
  | localTime (s : String)
  /-- Array of values. -/
  | array (a : List TomlValue)
  /-- Inline table. -/
  | inlineTable (t : List (String × TomlValue))
  deriving Repr

/-- A TOML table: ordered list of key-value pairs (preserves definition order). -/
abbrev TomlTable := List (String × TomlValue)

/-- Look up a value by key. -/
def TomlTable.get? (t : TomlTable) (key : String) : Option TomlValue :=
  (t.find? (·.1 == key)).map (·.2)

/-- Check if a key is present. -/
def TomlTable.hasKey (t : TomlTable) (key : String) : Bool :=
  t.any (·.1 == key)

/-- Validate that no two entries share the same key (TOML v1.0.0 §3.1). -/
def TomlTable.noDuplicateKeys (t : TomlTable) : Bool :=
  let keys := t.map (·.1)
  keys.length == keys.eraseDups.length

/-- Check whether all elements of a TOML array have the same top-level type tag
    (TOML v1.0.0 requires homogeneous arrays). -/
def TomlValue.typeTag : TomlValue → Nat
  | .string _         => 0
  | .integer _        => 1
  | .float _          => 2
  | .boolean _        => 3
  | .offsetDateTime _ => 4
  | .localDateTime _  => 5
  | .localDate _      => 6
  | .localTime _      => 7
  | .array _          => 8
  | .inlineTable _    => 9

/-- True if all elements of the array share the same type tag. -/
def TomlValue.isHomogeneousArray : List TomlValue → Bool
  | []      => true
  | v :: vs => vs.all (·.typeTag == v.typeTag)

/-- An empty table has no duplicate keys. -/
theorem TomlTable.empty_table_no_duplicates :
    TomlTable.noDuplicateKeys [] = true := by
  simp [noDuplicateKeys]

/-- An empty array is homogeneous. -/
theorem TomlValue.empty_array_is_homogeneous :
    TomlValue.isHomogeneousArray [] = true := by
  simp [isHomogeneousArray]

end SWELib.Basics
