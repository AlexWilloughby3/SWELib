/-!
# Protocol Buffers

Proto3 wire format model per the Protocol Buffers Encoding specification.
Formalizes the wire-level representation: wire types, field tags,
field values, and messages as ordered field lists.

This models the *wire format*, not the `.proto` schema language.
-/

namespace SWELib.Basics

/-- Wire types in the protobuf encoding (3-bit field, values 0–5). -/
inductive WireType where
  | varint : WireType  -- 0: int32, int64, uint32, uint64, sint32, sint64, bool, enum
  | i64    : WireType  -- 1: fixed64, sfixed64, double
  | len    : WireType  -- 2: string, bytes, embedded messages, packed repeated fields
  | sgroup : WireType  -- 3: group start (deprecated)
  | egroup : WireType  -- 4: group end (deprecated)
  | i32    : WireType  -- 5: fixed32, sfixed32, float
  deriving DecidableEq, Repr

/-- Decode a wire type from its 3-bit numeric value. -/
def WireType.fromNat : Nat → Option WireType
  | 0 => some .varint
  | 1 => some .i64
  | 2 => some .len
  | 3 => some .sgroup
  | 4 => some .egroup
  | 5 => some .i32
  | _ => none

/-- Encode a wire type to its 3-bit numeric value. -/
def WireType.toNat : WireType → Nat
  | .varint => 0
  | .i64    => 1
  | .len    => 2
  | .sgroup => 3
  | .egroup => 4
  | .i32    => 5

/-- A field tag: field number (1–536870911) paired with a wire type. -/
structure FieldTag where
  /-- Field number. Valid range: [1, 2^29 - 1] excluding [19000, 19999]. -/
  fieldNumber : Nat
  /-- Wire type of the field value. -/
  wireType : WireType
  deriving DecidableEq, Repr

/-- A field tag is valid if its number is in range and not in the reserved band. -/
def FieldTag.isValid (t : FieldTag) : Bool :=
  1 ≤ t.fieldNumber && t.fieldNumber ≤ 536870911 &&
  !(19000 ≤ t.fieldNumber && t.fieldNumber ≤ 19999)

/-- A protobuf field value, determined by wire type. -/
inductive ProtobufValue where
  /-- Variable-length integer (wire type 0). -/
  | varint (n : Nat)
  /-- 64-bit fixed value (wire type 1). -/
  | fixed64 (n : UInt64)
  /-- 32-bit fixed value (wire type 5). -/
  | fixed32 (n : UInt32)
  /-- Length-delimited bytes (wire type 2). -/
  | lengthDelimited (data : ByteArray)

/-- A single protobuf field: tag plus value. -/
structure ProtobufField where
  /-- Field tag (number + wire type). -/
  tag : FieldTag
  /-- Encoded value. -/
  value : ProtobufValue

/-- A protobuf message: ordered list of fields.
    Proto3 allows repeated field numbers (last-write-wins for scalars,
    concatenation for repeated fields). -/
abbrev ProtobufMessage := List ProtobufField

/-- Filter fields by field number (supports repeated fields). -/
def ProtobufMessage.fieldsWithNumber (msg : ProtobufMessage) (n : Nat) : List ProtobufField :=
  msg.filter (·.tag.fieldNumber == n)

/-- Wire type value fits in 3 bits (0–5). -/
theorem WireType.toNat_range (w : WireType) : w.toNat ≤ 5 := by
  cases w <;> simp [toNat]

/-- Valid field numbers are at least 1. -/
theorem FieldTag.valid_field_number_positive (t : FieldTag) (h : t.isValid = true) :
    1 ≤ t.fieldNumber := by
  simp [isValid] at h
  omega

/-- WireType.ofNat roundtrips with WireType.toNat. -/
theorem WireType.fromNat_toNat (w : WireType) : WireType.fromNat w.toNat = some w := by
  cases w <;> rfl

end SWELib.Basics
