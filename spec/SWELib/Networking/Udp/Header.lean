/-
Copyright (c) 2025 SWELib Authors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Team
-/

import SWELib.Networking.Udp.Port

/-!
# UDP Header

Formal specification of the UDP header structure (RFC 768).

The UDP header consists of 8 octets:
- Source Port (16 bits)
- Destination Port (16 bits)
- Length (16 bits)
- Checksum (16 bits)
-/

namespace SWELib.Networking.Udp

/-- UDP header (RFC 768) -/
structure Header where
  /-- Source port (0 if unused) -/
  sourcePort : Port
  /-- Destination port -/
  destinationPort : Port
  /-- Length in octets of entire datagram including header -/
  length : UInt16
  /-- 16-bit one's complement checksum (0x0000 means no checksum) -/
  checksum : UInt16
  deriving Repr, DecidableEq

/-- UDP header size in bytes (fixed at 8 octets per RFC 768) -/
def HEADER_SIZE : Nat := 8

/-- Minimum valid UDP datagram size (header only) -/
def MIN_DATAGRAM_SIZE : Nat := HEADER_SIZE

/-- Maximum valid UDP datagram size (RFC 768) -/
def MAX_DATAGRAM_SIZE : Nat := 65535

/-- UDP protocol number (IANA assignment) -/
def PROTOCOL_UDP : UInt8 := 17

/-- Create a UDP header with default values -/
def mkHeader (srcPort dstPort : Port) : Header :=
  { sourcePort := srcPort
    destinationPort := dstPort
    length := 0  -- Will be set when payload is known
    checksum := 0 }  -- Will be computed when needed

/-- Update header length based on payload size -/
def setLength (header : Header) (payloadSize : Nat) : Header :=
  { header with length := UInt16.ofNat (HEADER_SIZE + payloadSize) }

/-- Update header checksum -/
def setChecksum (header : Header) (checksum : UInt16) : Header :=
  { header with checksum := checksum }

end SWELib.Networking.Udp