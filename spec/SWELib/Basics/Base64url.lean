namespace SWELib.Basics

/-- Base64url alphabet: `A-Z a-z 0-9 - _` (RFC 4648 Section 5). -/
def base64urlAlphabet : String :=
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

/-- Look up a 6-bit index (0..63) in the Base64url alphabet. -/
private def encodeChar (idx : UInt8) : Char :=
  let alphabet := base64urlAlphabet.toList.toArray
  if h : idx.toNat < alphabet.size then alphabet[idx.toNat]
  else 'A'  -- unreachable for valid 6-bit values

/-- Decode a single Base64url character to its 6-bit value, or `none` if invalid. -/
private def decodeChar (c : Char) : Option UInt8 :=
  if 'A' ≤ c ∧ c ≤ 'Z' then some (c.toNat - 'A'.toNat).toUInt8
  else if 'a' ≤ c ∧ c ≤ 'z' then some (c.toNat - 'a'.toNat + 26).toUInt8
  else if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat + 52).toUInt8
  else if c == '-' then some 62
  else if c == '_' then some 63
  else none

/-- Encode a 3-byte group to 4 Base64url characters. -/
private def encodeGroup3 (b1 b2 b3 : UInt8) : List Char :=
  let idx1 := b1 >>> 2
  let idx2 := ((b1 &&& 3) <<< 4) ||| (b2 >>> 4)
  let idx3 := ((b2 &&& 0x0f) <<< 2) ||| (b3 >>> 6)
  let idx4 := b3 &&& 0x3f
  [encodeChar idx1, encodeChar idx2, encodeChar idx3, encodeChar idx4]

/-- Encode a 2-byte remainder to 3 Base64url characters (no padding). -/
private def encodeGroup2 (b1 b2 : UInt8) : List Char :=
  let idx1 := b1 >>> 2
  let idx2 := ((b1 &&& 3) <<< 4) ||| (b2 >>> 4)
  let idx3 := (b2 &&& 0x0f) <<< 2
  [encodeChar idx1, encodeChar idx2, encodeChar idx3]

/-- Encode a 1-byte remainder to 2 Base64url characters (no padding). -/
private def encodeGroup1 (b1 : UInt8) : List Char :=
  let idx1 := b1 >>> 2
  let idx2 := (b1 &&& 3) <<< 4
  [encodeChar idx1, encodeChar idx2]

/-- Process the byte array in 3-byte groups, encoding to Base64url characters. -/
private def encodeLoop (data : ByteArray) (i : Nat) (acc : List Char) : List Char :=
  if i + 2 < data.size then
    let chars := encodeGroup3 data[i]! data[i+1]! data[i+2]!
    encodeLoop data (i + 3) (acc ++ chars)
  else if i + 1 < data.size then
    acc ++ encodeGroup2 data[i]! data[i+1]!
  else if i < data.size then
    acc ++ encodeGroup1 data[i]!
  else
    acc
termination_by data.size - i

/-- Encode a byte array to a Base64url string without padding.
    Implementation: map each 3-byte group to 4 characters, using the URL-safe alphabet,
    and omit trailing `=` characters. -/
def base64urlEncode (data : ByteArray) : String :=
  String.ofList (encodeLoop data 0 [])

/-- Decode all characters to 6-bit values, or return `none` on any invalid character. -/
private def decodeAllChars (chars : List Char) : Option (List UInt8) :=
  chars.mapM decodeChar

/-- Decode a 4-character group to 3 bytes. -/
private def decodeGroup4 (v1 v2 v3 v4 : UInt8) : List UInt8 :=
  [ (v1 <<< 2) ||| (v2 >>> 4),
    ((v2 &&& 0x0f) <<< 4) ||| (v3 >>> 2),
    ((v3 &&& 3) <<< 6) ||| v4 ]

/-- Decode a 3-character group to 2 bytes. -/
private def decodeGroup3 (v1 v2 v3 : UInt8) : List UInt8 :=
  [ (v1 <<< 2) ||| (v2 >>> 4),
    ((v2 &&& 0x0f) <<< 4) ||| (v3 >>> 2) ]

/-- Decode a 2-character group to 1 byte. -/
private def decodeGroup2 (v1 v2 : UInt8) : List UInt8 :=
  [ (v1 <<< 2) ||| (v2 >>> 4) ]

/-- Process decoded 6-bit values in groups of 4. -/
private def decodeLoop (vals : List UInt8) (acc : List UInt8) : Option (List UInt8) :=
  match vals with
  | [] => some acc
  | [v1, v2] => some (acc ++ decodeGroup2 v1 v2)
  | [v1, v2, v3] => some (acc ++ decodeGroup3 v1 v2 v3)
  | v1 :: v2 :: v3 :: v4 :: rest =>
    decodeLoop rest (acc ++ decodeGroup4 v1 v2 v3 v4)
  | [_] => none  -- single char is invalid

/-- Decode a Base64url string to a byte array.
    Implementation: decode each character to its 6-bit value, then reassemble bytes.
    Returns `none` for invalid characters or invalid length (1 mod 4). -/
def base64urlDecode (s : String) : Option ByteArray :=
  match decodeAllChars s.toList with
  | none => none
  | some vals =>
    match decodeLoop vals [] with
    | none => none
    | some bytes => some ⟨bytes.toArray⟩

/-- Theorem: Encoding then decoding returns the original data (when decoding succeeds). -/
theorem base64url_roundtrip (data : ByteArray) :
    base64urlDecode (base64urlEncode data) = some data := by
  sorry

/-- Theorem: Decoding then encoding returns the original string for valid Base64url. -/
theorem base64url_decode_encode (s : String) (h : base64urlDecode s ≠ none) :
    match base64urlDecode s with
    | some data => base64urlEncode data = s
    | none => False := by
  sorry

/-- Check if a string is valid Base64url (contains only characters from the alphabet). -/
def isValidBase64url (s : String) : Bool :=
  s.toList.all (λ c => base64urlAlphabet.contains c)

/-- Theorem: `isValidBase64url s` implies `base64urlDecode s ≠ none`. -/
theorem isValidBase64url_implies_decodable (s : String) (h : isValidBase64url s) :
    base64urlDecode s ≠ none := by
  sorry

end SWELib.Basics
