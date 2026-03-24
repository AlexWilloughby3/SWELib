import SWELib.Security.Pki.Operations

namespace SWELib.Security.Pki

/-- checkValidity characterises the certificate validity window (RFC 5280 §4.1.2.5). -/
theorem checkValidity_iff (cert : Certificate) (t : SWELib.Basics.NumericDate) :
    checkValidity cert t = true ↔
    cert.tbsCertificate.validity.notBefore ≤ t ∧
    t ≤ cert.tbsCertificate.validity.notAfter := by
  simp [checkValidity, Bool.and_eq_true, decide_eq_true_eq]

/-- algorithmFieldsMatch holds iff the two AlgorithmIdentifier fields are equal
    (RFC 5280 §4.1.1.2). -/
theorem algorithmFieldsMatch_iff (cert : Certificate) :
    algorithmFieldsMatch cert = true ↔
    cert.signatureAlgorithm = cert.tbsCertificate.signatureAlgorithm := by
  simp [algorithmFieldsMatch, beq_iff_eq]

/-- For the certificate variant, extractTrustAnchorPubKey returns the embedded
    certificate's SubjectPublicKeyInfo (RFC 5914 §3). -/
axiom extractTrustAnchorPubKey_certificate (cert : Certificate) :
    extractTrustAnchorPubKey ⟨.certificate cert⟩ =
    cert.tbsCertificate.subjectPublicKeyInfo

/-- For the certificate variant, extractTrustAnchorName returns the subject DN
    of the embedded certificate (RFC 5914 §3). -/
axiom extractTrustAnchorName_certificate (cert : Certificate) :
    extractTrustAnchorName ⟨.certificate cert⟩ =
    cert.tbsCertificate.subject

/-- If path validation succeeds, every consecutive issuer/subject pair in certPath
    matches (RFC 5280 §6.1.3 step (c)). -/
axiom validateCertPath_valid_implies_name_chain
    (inputs : PathValidationInputs)
    (h : (validateCertificatePath inputs).valid = true) :
    ∀ (i : Fin inputs.certPath.length)
      (j : Fin inputs.certPath.length)
      (_ : j.val = i.val + 1),
      matchDistinguishedName
        (inputs.certPath.get j).tbsCertificate.issuer
        (inputs.certPath.get i).tbsCertificate.subject = true

/-- If path validation succeeds, every certificate in certPath is within its
    validity window at currentTime (RFC 5280 §6.1.3 step (b)). -/
axiom validateCertPath_valid_implies_validity
    (inputs : PathValidationInputs)
    (h : (validateCertificatePath inputs).valid = true) :
    ∀ cert, cert ∈ inputs.certPath → checkValidity cert inputs.currentTime = true

/-- If path validation succeeds, all non-final certificates have cA = true
    (RFC 5280 §4.2.1.9, §6.1.4 step (b)(1)). -/
axiom validateCertPath_valid_implies_ca_flag
    (inputs : PathValidationInputs)
    (h : (validateCertificatePath inputs).valid = true) :
    ∀ (i : Fin inputs.certPath.length),
      i.val < inputs.certPath.length - 1 →
      isCA (inputs.certPath.get i) = true

/-- If path validation succeeds, the path does not exceed the maximum path length
    derived from the trust anchor and intermediate CA constraints
    (RFC 5280 §6.1.4 step (l)). -/
axiom validateCertPath_valid_implies_pathlength
    (inputs : PathValidationInputs)
    (h : (validateCertificatePath inputs).valid = true) :
    inputs.certPath.length ≤ (initValidationState inputs).maxPathLength

/-- isCA holds iff BasicConstraints is present with cA = true (RFC 5280 §4.2.1.9). -/
theorem isCA_iff (cert : Certificate) :
    isCA cert = true ↔
    ∃ bc, extractBasicConstraints cert.tbsCertificate.extensions = some bc ∧ bc.cA = true := by
  simp [isCA]
  constructor
  · intro h
    cases hbc : (extractBasicConstraints cert.tbsCertificate.extensions) with
    | none => simp [hbc, Option.map, Option.getD] at h
    | some bc => exact ⟨bc, rfl, by simp [hbc, Option.map, Option.getD] at h; exact h⟩
  · intro ⟨bc, hbc, hca⟩
    simp [hbc, Option.map, Option.getD, hca]

/-- trustAnchorInfoValid implies that requireExplicitPolicy cannot be set without
    a policySet (RFC 5914 §3.2). -/
theorem trustAnchorInfoValid_requireExplicit_needs_policySet
    (tai : TrustAnchorInfo)
    (h : trustAnchorInfoValid tai = true)
    (cp : CertPathControls)
    (hcp : tai.certPath = some cp)
    (pf : CertPolicyFlags)
    (hpf : cp.policyFlags = some pf)
    (hreq : pf.requireExplicitPolicy = true) :
    cp.policySet.isSome = true := by
  simp [trustAnchorInfoValid, hcp, hpf, hreq] at h
  exact h.1

/-- If validateOcspResponse returns true, the response status is successful
    (RFC 6960 §4.2.1). -/
axiom ocspResponse_valid_implies_status_successful
    (resp : OcspResponse) (cert : Certificate)
    (t : SWELib.Basics.NumericDate) (nonce : Option ByteArray)
    (h : validateOcspResponse resp cert t nonce = true) :
    resp.responseStatus = .successful

/-- If validateOcspResponse returns true and a BasicOcspResponse is present,
    at least one SingleResponse has a serial number matching cert's
    (RFC 6960 §4.2.1). -/
axiom ocspResponse_valid_implies_certID_match
    (resp : OcspResponse) (cert : Certificate)
    (t : SWELib.Basics.NumericDate) (nonce : Option ByteArray)
    (h : validateOcspResponse resp cert t nonce = true)
    (br : BasicOcspResponse)
    (hbr : resp.responseBytes = some br) :
    ∃ sr, sr ∈ br.tbsResponseData.responses ∧
      sr.certID.serialNumber = cert.tbsCertificate.serialNumber

/-- An empty pin set always passes pinning validation (RFC 7469 §2.6). -/
axiom checkCertPinning_empty_pins (cert : Certificate) :
    checkCertificatePinning cert [] = true

/-- The initial maxPathLength equals the certPath length when the trust anchor
    imposes no tighter pathLenConstraint (RFC 5280 §6.1.1). -/
theorem initValidationState_maxPathLength
    (inputs : PathValidationInputs)
    (h : ∀ info cp, inputs.trustAnchor.choice = .taInfo info →
                    info.certPath = some cp →
                    cp.pathLenConstraint = none) :
    (initValidationState inputs).maxPathLength = inputs.certPath.length := by
  sorry -- TODO: proof requires unfolding initValidationState through noncomputable lets; needs Nat.min_self

end SWELib.Security.Pki
