/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Platform

Platform specification for multi-architecture container images.

## Fields

- **architecture**: CPU architecture (e.g., "amd64", "arm64")
- **os**: Operating system (e.g., "linux", "windows")
- **osVersion**: OS version (optional, e.g., "10.0.14393" for Windows)
- **osFeatures**: OS features (optional, e.g., ["win32k"])
- **variant**: Architecture variant (optional, e.g., "v7" for ARM)

## References

- [OCI Image Platform](https://github.com/opencontainers/image-spec/blob/main/image-index.md#platform)
-/

/-- Platform specification for OS and architecture. -/
structure Platform where
  /-- CPU architecture (e.g., "amd64", "arm64"). -/
  architecture : String
  /-- Operating system (e.g., "linux", "windows"). -/
  os : String
  /-- Optional OS version. -/
  osVersion : Option String := none
  /-- Optional OS features. -/
  osFeatures : List String := []
  /-- Optional architecture variant. -/
  variant : Option String := none
  deriving DecidableEq, Repr

/-- Common platform: Linux AMD64. -/
def Platform.linuxAmd64 : Platform :=
  { architecture := "amd64", os := "linux" }

/-- Common platform: Linux ARM64. -/
def Platform.linuxArm64 : Platform :=
  { architecture := "arm64", os := "linux" }

/-- Common platform: Windows AMD64. -/
def Platform.windowsAmd64 : Platform :=
  { architecture := "amd64", os := "windows" }

/-- Check if two platforms match (for manifest selection). -/
def Platform.matches (p1 p2 : Platform) : Bool :=
  p1.architecture = p2.architecture && p1.os = p2.os

/-- STRUCTURAL: Platform matching is reflexive. -/
theorem Platform.matches_reflexive (p : Platform) :
    p.matches p = true := by
  simp [Platform.matches]

end SWELib.Cloud.OciImage