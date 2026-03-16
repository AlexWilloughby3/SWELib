/-!
# DNS Types

Core type definitions for the Domain Name System specification.

References:
- RFC 1034: https://www.rfc-editor.org/rfc/rfc1034
- RFC 1035: https://www.rfc-editor.org/rfc/rfc1035
- RFC 3596: https://www.rfc-editor.org/rfc/rfc3596
-/

namespace SWELib.Networking.Dns

/-! ## Label -/

/-- A single DNS label: a sequence of 1-63 octets. -/
structure Label where
  bytes : ByteArray

instance : Repr Label where
  reprPrec l n := reprPrec l.bytes.toList n

/-- A label is valid if its length is between 1 and 63 octets (RFC 1035 section 2.3.4). -/
def Label.isValid (l : Label) : Bool :=
  1 ≤ l.bytes.size && l.bytes.size ≤ 63

/-- Case-insensitive equality for a single byte (ASCII A-Z = a-z). -/
def bytesEqCI (a b : UInt8) : Bool :=
  let toLower (c : UInt8) : UInt8 :=
    if 65 ≤ c.toNat && c.toNat ≤ 90 then c + 32 else c
  toLower a == toLower b

/-- Case-insensitive equality for labels. -/
def Label.eqCI (a b : Label) : Bool :=
  a.bytes.size == b.bytes.size &&
  (a.bytes.toList.zip b.bytes.toList).all fun (x, y) => bytesEqCI x y

/-! ## DomainName -/

/-- A domain name as a list of labels. The root (.) is represented by an empty list. -/
structure DomainName where
  labels : List Label
  deriving Repr

/-- Wire length = sum of (label_size + 1) for each label, plus 1 for the root zero octet. -/
def DomainName.wireLength (d : DomainName) : Nat :=
  d.labels.foldl (fun acc l => acc + l.bytes.size + 1) 0 + 1

/-- Text length (without trailing dot) = sum of label sizes + dots between labels. -/
def DomainName.textLength (d : DomainName) : Nat :=
  let total := d.labels.foldl (fun acc l => acc + l.bytes.size) 0
  if d.labels.length > 0 then total + d.labels.length - 1 else total

/-- A domain name is valid if all labels are valid and the wire length is at most 255. -/
def DomainName.isValid (d : DomainName) : Bool :=
  d.labels.all Label.isValid && d.wireLength ≤ 255

/-- The root domain name (. in text form). -/
def DomainName.root : DomainName := { labels := [] }

/-- Case-insensitive equality for domain names. -/
def DomainName.eqCI (a b : DomainName) : Bool :=
  a.labels.length == b.labels.length &&
  (a.labels.zip b.labels).all fun (x, y) => x.eqCI y

/-! ## RRType -/

/-- DNS resource record types. -/
inductive RRType where
  | a              -- 1:  IPv4 address
  | ns             -- 2:  Authoritative nameserver
  | cname          -- 5:  Canonical name alias
  | soa            -- 6:  Start of authority
  | ptr            -- 12: Domain name pointer
  | mx             -- 15: Mail exchanger
  | txt            -- 16: Text strings
  | aaaa           -- 28: IPv6 address
  | unknown (code : UInt16)
  deriving DecidableEq, Repr

/-- Numeric code for an RRType. -/
def RRType.toUInt16 : RRType -> UInt16
  | .a         => 1
  | .ns        => 2
  | .cname     => 5
  | .soa       => 6
  | .ptr       => 12
  | .mx        => 15
  | .txt       => 16
  | .aaaa      => 28
  | .unknown c => c

/-- Decode an RRType from its numeric code. -/
def RRType.fromUInt16 (code : UInt16) : RRType :=
  match code with
  | 1  => .a
  | 2  => .ns
  | 5  => .cname
  | 6  => .soa
  | 12 => .ptr
  | 15 => .mx
  | 16 => .txt
  | 28 => .aaaa
  | c  => .unknown c

/-! ## QType -/

/-- DNS query types (superset of RRType). -/
inductive QType where
  | rrType (t : RRType)  -- any concrete record type
  | axfr                  -- 252: zone transfer
  | any                   -- 255: wildcard
  deriving DecidableEq, Repr

/-! ## RRClass -/

/-- DNS resource record classes. -/
inductive RRClass where
  | in_            -- 1: Internet (use in_ to avoid keyword conflict)
  | cs             -- 2: CSNET (obsolete)
  | ch             -- 3: Chaos
  | hs             -- 4: Hesiod
  | unknown (code : UInt16)
  deriving DecidableEq, Repr

/-- Numeric code for an RRClass. -/
def RRClass.toUInt16 : RRClass -> UInt16
  | .in_       => 1
  | .cs        => 2
  | .ch        => 3
  | .hs        => 4
  | .unknown c => c

/-- Decode an RRClass from its numeric code. -/
def RRClass.fromUInt16 (code : UInt16) : RRClass :=
  match code with
  | 1 => .in_ | 2 => .cs | 3 => .ch | 4 => .hs | c => .unknown c

/-! ## QClass -/

/-- DNS query classes (superset of RRClass). -/
inductive QClass where
  | rrClass (c : RRClass)
  | any    -- 255
  deriving DecidableEq, Repr

/-! ## Opcode -/

/-- DNS message opcodes (bits 14-11 of the flags word). -/
inductive Opcode where
  | query            -- 0: standard query (RFC 1035)
  | iquery           -- 1: inverse query (RFC 1035, obsoleted by RFC 3425)
  | status           -- 2: server status request (RFC 1035)
  | notify           -- 4: zone change notification (RFC 1996)
  | update           -- 5: dynamic update (RFC 2136)
  | reserved (code : UInt8)  -- all other values
  deriving DecidableEq, Repr

/-- Numeric code for an Opcode. -/
def Opcode.toUInt8 : Opcode -> UInt8
  | .query       => 0
  | .iquery      => 1
  | .status      => 2
  | .notify      => 4
  | .update      => 5
  | .reserved c  => c

/-- Decode an Opcode from its numeric code. -/
def Opcode.fromUInt8 (code : UInt8) : Opcode :=
  match code with
  | 0 => .query | 1 => .iquery | 2 => .status | 4 => .notify | 5 => .update
  | c => .reserved c

/-! ## RCode -/

/-- DNS response codes (bits 3-0 of the flags word). -/
inductive RCode where
  | noerror   -- 0
  | formerr   -- 1
  | servfail  -- 2
  | nxdomain  -- 3
  | notimp    -- 4
  | refused   -- 5
  | yxdomain  -- 6
  | yxrrset   -- 7
  | nxrrset   -- 8
  | notauth   -- 9
  | notzone   -- 10
  | reserved (code : UInt8)
  deriving DecidableEq, Repr

/-- Numeric code for an RCode. -/
def RCode.toUInt8 : RCode -> UInt8
  | .noerror   => 0  | .formerr   => 1  | .servfail  => 2
  | .nxdomain  => 3  | .notimp    => 4  | .refused   => 5
  | .yxdomain  => 6  | .yxrrset   => 7  | .nxrrset   => 8
  | .notauth   => 9  | .notzone   => 10
  | .reserved c => c

/-- Decode an RCode from its numeric code. -/
def RCode.fromUInt8 (code : UInt8) : RCode :=
  match code with
  | 0 => .noerror | 1 => .formerr | 2 => .servfail | 3 => .nxdomain
  | 4 => .notimp | 5 => .refused | 6 => .yxdomain | 7 => .yxrrset
  | 8 => .nxrrset | 9 => .notauth | 10 => .notzone | c => .reserved c

/-! ## DnsFlags -/

/-- The 16-bit flags word of a DNS message header. -/
structure DnsFlags where
  qr     : Bool    -- 0=query, 1=response
  opcode : Opcode
  aa     : Bool    -- authoritative answer
  tc     : Bool    -- truncated
  rd     : Bool    -- recursion desired
  ra     : Bool    -- recursion available
  z      : Bool    -- reserved; MUST be zero
  ad     : Bool    -- authentic data (DNSSEC)
  cd     : Bool    -- checking disabled (DNSSEC)
  rcode  : RCode
  deriving Repr

end SWELib.Networking.Dns
