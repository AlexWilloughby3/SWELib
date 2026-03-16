/-!
# Base64url Bridge Axioms

Behavioral axioms for Base64url encoding/decoding as implemented by FFI.
Base64url is defined in RFC 4648 Section 5 and used in JWT (RFC 7515).

## References
- RFC 4648 Section 5: "Base 64 Encoding with URL and Filename Safe Alphabet"
- RFC 7515 Appendix C: "Notes on Implementing Base64url Encoding without Padding"
-/

import SWELib

namespace SWELib.Basics

-- TRUST: behavioral axiom, verified against FFI implementation

/-- Base64url encoding produces a string containing only characters
    from the Base64url alphabet (A-Z a-z 0-9 - _). -/
axiom base64urlEncode_valid : ∀ data,
    isValidBase64url (base64urlEncode data)

/-- Base64url decoding of an encoded string returns the original data. -/
axiom base64url_decode_encode : ∀ data,
    base64urlDecode (base64urlEncode data) = some data

/-- Base64url encoding of a decoded string returns the original string
    for valid Base64url input. -/
axiom base64url_encode_decode : ∀ s,
    isValidBase64url s → base64urlEncode (Option.get (base64urlDecode s) (by simp)) = s

/-- Base64url encoding is injective: different inputs produce different outputs. -/
axiom base64urlEncode_injective : ∀ a b,
    base64urlEncode a = base64urlEncode b → a = b

/-- Base64url decoding fails only on invalid strings. -/
axiom base64urlDecode_none_iff_invalid : ∀ s,
    base64urlDecode s = none ↔ ¬isValidBase64url s

/-- Base64url encoding preserves length relationship:
    output length = ceil(input_bytes * 4 / 3) without padding. -/
axiom base64urlEncode_length : ∀ data,
    let encoded := base64urlEncode data
    let inputBits := data.size * 8
    let outputChars := encoded.length
    outputChars * 6 ≥ inputBits ∧
    inputBits > (outputChars - 1) * 6

/-- Base64url decoding preserves data size:
    decoded bytes = floor(encoded_chars * 3 / 4). -/
axiom base64urlDecode_length : ∀ s,
    isValidBase64url s → ∀ data, base64urlDecode s = some data →
    let inputChars := s.length
    let outputBytes := data.size
    outputBytes * 8 = inputChars * 6 - (inputChars * 6) % 8

end SWELib.Basics