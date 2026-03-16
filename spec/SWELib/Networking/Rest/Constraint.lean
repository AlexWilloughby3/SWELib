import Std

/-!
# REST Architectural Constraints

REST architectural constraints as defined in Roy Fielding's dissertation:
1. Client-Server
2. Stateless
3. Cache
4. Uniform Interface
5. Layered System
6. Code-On-Demand

Reference: Fielding, Chapter 5: Representational State Transfer (REST)
-/

namespace SWELib.Networking.Rest

/-- REST architectural constraints enumeration.

    Each constraint represents a design principle that restricts
    the architecture's degrees of freedom to achieve desired properties.

    Section: Fielding Dissertation, Chapter 5.1.3-5.1.8 -/
inductive RestConstraint where
  /-- Client-Server: Separation of concerns between user interface
      and data storage concerns. -/
  | clientServer
  /-- Stateless: Each request from client to server must contain
      all information needed to understand the request. -/
  | stateless
  /-- Cache: Responses must be labeled as cacheable or non-cacheable. -/
  | cache
  /-- Uniform Interface: Identification of resources, manipulation
      through representations, self-descriptive messages, and
      hypermedia as the engine of application state (HATEOAS). -/
  | uniformInterface
  /-- Layered System: Architecture composed of hierarchical layers
      where each layer cannot see beyond the immediate layer. -/
  | layeredSystem
  /-- Code-On-Demand: Optional constraint allowing client functionality
      to be extended by downloading and executing code. -/
  | codeOnDemand
  deriving DecidableEq, Repr

/-- Decidable equality for RestConstraint (structural). -/
def RestConstraint_decEq (c1 c2 : RestConstraint) : Decidable (c1 = c2) :=
  inferInstance

/-- Constraint relationships (REQUIRES_HUMAN proof).

    Some constraints enable or depend on others:
    - Stateless enables cacheability
    - Uniform interface enables layered system
    - etc.

    TODO: Formalize these relationships -/
theorem constraint_relationships : True := by
  trivial

end SWELib.Networking.Rest