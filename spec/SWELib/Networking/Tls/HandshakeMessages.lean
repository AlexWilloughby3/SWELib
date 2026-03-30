import SWELib.Basics.Bytes
import SWELib.Networking.Tls.Extensions

/-!
# TLS Handshake Messages

Handshake message structures for TLS protocol (RFC 8446 Section 4).
-/

namespace SWELib.Networking.Tls

private instance : Repr ByteArray where
  reprPrec b _ := repr b.toList

/-- Key share entry for key exchange (RFC 8446 Section 4.2.8). -/
structure KeyShareEntry where
  /-- Named group for this key share -/
  group : NamedGroup
  /-- Key exchange data (public key) -/
  keyExchange : ByteArray
  deriving DecidableEq, Repr

/-- X.509 certificate (RFC 8446 Section 4.4.2). -/
structure Certificate where
  /-- Certificate data in DER format -/
  data : ByteArray
  deriving DecidableEq, Repr

/-- Certificate chain (RFC 8446 Section 4.4.2). -/
structure CertificateChain where
  /-- List of certificates, starting with the end-entity certificate -/
  certificates : List Certificate
  deriving DecidableEq, Repr

/-- Certificate Verify message (RFC 8446 Section 4.4.3). -/
structure CertificateVerify where
  /-- Signature algorithm -/
  algorithm : SignatureScheme
  /-- Signature over handshake messages -/
  signature : ByteArray
  deriving DecidableEq, Repr

/-- Finished message (RFC 8446 Section 4.4.4). -/
structure Finished where
  /-- Verify data (HMAC over handshake messages) -/
  verifyData : ByteArray
  deriving DecidableEq, Repr

/-- Client Hello message (RFC 8446 Section 4.1.2). -/
structure ClientHello where
  /-- Protocol version -/
  legacyVersion : ProtocolVersion
  /-- Client random -/
  random : Random
  /-- Session ID -/
  legacySessionId : SessionID
  /-- List of cipher suites -/
  cipherSuites : List CipherSuite
  /-- List of legacy compression methods -/
  legacyCompressionMethods : List CompressionMethod
  /-- List of extensions -/
  extensions : List Extension
  deriving DecidableEq, Repr

/-- Server Hello message (RFC 8446 Section 4.1.3). -/
structure ServerHello where
  /-- Protocol version -/
  legacyVersion : ProtocolVersion
  /-- Server random -/
  random : Random
  /-- Session ID -/
  legacySessionId : SessionID
  /-- Selected cipher suite -/
  cipherSuite : CipherSuite
  /-- Selected compression method -/
  legacyCompressionMethod : CompressionMethod
  /-- List of extensions -/
  extensions : List Extension
  deriving DecidableEq, Repr

/-- Encrypted Extensions message (RFC 8446 Section 4.3.1). -/
structure EncryptedExtensions where
  /-- List of extensions -/
  extensions : List Extension
  deriving DecidableEq, Repr

/-- Certificate Request message (RFC 8446 Section 4.3.2). -/
structure CertificateRequest where
  /-- List of extensions -/
  extensions : List Extension
  deriving DecidableEq, Repr

/-- New Session Ticket message (RFC 8446 Section 4.6.1). -/
structure NewSessionTicket where
  /-- Ticket lifetime in seconds -/
  ticketLifetime : Nat
  /-- Ticket age add (for obfuscating ticket age) -/
  ticketAgeAdd : UInt32
  /-- Ticket nonce -/
  ticketNonce : ByteArray
  /-- Ticket data (opaque to client) -/
  ticket : ByteArray
  /-- List of extensions -/
  extensions : List Extension
  deriving DecidableEq, Repr

/-- End of Early Data message (RFC 8446 Section 4.2.10). -/
structure EndOfEarlyData where
  deriving DecidableEq, Repr

/-- Key Update message (RFC 8446 Section 4.6.3). -/
inductive KeyUpdateRequest where
  /-- Update requested (RFC 8446 Section 4.6.3) -/
  | updateRequested : KeyUpdateRequest
  /-- Update not requested (RFC 8446 Section 4.6.3) -/
  | updateNotRequested : KeyUpdateRequest
  deriving DecidableEq, Repr

structure KeyUpdate where
  /-- Key update request -/
  request : KeyUpdateRequest
  deriving DecidableEq, Repr

/-- Handshake message (RFC 8446 Section 4). -/
inductive HandshakeMessage where
  /-- Client Hello (RFC 8446 Section 4.1.2) -/
  | clientHello : ClientHello → HandshakeMessage
  /-- Server Hello (RFC 8446 Section 4.1.3) -/
  | serverHello : ServerHello → HandshakeMessage
  /-- New Session Ticket (RFC 8446 Section 4.6.1) -/
  | newSessionTicket : NewSessionTicket → HandshakeMessage
  /-- End of Early Data (RFC 8446 Section 4.2.10) -/
  | endOfEarlyData : EndOfEarlyData → HandshakeMessage
  /-- Encrypted Extensions (RFC 8446 Section 4.3.1) -/
  | encryptedExtensions : EncryptedExtensions → HandshakeMessage
  /-- Certificate (RFC 8446 Section 4.4.2) -/
  | certificate : CertificateChain → HandshakeMessage
  /-- Certificate Request (RFC 8446 Section 4.3.2) -/
  | certificateRequest : CertificateRequest → HandshakeMessage
  /-- Certificate Verify (RFC 8446 Section 4.4.3) -/
  | certificateVerify : CertificateVerify → HandshakeMessage
  /-- Finished (RFC 8446 Section 4.4.4) -/
  | finished : Finished → HandshakeMessage
  /-- Key Update (RFC 8446 Section 4.6.3) -/
  | keyUpdate : KeyUpdate → HandshakeMessage
  deriving DecidableEq, Repr

/-- Get the handshake type from a handshake message. -/
def HandshakeMessage.getType : HandshakeMessage → HandshakeType
  | .clientHello _ => .clientHello
  | .serverHello _ => .serverHello
  | .newSessionTicket _ => .newSessionTicket
  | .endOfEarlyData _ => .endOfEarlyData
  | .encryptedExtensions _ => .encryptedExtensions
  | .certificate _ => .certificate
  | .certificateRequest _ => .certificateRequest
  | .certificateVerify _ => .certificateVerify
  | .finished _ => .finished
  | .keyUpdate _ => .keyUpdate

instance : ToString KeyUpdateRequest where
  toString req := match req with
    | .updateRequested => "update_requested"
    | .updateNotRequested => "update_not_requested"

/-- Validate that a KeyShareEntry has valid key exchange data. -/
def KeyShareEntry.validate : KeyShareEntry → Bool
  | ⟨_, keyExchange⟩ => keyExchange.size > 0

/-- Validate that a Certificate has non-empty data. -/
def Certificate.validate : Certificate → Bool
  | ⟨data⟩ => data.size > 0

/-- Validate that a CertificateChain has at least one certificate. -/
def CertificateChain.validate : CertificateChain → Bool
  | ⟨certificates⟩ => certificates.length > 0

/-- Validate that a CertificateVerify has non-empty signature. -/
def CertificateVerify.validate : CertificateVerify → Bool
  | ⟨_, signature⟩ => signature.size > 0

/-- Validate that a Finished has verify data of appropriate length. -/
def Finished.validate : Finished → Bool
  | ⟨verifyData⟩ => verifyData.size = 32  -- TLS 1.3 uses 32-byte verify data

/-- Validate that a ClientHello has required fields (RFC 8446 Section 4.1.2). -/
def ClientHello.validate : ClientHello → Bool
  | ⟨_, random, legacySessionId, cipherSuites, legacyCompressionMethods, _⟩ =>
    random.validate &&
    legacySessionId.validate &&
    cipherSuites.length > 0 &&
    legacyCompressionMethods.length > 0

/-- Validate that a ServerHello has required fields (RFC 8446 Section 4.1.3). -/
def ServerHello.validate : ServerHello → Bool
  | ⟨_, random, legacySessionId, _, _, _⟩ =>
    random.validate &&
    legacySessionId.validate

/-- Validate that a NewSessionTicket has valid fields (RFC 8446 Section 4.6.1). -/
def NewSessionTicket.validate : NewSessionTicket → Bool
  | ⟨_, _, _, ticket, _⟩ =>
    ticket.size > 0

/-- Validate a handshake message based on its type. -/
def HandshakeMessage.validate : HandshakeMessage → Bool
  | .clientHello ch => ch.validate
  | .serverHello sh => sh.validate
  | .newSessionTicket nst => nst.validate
  | .endOfEarlyData _ => true
  | .encryptedExtensions _ => true
  | .certificate cc => cc.validate
  | .certificateRequest _ => true
  | .certificateVerify cv => cv.validate
  | .finished f => f.validate
  | .keyUpdate _ => true

/-- Check if a handshake message is from the client. -/
def HandshakeMessage.isFromClient : HandshakeMessage → Bool
  | .clientHello _ => true
  | .endOfEarlyData _ => true
  | .certificateVerify _ => true
  | .finished _ => true
  | .keyUpdate _ => true
  | _ => false

/-- Check if a handshake message is from the server. -/
def HandshakeMessage.isFromServer : HandshakeMessage → Bool
  | .serverHello _ => true
  | .encryptedExtensions _ => true
  | .certificate _ => true
  | .certificateRequest _ => true
  | .finished _ => true
  | .newSessionTicket _ => true
  | _ => false

end SWELib.Networking.Tls
