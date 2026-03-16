import SWELib.Basics.Uri
import Std

/-!
# REST Hypermedia Links

Hypermedia links as defined in RFC 8288 (Web Linking) and
Fielding's HATEOAS constraint.

Reference:
- RFC 8288: Web Linking
- Fielding Dissertation, Chapter 5.1.5 (Uniform Interface)
-/

namespace SWELib.Networking.Rest

/-- Link relation type as defined in RFC 8288 Section 3.

    A link relation identifies the semantics of a link.
    Standard relations include "self", "next", "prev", etc.

    Section: RFC 8288 Section 3 -/
structure LinkRelation where
  /-- Link relation type (e.g., "self", "next", "prev"). -/
  rel : String
  /-- Target URI of the link. -/
  href : SWELib.Basics.Uri
  /-- Optional media type hint for the target resource. -/
  type : Option String := none
  deriving DecidableEq, Repr

/-- Decidable equality for LinkRelation (structural). -/
def LinkRelation_decEq (l1 l2 : LinkRelation) : Decidable (l1 = l2) :=
  inferInstance

/-- Self-link property: a link with relation "self" must have a non-empty href.

    Section: RFC 8288 Section 3.1 (registered relation types) -/
theorem self_link_nonempty (link : LinkRelation) (h : link.rel = "self") :
    link.href.path ≠ "" ∨ link.href.authority.isSome := by
  sorry

/-- Check if a link relation is a registered IANA relation.

    Section: RFC 8288 Section 4.2 (IANA Link Relations Registry) -/
def LinkRelation.isRegistered (link : LinkRelation) : Bool :=
  let registered := ["about", "alternate", "author", "bookmark", "canonical",
    "chapter", "collection", "contents", "copyright", "create-form", "current",
    "describedby", "describes", "disclosure", "duplicate", "edit", "edit-form",
    "edit-media", "enclosure", "first", "glossary", "help", "hosts", "hub",
    "icon", "index", "item", "last", "latest-version", "license", "lrdd",
    "memento", "monitor", "monitor-group", "next", "next-archive", "nofollow",
    "noreferrer", "original", "payment", "predecessor-version", "prefetch",
    "prev", "preview", "previous", "privacy-policy", "profile", "related",
    "replies", "search", "section", "self", "service", "start", "stylesheet",
    "subsection", "successor-version", "tag", "terms-of-service", "timegate",
    "timemap", "type", "up", "version-history", "via", "working-copy",
    "working-copy-of"]
  registered.contains link.rel

end SWELib.Networking.Rest