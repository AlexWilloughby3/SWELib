import SWELib.Networking.Dns.Message

/-!
# DNS Invariants

Validity predicates and correctness theorems for DNS messages and records.

References:
- RFC 1035: https://www.rfc-editor.org/rfc/rfc1035
- RFC 2181: https://www.rfc-editor.org/rfc/rfc2181
-/

namespace SWELib.Networking.Dns

/-! ## Label validity -/

/-- A valid label has 1-63 bytes (RFC 1035 section 2.3.4). -/
theorem label_valid_iff (l : Label) :
    l.isValid = true ↔ 1 ≤ l.bytes.size ∧ l.bytes.size ≤ 63 := by
  simp [Label.isValid, Bool.and_eq_true, decide_eq_true_eq]

/-- A label with 0 bytes is invalid. -/
theorem label_empty_invalid (l : Label) (h : l.bytes.size = 0) :
    l.isValid = false := by
  simp [Label.isValid, h]

/-- A label with 64 bytes is invalid. -/
theorem label_64_invalid (l : Label) (h : l.bytes.size = 64) :
    l.isValid = false := by
  simp [Label.isValid, h]

/-! ## DomainName wire length -/

/-- The root domain name has wire length 1 (just the zero-length root octet). -/
theorem wireLength_root : DomainName.root.wireLength = 1 := by rfl

/-- Wire length is always at least 1 (the root zero octet). -/
theorem wireLength_pos (d : DomainName) : 0 < d.wireLength := by
  simp [DomainName.wireLength]

private theorem foldl_wireLength_shift (ls : List Label) (n : Nat) :
    ls.foldl (fun acc l => acc + l.bytes.size + 1) n =
    ls.foldl (fun acc l => acc + l.bytes.size + 1) 0 + n := by
  induction ls generalizing n with
  | nil => simp
  | cons hd tl ih =>
    simp only [List.foldl_cons]
    rw [ih (n + hd.bytes.size + 1), ih (0 + hd.bytes.size + 1)]
    omega

/-- Prepending a label increases the wire length by label size + 1 length octet. -/
theorem wireLength_cons (l : Label) (d : DomainName) :
    ({ labels := l :: d.labels } : DomainName).wireLength = d.wireLength + l.bytes.size + 1 := by
  simp only [DomainName.wireLength, List.foldl_cons]
  rw [foldl_wireLength_shift d.labels (0 + l.bytes.size + 1)]
  omega

/-! ## DomainName text length -/

/-- The root domain name has text length 0. -/
theorem textLength_root : DomainName.root.textLength = 0 := by rfl

/-! ## DomainName validity -/

/-- The root domain name is valid. -/
theorem root_isValid : DomainName.root.isValid = true := by decide

/-- A valid domain name has wire length at most 255. -/
theorem valid_wireLength_le_255 (d : DomainName) (h : d.isValid = true) :
    d.wireLength ≤ 255 := by
  simp [DomainName.isValid, Bool.and_eq_true, decide_eq_true_eq] at h
  exact h.2

/-! ## RData type tags -/

/-- RData.rrtype agrees with constructor for each record type. -/
theorem rdataRrtype_a (addr : UInt32) : (RData.a addr).rrtype = .a := by rfl
theorem rdataRrtype_ns (n : DomainName) : (RData.ns n).rrtype = .ns := by rfl
theorem rdataRrtype_cname (n : DomainName) : (RData.cname n).rrtype = .cname := by rfl
theorem rdataRrtype_soa (m r : DomainName) (s rf rt e mn : UInt32) :
    (RData.soa m r s rf rt e mn).rrtype = .soa := by rfl
theorem rdataRrtype_ptr (n : DomainName) : (RData.ptr n).rrtype = .ptr := by rfl
theorem rdataRrtype_mx (p : UInt16) (e : DomainName) : (RData.mx p e).rrtype = .mx := by rfl
theorem rdataRrtype_txt (ss : List ByteArray) : (RData.txt ss).rrtype = .txt := by rfl
theorem rdataRrtype_aaaa (addr : ByteArray) : (RData.aaaa addr).rrtype = .aaaa := by rfl

/-! ## ResourceRecord validity -/

/-- rdata type must match the declared rrtype field. -/
def rdataMatchesType (rr : ResourceRecord) : Bool :=
  rr.rdata.rrtype == rr.rrtype

/-- Validity of rdata contents:
    - AAAA must be exactly 16 bytes (RFC 3596 section 2).
    - TXT must have at least one string, each at most 255 bytes (RFC 1035 section 3.3.14). -/
def isValidRdata : RData -> Bool
  | .aaaa addr => addr.size == 16
  | .txt strs  => !strs.isEmpty && strs.all (fun s => decide (s.size ≤ 255))
  | _          => true

/-- A resource record is valid when its rdata type matches and content is valid. -/
def isValidRR (rr : ResourceRecord) : Bool :=
  rdataMatchesType rr && isValidRdata rr.rdata

/-- AAAA rdata has exactly 16 bytes when valid. -/
theorem aaaa_valid_size (addr : ByteArray)
    (h : isValidRdata (.aaaa addr) = true) : addr.size = 16 := by
  simp [isValidRdata, beq_iff_eq] at h
  exact h

/-- TXT rdata is non-empty when valid. -/
theorem txt_valid_nonempty (strs : List ByteArray)
    (h : isValidRdata (.txt strs) = true) : strs ≠ [] := by
  intro hnil
  subst hnil
  simp [isValidRdata] at h

/-- TXT strings each have at most 255 bytes when valid. -/
theorem txt_valid_sizes (strs : List ByteArray)
    (h : isValidRdata (.txt strs) = true) :
    ∀ s ∈ strs, s.size ≤ 255 := by
  simp [isValidRdata, Bool.and_eq_true, List.all_eq_true, decide_eq_true_eq] at h
  exact h.2

/-! ## RRset validity -/

/-- An RRset is valid when non-empty, all rdatas match the declared type, and contents are valid. -/
def isValidRRset (rs : RRset) : Bool :=
  !rs.rdatas.isEmpty &&
  rs.rdatas.all (fun r => r.rrtype == rs.rrtype) &&
  rs.rdatas.all isValidRdata

/-! ## Message-level predicates -/

/-- The reserved Z bit must be zero in all messages (RFC 1035 section 4.1.1). -/
def isWellFormedFlags (f : DnsFlags) : Bool := !f.z

/-- A DNS query has QR = 0. -/
def isValidQuery (msg : DnsMessage) : Bool :=
  !msg.header.flags.qr && isWellFormedFlags msg.header.flags

/-- A DNS response has QR = 1. -/
def isValidResponse (msg : DnsMessage) : Bool :=
  msg.header.flags.qr && isWellFormedFlags msg.header.flags

/-- A message is generally well-formed. -/
def isValidMessage (msg : DnsMessage) : Bool :=
  isWellFormedFlags msg.header.flags &&
  msg.answers.all isValidRR &&
  msg.authority.all isValidRR &&
  msg.additional.all isValidRR

/-! ## QR mutual exclusion -/

/-- A valid query is not a valid response. -/
theorem query_not_response (msg : DnsMessage) (h : isValidQuery msg = true) :
    isValidResponse msg = false := by
  simp [isValidQuery, isValidResponse] at *
  obtain ⟨hqr, _⟩ := h
  simp [hqr]

/-- A valid response is not a valid query. -/
theorem response_not_query (msg : DnsMessage) (h : isValidResponse msg = true) :
    isValidQuery msg = false := by
  simp [isValidQuery, isValidResponse] at *
  obtain ⟨hqr, _⟩ := h
  simp [hqr]

/-! ## Response ID matches query ID -/

/-- The ID of a DNS response must match the ID of the corresponding query. -/
def responseMatchesQuery (resp req : DnsMessage) : Prop :=
  resp.header.id = req.header.id

/-- Response-query ID matching is symmetric. -/
theorem responseMatchesQuery_comm (a b : DnsMessage) :
    responseMatchesQuery a b ↔ responseMatchesQuery b a := by
  simp [responseMatchesQuery, eq_comm]

/-! ## TTL clamping -/

/-- TTL values with the high bit set should be treated as 0 (RFC 2181 section 8). -/
def isClampedTTL (ttl : UInt32) : Bool :=
  decide (ttl.toNat ≤ 2147483647)

/-- The clamped value equals 0 for TTLs with the high bit set. -/
def clampTTL (ttl : UInt32) : UInt32 :=
  if ttl.toNat > 2147483647 then 0 else ttl

theorem clampTTL_isValid (ttl : UInt32) :
    isClampedTTL (clampTTL ttl) = true := by
  unfold clampTTL isClampedTTL
  simp only [decide_eq_true_eq]
  split
  · simp
  · omega

/-! ## CNAME exclusivity -/

/-- A name cannot have both a CNAME record and any other record type (RFC 2181 section 10.1). -/
def cnameExclusive (rrs : List ResourceRecord) : Prop :=
  ∀ name : DomainName,
    (∃ rr ∈ rrs, rr.name.eqCI name && (rr.rrtype == .cname) = true) →
    ∀ rr ∈ rrs, rr.name.eqCI name = true → rr.rrtype = .cname

/-- A single-element list trivially satisfies CNAME exclusivity. -/
theorem cnameExclusive_singleton (rr : ResourceRecord) :
    cnameExclusive [rr] := by
  intro name ⟨rr', hrr', heq⟩
  simp only [List.mem_singleton] at hrr'
  subst hrr'
  intro rr'' hrr'' _
  simp only [List.mem_singleton] at hrr''
  subst hrr''
  have h := (Bool.and_eq_true _ _).mp heq
  exact eq_of_beq (of_decide_eq_true h.2)

/-! ## RRset TTL uniformity -/

/-- All RRs with the same owner/type/class must have the same TTL (RFC 2181 section 5.2). -/
def rrsetTTLUniform (rrs : List ResourceRecord) : Prop :=
  ∀ r1 ∈ rrs, ∀ r2 ∈ rrs,
    r1.name.eqCI r2.name = true →
    r1.rrtype = r2.rrtype →
    r1.rrclass = r2.rrclass →
    r1.ttl = r2.ttl

/-- A single-record list trivially satisfies TTL uniformity. -/
theorem rrsetTTLUniform_singleton (rr : ResourceRecord) :
    rrsetTTLUniform [rr] := by
  intro r1 hr1 r2 hr2 _ _ _
  simp at hr1 hr2
  subst hr1; subst hr2; rfl

/-! ## SOA in authority for negative responses -/

/-- A well-formed NXDOMAIN response has an SOA record in the authority section (RFC 1034 section 3.7). -/
def hasSOAInAuthority (msg : DnsMessage) : Bool :=
  msg.authority.any (fun rr => rr.rrtype == .soa)

/-- NXDOMAIN with no answers is a negative response. -/
def isNXDOMAINResponse (msg : DnsMessage) : Bool :=
  isValidResponse msg &&
  msg.header.flags.rcode == .nxdomain &&
  msg.answers.isEmpty

end SWELib.Networking.Dns
