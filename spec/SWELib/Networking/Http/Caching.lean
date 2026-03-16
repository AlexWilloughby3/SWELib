import SWELib.Networking.Http.Field
import SWELib.Networking.Http.Message
import SWELib.Networking.Http.Method

/-!
# HTTP Caching

RFC 9110 Section 3.3 and RFC 9111: Cache directives and freshness.

Only the spec-level constraints are modelled here; the full caching
machinery is in RFC 9111.
-/

namespace SWELib.Networking.Http

/-- Cache directive values (RFC 9111 Section 5). -/
inductive CacheDirective where
  /-- no-store: do not cache this response at all. -/
  | noStore
  /-- no-cache: must revalidate before using cached copy. -/
  | noCache
  /-- max-age: maximum freshness lifetime in seconds. -/
  | maxAge (seconds : Nat)
  /-- s-maxage: shared cache max-age override. -/
  | sMaxage (seconds : Nat)
  /-- must-revalidate: must revalidate stale entries. -/
  | mustRevalidate
  /-- private: only store in private (user-specific) caches. -/
  | private_
  /-- public: may store in shared caches. -/
  | public_
  /-- immutable: cached response will not change (RFC 8246). -/
  | immutable
  /-- Any extension directive. -/
  | other (name : String) (value : Option String)
  deriving DecidableEq, Repr

instance : ToString CacheDirective where
  toString
    | .noStore        => "no-store"
    | .noCache        => "no-cache"
    | .maxAge n       => s!"max-age={n}"
    | .sMaxage n      => s!"s-maxage={n}"
    | .mustRevalidate => "must-revalidate"
    | .private_       => "private"
    | .public_        => "public"
    | .immutable      => "immutable"
    | .other n none   => n
    | .other n (some v) => s!"{n}={v}"

/-- Whether a cache directive prevents storage (RFC 9111 Section 5.2). -/
def CacheDirective.preventsStorage : CacheDirective → Bool
  | .noStore => true
  | _        => false

/-- Whether a response with this directive requires revalidation before use. -/
def CacheDirective.requiresRevalidation : CacheDirective → Bool
  | .noCache | .mustRevalidate => true
  | _ => false

/-- A response is storable in cache if none of its Cache-Control directives
    prevent storage (RFC 9111 Section 3). -/
def Response.isCacheStorable (_resp : Response) (directives : List CacheDirective) : Bool :=
  !directives.any (·.preventsStorage)

/-- A response is fresh if it has a max-age directive and the age has not exceeded it. -/
def Response.isFresh (directives : List CacheDirective) (currentAge : Nat) : Bool :=
  directives.any fun d => match d with
    | .maxAge n => currentAge < n
    | _ => false

-- Theorems

/-- no-store prevents caching. -/
theorem noStore_prevents_storage :
    CacheDirective.preventsStorage .noStore = true := by rfl

/-- A response with no-store directive is never storable, regardless of method.
    This is a convenience specialisation of `noStore_prevents_storage`. -/
theorem noStore_response_not_storable (resp : Response) :
    Response.isCacheStorable resp [.noStore] = false := by
  simp [Response.isCacheStorable, List.any, CacheDirective.preventsStorage]

/-- A response with max-age=0 is never fresh regardless of current age. -/
theorem maxAge_zero_not_fresh (age : Nat) :
    Response.isFresh [.maxAge 0] age = false := by
  simp [Response.isFresh, List.any]

end SWELib.Networking.Http
