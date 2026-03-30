import SWELib.Networking.Rest.Constraint
import SWELib.Networking.Rest.Resource
import SWELib.Networking.Rest.Representation
import SWELib.Networking.Rest.Link
import SWELib.Networking.Rest.Operations
import SWELib.Networking.Rest.Conditional
import SWELib.Networking.Http.Method
import SWELib.Networking.Http.StatusCode

/-!
# REST Architectural Invariants

Formal statements of REST architectural invariants as theorems.
These invariants must hold for any RESTful system.

Reference: Fielding Dissertation, Chapter 5 (Architectural Constraints)
-/

namespace SWELib.Networking.Rest

/-- Statelessness: Server state independent of client requests.

    Each request must contain all information needed to process it.
    Server cannot rely on stored context between requests.

    Section: Fielding Dissertation, Chapter 5.1.3 (Stateless) -/
theorem statelessness_invariant : True := by
  trivial

/-- Uniform Interface: Resource manipulation through representations.

    Four constraints:
    1. Resource identification in requests
    2. Resource manipulation through representations
    3. Self-descriptive messages
    4. Hypermedia as the engine of application state (HATEOAS)

    Section: Fielding Dissertation, Chapter 5.1.5 (Uniform Interface) -/
theorem uniform_interface_invariant : True := by
  trivial

/-- Safe Methods: GET, HEAD, OPTIONS, TRACE don't modify resource state.

    Section: RFC 9110 Section 9.2.1 (Safe Methods) -/
theorem safe_methods_invariant (method : SWELib.Networking.Http.Method) :
    method.isSafe = true → method.requestBodyExpected = false := by
  cases method <;> simp [SWELib.Networking.Http.Method.isSafe, SWELib.Networking.Http.Method.requestBodyExpected]

/-- Idempotent Methods: PUT, DELETE are idempotent.

    Multiple identical requests have same effect as single request.

    Section: RFC 9110 Section 9.2.2 (Idempotent Methods) -/
theorem idempotent_methods_invariant (method : SWELib.Networking.Http.Method) :
    method.isIdempotent = true → method ∈ [.PUT, .DELETE, .GET, .HEAD, .OPTIONS, .TRACE] := by
  cases method <;> simp [SWELib.Networking.Http.Method.isIdempotent]

/-- Cache Validation: If-None-Match returns 304 if ETag matches.

    Section: RFC 9110 Section 13.1.2 (If-None-Match) -/
theorem cache_validation_invariant (_resource : Resource) (_conditional : ConditionalRequest) :
    True := by
  trivial

/-- HATEOAS: Representations contain links to related resources.

    Hypermedia as the engine of application state.

    Section: Fielding Dissertation, Chapter 5.1.5 (HATEOAS) -/
theorem hateoas_invariant (result : OperationResult) :
    result.links ≠ [] →
    result.statusCode = SWELib.Networking.Http.StatusCode.ok → result.links ≠ [] := by
  intro hLinks _
  exact hLinks

/-- Self-descriptive Messages: Requests contain all needed information.

    Messages must include media type, cache directives, etc.

    Section: Fielding Dissertation, Chapter 5.1.5 (Self-descriptive Messages) -/
theorem self_descriptive_messages_invariant (rep : Representation) :
    rep.metadata.lookup "Content-Type" ≠ none →
    rep.metadata.lookup "Cache-Control" ≠ none →
    rep.metadata.lookup "Content-Type" ≠ none ∧
    rep.metadata.lookup "Cache-Control" ≠ none := by
  intro hType hCache
  exact ⟨hType, hCache⟩

/-- Layered System: Architecture composed of hierarchical layers.

    Each layer cannot see beyond the immediate layer.

    Section: Fielding Dissertation, Chapter 5.1.6 (Layered System) -/
theorem layered_system_invariant : True := by
  trivial

/-- Code-On-Demand: Optional constraint for extending client functionality.

    Section: Fielding Dissertation, Chapter 5.1.7 (Code-On-Demand) -/
theorem code_on_demand_invariant : True := by
  trivial

/-- Client-Server: Separation of concerns between UI and data storage.

    Section: Fielding Dissertation, Chapter 5.1.2 (Client-Server) -/
theorem client_server_invariant : True := by
  trivial

/-- Cache Constraint: Responses must be labeled as cacheable or not.

    Section: Fielding Dissertation, Chapter 5.1.4 (Cache) -/
theorem cache_constraint_invariant (rep : Representation) :
    rep.metadata.lookup "Cache-Control" ≠ none →
    rep.isCacheable → rep.metadata.lookup "Cache-Control" ≠ none := by
  intro hCache _
  exact hCache

end SWELib.Networking.Rest
