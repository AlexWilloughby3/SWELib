import SWELib.Basics.Uri

/-!
# HTTP Target Resource

RFC 9110 Sections 4, 7.1, 7.2: Target URI determination and Host header.
-/

namespace SWELib.Networking.Http

open SWELib.Basics

/-- The request target forms used in HTTP messages (RFC 9110 Section 7.1).

    Most requests use `originForm` (path + optional query).
    The other forms are method-specific:
    - `absoluteForm`: used when talking to proxies
    - `asteriskForm`: only valid with OPTIONS
    - `authorityForm`: only valid with CONNECT -/
inductive RequestTarget where
  /-- origin-form: absolute path and optional query (most common).
      Example: `/pub/WWW/?q=test` -/
  | originForm (path : String) (query : Option String)
  /-- absolute-form: full URI, used for proxy requests.
      Example: `http://www.example.com/pub/WWW/` -/
  | absoluteForm (uri : Uri)
  /-- authority-form: host:port, used only with CONNECT (Section 9.3.6).
      Example: `www.example.com:443` -/
  | authorityForm (host : String) (port : Nat)
  /-- asterisk-form: `*`, used only with OPTIONS (Section 9.3.7). -/
  | asteriskForm
  deriving DecidableEq, Repr

/-- Default port for an HTTP scheme (RFC 9110 Section 4.2).
    - "http" defaults to port 80
    - "https" defaults to port 443 -/
def defaultPort : String → Option Nat
  | "http" => some 80
  | "https" => some 443
  | _ => none

/-- Resolve the effective port for a URI, using the scheme default
    if no explicit port is given. -/
def Uri.effectivePort (u : Uri) : Option Nat :=
  u.port <|> defaultPort u.scheme

/-- An "http" URI MUST NOT have an empty host (RFC 9110 Section 4.2.1). -/
def Uri.hasNonEmptyHost (u : Uri) : Bool :=
  match u.authority with
  | some auth => !auth.host.isEmpty
  | none => false

-- Theorems

/-- The default port for "http" is 80. -/
theorem defaultPort_http : defaultPort "http" = some 80 := rfl

/-- The default port for "https" is 443. -/
theorem defaultPort_https : defaultPort "https" = some 443 := rfl

end SWELib.Networking.Http
