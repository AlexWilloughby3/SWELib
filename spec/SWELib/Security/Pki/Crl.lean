import SWELib.Security.Pki.Types
import SWELib.Security.Pki.Extensions

namespace SWELib.Security.Pki

/-- Reason a certificate was revoked (RFC 5280 §5.3.1). -/
inductive RevocationReason where
  | unspecified
  | keyCompromise
  | cACompromise
  | affiliationChanged
  | superseded
  | cessationOfOperation
  | certificateHold
  | removeFromCRL
  | privilegeWithdrawn
  | aACompromise
  deriving DecidableEq, Repr

/-- Entry in a CRL's revokedCertificates list (RFC 5280 §5.1.2.6). -/
structure RevokedCertEntry where
  serialNumber   : Nat
  revocationDate : SWELib.Basics.NumericDate
  reasonCode     : Option RevocationReason
  deriving DecidableEq

/-- The to-be-signed portion of a Certificate Revocation List (RFC 5280 §5.1.2). -/
structure TBSCertList where
  issuer              : DistinguishedName
  thisUpdate          : SWELib.Basics.NumericDate
  nextUpdate          : Option SWELib.Basics.NumericDate
  revokedCertificates : List RevokedCertEntry
  extensions          : List Extension

/-- A complete CRL (RFC 5280 §5.1). -/
structure CertificateList where
  tbsCertList        : TBSCertList
  signatureAlgorithm : AlgorithmIdentifier
  signatureValue     : ByteArray

-- OCSP types (RFC 6960)

/-- Identifies a certificate for OCSP lookup (RFC 6960 §4.1.1). -/
structure CertID where
  hashAlgorithm  : AlgorithmIdentifier
  issuerNameHash : ByteArray
  issuerKeyHash  : ByteArray
  serialNumber   : Nat

/-- OCSP certificate status (RFC 6960 §4.2.1). -/
inductive CertStatus where
  | good
  | revoked (revocationTime : SWELib.Basics.NumericDate) (reason : Option RevocationReason)
  | unknown

/-- Identifies an OCSP responder (RFC 6960 §4.2.1). -/
inductive ResponderID where
  | byName (dn      : DistinguishedName)
  | byKey  (keyHash : ByteArray)

/-- Single certificate status response within an OCSP reply (RFC 6960 §4.2.1). -/
structure SingleResponse where
  certID     : CertID
  certStatus : CertStatus
  thisUpdate : SWELib.Basics.NumericDate
  nextUpdate : Option SWELib.Basics.NumericDate

/-- The to-be-signed portion of a BasicOCSPResponse (RFC 6960 §4.2.1). -/
structure ResponseData where
  responderID : ResponderID
  producedAt  : SWELib.Basics.NumericDate
  responses   : List SingleResponse

/-- Top-level OCSP response status code (RFC 6960 §4.2.1). -/
inductive OcspResponseStatus where
  | successful
  | malformedRequest
  | internalError
  | tryLater
  | sigRequired
  | unauthorized
  deriving DecidableEq, Repr

/-- The basic OCSP response structure (RFC 6960 §4.2.1). -/
structure BasicOcspResponse where
  tbsResponseData    : ResponseData
  signatureAlgorithm : AlgorithmIdentifier
  signature          : ByteArray
  certs              : Option (List Certificate)

/-- Top-level OCSP response envelope (RFC 6960 §4.2.1). -/
structure OcspResponse where
  responseStatus : OcspResponseStatus
  responseBytes  : Option BasicOcspResponse

end SWELib.Security.Pki
