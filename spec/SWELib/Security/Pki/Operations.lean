import SWELib.Security.Pki.Types
import SWELib.Security.Pki.Extensions
import SWELib.Security.Pki.TrustAnchor
import SWELib.Security.Pki.Crl
import SWELib.Security.Hashing

namespace SWELib.Security.Pki

open SWELib.Security (HashAlgorithm)

/-- Errors that can arise during RFC 5280 §6.1 path validation. -/
inductive PathValidationError where
  | signatureVerificationFailed
  | certificateExpired
  | certificateNotYetValid
  | issuerSubjectMismatch
  | certificateRevoked         (reason : RevocationReason)
  | unrecognizedCriticalExtension (oid : OID)
  | missingKeyCertSign
  | notACertificateAuthority
  | pathLengthExceeded
  | nameConstraintViolation    (name : GeneralName)
  | emptyValidPolicyTree
  | algorithmMismatch
  | trustAnchorNotFound
  | pathTooShort
  | ocspResponseStatusError    (status : OcspResponseStatus)
  | ocspSignatureInvalid
  | ocspSignerUnauthorized
  | ocspResponseStale
  | ocspNonceMismatch
  | ocspCertIDMismatch
  | crlSignatureInvalid
  | crlExpired
  | pinnedKeyMismatch
  | trustAnchorInfoForbiddenExtension (oid : OID)

/-- Result of RFC 5280 §6.1 path validation (§6.1.6). -/
structure PathValidationResult where
  valid            : Bool
  workingPublicKey : Option SubjectPublicKeyInfo
  validPolicies    : Option (List OID)
  error            : Option PathValidationError

/-- A node in the valid policy tree (RFC 5280 §6.1.2).
    Deferred: policy tree walk is not implemented in this pass. -/
structure ValidPolicyNode where
  validPolicy       : OID
  qualifiers        : List ByteArray
  expectedPolicySet : List OID

/-- A certificate or SPKI pin entry (RFC 7469 §2.4). -/
structure PinnedKey where
  certHash : Option (HashAlgorithm × ByteArray)
  spkiHash : Option (HashAlgorithm × ByteArray)

/-- Inputs to the RFC 5280 §6.1 path validation algorithm (§6.1.1). -/
structure PathValidationInputs where
  certPath                     : List Certificate
  trustAnchor                  : TrustAnchor
  initialPolicySet             : List OID
  initialPermittedSubtrees     : Option (List GeneralSubtree)
  initialExcludedSubtrees      : Option (List GeneralSubtree)
  initialRequireExplicitPolicy : Bool
  initialInhibitPolicyMapping  : Bool
  initialInhibitAnyPolicy      : Bool
  currentTime                  : SWELib.Basics.NumericDate

/-- Working state for the RFC 5280 §6.1 path validation algorithm (§6.1.2). -/
structure PathValidationState where
  workingPublicKey  : SubjectPublicKeyInfo
  workingIssuerName : DistinguishedName
  validPolicyTree   : Option (List ValidPolicyNode)
  permittedSubtrees : Option (List GeneralSubtree)
  excludedSubtrees  : Option (List GeneralSubtree)
  explicitPolicy    : Nat
  inhibitAnyPolicy  : Nat
  policyMapping     : Nat
  maxPathLength     : Nat

-- Bridge parse axioms

/-- DER-parse the value bytes of a BasicConstraints extension (RFC 5280 §4.2.1.9). -/
axiom parseBasicConstraints : ByteArray → Option BasicConstraints

/-- DER-parse the value bytes of a KeyUsage extension (RFC 5280 §4.2.1.3). -/
axiom parseKeyUsageBits : ByteArray → Option KeyUsageBits

-- Extraction helpers

/-- Extract and parse the BasicConstraints extension from a list of extensions (RFC 5280 §4.2.1.9). -/
noncomputable def extractBasicConstraints (exts : List Extension) : Option BasicConstraints :=
  (exts.find? (fun e => e.oid == oid_basicConstraints)).bind (fun e => parseBasicConstraints e.value)

/-- Extract and parse the KeyUsage extension from a list of extensions (RFC 5280 §4.2.1.3). -/
noncomputable def extractKeyUsage (exts : List Extension) : Option KeyUsageBits :=
  (exts.find? (fun e => e.oid == oid_keyUsage)).bind (fun e => parseKeyUsageBits e.value)

-- Computable pure operations

/-- True iff both AlgorithmIdentifier fields in the certificate are equal (RFC 5280 §4.1.1.2).
    They MUST be identical. -/
def algorithmFieldsMatch (cert : Certificate) : Bool :=
  cert.signatureAlgorithm == cert.tbsCertificate.signatureAlgorithm

/-- True iff currentTime is within the certificate's validity interval (RFC 5280 §4.1.2.5,
    §6.1.3 step (b)). -/
def checkValidity (cert : Certificate) (t : SWELib.Basics.NumericDate) : Bool :=
  decide (cert.tbsCertificate.validity.notBefore ≤ t) &&
  decide (t ≤ cert.tbsCertificate.validity.notAfter)

/-- True iff the certificate has BasicConstraints with cA = true (RFC 5280 §4.2.1.9).
    Noncomputable because it calls the bridge DER parser. -/
noncomputable def isCA (cert : Certificate) : Bool :=
  (extractBasicConstraints cert.tbsCertificate.extensions).map (·.cA) |>.getD false

-- Bridge axioms for cryptographic and complex operations

/-- Verify that cert.signatureValue is a valid signature over DER(cert.tbsCertificate)
    under the given public key (RFC 5280 §6.1.3 step (a)(1)). -/
axiom verifyCertificateSignature : Certificate → SubjectPublicKeyInfo → Bool

/-- Name matching per RFC 5280 §7.1 (case-insensitive, whitespace-normalised,
    PrintableString/UTF8String equivalence). Axiomatized: the full §7.1 rules are
    not computable in the spec layer. -/
axiom matchDistinguishedName : DistinguishedName → DistinguishedName → Bool

/-- True iff cert's subject and issuer are identical under matchDistinguishedName
    (RFC 5280 §3.3 -- self-issued certificate definition). -/
noncomputable def isSelfIssued (cert : Certificate) : Bool :=
  matchDistinguishedName cert.tbsCertificate.subject cert.tbsCertificate.issuer

/-- Full RFC 5280 §6.1 path validation algorithm.
    Returns valid = true iff the complete algorithm succeeds for all certificates
    in inputs.certPath anchored at inputs.trustAnchor. -/
axiom validateCertificatePath : PathValidationInputs → PathValidationResult

/-- Check revocation status of cert using issuerCert and a CRL at time t
    (RFC 5280 §6.3). -/
axiom checkRevocationCRL :
  Certificate → Certificate → CertificateList → SWELib.Basics.NumericDate → CertStatus

/-- Validate an OCSP response for cert at time t with optional request nonce
    (RFC 6960 §4.2.1). -/
axiom validateOcspResponse :
  OcspResponse → Certificate → SWELib.Basics.NumericDate → Option ByteArray → Bool

/-- True iff signerCert is authorised to sign OCSP responses for certs issued by
    issuerCert (RFC 6960 §4.2.2.2). -/
axiom ocspSignerAuthorized : Certificate → Certificate → Bool

/-- Extract the public key from a TrustAnchor regardless of choice variant
    (RFC 5914 §3). -/
axiom extractTrustAnchorPubKey : TrustAnchor → SubjectPublicKeyInfo

/-- Extract the subject/taName from a TrustAnchor regardless of choice variant
    (RFC 5914 §3). -/
axiom extractTrustAnchorName : TrustAnchor → DistinguishedName

/-- True iff cert matches at least one pin in pins, or pins is empty (RFC 7469 §2.6). -/
axiom checkCertificatePinning : Certificate → List PinnedKey → Bool

/-- Hash of the DER-encoded SubjectPublicKeyInfo (RFC 7469 §2.4).
    Used for SPKI pin generation and comparison. -/
axiom hashSubjectPublicKeyInfo : SubjectPublicKeyInfo → HashAlgorithm → ByteArray

/-- Initialise the RFC 5280 §6.1.2 working state from the validation inputs.
    Sets counters, working public key, and issuer name from the trust anchor. -/
noncomputable def initValidationState (inputs : PathValidationInputs) : PathValidationState :=
  let n := inputs.certPath.length
  let taPubKey := extractTrustAnchorPubKey inputs.trustAnchor
  let taName   := extractTrustAnchorName   inputs.trustAnchor
  let taPathLen : Nat :=
    match inputs.trustAnchor.choice with
    | .taInfo info =>
      match info.certPath with
      | some cp => cp.pathLenConstraint.getD n
      | none    => n
    | _ => n
  { workingPublicKey  := taPubKey
  , workingIssuerName := taName
  , validPolicyTree   := some []   -- initialised to single anyPolicy root; deferred
  , permittedSubtrees := inputs.initialPermittedSubtrees
  , excludedSubtrees  := inputs.initialExcludedSubtrees
  , explicitPolicy    := if inputs.initialRequireExplicitPolicy then 0 else n + 1
  , inhibitAnyPolicy  := if inputs.initialInhibitAnyPolicy      then 0 else n + 1
  , policyMapping     := if inputs.initialInhibitPolicyMapping   then 0 else n + 1
  , maxPathLength     := min n taPathLen
  }

end SWELib.Security.Pki
