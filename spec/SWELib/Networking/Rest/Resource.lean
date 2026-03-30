import SWELib.Basics.Uri
import SWELib.Networking.Rest.Representation
import SWELib.Networking.Http.Method
import Std

/-!
# REST Resources

Resources as defined in Fielding's dissertation:
"Any information that can be named can be a resource."

Reference: Fielding Dissertation, Chapter 5.2.1 (Resources and Representations)
-/

namespace SWELib.Networking.Rest

/-- REST resource.

    A resource is identified by a URI and has:
    1. One or more representations
    2. Supported HTTP methods
    3. Associated metadata

    Section: Fielding Dissertation, Chapter 5.2.1 -/
structure Resource where
  /-- URI identifying the resource. -/
  uri : SWELib.Basics.Uri
  /-- Available representations of the resource. -/
  representations : List Representation
  /-- HTTP methods supported by this resource. -/
  methods : List SWELib.Networking.Http.Method
  deriving Repr

/-- Well-formed REST resource invariants.

    This model treats GET support and nonempty representations as
    explicit invariants on a resource description. -/
def Resource.WellFormed (r : Resource) : Prop :=
  SWELib.Networking.Http.Method.GET ∈ r.methods ∧
  r.representations ≠ []

/-- Resource invariant: GET must be in the supported methods.

    This is a fundamental REST principle - every resource should be
    retrievable via GET.

    Section: Fielding Dissertation, Chapter 5.2.1.1 (Resource Manipulation) -/
 theorem resource_get_required (r : Resource) (h_wf : r.WellFormed) :
    SWELib.Networking.Http.Method.GET ∈ r.methods := by
  exact h_wf.1

/-- Representation non-empty invariant: a resource must have at least one representation.

    Section: Fielding Dissertation, Chapter 5.2.1 (Resources have representations) -/
theorem representations_nonempty (r : Resource) (h_wf : r.WellFormed) :
    r.representations ≠ [] := by
  exact h_wf.2

/-- Check if resource supports a specific HTTP method. -/
def Resource.supportsMethod (r : Resource) (method : SWELib.Networking.Http.Method) : Bool :=
  r.methods.contains method

/-- Get the primary representation (first in the list). -/
def Resource.primaryRepresentation (r : Resource) : Option Representation :=
  r.representations.head?

/-- Find a representation by media type. -/
def Resource.findRepresentation (r : Resource) (mediaType : SWELib.Networking.Http.MediaType) :
    Option Representation :=
  r.representations.find? (λ rep => rep.mediaType == mediaType)

/-- Get all media types supported by this resource. -/
def Resource.supportedMediaTypes (r : Resource) : List SWELib.Networking.Http.MediaType :=
  r.representations.map (·.mediaType)

/-- Check if resource supports a media type. -/
def Resource.supportsMediaType (r : Resource) (mediaType : SWELib.Networking.Http.MediaType) : Bool :=
  r.representations.any (λ rep => rep.mediaType == mediaType)

/-- Safe methods supported by this resource. -/
def Resource.safeMethods (r : Resource) : List SWELib.Networking.Http.Method :=
  r.methods.filter (λ m => m.isSafe)

/-- Idempotent methods supported by this resource. -/
def Resource.idempotentMethods (r : Resource) : List SWELib.Networking.Http.Method :=
  r.methods.filter (λ m => m.isIdempotent)

end SWELib.Networking.Rest
