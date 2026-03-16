/-!
# UUID

Universally Unique Identifier per RFC 9562 (supersedes RFC 4122).
Defines the 128-bit UUID structure, variant/version extraction,
and sentinel values (Nil, Max).
-/

namespace SWELib.Basics

/-- UUID variant field values (RFC 9562 §4.1). -/
inductive UuidVariant where
  | ncs       : UuidVariant   -- 0b0xx
  | rfc9562   : UuidVariant   -- 0b10x
  | microsoft : UuidVariant   -- 0b110
  | reserved  : UuidVariant   -- 0b111
  deriving DecidableEq, Repr

/-- UUID version values (RFC 9562 §4.2). -/
inductive UuidVersion where
  | v1 : UuidVersion  -- Gregorian time-based
  | v2 : UuidVersion  -- DCE security
  | v3 : UuidVersion  -- MD5 name-based
  | v4 : UuidVersion  -- Random
  | v5 : UuidVersion  -- SHA-1 name-based
  | v6 : UuidVersion  -- Reordered Gregorian time-based
  | v7 : UuidVersion  -- Unix Epoch time-based
  | v8 : UuidVersion  -- Custom
  deriving DecidableEq, Repr

/-- A UUID represented as two 64-bit words (128 bits total).
    `hi` holds bits [127:64], `lo` holds bits [63:0], network byte order. -/
structure Uuid where
  /-- Upper 64 bits (contains version in bits [51:48] of the full UUID). -/
  hi : UInt64
  /-- Lower 64 bits (contains variant in bits [65:64] of the full UUID, i.e. top bits of lo). -/
  lo : UInt64
  deriving DecidableEq, Repr

/-- The Nil UUID — all 128 bits set to zero (RFC 9562 §5.9). -/
def Uuid.nil : Uuid := ⟨0, 0⟩

/-- The Max UUID — all 128 bits set to one (RFC 9562 §5.10). -/
def Uuid.max : Uuid := ⟨UInt64.ofNat 0xFFFFFFFFFFFFFFFF, UInt64.ofNat 0xFFFFFFFFFFFFFFFF⟩

/-- True if all 128 bits are zero. -/
def Uuid.isNil (u : Uuid) : Bool := u.hi == 0 && u.lo == 0

/-- True if all 128 bits are one. -/
def Uuid.isMax (u : Uuid) : Bool :=
  u.hi == UInt64.ofNat 0xFFFFFFFFFFFFFFFF && u.lo == UInt64.ofNat 0xFFFFFFFFFFFFFFFF

/-- Extract version from bits [51:48] (top 4 bits of `hi` low half). -/
def Uuid.versionBits (u : Uuid) : UInt8 :=
  (u.hi >>> 12 &&& 0xF).toUInt8

/-- Decode version from the 4-bit field, if it maps to a known version. -/
def Uuid.version (u : Uuid) : Option UuidVersion :=
  match u.versionBits.toNat with
  | 1 => some .v1
  | 2 => some .v2
  | 3 => some .v3
  | 4 => some .v4
  | 5 => some .v5
  | 6 => some .v6
  | 7 => some .v7
  | 8 => some .v8
  | _ => none

/-- Extract variant from the top bits of `lo`. -/
def Uuid.variant (u : Uuid) : UuidVariant :=
  let topBits := (u.lo >>> 62).toNat
  match topBits with
  | 0 | 1 => .ncs        -- 0b0x
  | 2     => .rfc9562     -- 0b10
  | 3     => .microsoft   -- 0b11 (further disambiguation omitted for spec simplicity)
  | _     => .reserved

/-- Convert to a 16-byte array in network byte order. -/
def Uuid.toByteArray (u : Uuid) : ByteArray :=
  let hi := u.hi.toNat
  let lo := u.lo.toNat
  ⟨#[ (hi >>> 56 % 256).toUInt8, (hi >>> 48 % 256).toUInt8,
       (hi >>> 40 % 256).toUInt8, (hi >>> 32 % 256).toUInt8,
       (hi >>> 24 % 256).toUInt8, (hi >>> 16 % 256).toUInt8,
       (hi >>> 8  % 256).toUInt8, (hi       % 256).toUInt8,
       (lo >>> 56 % 256).toUInt8, (lo >>> 48 % 256).toUInt8,
       (lo >>> 40 % 256).toUInt8, (lo >>> 32 % 256).toUInt8,
       (lo >>> 24 % 256).toUInt8, (lo >>> 16 % 256).toUInt8,
       (lo >>> 8  % 256).toUInt8, (lo       % 256).toUInt8 ]⟩

/-- The Nil UUID has both words equal to zero. -/
theorem Uuid.nil_uuid_all_zero : Uuid.nil.hi = 0 ∧ Uuid.nil.lo = 0 := by
  simp [Uuid.nil]

/-- The Nil UUID satisfies isNil. -/
theorem Uuid.nil_is_nil : Uuid.nil.isNil = true := by
  native_decide

/-- The Max UUID satisfies isMax. -/
theorem Uuid.max_is_max : Uuid.max.isMax = true := by
  native_decide

end SWELib.Basics
