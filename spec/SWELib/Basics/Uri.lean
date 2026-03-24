/-!
# URI

Minimal URI specification per RFC 3986, sufficient for HTTP target identification.
Used by `SWELib.Networking.Http.Target`.
-/

namespace SWELib.Basics

/-- Authority component of a URI: host with optional userinfo and port. -/
structure UriAuthority where
  /-- Host identifier (domain name or IP literal). -/
  host : String
  /-- Optional port number. -/
  port : Option Nat := none
  deriving DecidableEq, Repr

/-- A parsed Uniform Resource Identifier per RFC 3986 Section 3.
    Components are optional per the RFC; only `scheme` and `path` are
    always syntactically present (path may be empty). -/
structure Uri where
  /-- URI scheme (e.g., "http", "https"). Stored lowercase. -/
  scheme : String
  /-- Authority component (host, optional port). -/
  authority : Option UriAuthority := none
  /-- Hierarchical path component (may be empty). -/
  path : String := ""
  /-- Query component (without leading '?'). -/
  query : Option String := none
  /-- Fragment component (without leading '#'). -/
  fragment : Option String := none
  deriving DecidableEq, Repr

/-- Extract host string from a URI, if authority is present. -/
def Uri.host (u : Uri) : Option String :=
  u.authority.map (·.host)

/-- Extract port from a URI, if authority is present and port is specified. -/
def Uri.port (u : Uri) : Option Nat :=
  u.authority.bind (·.port)

/-- Parse a URI string (simplified). -/
def Uri.parse (s : String) : Option Uri :=
  -- Simple parsing for common patterns
  if s.startsWith "ws://" then
    some { scheme := "ws", authority := none, path := (s.drop 5).toString }
  else if s.startsWith "wss://" then
    some { scheme := "wss", authority := none, path := (s.drop 6).toString }
  else if s.startsWith "http://" then
    some { scheme := "http", authority := none, path := (s.drop 7).toString }
  else if s.startsWith "https://" then
    some { scheme := "https", authority := none, path := (s.drop 8).toString }
  else
    none

/-- Check if URI scheme is WebSocket (ws or wss). -/
def Uri.isWebSocket (u : Uri) : Bool :=
  u.scheme = "ws" ∨ u.scheme = "wss"

end SWELib.Basics
