/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.OciImage.ImageIndex
import SWELib.Cloud.OciImage.Platform

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Platform Resolution

Platform matching algorithm for multi-architecture image selection.

## Match Scoring

- **exact**: All fields match (os, architecture, variant, etc.)
- **compatible**: Required fields match (os, architecture)
- **none**: No match

## Algorithm

Returns first manifest with compatible platform (exact match preferred).
-/

/-- Platform match score. -/
inductive MatchScore where
  | exact : MatchScore       -- All fields match
  | compatible : MatchScore  -- Required fields match
  | none : MatchScore        -- No match
  deriving DecidableEq, Repr

/-- Match two platforms with scoring. -/
def matchPlatform (p1 p2 : Platform) : MatchScore :=
  if p1.architecture ≠ p2.architecture || p1.os ≠ p2.os then
    .none
  else if p1.osVersion = p2.osVersion && p1.variant = p2.variant then
    .exact
  else
    .compatible

/-- Select best matching manifest from index. -/
def selectBestManifest (idx : ImageIndex) (p : Platform) : Option Descriptor :=
  -- First try exact match
  match idx.manifests.find? (fun d =>
    match d.platform with
    | some plat => matchPlatform plat p = .exact
    | none => false) with
  | some d => some d
  | none =>
    -- Fall back to compatible match
    idx.manifests.find? (fun d =>
      match d.platform with
      | some plat => matchPlatform plat p = .compatible
      | none => false)

/-- STRUCTURAL: Exact match requires os and architecture equality. -/
theorem matchPlatform_exact_requires_os_arch (p1 p2 : Platform) :
    matchPlatform p1 p2 = .exact →
    (p1.architecture = p2.architecture && p1.os = p2.os) = true := by
  intro h
  unfold matchPlatform at h
  split at h
  · simp at h
  · split at h
    · rename_i hNoMismatch hExact
      simp at hNoMismatch
      simp [hNoMismatch.1, hNoMismatch.2]
    · simp at h

/-- ALGEBRAIC: Platform matching is reflexive for exact. -/
theorem matchPlatform_reflexive (p : Platform) :
    matchPlatform p p = .exact := by
  simp [matchPlatform]

/-- ALGEBRAIC: Selected manifest is from index. -/
theorem selectBestManifest_in_list (idx : ImageIndex) (p : Platform) (d : Descriptor) :
    selectBestManifest idx p = some d → d ∈ idx.manifests := by
  intro h
  unfold selectBestManifest at h
  split at h
  · rename_i d' hFind
    injection h with hd
    subst hd
    exact List.mem_of_find?_eq_some hFind
  · exact List.mem_of_find?_eq_some h

end SWELib.Cloud.OciImage
