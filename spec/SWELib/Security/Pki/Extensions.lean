import SWELib.Security.Pki.Types

namespace SWELib.Security.Pki

-- OID constants (RFC 5280)

def oid_basicConstraints       : OID := "2.5.29.19"
def oid_keyUsage               : OID := "2.5.29.15"
def oid_extKeyUsage            : OID := "2.5.29.37"
def oid_nameConstraints        : OID := "2.5.29.30"
def oid_certificatePolicies    : OID := "2.5.29.32"
def oid_anyPolicy              : OID := "2.5.29.32.0"
def oid_subjectKeyIdentifier   : OID := "2.5.29.14"
def oid_authorityKeyIdentifier : OID := "2.5.29.35"
def oid_inhibitAnyPolicy       : OID := "2.5.29.54"
def oid_policyConstraints      : OID := "2.5.29.36"
def oid_policyMappings         : OID := "2.5.29.33"
def oid_ekuServerAuth          : OID := "1.3.6.1.5.5.7.3.1"
def oid_ekuClientAuth          : OID := "1.3.6.1.5.5.7.3.2"
def oid_ekuOcspSigning         : OID := "1.3.6.1.5.5.7.3.9"

/-- BasicConstraints extension (RFC 5280 §4.2.1.9).
    MUST be critical in CA certificates. -/
structure BasicConstraints where
  cA                : Bool
  pathLenConstraint : Option Nat
  deriving DecidableEq, Repr

/-- KeyUsage extension bit string (RFC 5280 §4.2.1.3).
    SHOULD be critical when present. -/
structure KeyUsageBits where
  digitalSignature  : Bool
  contentCommitment : Bool   -- formerly nonRepudiation
  keyEncipherment   : Bool
  dataEncipherment  : Bool
  keyAgreement      : Bool
  keyCertSign       : Bool
  cRLSign           : Bool
  encipherOnly      : Bool
  decipherOnly      : Bool
  deriving DecidableEq, Repr

/-- ExtendedKeyUsage extension (RFC 5280 §4.2.1.12). -/
structure ExtendedKeyUsage where
  purposes : List OID
  deriving DecidableEq, Repr

/-- A GeneralSubtree used in NameConstraints (RFC 5280 §4.2.1.10).
    minimum defaults to 0; maximum absent means unlimited. -/
structure GeneralSubtree where
  base    : GeneralName
  minimum : Nat
  maximum : Option Nat

/-- NameConstraints extension (RFC 5280 §4.2.1.10). MUST be critical.
    At least one of the two fields MUST be present. -/
structure NameConstraints where
  permittedSubtrees : Option (List GeneralSubtree)
  excludedSubtrees  : Option (List GeneralSubtree)

/-- Policy information for a single certificate policy (RFC 5280 §4.2.1.4). -/
structure PolicyInformation where
  policyIdentifier : OID
  policyQualifiers : Option (List ByteArray)

/-- CertificatePolicies extension (RFC 5280 §4.2.1.4).
    Each policyIdentifier MUST appear at most once. -/
structure CertificatePolicies where
  policies : List PolicyInformation

/-- AuthorityKeyIdentifier extension (RFC 5280 §4.2.1.1). MUST be non-critical. -/
structure AuthorityKeyIdentifier where
  keyIdentifier             : Option ByteArray
  authorityCertIssuer       : Option (List GeneralName)
  authorityCertSerialNumber : Option Nat

end SWELib.Security.Pki
