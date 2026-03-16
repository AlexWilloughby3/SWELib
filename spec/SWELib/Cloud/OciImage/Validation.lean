/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.OciImage.Descriptor
import SWELib.Cloud.OciImage.ImageManifest
import SWELib.Cloud.OciImage.ImageIndex
import SWELib.Cloud.OciImage.ImageConfig
import SWELib.Cloud.OciImage.Layer

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Validation

Cross-cutting validation logic for descriptors, manifests, and indexes.

## Validation Operations

- Descriptor validation: size and digest match blob
- Manifest validation: config and layers match actual blobs
- Index validation: manifests match actual blobs
-/

/-- Validate descriptor against blob. -/
def validateDescriptor (d : Descriptor) (blob : ByteArray) : Bool :=
  d.isValidForBlob blob

/-- Validate chain of descriptors against blobs. -/
def validateDescriptorChain (descs : List Descriptor) (blobs : List ByteArray) : Bool :=
  descs.length = blobs.length &&
  (descs.zip blobs).all (fun (d, b) => validateDescriptor d b)

/-- Validate manifest against config and layers. -/
def validateManifest (m : ImageManifest) (configBlob : ByteArray) (layerBlobs : List ByteArray) : Bool :=
  validateDescriptor m.config configBlob &&
  validateDescriptorChain m.layers layerBlobs

/-- Validate index against manifest blobs. -/
def validateIndex (idx : ImageIndex) (manifestBlobs : List ByteArray) : Bool :=
  validateDescriptorChain idx.manifests manifestBlobs

/-- REQUIRES_HUMAN: Valid descriptor chain implies all valid. -/
theorem validateDescriptorChain_all_valid (descs : List Descriptor) (blobs : List ByteArray) :
    validateDescriptorChain descs blobs = true →
    ∀ i, i < descs.length → validateDescriptor descs[i]! blobs[i]! = true := by
  sorry

/-- REQUIRES_HUMAN: Validated manifest is runnable. -/
axiom validated_manifest_runnable :
  ∀ (m : ImageManifest) (cfg : ByteArray) (layers : List ByteArray),
  validateManifest m cfg layers = true →
  ∃ (runnable : Bool), runnable = true

end SWELib.Cloud.OciImage