/-!
# HTTP Header Fields

RFC 9110 Section 5: Field names, values, and header list operations.
-/

namespace SWELib.Networking.Http

/-- An HTTP header field name (RFC 9110 Section 5.1).
    Field names are tokens and are compared case-insensitively. -/
structure FieldName where
  /-- The raw field name string as received/sent. -/
  raw : String
  deriving Repr

/-- Case-insensitive equality for field names (RFC 9110 Section 5.1). -/
instance : BEq FieldName where
  beq a b := a.raw.toLower == b.raw.toLower

instance : Hashable FieldName where
  hash fn := hash fn.raw.toLower

instance : ToString FieldName where
  toString fn := fn.raw

-- Well-known field names (RFC 9110)

def FieldName.host : FieldName := ⟨"Host"⟩
def FieldName.contentType : FieldName := ⟨"Content-Type"⟩
def FieldName.contentLength : FieldName := ⟨"Content-Length"⟩
def FieldName.contentEncoding : FieldName := ⟨"Content-Encoding"⟩
def FieldName.contentLanguage : FieldName := ⟨"Content-Language"⟩
def FieldName.contentLocation : FieldName := ⟨"Content-Location"⟩
def FieldName.etag : FieldName := ⟨"ETag"⟩
def FieldName.lastModified : FieldName := ⟨"Last-Modified"⟩
def FieldName.date : FieldName := ⟨"Date"⟩
def FieldName.location : FieldName := ⟨"Location"⟩
def FieldName.retryAfter : FieldName := ⟨"Retry-After"⟩
def FieldName.server : FieldName := ⟨"Server"⟩
def FieldName.userAgent : FieldName := ⟨"User-Agent"⟩
def FieldName.allow : FieldName := ⟨"Allow"⟩
def FieldName.accept : FieldName := ⟨"Accept"⟩
def FieldName.acceptEncoding : FieldName := ⟨"Accept-Encoding"⟩
def FieldName.acceptLanguage : FieldName := ⟨"Accept-Language"⟩
def FieldName.authorization : FieldName := ⟨"Authorization"⟩
def FieldName.wwwAuthenticate : FieldName := ⟨"WWW-Authenticate"⟩
def FieldName.cacheControl : FieldName := ⟨"Cache-Control"⟩
def FieldName.connection : FieldName := ⟨"Connection"⟩
def FieldName.transferEncoding : FieldName := ⟨"Transfer-Encoding"⟩
def FieldName.vary : FieldName := ⟨"Vary"⟩
-- Conditional request headers (RFC 9110 Section 13)
def FieldName.ifMatch : FieldName := ⟨"If-Match"⟩
def FieldName.ifNoneMatch : FieldName := ⟨"If-None-Match"⟩
def FieldName.ifModifiedSince : FieldName := ⟨"If-Modified-Since"⟩
def FieldName.ifUnmodifiedSince : FieldName := ⟨"If-Unmodified-Since"⟩
def FieldName.ifRange : FieldName := ⟨"If-Range"⟩
-- Range request headers (RFC 9110 Section 14)
def FieldName.range : FieldName := ⟨"Range"⟩
def FieldName.contentRange : FieldName := ⟨"Content-Range"⟩
-- Protocol negotiation headers
def FieldName.upgrade : FieldName := ⟨"Upgrade"⟩
def FieldName.expect : FieldName := ⟨"Expect"⟩
def FieldName.via : FieldName := ⟨"Via"⟩
def FieldName.trailer : FieldName := ⟨"Trailer"⟩
def FieldName.te : FieldName := ⟨"TE"⟩
def FieldName.proxyAuthorization : FieldName := ⟨"Proxy-Authorization"⟩
def FieldName.proxyAuthenticate : FieldName := ⟨"Proxy-Authenticate"⟩

/-- Whether a field name is a hop-by-hop header per RFC 9110 Section 7.6.1.
    Hop-by-hop headers apply only to the immediate connection and MUST NOT
    be forwarded by proxies. -/
def FieldName.isHopByHop (fn : FieldName) : Bool :=
  [FieldName.connection, FieldName.transferEncoding, FieldName.te,
   FieldName.trailer, FieldName.upgrade].any (· == fn)

/-- A single header field line: a name-value pair (RFC 9110 Section 5.2). -/
structure Field where
  /-- The field name. -/
  name : FieldName
  /-- The field value (opaque string at this level). -/
  value : String
  deriving Repr

/-- Header field list: ordered sequence of fields that may contain
    duplicate names (per D-001). This preserves insertion order and
    allows multiple fields with the same name, as required by HTTP. -/
abbrev Headers := List Field

-- Header list operations

/-- Get all values for a given field name (case-insensitive).
    Returns values in the order they appear. -/
def Headers.getAll (hs : Headers) (name : FieldName) : List String :=
  (hs.filter (·.name == name)).map (·.value)

/-- Get the first value for a given field name, if any.
    Leading and trailing OWS is stripped per RFC 9110 Section 5.5. -/
def Headers.get? (hs : Headers) (name : FieldName) : Option String :=
  (hs.find? (·.name == name)).map (·.value.trimAscii.toString)

/-- Combine all values for a field name with ", " separator
    (RFC 9110 Section 5.3: field lines with the same name can be
    combined into one comma-separated list). -/
def Headers.getCombined (hs : Headers) (name : FieldName) : Option String :=
  let values := hs.getAll name
  if values.isEmpty then none
  else some (", ".intercalate values)

/-- Check whether a field name is present in the headers. -/
def Headers.contains (hs : Headers) (name : FieldName) : Bool :=
  hs.any (·.name == name)

/-- Add a field to the end of the header list. -/
def Headers.add (hs : Headers) (name : FieldName) (value : String) : Headers :=
  hs ++ [{ name, value }]

/-- Remove all fields with a given name. -/
def Headers.remove (hs : Headers) (name : FieldName) : Headers :=
  hs.filter (·.name != name)

/-- Parse Content-Length value from headers, if present and valid. -/
def Headers.getContentLength (hs : Headers) : Option Nat :=
  (hs.get? FieldName.contentLength).bind (·.trimAscii.toString.toNat?)

/-- Get the Transfer-Encoding header value from headers, if present. -/
def Headers.getTransferEncoding (hs : Headers) : Option String :=
  hs.get? FieldName.transferEncoding

-- Theorems

/-- Getting all values from an empty header list yields empty list. -/
theorem Headers.getAll_nil (name : FieldName) :
    Headers.getAll [] name = [] := by
  simp [getAll, List.filter]

/-- Field name comparison is case-insensitive (RFC 9110 §5.1). -/
theorem FieldName.beq_toLower (a b : FieldName) :
    (a == b) = (a.raw.toLower == b.raw.toLower) := by
  simp [BEq.beq]

/-- Case-insensitive header lookup invariant: field names that differ only in
    case retrieve identical values (RFC 9110 §5.1). -/
theorem Headers.getAll_case_eq (hs : Headers) (a b : FieldName)
    (h : a.raw.toLower = b.raw.toLower) : hs.getAll a = hs.getAll b := by
  unfold getAll
  have hsuff : ∀ f : Field, (f.name == a) = (f.name == b) := by
    intro f
    show (f.name.raw.toLower == a.raw.toLower) = (f.name.raw.toLower == b.raw.toLower)
    rw [h]
  congr 1
  exact List.filter_congr fun f _ => by rw [hsuff f]

/-- Removing a header name that is not present is a no-op. -/
theorem Headers.remove_not_present (hs : Headers) (name : FieldName)
    (h : hs.contains name = false) : hs.remove name = hs := by
  unfold remove contains at *
  rw [List.filter_eq_self]
  intro f hf
  rw [List.any_eq_false] at h
  have := h f hf
  show (f.name != name) = true
  simp only [bne, Bool.not_eq_true'] at this ⊢
  exact Bool.eq_false_iff.mpr this

/-- Getting all values from a singleton list with a matching name yields
    a singleton list with the value. -/
theorem Headers.getAll_singleton (name : FieldName) (value : String) :
    Headers.getAll [{ name, value }] name = [value] := by
  simp [getAll, List.filter, List.map, BEq.beq]

/-- Adding a field increases the length of the header list by one. -/
theorem Headers.add_length (hs : Headers) (name : FieldName) (value : String) :
    (hs.add name value).length = hs.length + 1 := by
  simp [add, List.length_append]

end SWELib.Networking.Http
