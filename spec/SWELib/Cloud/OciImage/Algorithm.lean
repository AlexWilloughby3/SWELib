/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Hash Algorithms

Hash algorithms for content-addressable digests per OCI Image Specification.

## Algorithms

- **sha256** (required): SHA-256, 256-bit output
- **sha512** (optional): SHA-512, 512-bit output
- **blake3** (optional): BLAKE3, variable output

## References

- [OCI Image Digest](https://github.com/opencontainers/image-spec/blob/main/descriptor.md#digests)
-/

/-- Hash algorithm for digest computation. -/
inductive Algorithm where
  | sha256 : Algorithm
  | sha512 : Algorithm
  | blake3 : Algorithm
  deriving DecidableEq, Repr, Inhabited

instance : ToString Algorithm where
  toString alg := match alg with
    | .sha256 => "sha256"
    | .sha512 => "sha512"
    | .blake3 => "blake3"

/-- Parse algorithm name from string. -/
def Algorithm.parse (s : String) : Option Algorithm :=
  match s with
  | "sha256" => some .sha256
  | "sha512" => some .sha512
  | "blake3" => some .blake3
  | _ => none

/-- STRUCTURAL: toString and parse form a roundtrip for valid algorithms. -/
theorem Algorithm.parse_toString (alg : Algorithm) :
    Algorithm.parse (toString alg) = some alg := by
  cases alg <;> rfl

end SWELib.Cloud.OciImage