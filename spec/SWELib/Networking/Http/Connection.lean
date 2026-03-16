import SWELib.Networking.Http.Field
import SWELib.Networking.Http.Message
import SWELib.Networking.Http.StatusCode

/-!
# HTTP Connection Management

RFC 9110 Section 7.6, RFC 9112 Section 9: Connection management,
persistence, and the Connection header.
-/

namespace SWELib.Networking.Http

/-- Connection option values (RFC 9110 Section 7.6.1). -/
inductive ConnectionOption where
  /-- `close`: request or signal connection closure after this exchange. -/
  | close
  /-- `keep-alive`: request connection persistence (HTTP/1.0 extension). -/
  | keepAlive
  /-- Any other connection option by name. -/
  | other (name : String)
  deriving DecidableEq, Repr

instance : ToString ConnectionOption where
  toString
    | .close     => "close"
    | .keepAlive => "keep-alive"
    | .other s   => s

/-- Connection persistence model per HTTP version and Connection header. -/
inductive ConnectionPersistence where
  /-- The connection will be reused for subsequent requests. -/
  | persistent
  /-- The connection will be closed after this exchange. -/
  | close_
  deriving DecidableEq, Repr

/-- Determine connection persistence from version and Connection header.
    - HTTP/1.1: persistent by default unless "close" token is present.
    - HTTP/1.0: non-persistent by default unless "keep-alive" token is present.
    RFC 9112 Section 9.3. The Connection header is a comma-separated list of tokens
    (RFC 9110 Section 7.6.1); each token is trimmed and compared case-insensitively. -/
def determineConnectionPersistence (version : Version) (connHeader : Option String) :
    ConnectionPersistence :=
  let tokens := (connHeader.getD "").splitOn "," |>.map (·.trimAscii.toString.toLower)
  let hasClose := tokens.any (· == "close")
  let hasKeepAlive := tokens.any (· == "keep-alive")
  if version == Version.http11 then
    if hasClose then .close_ else .persistent
  else
    if hasKeepAlive then .persistent else .close_

/-- RFC 9110 Section 7.6.1: Hop-by-hop headers listed in Connection MUST NOT
    be forwarded. A proxy MUST remove them before forwarding the message. -/
def Request.connectionOptions (req : Request) : List String :=
  match req.headers.get? FieldName.connection with
  | none => []
  | some v => v.splitOn "," |>.map (·.trimAscii.toString)

/-- A header is connection-specific if it appears in the Connection header
    options (RFC 9110 Section 7.6.1). -/
def Request.isConnectionSpecific (req : Request) (fieldName : FieldName) : Bool :=
  req.connectionOptions.any (· == fieldName.raw)

-- Theorems

/-- HTTP/1.1 connections are persistent by default (RFC 9112 Section 9.3). -/
theorem http11_persistent_by_default :
    determineConnectionPersistence Version.http11 none = .persistent := by
  native_decide

/-- HTTP/1.0 connections are non-persistent by default (RFC 9112 Section 9.3). -/
theorem http10_nonpersistent_by_default :
    determineConnectionPersistence Version.http10 none = .close_ := by
  native_decide

/-- Connection: close overrides HTTP/1.1 default persistence. -/
theorem http11_close_header_closes :
    determineConnectionPersistence Version.http11 (some "close") = .close_ := by
  native_decide

end SWELib.Networking.Http
