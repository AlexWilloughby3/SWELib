/-!
# Semantic Versioning

Semantic Versioning 2.0.0 specification.
Defines version structure, precedence ordering, and bump operations.
-/

namespace SWELib.Basics

/-- A pre-release identifier: either a numeric value or an alphanumeric string (SemVer §9). -/
inductive PreReleaseId where
  | numeric (n : Nat) : PreReleaseId
  | alphanumeric (s : String) : PreReleaseId
  deriving DecidableEq, Repr

/-- A semantic version per SemVer 2.0.0. -/
structure Semver where
  /-- Major version — incompatible API changes. -/
  major : Nat
  /-- Minor version — backwards-compatible functionality. -/
  minor : Nat
  /-- Patch version — backwards-compatible bug fixes. -/
  patch : Nat
  /-- Pre-release identifiers (SemVer §9). -/
  preRelease : List PreReleaseId := []
  /-- Build metadata identifiers (SemVer §10). Ignored in precedence. -/
  build : List String := []
  deriving DecidableEq, Repr

/-- A version is stable if its major version is greater than 0 (SemVer §4). -/
def Semver.isStable (v : Semver) : Bool := v.major > 0

/-- A version is a pre-release if it has pre-release identifiers (SemVer §9). -/
def Semver.isPreRelease (v : Semver) : Bool := !v.preRelease.isEmpty

/-- Compare two pre-release identifiers per SemVer §11.4. -/
def PreReleaseId.cmp : PreReleaseId → PreReleaseId → Ordering
  | .numeric a, .numeric b => Ord.compare a b
  | .alphanumeric a, .alphanumeric b => Ord.compare a b
  | .numeric _, .alphanumeric _ => .lt  -- numeric < alphanumeric
  | .alphanumeric _, .numeric _ => .gt

/-- Compare two pre-release identifier lists lexicographically (SemVer §11.4). -/
def PreReleaseId.cmpList : List PreReleaseId → List PreReleaseId → Ordering
  | [], [] => .eq
  | [], _ :: _ => .lt   -- fewer fields = lower precedence
  | _ :: _, [] => .gt
  | a :: as, b :: bs =>
    match a.cmp b with
    | .eq => cmpList as bs
    | ord => ord

/-- Total ordering of semantic versions per SemVer §11.
    Build metadata is ignored in precedence. -/
def Semver.cmp (a b : Semver) : Ordering :=
  match Ord.compare a.major b.major with
  | .eq =>
    match Ord.compare a.minor b.minor with
    | .eq =>
      match Ord.compare a.patch b.patch with
      | .eq =>
        match a.preRelease, b.preRelease with
        | [], [] => .eq
        | _ :: _, [] => .lt   -- pre-release < release
        | [], _ :: _ => .gt
        | as, bs => PreReleaseId.cmpList as bs
      | ord => ord
    | ord => ord
  | ord => ord

/-- Bump major version: increments major, resets minor and patch to 0,
    clears pre-release and build (SemVer §8). -/
def Semver.bumpMajor (v : Semver) : Semver :=
  { major := v.major + 1, minor := 0, patch := 0 }

/-- Bump minor version: increments minor, resets patch to 0,
    clears pre-release and build (SemVer §7). -/
def Semver.bumpMinor (v : Semver) : Semver :=
  { major := v.major, minor := v.minor + 1, patch := 0 }

/-- Bump patch version: increments patch,
    clears pre-release and build (SemVer §6). -/
def Semver.bumpPatch (v : Semver) : Semver :=
  { major := v.major, minor := v.minor, patch := v.patch + 1 }

/-- Compare a pre-release id with itself yields .eq. -/
private theorem PreReleaseId.cmp_refl (a : PreReleaseId) : a.cmp a = .eq := by
  cases a with
  | numeric n => simp [PreReleaseId.cmp, Ord.compare, compareOfLessAndEq]
  | alphanumeric s => simp [PreReleaseId.cmp, Ord.compare, compareOfLessAndEq]

/-- Compare a pre-release list with itself yields .eq. -/
private theorem PreReleaseId.cmpList_refl : (ids : List PreReleaseId) →
    PreReleaseId.cmpList ids ids = .eq
  | [] => rfl
  | a :: as => by
    simp [cmpList, cmp_refl a]
    exact cmpList_refl as

/-- Two versions differing only in build metadata are equal under cmp (SemVer §10). -/
theorem Semver.build_ignored_in_precedence (v : Semver) (b1 b2 : List String) :
    Semver.cmp { v with build := b1 } { v with build := b2 } = .eq := by
  unfold cmp
  simp
  cases v.preRelease with
  | nil => rfl
  | cons hd tl => exact PreReleaseId.cmpList_refl (hd :: tl)

/-- A pre-release version has lower precedence than the same release version (SemVer §11.3). -/
theorem Semver.prerelease_lower_than_release (v : Semver) (ids : List PreReleaseId) (h : ids ≠ []) :
    Semver.cmp { v with preRelease := ids } { v with preRelease := [] } = .lt := by
  unfold cmp
  simp
  cases ids with
  | nil => contradiction
  | cons hd tl => simp

/-- bumpMajor resets minor and patch to 0. -/
theorem Semver.bump_major_resets_minor_patch (v : Semver) :
    (v.bumpMajor).minor = 0 ∧ (v.bumpMajor).patch = 0 := by
  simp [bumpMajor]

end SWELib.Basics
