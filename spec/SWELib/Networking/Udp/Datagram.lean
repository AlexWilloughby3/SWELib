/-
Copyright (c) 2025 SWELib Authors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Team
-/

import SWELib.Networking.Udp.Header

/-!
# UDP Datagram

Formal specification of UDP datagrams and pseudo-headers (RFC 768).

A UDP datagram consists of a header and payload. The checksum computation
includes a pseudo-header with IP-layer information.
-/

namespace SWELib.Networking.Udp

/-- Complete UDP datagram -/
structure Datagram where
  /-- UDP header -/
  header : Header
  /-- Payload data -/
  payload : ByteArray

/-- Pseudo-header for checksum computation (RFC 768 for IPv4, RFC 2460 for IPv6) -/
structure PseudoHeader where
  /-- IP version (4 for IPv4, 6 for IPv6) -/
  version : UInt8
  /-- Source IP address (4 bytes for IPv4, 16 bytes for IPv6) -/
  sourceAddress : ByteArray
  /-- Destination IP address (same size as source) -/
  destinationAddress : ByteArray
  /-- Protocol number (17 for UDP) -/
  protocol : UInt8
  /-- UDP length field -/
  udpLength : UInt16

/-- Create a UDP datagram -/
def mkDatagram (srcPort dstPort : Port) (payload : ByteArray) : Datagram :=
  let header := mkHeader srcPort dstPort
  let headerWithLength := setLength header payload.size
  { header := headerWithLength, payload := payload }

/-- Create a pseudo-header for IPv4 -/
def mkPseudoHeaderIPv4 (srcAddr dstAddr : ByteArray) (udpLength : UInt16) : PseudoHeader :=
  { version := 4
    sourceAddress := srcAddr
    destinationAddress := dstAddr
    protocol := PROTOCOL_UDP
    udpLength := udpLength }

/-- Create a pseudo-header for IPv6 -/
def mkPseudoHeaderIPv6 (srcAddr dstAddr : ByteArray) (udpLength : UInt16) : PseudoHeader :=
  { version := 6
    sourceAddress := srcAddr
    destinationAddress := dstAddr
    protocol := PROTOCOL_UDP
    udpLength := udpLength }

/-- Get the total size of a datagram in bytes -/
def datagramSize (datagram : Datagram) : Nat :=
  HEADER_SIZE + datagram.payload.size

/-- Check if a datagram is empty (no payload) -/
def isEmpty (datagram : Datagram) : Bool :=
  datagram.payload.size = 0

/-- Extract source port from datagram -/
def getSourcePort (datagram : Datagram) : Port :=
  datagram.header.sourcePort

/-- Extract destination port from datagram -/
def getDestinationPort (datagram : Datagram) : Port :=
  datagram.header.destinationPort

end SWELib.Networking.Udp