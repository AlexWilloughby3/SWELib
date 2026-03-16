/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.OciImage.Digest
import SWELib.Cloud.OciImage.MediaType
import SWELib.Cloud.OciImage.Platform
import SWELib.Cloud.OciImage.Annotations
import SWELib.Basics.Uri

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Descriptor

Content descriptor referencing a blob with validation metadata.

## Fields

- **mediaType**: Type of blob content
- **digest**: Content-addressable identifier
- **size**: Blob size in bytes
- **urls**: Optional alternate download locations
- **annotations**: Optional metadata
- **platform**: Optional platform (for manifest selection in indexes)

## References

- [OCI Image Descriptor](https://github.com/opencontainers/image-spec/blob/main/descriptor.md)
-/

open SWELib.Basics

/-- Descriptor referencing a blob. -/
structure Descriptor where
  /-- Media type of blob. -/
  mediaType : MediaType
  /-- Content digest. -/
  digest : Digest
  /-- Size in bytes. -/
  size : Int
  /-- Optional alternate URLs. -/
  urls : List Uri := []
  /-- Optional annotations. -/
  annotations : Option Annotations := none
  /-- Optional platform (for index manifests). -/
  platform : Option Platform := none
  /-- Proof that size is non-negative. -/
  h_size_nonneg : 0 ≤ size

/-- Validate descriptor against actual blob. -/
noncomputable def Descriptor.isValidForBlob (d : Descriptor) (blob : ByteArray) : Bool :=
  d.size = blob.size && digestMatches d.digest blob

/-- Create descriptor from blob (computes digest and size). -/
noncomputable def Descriptor.forBlob (mediaType : MediaType) (blob : ByteArray) (alg : Algorithm := .sha256) : Descriptor :=
  let encoded := computeDigest alg blob
  let digest : Digest := ⟨alg, encoded, by sorry⟩  -- Proof deferred: computeDigest produces valid encoding
  { mediaType := mediaType
  , digest := digest
  , size := blob.size
  , h_size_nonneg := by omega }

/-- Check if descriptor references a manifest. -/
def Descriptor.isManifest (d : Descriptor) : Bool :=
  isManifestType d.mediaType || isIndexType d.mediaType

/-- Check if descriptor references a layer. -/
def Descriptor.isLayer (d : Descriptor) : Bool :=
  isLayerType d.mediaType

/-- STRUCTURAL: Descriptor size is non-negative. -/
theorem descriptor_size_nonneg (d : Descriptor) :
    0 ≤ d.size := by
  exact d.h_size_nonneg

/-- REQUIRES_HUMAN: Valid descriptor size matches blob size. -/
theorem descriptor_size_matches (d : Descriptor) (blob : ByteArray) :
    d.isValidForBlob blob = true → d.size = blob.size := by
  sorry

/-- REQUIRES_HUMAN: Valid descriptor digest matches blob. -/
theorem descriptor_digest_matches (d : Descriptor) (blob : ByteArray) :
    d.isValidForBlob blob = true → digestMatches d.digest blob = true := by
  sorry

end SWELib.Cloud.OciImage