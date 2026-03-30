/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Annotations

Annotation key-value pairs for image metadata.

## Standard Annotation Keys

Pre-defined keys following `org.opencontainers.image.*` convention:
- created, authors, url, documentation, source
- version, revision, vendor, licenses
- ref.name, title, description

## References

- [OCI Image Annotations](https://github.com/opencontainers/image-spec/blob/main/annotations.md)
-/

/-- Annotation key-value pairs (preserves order). -/
def Annotations := List (String × String)

instance : Repr Annotations where
  reprPrec a n := @Repr.reprPrec (List (String × String)) instReprList (a : List (String × String)) n

/-- Standard annotation: creation timestamp. -/
def annotationCreated : String := "org.opencontainers.image.created"

/-- Standard annotation: image authors. -/
def annotationAuthors : String := "org.opencontainers.image.authors"

/-- Standard annotation: image URL. -/
def annotationUrl : String := "org.opencontainers.image.url"

/-- Standard annotation: documentation URL. -/
def annotationDocumentation : String := "org.opencontainers.image.documentation"

/-- Standard annotation: source repository. -/
def annotationSource : String := "org.opencontainers.image.source"

/-- Standard annotation: version string. -/
def annotationVersion : String := "org.opencontainers.image.version"

/-- Standard annotation: source control revision. -/
def annotationRevision : String := "org.opencontainers.image.revision"

/-- Standard annotation: vendor name. -/
def annotationVendor : String := "org.opencontainers.image.vendor"

/-- Standard annotation: license identifiers. -/
def annotationLicenses : String := "org.opencontainers.image.licenses"

/-- Standard annotation: reference name. -/
def annotationRefName : String := "org.opencontainers.image.ref.name"

/-- Standard annotation: human-readable title. -/
def annotationTitle : String := "org.opencontainers.image.title"

/-- Standard annotation: human-readable description. -/
def annotationDescription : String := "org.opencontainers.image.description"

/-- Get annotation value by key. -/
def Annotations.get (a : Annotations) (key : String) : Option String :=
  a.find? (fun p => p.1 = key) |>.map (·.2)

/-- Set annotation value (replaces if exists, appends otherwise). -/
def Annotations.set (a : Annotations) (key : String) (value : String) : Annotations :=
  let filtered := a.filter (fun p => p.1 ≠ key)
  filtered.append [(key, value)]

/-- Remove annotation by key. -/
def Annotations.remove (a : Annotations) (key : String) : Annotations :=
  a.filter (fun p => p.1 ≠ key)

end SWELib.Cloud.OciImage
