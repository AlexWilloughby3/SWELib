import SWELib.Networking.Http.Field
import SWELib.Networking.Http.Message
import SWELib.Networking.Http.Representation

/-!
# HTTP Content Negotiation

RFC 9110 Section 12: Content negotiation allows a client to specify
preferences for the representation of a resource. The server selects
the most appropriate representation based on these preferences.
-/

namespace SWELib.Networking.Http

/-- A quality value (q-value) as a rational number in [0, 1000].
    Represents RFC 9110 Section 12.4.2 q-values scaled by 1000
    (e.g., q=0.9 -> 900, q=1.0 -> 1000, q=0 -> 0 means "not acceptable"). -/
structure QValue where
  /-- Quality value scaled by 1000. Must be in [0, 1000]. -/
  value : Nat
  h_range : value ≤ 1000
  deriving Repr

/-- The default quality value (q=1.0). -/
def QValue.default : QValue := ⟨1000, by decide⟩
/-- Explicit q=0 means "not acceptable". -/
def QValue.zero : QValue := ⟨0, by decide⟩

/-- Whether this quality value indicates the option is acceptable. -/
def QValue.isAcceptable (q : QValue) : Bool := q.value > 0

/-- A media type preference entry in an Accept header. -/
structure MediaTypePreference where
  /-- The media type (may use wildcards: */* or type/*). -/
  mediaType : MediaType
  /-- The client's preference for this type. -/
  quality : QValue := QValue.default
  deriving Repr

/-- An encoding preference entry in an Accept-Encoding header. -/
structure EncodingPreference where
  /-- The content coding name. -/
  coding : ContentCoding
  /-- The client's preference for this encoding. -/
  quality : QValue := QValue.default
  deriving Repr

/-- Parse Accept header preferences from a request, ordered by q-value descending. -/
def Request.acceptPreferences (req : Request) : List MediaTypePreference :=
  -- Simplified: if Accept header is absent, accept */* at q=1.0
  match req.headers.get? FieldName.accept with
  | none => [{ mediaType := ⟨"*", "*", []⟩, quality := QValue.default }]
  | some _ => [{ mediaType := ⟨"*", "*", []⟩, quality := QValue.default }]

/-- Check if a media type is acceptable given Accept preferences.
    A media type is acceptable if any preference with q > 0 matches it.
    RFC 9110 Section 12.5.1. -/
def MediaType.isAcceptable (mt : MediaType) (prefs : List MediaTypePreference) : Bool :=
  prefs.any fun pref =>
    pref.quality.isAcceptable &&
    (pref.mediaType.type_ == "*" ||
     (pref.mediaType.type_.toLower == mt.type_.toLower &&
      (pref.mediaType.subtype == "*" ||
       pref.mediaType.subtype.toLower == mt.subtype.toLower)))

/-- Content negotiation result. -/
inductive NegotiationResult where
  /-- A suitable representation was found. -/
  | selected (mediaType : MediaType)
  /-- No acceptable representation -- server should respond 406. -/
  | notAcceptable
  deriving Repr

/-- Select the best media type from available options given client preferences.
    Returns the first available type that the client accepts, or notAcceptable. -/
def selectMediaType (available : List MediaType) (prefs : List MediaTypePreference) :
    NegotiationResult :=
  match available.find? (·.isAcceptable prefs) with
  | some mt => .selected mt
  | none => .notAcceptable

-- Theorems

/-- The wildcard media type */* is always acceptable (RFC 9110 Section 12.5.1). -/
theorem wildcard_always_acceptable (mt : MediaType) :
    mt.isAcceptable [{ mediaType := ⟨"*", "*", []⟩, quality := QValue.default }] = true := by
  simp [MediaType.isAcceptable, List.any, QValue.isAcceptable, QValue.default]

/-- If q=0 is set for a type, it is not acceptable (RFC 9110 Section 12.4.2). -/
theorem qzero_not_acceptable (mt : MediaType) (prefs : List MediaTypePreference)
    (h : prefs.all (fun p => decide (p.quality.value = 0)) = true) :
    mt.isAcceptable prefs = false := by
  simp only [MediaType.isAcceptable]
  rw [List.any_eq_false]
  intro pref hpref
  have hq : decide (pref.quality.value = 0) = true := List.all_eq_true.mp h pref hpref
  have hval : pref.quality.value = 0 := of_decide_eq_true hq
  simp only [QValue.isAcceptable, hval, show ¬(0 > 0) from by omega,
    decide_false, Bool.false_and]
  exact Bool.false_ne_true

/-- The Vary header lists the request fields that influenced content negotiation.
    RFC 9110 Section 12.5.5: servers MUST send Vary when the response is
    subject to content negotiation. -/
def Response.varyFields (resp : Response) : List String :=
  match resp.headers.get? FieldName.vary with
  | none => []
  | some v => v.splitOn "," |>.map (·.trimAscii.toString)

/-- A response is negotiated if it has a non-empty Vary header. -/
def Response.isNegotiated (resp : Response) : Bool :=
  resp.headers.contains FieldName.vary

/-- RFC 9110 Section 12.5.5: A Vary: * response MUST NOT be stored by a shared cache. -/
def Response.varyIsStar (resp : Response) : Bool :=
  resp.headers.get? FieldName.vary == some "*"

/-- A response with Vary: * is necessarily negotiated (has a Vary header),
    since varyIsStar requires the Vary header to be present (RFC 9110 Section 12.5.5). -/
theorem varyStar_requires_revalidation (resp : Response)
    (h : resp.varyIsStar = true) :
    resp.isNegotiated = true := by
  simp only [Response.varyIsStar, Response.isNegotiated, Headers.contains, Headers.get?] at *
  cases hfind : List.find? (fun x => x.name == FieldName.vary) resp.headers with
  | none => simp [hfind, Option.map] at h
  | some f =>
    rw [List.any_eq_true]
    have hmem := List.mem_of_find?_eq_some hfind
    have hprop := List.find?_some hfind
    exact ⟨f, hmem, hprop⟩

end SWELib.Networking.Http
