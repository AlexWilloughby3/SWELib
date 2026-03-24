import SWELib.Basics.Time

namespace SWELib.Security.Pki

-- ByteArray instances needed for deriving in Lean 4.0.0
instance : BEq ByteArray where
  beq a b := a.data == b.data

instance : DecidableEq ByteArray := fun a b =>
  if h : a.data = b.data then
    isTrue (by cases a; cases b; simp at h; exact congrArg ByteArray.mk h)
  else
    isFalse (by intro heq; apply h; cases heq; rfl)

/-- Object Identifier, represented as a dotted-decimal string (RFC 5280 §4.1.1.2). -/
abbrev OID := String

/-- Algorithm identifier: OID plus optional DER-encoded parameters (RFC 5280 §4.1.1.2). -/
structure AlgorithmIdentifier where
  algorithm  : OID
  parameters : Option ByteArray
  deriving DecidableEq

/-- Certificate validity interval (RFC 5280 §4.1.2.5).
    Both bounds are seconds since the Unix epoch (UTCTime through 2049,
    GeneralizedTime for 2050+). -/
structure Validity where
  notBefore : SWELib.Basics.NumericDate
  notAfter  : SWELib.Basics.NumericDate
  deriving DecidableEq

/-- Distinguished Name as an RDN sequence (RFC 5280 §4.1.2.4).
    Outer list: sequence of RDNs. Inner list: multi-valued RDN (typically singleton).
    Each pair is (attribute type OID, attribute value string). -/
structure DistinguishedName where
  rdnSequence : List (List (String × String))
  deriving DecidableEq, Inhabited

/-- GeneralName CHOICE (RFC 5280 §4.2.1.6).
    Only the most common variants are represented; raw bytes cover the rest. -/
inductive GeneralName where
  | rfc822Name    (email : String)
  | dnsName       (host  : String)
  | directoryName (dn    : DistinguishedName)
  | uri           (u     : String)
  | ipAddress     (addr  : ByteArray)
  | registeredID  (oid   : OID)
  | otherName     (raw   : ByteArray)

/-- Subject public key info: algorithm plus raw key bits (RFC 5280 §4.1.2.7). -/
structure SubjectPublicKeyInfo where
  algorithm        : AlgorithmIdentifier
  subjectPublicKey : ByteArray

/-- A single X.509v3 extension (RFC 5280 §4.1.2.9).
    The value is DER-encoded; parsing is performed by the bridge layer. -/
structure Extension where
  oid      : OID
  critical : Bool
  value    : ByteArray

/-- Certificate version (RFC 5280 §4.1.2.1). -/
inductive CertVersion where
  | v1 | v2 | v3
  deriving DecidableEq, Repr

/-- The to-be-signed portion of an X.509 certificate (RFC 5280 §4.1.2). -/
structure TBSCertificate where
  version              : CertVersion
  serialNumber         : Nat
  signatureAlgorithm   : AlgorithmIdentifier
  issuer               : DistinguishedName
  validity             : Validity
  subject              : DistinguishedName
  subjectPublicKeyInfo : SubjectPublicKeyInfo
  issuerUniqueID       : Option ByteArray
  subjectUniqueID      : Option ByteArray
  extensions           : List Extension

/-- A complete X.509 certificate (RFC 5280 §4.1). -/
structure Certificate where
  tbsCertificate     : TBSCertificate
  signatureAlgorithm : AlgorithmIdentifier
  signatureValue     : ByteArray

end SWELib.Security.Pki
