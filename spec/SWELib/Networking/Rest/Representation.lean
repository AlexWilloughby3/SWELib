import SWELib.Networking.Http.Representation
import Std

/-!
# REST Representations

Resource representations as defined in Fielding's dissertation:
"A representation is a sequence of bytes, plus representation metadata
to describe those bytes."

Reference: Fielding Dissertation, Chapter 5.2.1 (Resources and Representations)
-/

namespace SWELib.Networking.Rest

/-- REST resource representation.

    A representation consists of:
    1. Media type describing the data format
    2. The actual data bytes
    3. Metadata about the representation

    Section: Fielding Dissertation, Chapter 5.2.1 -/
structure Representation where
  /-- Media type of the representation data. -/
  mediaType : SWELib.Networking.Http.MediaType
  /-- Representation data as string. -/
  data : String
  /-- Representation metadata as key-value pairs.
      Includes headers like Content-Type, Content-Length, ETag, Last-Modified. -/
  metadata : List (String × String) := []
  deriving Repr


/-- Metadata invariant: Content-Type metadata must match the mediaType field.

    Section: RFC 9110 Section 8.3 (Content-Type) -/
theorem metadata_content_type_invariant (rep : Representation) :
    (rep.metadata.find? (λ (k, _) => k == "Content-Type") |>.map (·.2.toLower)) =
      some (toString rep.mediaType).toLower := by
  sorry

/-- Get the ETag from representation metadata, if present.

    Section: RFC 9110 Section 8.8.3 (ETag) -/
def Representation.getETag (rep : Representation) : Option SWELib.Networking.Http.ETag :=
  match rep.metadata.find? (λ (k, _) => k == "ETag") with
  | some (_, etagStr) =>
    -- Parse ETag string (e.g., W/"xyz" or "xyz")
    if etagStr.startsWith "W/" then
      some ⟨(etagStr.drop 2).toString, true⟩  -- Remove W/ prefix
    else if etagStr.startsWith "\"" then
      some ⟨(etagStr.drop 1).toString, false⟩  -- Remove leading quote
    else
      none
  | none => none

/-- Get the Last-Modified timestamp from metadata, if present.

    Section: RFC 9110 Section 8.8.2 (Last-Modified) -/
def Representation.getLastModified (rep : Representation) : Option String :=
  rep.metadata.find? (λ (k, _) => k == "Last-Modified") |>.map (·.2)

/-- Check if representation is cacheable based on metadata.

    Section: RFC 9110 Section 9.2.3 (Cacheable Methods) -/
def Representation.isCacheable (rep : Representation) : Bool :=
  match rep.metadata.find? (λ (k, _) => k == "Cache-Control") with
  | some (_, control) =>
    let directives := control.splitOn ","
    !directives.any (λ d => d.trimAscii == "no-cache") &&
    !directives.any (λ d => d.trimAscii == "no-store")
  | none => true  -- Cacheable by default for safe methods

end SWELib.Networking.Rest