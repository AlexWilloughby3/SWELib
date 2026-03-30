import SWELib
import SWELibImpl.Bridge

/-!
# UriParser

Executable UriParser implementation.
-/


namespace SWELibImpl.Basics

open SWELib.Basics

/-- Split a string on the first occurrence of a delimiter, returning the parts before and after. -/
private def splitFirst (s : String) (delim : Char) : String × Option String :=
  match s.splitOn (String.singleton delim) with
  | [] | [_] => (s, none)
  | x :: rest => (x, some (String.intercalate (String.singleton delim) rest))

/-- Parse "host" or "host:port" or "user@host:port" into a `UriAuthority`. -/
private def parseAuthority (s : String) : UriAuthority :=
  let hostPort := match splitFirst s '@' with
    | (_, some rest) => rest
    | (all, none)    => all
  match splitFirst hostPort ':' with
  | (host, some p) => { host := host, port := p.toNat? }
  | (host, none)   => { host := host, port := none }

/-- Parse a URI string per RFC 3986 §3.
    Handles: `scheme://[authority][/path][?query][#fragment]`
    Falls back to the spec's `Uri.parse` for unrecognised forms. -/
def parseUri (s : String) : Option Uri :=
  -- Peel off fragment
  let (noFrag, fragment) := splitFirst s '#'
  -- Peel off query
  let (noQuery, query) := splitFirst noFrag '?'
  -- Split on "://"
  match noQuery.splitOn "://" with
  | scheme :: rest =>
    let afterScheme := String.intercalate "://" rest
    if afterScheme.startsWith "/" then
      -- No authority (e.g. "file:///tmp")
      some { scheme := scheme.toLower, authority := none,
             path := afterScheme, query := query, fragment := fragment }
    else
      match splitFirst afterScheme '/' with
      | (authStr, some pathRest) =>
        some { scheme := scheme.toLower,
               authority := some (parseAuthority authStr),
               path := "/" ++ pathRest, query := query, fragment := fragment }
      | (authStr, none) =>
        some { scheme := scheme.toLower,
               authority := some (parseAuthority authStr),
               path := "", query := query, fragment := fragment }
  | _ => Uri.parse s   -- fall back to spec parser

/-- Return the default port for a well-known scheme. -/
def defaultPort : String → Option Nat
  | "http" | "ws"   => some 80
  | "https" | "wss" => some 443
  | "ftp"            => some 21
  | "ssh"            => some 22
  | _                => none

/-- The effective port: explicit port if present, otherwise the scheme default. -/
def effectivePort (u : Uri) : Option Nat :=
  u.port <|> defaultPort u.scheme

/-- Serialize a `Uri` back to its string representation. -/
def serializeUri (u : Uri) : String :=
  let auth := match u.authority with
    | none   => ""
    | some a => "//" ++ a.host ++ (a.port.map (fun p => ":" ++ toString p) |>.getD "")
  let q := u.query.map    ("?" ++ ·) |>.getD ""
  let f := u.fragment.map ("#" ++ ·) |>.getD ""
  u.scheme ++ ":" ++ auth ++ u.path ++ q ++ f

/-- Normalize a path by collapsing "." and ".." segments (RFC 3986 §5.2.4). -/
def normalizePath (path : String) : String :=
  let segs := path.splitOn "/"
  let out := segs.foldl (fun acc seg =>
    match seg with
    | "." => acc
    | ".." => acc.dropLast
    | s    => acc ++ [s]) ([] : List String)
  String.intercalate "/" out

end SWELibImpl.Basics
