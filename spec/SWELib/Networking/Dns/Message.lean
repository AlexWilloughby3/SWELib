import SWELib.Networking.Dns.Types

/-!
# DNS Message Structures

Composite structures: DnsHeader, Question, RData, ResourceRecord, RRset, DnsMessage.

References:
- RFC 1035 section 4: https://www.rfc-editor.org/rfc/rfc1035
-/

namespace SWELib.Networking.Dns

/-! ## DnsHeader -/

/-- The fixed 12-octet DNS message header (RFC 1035 section 4.1.1). -/
structure DnsHeader where
  id      : UInt16  -- query/response identifier
  flags   : DnsFlags
  qdcount : UInt16  -- question count
  ancount : UInt16  -- answer count
  nscount : UInt16  -- authority count
  arcount : UInt16  -- additional count
  deriving Repr

/-! ## Question -/

/-- A DNS question entry (RFC 1035 section 4.1.2). -/
structure Question where
  qname  : DomainName
  qtype  : QType
  qclass : QClass
  deriving Repr

private instance : Repr ByteArray where
  reprPrec b n := reprPrec b.toList n

/-! ## RData -/

/-- Typed resource record data (RFC 1035 section 3.3, RFC 3596 section 2). -/
inductive RData where
  /-- A (TYPE 1): 32-bit IPv4 address in network byte order. -/
  | a     (addr      : UInt32)
  /-- NS (TYPE 2): authoritative nameserver hostname. -/
  | ns    (nsdname   : DomainName)
  /-- CNAME (TYPE 5): canonical name this label is an alias for. -/
  | cname (target    : DomainName)
  /-- SOA (TYPE 6): start-of-authority record (RFC 1035 section 3.3.13). -/
  | soa   (mname rname : DomainName)
          (serial refresh retry expire minimum : UInt32)
  /-- PTR (TYPE 12): reverse-DNS domain name pointer. -/
  | ptr   (ptrdname  : DomainName)
  /-- MX (TYPE 15): mail exchanger; lower preference = higher priority. -/
  | mx    (preference : UInt16) (exchange : DomainName)
  /-- TXT (TYPE 16): one or more character strings (each at most 255 bytes). -/
  | txt   (strings   : List ByteArray)
  /-- AAAA (TYPE 28): 128-bit IPv6 address (exactly 16 bytes). -/
  | aaaa  (addr      : ByteArray)
  /-- Unknown or unimplemented record type (forward-compatibility). -/
  | unknown (code : UInt16) (bytes : ByteArray)
  deriving Repr

/-- Total function extracting the RRType tag from an RData value. -/
def RData.rrtype : RData -> RRType
  | .a _           => .a
  | .ns _          => .ns
  | .cname _       => .cname
  | .soa ..        => .soa
  | .ptr _         => .ptr
  | .mx ..         => .mx
  | .txt _         => .txt
  | .aaaa _        => .aaaa
  | .unknown c _   => .unknown c

/-! ## ResourceRecord -/

/-- A single DNS resource record (RFC 1035 section 3.2.1). -/
structure ResourceRecord where
  name    : DomainName
  rrtype  : RRType
  rrclass : RRClass
  ttl     : UInt32
  rdata   : RData
  deriving Repr

/-! ## RRset -/

/-- A set of resource records sharing the same owner, type, and class (RFC 2181 section 5).
    All records in an RRset must have the same TTL. -/
structure RRset where
  name    : DomainName
  rrtype  : RRType
  rrclass : RRClass
  ttl     : UInt32
  rdatas  : List RData
  deriving Repr

/-! ## DnsMessage -/

/-- A complete DNS message (RFC 1035 section 4.1). -/
structure DnsMessage where
  header     : DnsHeader
  questions  : List Question
  answers    : List ResourceRecord
  authority  : List ResourceRecord
  additional : List ResourceRecord
  deriving Repr

/-- The wire-protocol port for DNS. -/
def DNS_PORT : UInt16 := 53

/-- Maximum UDP message size without EDNS0 (RFC 1035 section 4.2.1). -/
def DNS_UDP_MAX : Nat := 512

end SWELib.Networking.Dns
