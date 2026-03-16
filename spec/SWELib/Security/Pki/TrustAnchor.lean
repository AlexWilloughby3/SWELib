import SWELib.Security.Pki.Types
import SWELib.Security.Pki.Extensions

namespace SWELib.Security.Pki

/-- Flags controlling policy enforcement at the trust anchor (RFC 5914 §2). -/
structure CertPolicyFlags where
  inhibitPolicyMapping  : Bool
  requireExplicitPolicy : Bool
  inhibitAnyPolicy      : Bool
  deriving DecidableEq, Repr

/-- Controls applied to path validation when this trust anchor is used (RFC 5914 §3.1). -/
structure CertPathControls where
  taName            : DistinguishedName
  policySet         : Option (List PolicyInformation)
  policyFlags       : Option CertPolicyFlags
  nameConstr        : Option NameConstraints
  pathLenConstraint : Option Nat

/-- Trust anchor information record (RFC 5914 §3.1). -/
structure TrustAnchorInfo where
  pubKey   : SubjectPublicKeyInfo
  keyId    : ByteArray
  taTitle  : Option String
  certPath : Option CertPathControls
  exts     : List Extension

/-- The three forms in which a trust anchor may be expressed (RFC 5914 §2). -/
inductive TrustAnchorChoice where
  | certificate (cert : Certificate)
  | tbsCert     (tbs  : TBSCertificate)
  | taInfo      (info : TrustAnchorInfo)

/-- A trust anchor used as the root of a certification path (RFC 5914 §2). -/
structure TrustAnchor where
  choice : TrustAnchorChoice

/-- OIDs that MUST NOT appear in TrustAnchorInfo.exts (RFC 5914 §3.2).
    These are expressed via the certPath fields instead. -/
def forbiddenTrustAnchorExtOids : List OID :=
  [ oid_nameConstraints
  , oid_policyConstraints
  , oid_inhibitAnyPolicy
  , oid_certificatePolicies ]

/-- Validate a TrustAnchorInfo record (RFC 5914 §3.2).
    Returns false if requireExplicitPolicy is set without a policySet, or if any
    forbidden extension appears as a critical extension in exts. -/
def trustAnchorInfoValid (tai : TrustAnchorInfo) : Bool :=
  let policyFlagOk :=
    match tai.certPath with
    | none    => true
    | some cp =>
      match cp.policyFlags with
      | none    => true
      | some pf => !pf.requireExplicitPolicy || cp.policySet.isSome
  let noForbiddenCritical :=
    tai.exts.all (fun e => !e.critical || !forbiddenTrustAnchorExtOids.contains e.oid)
  policyFlagOk && noForbiddenCritical

end SWELib.Security.Pki
