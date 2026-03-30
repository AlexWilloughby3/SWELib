/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.OciImage.Algorithm

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Digest

Content-addressable digest identifiers.

## Format

Digests have the format: `algorithm:encoded`
- algorithm: sha256, sha512, or blake3
- encoded: hex string (64 chars for sha256, 128 for sha512)

## References

- [OCI Image Digest](https://github.com/opencontainers/image-spec/blob/main/descriptor.md#digests)
-/

/-- Check if encoded string is valid for algorithm. -/
def isValidEncoding (alg : Algorithm) (encoded : String) : Bool :=
  match alg with
  | .sha256 => encoded.length = 64 && encoded.all (fun c => c.isDigit || ('a' ≤ c && c ≤ 'f'))
  | .sha512 => encoded.length = 128 && encoded.all (fun c => c.isDigit || ('a' ≤ c && c ≤ 'f'))
  | .blake3 => encoded.length > 0  -- Implementation-defined

/-- Content-addressable digest. -/
structure Digest where
  /-- Hash algorithm. -/
  algorithm : Algorithm
  /-- Hex-encoded hash value. -/
  encoded : String
  /-- Proof that encoding is valid for algorithm. -/
  h_valid : isValidEncoding algorithm encoded = true
  deriving DecidableEq

instance : ToString Digest where
  toString d := s!"{d.algorithm}:{d.encoded}"

/-- Parse digest from string (format: "algorithm:encoded"). -/
def Digest.parse (s : String) : Option Digest :=
  match s.splitOn ":" with
  | [algStr, enc] =>
    match Algorithm.parse algStr with
    | some alg =>
      if h : isValidEncoding alg enc then
        some ⟨alg, enc, h⟩
      else
        none
    | none => none
  | _ => none

/-- Smart constructor for SHA-256 digest. -/
def Digest.sha256 (hex : String) : Option Digest :=
  if h : isValidEncoding .sha256 hex then
    some ⟨.sha256, hex, h⟩
  else
    none

/-- Smart constructor for SHA-512 digest. -/
def Digest.sha512 (hex : String) : Option Digest :=
  if h : isValidEncoding .sha512 hex then
    some ⟨.sha512, hex, h⟩
  else
    none

/-- AXIOM: Compute digest of blob (requires cryptographic hash implementation). -/
axiom computeDigest : Algorithm → ByteArray → String

/-- AXIOM: Verify blob matches digest. -/
axiom digestMatches : Digest → ByteArray → Bool

/-- STRUCTURAL: SHA-256 digests have exactly 64 hex characters. -/
theorem sha256_length (d : Digest) (h : d.algorithm = .sha256) :
    d.encoded.length = 64 := by
  have hvalid := d.h_valid
  rw [h] at hvalid
  simp [isValidEncoding] at hvalid
  exact hvalid.1

/-- STRUCTURAL: Parse and toString roundtrip for valid digests. -/
axiom parse_toString (d : Digest) :
    Digest.parse (toString d) = some d

/-- REQUIRES_HUMAN: Digest immutability (cryptographic collision resistance). -/
axiom digest_immutability :
  ∀ (alg : Algorithm) (blob1 blob2 : ByteArray),
  computeDigest alg blob1 = computeDigest alg blob2 → blob1 = blob2

end SWELib.Cloud.OciImage
