/-
Copyright (c) 2025 SWELib Authors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Team
-/

import SWELib.Networking.Udp.Port
import SWELib.Networking.Udp.Header
import SWELib.Networking.Udp.Datagram
import SWELib.Networking.Udp.Checksum
import SWELib.Networking.Udp.Socket
import SWELib.Networking.Udp.Validation

/-!
# UDP Properties

Theorems and invariants about UDP datagrams and operations.

This module contains formal proofs about UDP properties from RFC 768.
-/

namespace SWELib.Networking.Udp

/-!
## Structural Theorems
-/

-- INV-UDP-1: UDP header length = 8 octets
theorem header_size_fixed : HEADER_SIZE = 8 := by
  rfl

-- INV-UDP-2: Length field ≥ 8 (minimum datagram size)
theorem length_ge_header_size (hdr : Header) (h : validateHeader hdr) :
    hdr.length ≥ 8 := by
  simp [validateHeader] at h
  exact h.left

-- INV-UDP-3: Length field = header size + payload size
theorem length_matches_payload (dg : Datagram) (h : validateDatagram dg) :
    dg.header.length.toNat = 8 + dg.payload.size := by
  simp [validateDatagram] at h
  exact h.right

-- INV-UDP-4: Maximum datagram size = 65535 octets
theorem max_datagram_size (hdr : Header) (h : validateHeader hdr) :
    hdr.length ≤ 65535 := by
  simp [validateHeader] at h
  exact h.right

/-!
## Algebraic Theorems
-/

-- INV-UDP-5: Checksum covers pseudo-header + UDP header + payload
-- (This is implemented in udpChecksum; see Checksum.lean for details)

-- INV-UDP-6: Zero checksum (0x0000) means no checksum was computed
theorem zero_checksum_means_none (hdr : Header) :
    hdr.checksum = 0 → ¬ hasChecksum hdr := by
  intro h
  simp [hasChecksum, h]

-- INV-UDP-7: Computed zero checksum transmitted as all ones (0xFFFF)
theorem zero_computed_becomes_ones (pseudo : PseudoHeader) (hdr : Header) (payload : ByteArray) :
    rawChecksum pseudo hdr payload = 0 → udpChecksum pseudo hdr payload = 0xFFFF := by
  intro h
  simp [udpChecksum_eq_rawChecksum_or_ffff, h]

-- Checksum property: ones' complement involution for 16-bit words
theorem checksum_involution (x : UInt16) : ~~~(~~~x) = x := by
  apply UInt16.ext
  simp [UInt16.not]

-- Zero checksum is always valid (RFC 768)
theorem zero_checksum_always_valid (datagram : Datagram) (pseudo : PseudoHeader) :
    datagram.header.checksum = 0 → isValidChecksum datagram pseudo := by
  intro h
  simp [isValidChecksum, hasChecksum, h]

/-!
## Socket State Theorems
-/

-- Socket cannot be connected without being bound
theorem connected_implies_bound (socket : SocketState) :
    socket.connected → socket.bound := by
  intro h
  simp [SocketState] at h ⊢
  exact h

-- Note: Bound socket may have localPort = 0 (source port unspecified)

-- Initial socket is unbound and unconnected
theorem initial_socket_state_properties :
    ¬ initialSocketState.bound ∧ ¬ initialSocketState.connected := by
  simp [initialSocketState]

/-!
## Semantic Properties
-/

-- UDP is connectionless: send doesn't change connection state
theorem send_preserves_connection_state (socket : SocketState)
    (dg : Datagram) (addr : Std.Net.Addr) (port : Port) :
    (udpSend socket dg addr port).toOption.map (·.connected) = some socket.connected := by
  simp [udpSend]
  split <;> simp

-- UDP send preserves binding state
theorem send_preserves_bound_state (socket : SocketState)
    (dg : Datagram) (addr : Std.Net.Addr) (port : Port) :
    (udpSend socket dg addr port).toOption.map (·.bound) = some socket.bound := by
  simp [udpSend]
  split <;> simp

-- Valid datagram has correct length field
theorem valid_datagram_has_correct_length (dg : Datagram) (h : validateDatagram dg) :
    dg.header.length.toNat = datagramSize dg := by
  simp [validateDatagram, datagramSize] at h ⊢
  exact h.right

-- Empty datagram has minimum size
theorem empty_datagram_min_size (dg : Datagram) (h : isEmpty dg) :
    datagramSize dg = HEADER_SIZE := by
  simp [isEmpty, datagramSize] at h ⊢
  exact h

-- Port validation theorems
theorem well_known_port_valid (p : Port) (h : isWellKnownPort p) : isValidPort p := by
  simp [isValidPort]

theorem registered_port_valid (p : Port) (h : isRegisteredPort p) : isValidPort p := by
  simp [isValidPort]

theorem dynamic_port_valid (p : Port) (h : isDynamicPort p) : isValidPort p := by
  simp [isValidPort]

/-!
## Examples
-/

/-- Example: DNS query datagram -/
def exampleDnsQuery : Datagram :=
  mkDatagram 54321 53 (ByteArray.mk #[0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0])

/-- Example: IPv4 pseudo-header for DNS query -/
def examplePseudoIPv4 : PseudoHeader :=
  mkPseudoHeaderIPv4 (ByteArray.mk #[192, 168, 1, 1]) (ByteArray.mk #[8, 8, 8, 8]) 20

/-- Example validation checks -/
#eval validateDatagram exampleDnsQuery
#eval validatePseudoHeaderIPv4 examplePseudoIPv4
#eval udpChecksum examplePseudoIPv4 exampleDnsQuery.header exampleDnsQuery.payload

/-- Example: IPv6 pseudo-header -/
def examplePseudoIPv6 : PseudoHeader :=
  mkPseudoHeaderIPv6
    (ByteArray.mk #[0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])  -- 2001:db8::1
    (ByteArray.mk #[0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2])  -- 2001:db8::2
    20

/-- Example: Datagram with zero checksum (no checksum) -/
def exampleZeroChecksum : Datagram :=
  let dg := mkDatagram 1234 80 (ByteArray.mk #[1,2,3,4])
  { dg with header := setChecksum dg.header 0 }

/-- Example: Datagram with source port 0 (unspecified) -/
def exampleNoSourcePort : Datagram :=
  mkDatagram 0 53 (ByteArray.mk #[0, 1])

/-- Example: Maximum payload size datagram -/
def exampleMaxPayload : Datagram :=
  let payload := ByteArray.mk (List.replicate (MAX_DATAGRAM_SIZE - HEADER_SIZE) 0)
  mkDatagram 1234 5678 payload

/-- More validation tests -/
#eval validatePseudoHeaderIPv6 examplePseudoIPv6
#eval validateDatagram exampleZeroChecksum
#eval validateDatagram exampleNoSourcePort
#eval validateDatagram exampleMaxPayload
#eval udpChecksum examplePseudoIPv6 exampleDnsQuery.header exampleDnsQuery.payload
#eval isValidChecksum exampleZeroChecksum examplePseudoIPv4

end SWELib.Networking.Udp