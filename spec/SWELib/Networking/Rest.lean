import SWELib.Networking.Rest.Constraint
import SWELib.Networking.Rest.Link
import SWELib.Networking.Rest.Representation
import SWELib.Networking.Rest.Resource
import SWELib.Networking.Rest.Conditional
import SWELib.Networking.Rest.Operations
import SWELib.Networking.Rest.Invariants
import SWELib.Networking.Rest.Error

/-!
# REST (Representational State Transfer)

Formal specification of REST architectural style as defined in
Roy Fielding's dissertation "Architectural Styles and the Design
of Network-based Software Architectures" (2000).

## Overview

REST is an architectural style for distributed hypermedia systems
with six constraints:
1. Client-Server
2. Stateless
3. Cache
4. Uniform Interface
5. Layered System
6. Code-On-Demand (optional)

## Key Concepts

- **Resources**: Any information that can be named
- **Representations**: Sequence of bytes plus metadata describing those bytes
- **Uniform Interface**: Resource identification, manipulation through
  representations, self-descriptive messages, HATEOAS
- **Stateless**: Each request contains all necessary context

## References

- Fielding, Roy Thomas. "Architectural Styles and the Design of
  Network-based Software Architectures." Doctoral dissertation,
  University of California, Irvine, 2000.
- RFC 9110: HTTP Semantics
- RFC 8288: Web Linking
-/

namespace SWELib.Networking.Rest

end SWELib.Networking.Rest
