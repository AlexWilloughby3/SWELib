import SWELib.Security.Jwt.Types
import SWELib.Security.Jwt.Key
import SWELib.Security.Jwt.Algorithm
import SWELib.Security.Hashing

namespace SWELib.Security.Jwt

/-- Signature verification errors (RFC 7515 Section 10). -/
inductive SignatureError where
  | invalidFormat
  | algorithmMismatch
  | invalidSignature
  | keyTypeMismatch
  | unsupportedAlgorithm
  deriving DecidableEq, Repr

/-- Claims validation errors (RFC 7519 Section 7.2). -/
inductive ClaimsError where
  | expired
  | notYetValid
  | invalidIssuer
  | invalidAudience
  | invalidSubject
  | missingRequiredClaim
  deriving DecidableEq, Repr

/-- Combined validation result. -/
inductive ValidationError where
  | signature (err : SignatureError)
  | claims (err : ClaimsError)
  deriving DecidableEq, Repr

/-- Configuration for JWT validation. -/
structure ValidationConfig where
  /-- Required issuer (if any) -/
  requiredIssuer : Option String := none
  /-- Required audience (if any) -/
  requiredAudience : Option String := none
  /-- Required subject (if any) -/
  requiredSubject : Option String := none
  /-- Clock skew tolerance in seconds -/
  clockSkew : Nat := 60
  /-- Require expiration claim -/
  requireExp : Bool := true
  /-- Require issued at claim -/
  requireIat : Bool := false
  /-- Require JWT ID claim -/
  requireJti : Bool := false
  deriving DecidableEq, Repr

/-- Default validation configuration (strict). -/
def ValidationConfig.default : ValidationConfig :=
  { requireExp := true, clockSkew := 60 }

/-- Verify JWT signature against a key. -/
noncomputable def verifySignature (jwt : Jwt) (key : Jwk) : Except SignatureError Unit :=
  match jwt.header.alg with
  | .none =>
    if jwt.signature.isEmpty then
      .ok ()
    else
      .error .invalidSignature
  | alg =>
    if ¬key.supportsAlgorithm alg then
      .error .keyTypeMismatch
    else
      -- Placeholder: actual signature verification requires bridge axioms for RS256/ES256
      .error .unsupportedAlgorithm

/-- Validate JWT claims against configuration, given the current time.
    Callers obtain `now` from `SWELib.Basics.NumericDate.now` in IO. -/
noncomputable def validateClaims (jwt : Jwt) (config : ValidationConfig)
    (now : SWELib.Basics.NumericDate) :
    Except ClaimsError Unit := do
  -- Check expiration (RFC 7519 §4.1.4)
  match jwt.claims.exp with
  | some exp =>
    if exp.addSeconds config.clockSkew < now then
      .error .expired
  | none =>
    if config.requireExp then
      .error .missingRequiredClaim
    else
      pure ()

  -- Check not before (RFC 7519 §4.1.5)
  match jwt.claims.nbf with
  | some nbf =>
    if now.addSeconds config.clockSkew < nbf then
      .error .notYetValid
    else
      pure ()
  | none => pure ()

  -- Check issuer
  match config.requiredIssuer, jwt.claims.iss with
  | some required, some actual =>
    if required ≠ actual then
      .error .invalidIssuer
    else
      pure ()
  | some _, none =>
    .error .missingRequiredClaim
  | _, _ => pure ()

  -- Check audience
  match config.requiredAudience, jwt.claims.aud with
  | some required, some audienceList =>
    if ¬audienceList.contains required then
      .error .invalidAudience
    else
      pure ()
  | some _, none =>
    .error .missingRequiredClaim
  | _, _ => pure ()

  -- Check subject
  match config.requiredSubject, jwt.claims.sub with
  | some required, some actual =>
    if required ≠ actual then
      .error .invalidSubject
    else
      pure ()
  | some _, none =>
    .error .missingRequiredClaim
  | _, _ => pure ()

  -- Check issued at (if required)
  if config.requireIat ∧ jwt.claims.iat.isNone then
    .error .missingRequiredClaim

  -- Check JWT ID (if required)
  if config.requireJti ∧ jwt.claims.jti.isNone then
    .error .missingRequiredClaim

  .ok ()

/-- Complete JWT validation (signature + claims), given the current time. -/
noncomputable def validate (jwt : Jwt) (key : Jwk) (config : ValidationConfig)
    (now : SWELib.Basics.NumericDate) :
    Except ValidationError Unit :=
  match verifySignature jwt key with
  | .error sigErr => .error (.signature sigErr)
  | .ok () =>
    match validateClaims jwt config now with
    | .error claimsErr => .error (.claims claimsErr)
    | .ok () => .ok ()

/-- Check if JWT is expired (considering clock skew), given the current time. -/
noncomputable def isExpired (jwt : Jwt) (now : SWELib.Basics.NumericDate) (clockSkew : Nat := 60) : Bool :=
  match jwt.claims.exp with
  | some exp => exp.addSeconds clockSkew < now
  | none => false

/-- Check if JWT is not yet valid (considering clock skew), given the current time. -/
noncomputable def isNotYetValid (jwt : Jwt) (now : SWELib.Basics.NumericDate) (clockSkew : Nat := 60) : Bool :=
  match jwt.claims.nbf with
  | some nbf => now.addSeconds clockSkew < nbf
  | none => false

/-- Check if JWT has valid time window (exp > now > nbf with skew). -/
noncomputable def hasValidTimeWindow (jwt : Jwt) (now : SWELib.Basics.NumericDate) (clockSkew : Nat := 60) : Bool :=
  ¬isExpired jwt now clockSkew ∧ ¬isNotYetValid jwt now clockSkew

/-- Get remaining validity time in seconds (negative if expired). -/
noncomputable def remainingValidity (jwt : Jwt) (now : SWELib.Basics.NumericDate) : Int :=
  match jwt.claims.exp with
  | some exp =>
    (SWELib.Basics.NumericDate.toSeconds exp : Int) -
      (SWELib.Basics.NumericDate.toSeconds now : Int)
  | none => Int.ofNat (2^63 - 1)  -- Max positive value if no expiration

/-- Theorem: If validation succeeds, JWT is not expired. -/
axiom validate_not_expired (jwt : Jwt) (key : Jwk) (config : ValidationConfig)
    (now : SWELib.Basics.NumericDate)
    (h : validate jwt key config now = .ok ()) :
    ¬isExpired jwt now config.clockSkew

/-- Theorem: If validation succeeds, JWT is not "not yet valid". -/
axiom validate_not_not_yet_valid (jwt : Jwt) (key : Jwk) (config : ValidationConfig)
    (now : SWELib.Basics.NumericDate)
    (h : validate jwt key config now = .ok ()) :
    ¬isNotYetValid jwt now config.clockSkew

/-- Theorem: Validation with default config requires expiration claim. -/
axiom validate_default_requires_exp (jwt : Jwt) (key : Jwk)
    (now : SWELib.Basics.NumericDate)
    (h : validate jwt key ValidationConfig.default now = .ok ()) :
    jwt.claims.exp.isSome

/-- Create a validation configuration builder. -/
def ValidationConfigBuilder : Type :=
  ValidationConfig → ValidationConfig

/-- Set required issuer. -/
def withIssuer (issuer : String) : ValidationConfigBuilder :=
  λ config => { config with requiredIssuer := some issuer }

/-- Set required audience. -/
def withAudience (audience : String) : ValidationConfigBuilder :=
  λ config => { config with requiredAudience := some audience }

/-- Set required subject. -/
def withSubject (subject : String) : ValidationConfigBuilder :=
  λ config => { config with requiredSubject := some subject }

/-- Set clock skew. -/
def withClockSkew (seconds : Nat) : ValidationConfigBuilder :=
  λ config => { config with clockSkew := seconds }

/-- Build final configuration from builder chain. -/
def buildConfig (builders : List ValidationConfigBuilder) : ValidationConfig :=
  builders.foldl (λ config builder => builder config) ValidationConfig.default

end SWELib.Security.Jwt
