/-
Copyright (c) 2025 SWELib Authors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Team
-/

import SWELib.Networking.Udp.Datagram

/-!
# UDP Checksum

Formal specification of UDP checksum computation (RFC 768).

The UDP checksum is the 16-bit one's complement of the one's complement
sum of a pseudo-header, the UDP header, and the payload.
-/

namespace SWELib.Networking.Udp

/-- Get 16-bit word at index i (big-endian) from byte array -/
private def getWordBE (data : ByteArray) (i : Nat) : UInt16 :=
  let high := data[i]!.toUInt16
  let low := data[i + 1]!.toUInt16
  (high <<< 8) ||| low

/-- Compute the one's complement sum of 16-bit words -/
private def onesComplementSum (data : ByteArray) : UInt32 :=
  let len := data.size
  let paddedLen := if len % 2 = 1 then len + 1 else len
  let rec sum (i : Nat) (acc : UInt32) : UInt32 :=
    if i ≥ paddedLen then
      acc
    else
      let word : UInt16 :=
        if i < len then
          if i + 1 < len then
            getWordBE data i
          else
            -- Last byte when odd length, pad with zero
            (data[i]!.toUInt16 <<< 8)
        else
          -- Padding byte (should not happen)
          0
      let newAcc := acc + word.toUInt32
      sum (i + 2) newAcc
  -- Fold carries
  let s := sum 0 0
  let folded := (s &&& 0xFFFF) + (s >>> 16)
  -- If still > 0xFFFF, fold again (at most once needed)
  if folded > 0xFFFF then
    (folded &&& 0xFFFF) + (folded >>> 16)
  else
    folded

/-- Serialize pseudo-header to byte array for checksum computation -/
private def serializePseudoHeader (pseudo : PseudoHeader) : ByteArray :=
  match pseudo.version with
  | 4 =>
      -- IPv4 pseudo-header (RFC 768): 12 bytes
      let buf : ByteArray := ByteArray.mkEmpty 12
      let buf := buf.append pseudo.sourceAddress  -- 4 bytes
      let buf := buf.append pseudo.destinationAddress  -- 4 bytes
      let buf := buf.push 0  -- zero byte
      let buf := buf.push pseudo.protocol  -- protocol
      -- UDP length as big-endian 16-bit
      let lenHigh := UInt8.ofNat ((pseudo.udpLength >>> 8).toNat)
      let lenLow := UInt8.ofNat ((pseudo.udpLength &&& 0xFF).toNat)
      let buf := buf.push lenHigh
      buf.push lenLow
  | 6 =>
      -- IPv6 pseudo-header (RFC 2460): 40 bytes
      let buf : ByteArray := ByteArray.mkEmpty 40
      let buf := buf.append pseudo.sourceAddress  -- 16 bytes
      let buf := buf.append pseudo.destinationAddress  -- 16 bytes
      -- 32-bit UDP length (big-endian)
      let len3 := UInt8.ofNat ((pseudo.udpLength >>> 24).toNat)
      let len2 := UInt8.ofNat (((pseudo.udpLength >>> 16) &&& 0xFF).toNat)
      let len1 := UInt8.ofNat (((pseudo.udpLength >>> 8) &&& 0xFF).toNat)
      let len0 := UInt8.ofNat ((pseudo.udpLength &&& 0xFF).toNat)
      let buf := buf.push len3
      let buf := buf.push len2
      let buf := buf.push len1
      let buf := buf.push len0
      -- 24 bits of zero
      let buf := buf.push 0
      let buf := buf.push 0
      let buf := buf.push 0
      -- Next header (protocol)
      buf.push pseudo.protocol
  | _ =>
      -- Unknown version, fallback to IPv4 format (should not happen)
      ByteArray.empty

/-- Serialize UDP header to byte array for checksum computation -/
private def serializeHeader (header : Header) : ByteArray :=
  let buf : ByteArray := ByteArray.mkEmpty 8
  let push16 (buf : ByteArray) (val : UInt16) : ByteArray :=
    let high := UInt8.ofNat ((val >>> 8).toNat)
    let low := UInt8.ofNat ((val &&& 0xFF).toNat)
    buf.push high |>.push low
  let buf := push16 buf header.sourcePort
  let buf := push16 buf header.destinationPort
  let buf := push16 buf header.length
  let buf := push16 buf 0  -- checksum field as zero for computation
  buf

/-- Compute UDP checksum (RFC 768) -/
def udpChecksum (pseudoHeader : PseudoHeader) (header : Header) (payload : ByteArray) : UInt16 :=
  let pseudoBytes := serializePseudoHeader pseudoHeader
  let headerBytes := serializeHeader header
  let combined := pseudoBytes ++ headerBytes ++ payload
  let sum := onesComplementSum combined
  -- One's complement (invert bits)
  let complement := ~~~sum
  let result16 := UInt16.ofUInt32 (complement &&& 0xFFFF)
  -- RFC 768: If computed checksum is zero, transmit as all ones (0xFFFF)
  if result16 = 0 then 0xFFFF else result16

/-- Raw checksum value before zero-to-ones conversion -/
def rawChecksum (pseudoHeader : PseudoHeader) (header : Header) (payload : ByteArray) : UInt16 :=
  let pseudoBytes := serializePseudoHeader pseudoHeader
  let headerBytes := serializeHeader header
  let combined := pseudoBytes ++ headerBytes ++ payload
  let sum := onesComplementSum combined
  let complement := ~~~sum
  UInt16.ofUInt32 (complement &&& 0xFFFF)

theorem udpChecksum_eq_rawChecksum_or_ffff (pseudo : PseudoHeader) (header : Header) (payload : ByteArray) :
    udpChecksum pseudo header payload =
    let raw := rawChecksum pseudo header payload
    if raw = 0 then 0xFFFF else raw := by
  simp [udpChecksum, rawChecksum]

/-- Validate UDP checksum -/
def udpValidate (datagram : Datagram) (pseudoHeader : PseudoHeader) : Bool :=
  let computed := udpChecksum pseudoHeader datagram.header datagram.payload
  -- Zero checksum means "no checksum" (RFC 768)
  datagram.header.checksum = 0 ∨ computed = datagram.header.checksum

/-- Check if checksum is present (non-zero) -/
def hasChecksum (header : Header) : Bool :=
  header.checksum ≠ 0

/-- Check if checksum is valid for a datagram -/
def isValidChecksum (datagram : Datagram) (pseudoHeader : PseudoHeader) : Bool :=
  if hasChecksum datagram.header then
    udpValidate datagram pseudoHeader
  else
    true  -- No checksum is always valid per RFC 768

/-- Compute and set checksum on a datagram -/
def withChecksum (datagram : Datagram) (pseudoHeader : PseudoHeader) : Datagram :=
  let checksum := udpChecksum pseudoHeader datagram.header datagram.payload
  let newHeader := setChecksum datagram.header checksum
  { datagram with header := newHeader }

/-- Remove checksum from a datagram (set to 0) -/
def withoutChecksum (datagram : Datagram) : Datagram :=
  let newHeader := setChecksum datagram.header 0
  { datagram with header := newHeader }

end SWELib.Networking.Udp