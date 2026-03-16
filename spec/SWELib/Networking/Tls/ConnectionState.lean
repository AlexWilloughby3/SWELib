/-!
# TLS Connection State

Connection state structures for TLS protocol (RFC 8446 Section 7).
-/

import SWELib.Basics.Bytes
import SWELib.Networking.Tls.RecordLayer
import SWELib.Security.Hashing

namespace SWELib.Networking.Tls

/-- Security parameters for a TLS connection (RFC 8446 Section 7.1). -/
structure SecurityParameters where
  /-- Cipher suite -/
  cipherSuite : CipherSuite
  /-- Compression algorithm (null for TLS 1.3) -/
  compressionAlgorithm : CompressionMethod
  /-- Master secret -/
  masterSecret : ByteArray
  /-- Client random -/
  clientRandom : Random
  /-- Server random -/
  serverRandom : Random
  deriving DecidableEq, Repr

/-- Traffic keys for record protection (RFC 8446 Section 7.3). -/
structure TrafficKeys where
  /-- Client write key -/
  clientWriteKey : ByteArray
  /-- Server write key -/
  serverWriteKey : ByteArray
  /-- Client write IV -/
  clientWriteIV : ByteArray
  /-- Server write IV -/
  serverWriteIV : ByteArray
  deriving DecidableEq, Repr

/-- Handshake state tracking (RFC 8446 Section 4). -/
structure HandshakeState where
  /-- Client hello message -/
  clientHello : Option ClientHello
  /-- Server hello message -/
  serverHello : Option ServerHello
  /-- Encrypted extensions message -/
  encryptedExtensions : Option EncryptedExtensions
  /-- Certificate chain -/
  certificate : Option CertificateChain
  /-- Certificate verify message -/
  certificateVerify : Option CertificateVerify
  /-- Finished message from server -/
  serverFinished : Option Finished
  /-- Finished message from client -/
  clientFinished : Option Finished
  /-- Handshake transcript hash -/
  transcriptHash : ByteArray
  deriving DecidableEq, Repr

/-- Session state for resumption (RFC 8446 Section 2.2). -/
structure SessionState where
  /-- Session identifier -/
  sessionId : SessionID
  /-- Session ticket -/
  ticket : ByteArray
  /-- Master secret -/
  masterSecret : ByteArray
  /-- Cipher suite -/
  cipherSuite : CipherSuite
  /-- Peer certificate -/
  peerCertificate : Option Certificate
  deriving DecidableEq, Repr

/-- Connection state for a TLS endpoint (RFC 8446 Section 7). -/
structure ConnectionState where
  /-- Security parameters -/
  securityParameters : SecurityParameters
  /-- Traffic keys -/
  trafficKeys : TrafficKeys
  /-- Handshake state -/
  handshakeState : HandshakeState
  /-- Session state (if resuming) -/
  sessionState : Option SessionState
  /-- Sequence number for outgoing records -/
  writeSequenceNumber : Nat
  /-- Sequence number for incoming records -/
  readSequenceNumber : Nat
  deriving DecidableEq, Repr

/-- Create initial handshake state. -/
def HandshakeState.initial : HandshakeState :=
  ⟨none, none, none, none, none, none, none, ByteArray.empty⟩

/-- Create initial connection state. -/
def ConnectionState.initial : ConnectionState :=
  let securityParams : SecurityParameters :=
    ⟨CipherSuite.tlsAes128GcmSha256, CompressionMethod.null, ByteArray.empty,
     ⟨ByteArray.empty⟩, ⟨ByteArray.empty⟩⟩
  let trafficKeys : TrafficKeys :=
    ⟨ByteArray.empty, ByteArray.empty, ByteArray.empty, ByteArray.empty⟩
  ⟨securityParams, trafficKeys, HandshakeState.initial, none, 0, 0⟩

/-- Update handshake state with a client hello. -/
def HandshakeState.withClientHello (state : HandshakeState) (ch : ClientHello) : HandshakeState :=
  { state with clientHello := some ch }

/-- Update handshake state with a server hello. -/
def HandshakeState.withServerHello (state : HandshakeState) (sh : ServerHello) : HandshakeState :=
  { state with serverHello := some sh }

/-- Update handshake state with encrypted extensions. -/
def HandshakeState.withEncryptedExtensions (state : HandshakeState) (ee : EncryptedExtensions) : HandshakeState :=
  { state with encryptedExtensions := some ee }

/-- Update handshake state with a certificate. -/
def HandshakeState.withCertificate (state : HandshakeState) (cert : CertificateChain) : HandshakeState :=
  { state with certificate := some cert }

/-- Update handshake state with a certificate verify. -/
def HandshakeState.withCertificateVerify (state : HandshakeState) (cv : CertificateVerify) : HandshakeState :=
  { state with certificateVerify := some cv }

/-- Update handshake state with server finished. -/
def HandshakeState.withServerFinished (state : HandshakeState) (sf : Finished) : HandshakeState :=
  { state with serverFinished := some sf }

/-- Update handshake state with client finished. -/
def HandshakeState.withClientFinished (state : HandshakeState) (cf : Finished) : HandshakeState :=
  { state with clientFinished := some cf }

/-- Update handshake state transcript hash. -/
def HandshakeState.withTranscriptHash (state : HandshakeState) (hash : ByteArray) : HandshakeState :=
  { state with transcriptHash := hash }

/-- Check if handshake is complete (RFC 8446 Section 4.4.4). -/
def HandshakeState.isComplete : HandshakeState → Bool
  | ⟨some _, some _, some _, some _, some _, some _, some _, _⟩ => true
  | _ => false

/-- Check if handshake has received server hello. -/
def HandshakeState.hasServerHello : HandshakeState → Bool
  | ⟨_, some _, _, _, _, _, _, _⟩ => true
  | _ => false

/-- Check if handshake has received client hello. -/
def HandshakeState.hasClientHello : HandshakeState → Bool
  | ⟨some _, _, _, _, _, _, _, _⟩ => true
  | _ => false

/-- Check if handshake has received server finished. -/
def HandshakeState.hasServerFinished : HandshakeState → Bool
  | ⟨_, _, _, _, _, some _, _, _⟩ => true
  | _ => false

/-- Check if handshake has received client finished. -/
def HandshakeState.hasClientFinished : HandshakeState → Bool
  | ⟨_, _, _, _, _, _, some _, _⟩ => true
  | _ => false

/-- Get the negotiated cipher suite from handshake state. -/
def HandshakeState.negotiatedCipherSuite : HandshakeState → Option CipherSuite
  | ⟨_, some sh, _, _, _, _, _, _⟩ => some sh.cipherSuite
  | _ => none

/-- Get the negotiated protocol version from handshake state. -/
def HandshakeState.negotiatedVersion : HandshakeState → Option ProtocolVersion
  | ⟨some ch, some sh, _, _, _, _, _, _⟩ =>
    if ch.legacyVersion = sh.legacyVersion then
      some ch.legacyVersion
    else
      none
  | _ => none

/-- Validate that security parameters are consistent. -/
def SecurityParameters.validate : SecurityParameters → Bool
  | ⟨cipherSuite, compressionAlgorithm, masterSecret, clientRandom, serverRandom⟩ =>
    masterSecret.size = 48 &&  -- TLS 1.3 master secret is 48 bytes
    clientRandom.validate &&
    serverRandom.validate

/-- Validate that traffic keys have appropriate sizes. -/
def TrafficKeys.validate : TrafficKeys → Bool
  | ⟨clientWriteKey, serverWriteKey, clientWriteIV, serverWriteIV⟩ =>
    clientWriteKey.size > 0 &&
    serverWriteKey.size > 0 &&
    clientWriteIV.size > 0 &&
    serverWriteIV.size > 0

/-- Validate that session state is consistent. -/
def SessionState.validate : SessionState → Bool
  | ⟨sessionId, ticket, masterSecret, cipherSuite, peerCertificate⟩ =>
    sessionId.validate &&
    ticket.size > 0 &&
    masterSecret.size = 48

/-- Validate that connection state is consistent. -/
def ConnectionState.validate : ConnectionState → Bool
  | ⟨securityParameters, trafficKeys, handshakeState, sessionState, writeSeq, readSeq⟩ =>
    securityParameters.validate &&
    trafficKeys.validate &&
    (match sessionState with
     | some ss => ss.validate
     | none => true)

/-- Increment write sequence number. -/
def ConnectionState.incrementWriteSequence (state : ConnectionState) : ConnectionState :=
  { state with writeSequenceNumber := state.writeSequenceNumber + 1 }

/-- Increment read sequence number. -/
def ConnectionState.incrementReadSequence (state : ConnectionState) : ConnectionState :=
  { state with readSequenceNumber := state.readSequenceNumber + 1 }

/-- Reset sequence numbers (for key update). -/
def ConnectionState.resetSequenceNumbers (state : ConnectionState) : ConnectionState :=
  { state with writeSequenceNumber := 0, readSequenceNumber := 0 }

/-- Check if connection is ready to send application data (RFC 8446 Section 4.4.4). -/
def ConnectionState.canSendApplicationData : ConnectionState → Bool
  | ⟨_, _, handshakeState, _, _, _⟩ => handshakeState.hasServerFinished

/-- Check if connection is ready to receive application data (RFC 8446 Section 4.4.4). -/
def ConnectionState.canReceiveApplicationData : ConnectionState → Bool
  | ⟨_, _, handshakeState, _, _, _⟩ => handshakeState.hasClientFinished

end SWELib.Networking.Tls