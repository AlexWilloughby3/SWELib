/-
Copyright (c) 2025 SWELib Authors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Team
-/

import SWELib.Networking.Udp.Header
import SWELib.Networking.Udp.Datagram

/-!
# UDP Validation

Formal specification of UDP datagram validation functions.

Validation ensures that UDP datagrams conform to RFC 768 requirements.
-/

namespace SWELib.Networking.Udp

/-- Validate UDP header invariants -/
def validateHeader (header : Header) : Bool :=
  header.length ≥ 8 ∧  -- Minimum datagram size
  header.length ≤ 65535  -- Maximum UDP datagram size

/-- Validate complete datagram -/
def validateDatagram (datagram : Datagram) : Bool :=
  validateHeader datagram.header ∧
  datagram.header.length.toNat = 8 + datagram.payload.size

/-- Validate that port numbers are within valid range -/
def validatePorts (header : Header) : Bool :=
  isValidPort header.sourcePort ∧ isValidPort header.destinationPort

/-- Validate that source port is optional (zero means no source port) -/
def validateSourcePort (_header : Header) : Bool :=
  true

/-- Validate that destination port is not zero -/
def validateDestinationPort (header : Header) : Bool :=
  header.destinationPort ≠ 0

/-- Validate payload size constraints -/
def validatePayloadSize (datagram : Datagram) : Bool :=
  let payloadSize := datagram.payload.size
  payloadSize ≤ MAX_DATAGRAM_SIZE - HEADER_SIZE

/-- Comprehensive datagram validation -/
def validateDatagramComplete (datagram : Datagram) : Bool :=
  validateDatagram datagram ∧
  validatePorts datagram.header ∧
  validateDestinationPort datagram.header ∧
  validatePayloadSize datagram

/-- Check if datagram can be fragmented at IP layer -/
def canBeFragmented (datagram : Datagram) : Bool :=
  datagram.payload.size > (MAX_DATAGRAM_SIZE - HEADER_SIZE)

/-- Check if datagram requires fragmentation -/
def requiresFragmentation (datagram : Datagram) (mtu : Nat) : Bool :=
  let totalSize := datagramSize datagram
  totalSize > mtu

/-- Validate pseudo-header for IPv4 -/
def validatePseudoHeaderIPv4 (pseudo : PseudoHeader) : Bool :=
  pseudo.version = 4 ∧
  pseudo.sourceAddress.size = 4 ∧  -- IPv4 address size
  pseudo.destinationAddress.size = 4 ∧
  pseudo.protocol = PROTOCOL_UDP

/-- Validate pseudo-header for IPv6 -/
def validatePseudoHeaderIPv6 (pseudo : PseudoHeader) : Bool :=
  pseudo.version = 6 ∧
  pseudo.sourceAddress.size = 16 ∧  -- IPv6 address size
  pseudo.destinationAddress.size = 16 ∧
  pseudo.protocol = PROTOCOL_UDP

/-- Validate that checksum field is properly formatted -/
def validateChecksumField (_header : Header) : Bool :=
  -- Checksum can be 0 (no checksum) or any valid 16-bit value
  true  -- All UInt16 values are valid

end SWELib.Networking.Udp