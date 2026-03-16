import SWELib.Networking.Http.Field
import SWELib.Networking.Http.Message

/-!
# HTTP Representation Data and Metadata

RFC 9110 Section 8: Content-Type, Content-Encoding, Content-Length,
ETag, Last-Modified, and related representation metadata.
-/

namespace SWELib.Networking.Http

/-- Media type (RFC 9110 Section 8.3.1).
    Represents a MIME type like `text/html; charset=utf-8`. -/
structure MediaType where
  /-- Top-level type (e.g., "text", "application"). Case-insensitive. -/
  type_ : String
  /-- Subtype (e.g., "html", "json"). Case-insensitive. -/
  subtype : String
  /-- Parameters (e.g., [("charset", "utf-8")]). -/
  parameters : List (String × String) := []
  deriving Repr

/-- Case-insensitive comparison for media types (type and subtype only,
    parameters are not considered for type equality per RFC 9110). -/
instance : BEq MediaType where
  beq a b := a.type_.toLower == b.type_.toLower &&
             a.subtype.toLower == b.subtype.toLower

instance : ToString MediaType where
  toString mt :=
    let base := s!"{mt.type_}/{mt.subtype}"
    let params := mt.parameters.map fun (k, v) => s!"; {k}={v}"
    base ++ String.join params

-- Common media types

def MediaType.textPlain : MediaType := ⟨"text", "plain", []⟩
def MediaType.textHtml : MediaType := ⟨"text", "html", []⟩
def MediaType.applicationJson : MediaType := ⟨"application", "json", []⟩
def MediaType.applicationOctetStream : MediaType := ⟨"application", "octet-stream", []⟩
def MediaType.applicationFormUrlencoded : MediaType := ⟨"application", "x-www-form-urlencoded", []⟩
def MediaType.multipartFormData : MediaType := ⟨"multipart", "form-data", []⟩

/-- Content coding values (RFC 9110 Section 8.4.1). -/
inductive ContentCoding where
  | compress
  | deflate
  | gzip
  | identity
  | other (name : String)
  deriving DecidableEq, Repr

/-- Transfer coding values for Transfer-Encoding header (RFC 9112 Section 7).
    Distinct from ContentCoding: transfer codings apply to the message
    transport layer, not the representation itself. -/
inductive TransferCoding where
  /-- Chunked transfer encoding — the payload body is sent as a series of chunks. -/
  | chunked
  | compress
  | deflate
  | gzip
  | identity
  | other (name : String)
  deriving DecidableEq, Repr

instance : ToString TransferCoding where
  toString
    | .chunked  => "chunked"
    | .compress => "compress"
    | .deflate  => "deflate"
    | .gzip     => "gzip"
    | .identity => "identity"
    | .other s  => s

/-- Entity tag value (RFC 9110 Section 8.8.3).
    ETags are opaque quoted strings, optionally prefixed with W/ for weak. -/
structure ETag where
  /-- The opaque tag value (without quotes). -/
  value : String
  /-- Whether this is a weak validator (W/ prefix). -/
  weak : Bool := false
  deriving DecidableEq, Repr

instance : ToString ETag where
  toString et :=
    let pfx := if et.weak then "W/" else ""
    s!"{pfx}\"{et.value}\""

/-- Strong comparison function for entity tags (RFC 9110 Section 8.8.3.2).
    Two entity tags are strongly equivalent only if both are strong
    and their opaque-tags match character-by-character. -/
def ETag.strongEq (a b : ETag) : Bool :=
  !a.weak && !b.weak && a.value == b.value

/-- Weak comparison function for entity tags (RFC 9110 Section 8.8.3.2).
    Two entity tags are weakly equivalent if their opaque-tags match,
    regardless of weak/strong marking. -/
def ETag.weakEq (a b : ETag) : Bool :=
  a.value == b.value

/-- Content-Length validity: if Content-Length header is present,
    it must equal the actual body size (RFC 9110 Section 8.6). -/
def contentLengthValid (resp : Response) : Prop :=
  match resp.contentLength, resp.body with
  | some n, some b => b.size = n
  | some _, none => False
  | none, _ => True

-- Theorems

/-- Strong ETag equality implies weak equality (RFC 9110 Section 8.8.3.2). -/
theorem ETag.strong_implies_weak (a b : ETag) :
    a.strongEq b = true → a.weakEq b = true := by
  unfold strongEq weakEq
  intro h
  simp only [Bool.and_eq_true] at h
  exact h.2

/-- Weak ETag equality is reflexive. -/
theorem ETag.weakEq_refl (e : ETag) : e.weakEq e = true := by
  simp [weakEq, BEq.beq]

/-- Weak ETag equality is symmetric. -/
theorem ETag.weakEq_symm (a b : ETag) :
    a.weakEq b = true → b.weakEq a = true := by
  simp [weakEq, BEq.beq]
  intro h; exact h.symm

/-- A byte range specification (RFC 9110 Section 14.1.2). -/
inductive ByteRangeSpec where
  /-- A range from firstPos to lastPos (inclusive).
      `lastPos = none` means "to end of representation". -/
  | intRange (firstPos : Nat) (lastPos : Option Nat)
  /-- A suffix range: the last N bytes of the representation. -/
  | suffixRange (suffixLength : Nat)
  deriving DecidableEq, Repr

/-- A Range header value (RFC 9110 Section 14.1).
    Specifies one or more byte ranges to retrieve. -/
structure RangeHeader where
  /-- The range unit (RFC 9110 Section 14.1.1, typically "bytes"). -/
  unit : String
  /-- One or more range specifications (RFC 9110 Section 14.1.2). -/
  ranges : List ByteRangeSpec
  deriving Repr

/-- A Content-Range header value (RFC 9110 Section 14.4). -/
inductive ContentRangeValue where
  /-- A satisfiable range response: unit firstPos-lastPos/completeLength. -/
  | range (unit : String) (firstPos : Nat) (lastPos : Nat) (completeLength : Nat)
  /-- An unsatisfied range (used in 416 responses): unit */completeLength. -/
  | unsatisfied (unit : String) (completeLength : Nat)
  deriving DecidableEq, Repr

instance : ToString ContentRangeValue where
  toString
    | .range u f l c   => s!"{u} {f}-{l}/{c}"
    | .unsatisfied u c  => s!"{u} */{c}"

/-- A satisfiable range must have firstPos <= lastPos (RFC 9110 Section 14.4). -/
def ContentRangeValue.isValid : ContentRangeValue -> Bool
  | .range _ f l _ => f <= l
  | .unsatisfied _ _ => true

/-- A satisfiable range must not exceed the complete length (RFC 9110 Section 14.4). -/
def ContentRangeValue.withinBounds : ContentRangeValue -> Bool
  | .range _ _ l c => l < c
  | .unsatisfied _ _ => true

-- Theorems about range validity

/-- A valid range has firstPos <= lastPos. -/
theorem ContentRangeValue.valid_range_ordered {f l c : Nat} :
    ContentRangeValue.isValid (.range "bytes" f l c) = true ↔ f ≤ l := by
  simp [isValid, decide_eq_true_eq]

/-- The unsatisfied range is always valid. -/
theorem ContentRangeValue.unsatisfied_valid (u : String) (c : Nat) :
    ContentRangeValue.isValid (.unsatisfied u c) = true := by
  simp [isValid]

/-- A content range within bounds has lastPos < completeLength. -/
theorem ContentRangeValue.withinBounds_iff {f l c : Nat} :
    ContentRangeValue.withinBounds (.range "bytes" f l c) = true ↔ l < c := by
  simp [withinBounds, decide_eq_true_eq]

/-- Strong ETag equality is asymmetric with respect to weak flag:
    a weak ETag cannot strongly equal any ETag. -/
theorem ETag.weak_not_strongEq (a b : ETag) (hw : a.weak = true) :
    a.strongEq b = false := by
  simp [strongEq, hw]

/-- Strong ETag comparison is stricter than weak: if two ETags are not weakly
    equal, they are certainly not strongly equal. -/
theorem ETag.notWeakEq_implies_notStrongEq (a b : ETag) :
    a.weakEq b = false → a.strongEq b = false := by
  intro h
  simp only [weakEq] at h
  simp only [strongEq, h, Bool.and_false]

end SWELib.Networking.Http
