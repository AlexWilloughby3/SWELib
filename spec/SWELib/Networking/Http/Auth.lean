import SWELib.Networking.Http.Field
import SWELib.Networking.Http.Message
import SWELib.Networking.Http.StatusCode

/-!
# HTTP Authentication

RFC 9110 Section 11: The HTTP authentication framework.
Defines the challenge-response model used by WWW-Authenticate
and Authorization headers.
-/

namespace SWELib.Networking.Http

/-- An HTTP authentication scheme (RFC 9110 Section 11.1). -/
inductive AuthScheme where
  /-- Basic authentication (RFC 7617). -/
  | basic
  /-- Bearer token authentication (RFC 6750, used with OAuth 2.0). -/
  | bearer
  /-- Digest authentication (RFC 7616). -/
  | digest
  /-- Any other scheme identified by name. -/
  | other (name : String)
  deriving DecidableEq, Repr

instance : ToString AuthScheme where
  toString
    | .basic     => "Basic"
    | .bearer    => "Bearer"
    | .digest    => "Digest"
    | .other s   => s

/-- An authentication challenge sent in a WWW-Authenticate header
    (RFC 9110 Section 11.6.1). -/
structure AuthChallenge where
  /-- The authentication scheme. -/
  scheme : AuthScheme
  /-- The realm parameter identifying the protection space. -/
  realm  : Option String := none
  /-- Additional scheme-specific parameters. -/
  params : List (String × String) := []
  deriving Repr

/-- An authentication credential sent in an Authorization header
    (RFC 9110 Section 11.6.2). -/
structure AuthCredential where
  /-- The authentication scheme. -/
  scheme : AuthScheme
  /-- The credential token or parameter list. -/
  token  : String
  deriving Repr

/-- Check whether a response is an authentication challenge (401/407).
    RFC 9110 Section 11.6: A 401 response MUST include WWW-Authenticate.
                            A 407 response MUST include Proxy-Authenticate. -/
def isAuthChallenge (resp : Response) : Bool :=
  resp.status.code == 401 || resp.status.code == 407

/-- RFC 9110 Section 11.6.1: A 401 Unauthorized response MUST include
    a WWW-Authenticate header. -/
def unauthorizedMustHaveWWWAuthenticate (resp : Response) : Prop :=
  resp.status.code = 401 →
    resp.headers.contains FieldName.wwwAuthenticate = true

/-- RFC 9110 Section 11.6.3: A 407 Proxy Authentication Required response
    MUST include a Proxy-Authenticate header. -/
def authProxyAuthRequiredHasProxyAuthenticate (resp : Response) : Prop :=
  resp.status.code = 407 →
    resp.headers.contains FieldName.proxyAuthenticate = true

-- Theorems

/-- If a response requires WWW-Authenticate and the header is present,
    the authentication requirement is satisfied. -/
theorem wwwAuth_satisfied (resp : Response)
    (_ : resp.status.code = 401)
    (hHeader : resp.headers.contains FieldName.wwwAuthenticate = true) :
    unauthorizedMustHaveWWWAuthenticate resp := by
  intro _; exact hHeader

end SWELib.Networking.Http
