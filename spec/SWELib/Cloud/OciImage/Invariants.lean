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
import SWELib.Cloud.OciImage.Validation
import SWELib.Cloud.OciImage.Resolution

namespace SWELib.Cloud.OciImage.Invariants

/-!
# OCI Image Invariants

Global consistency properties for OCI Image Format.

## Categories

1. Content addressability (digest immutability)
2. Schema constraints (version 2)
3. Layer ordering (base to top)
4. Platform selection (deterministic)
5. Whiteout semantics (deletion correctness)
-/

open SWELib.Cloud.OciImage

-- INV-1: Digest immutability (content addressability)
-- Already defined in Digest.lean as digest_immutability axiom

-- INV-2: Schema version constraint for manifests
theorem inv_manifest_schema_v2 (m : ImageManifest) :
    m.schemaVersion = 2 := by
  exact m.h_schema

-- INV-3: Schema version constraint for indexes
theorem inv_index_schema_v2 (idx : ImageIndex) :
    idx.schemaVersion = 2 := by
  exact idx.h_schema

-- INV-4: Layer ordering preserved (REQUIRES_HUMAN: semantic property)
axiom inv_layer_order_preserved :
  ∀ (m : ImageManifest) (layers : List Layer),
  layers.length = m.layers.length →
  ∃ (apply : List Layer → ByteArray),
    ∀ perm, perm ≠ layers → apply perm ≠ apply layers

-- INV-5: Descriptor size-digest correspondence
theorem inv_descriptor_size_digest (d : Descriptor) (blob : ByteArray) :
    validateDescriptor d blob = true →
    d.size = blob.size && digestMatches d.digest blob = true := by
  intro h
  simp [validateDescriptor, Descriptor.isValidForBlob] at h
  exact h

-- INV-6: Config diffIds match layer uncompressed digests (REQUIRES_HUMAN)
axiom inv_config_diffids_match_layers :
  ∀ (cfg : ImageConfig) (layers : List Layer),
  cfg.rootfs.diffIds.length = layers.length →
  ∀ i, i < layers.length →
    cfg.rootfs.diffIds[i]! = layers[i]!.uncompressedDigest

-- INV-7: Platform-specific manifests in index
theorem inv_index_manifests_have_platform (idx : ImageIndex) (d : Descriptor) :
    d ∈ idx.manifests → d.platform.isSome := by
  intro h
  exact idx.h_manifests_platform d h

-- INV-8: At least one layer required in manifest
theorem inv_manifest_has_layers (m : ImageManifest) :
    m.layers ≠ [] := by
  exact m.h_layers_nonempty

-- INV-9: Whiteout semantics consistency (REQUIRES_HUMAN)
axiom inv_whiteout_deletion :
  ∀ (layer : Layer) (entry : WhiteoutEntry) (fs : ByteArray),
  entry ∈ layer.whiteouts →
  entry.whiteoutType = .regular →
  ∃ (fileExists : ByteArray → String → Bool),
    fileExists (applyLayer fs layer) entry.path = false

-- INV-10: Content addressability - digest uniquely identifies content
-- This is the digest_immutability axiom from Digest.lean

-- INV-11: Platform selection determinism (ALGEBRAIC)
theorem inv_platform_selection_deterministic (idx : ImageIndex) (p : Platform) :
    ∀ r1 r2, selectBestManifest idx p = r1 →
             selectBestManifest idx p = r2 →
             r1 = r2 := by
  intros r1 r2 h1 h2
  rw [h1, h2]

end SWELib.Cloud.OciImage.Invariants