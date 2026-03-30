import SWELib.Basics.ByteStream
import SWELib.Networking.Http.Message
import SWELib.Networking.Http.Connection
import SWELib.Networking.Http.Framing
import SWELib.Networking.Tls.SecureStream

/-!
# HTTPS — HTTP over TLS

An HTTPS connection is HTTP framing over the plaintext side of a SecureStream.
The definition is straightforward because SecureStream handles all security complexity.

## Why This Layering Works

1. **HTTP doesn't know about TLS.** The existing HTTP module operates on bytes.
   It doesn't care whether those bytes flow over a raw TCP ByteStream or the
   plaintext side of a SecureStream. No changes to HTTP formalization needed.

2. **Security properties compose upward.** An HTTP Request sent over HTTPS
   inherits SecureStream's confidentiality/integrity/authentication axioms
   automatically.

3. **The axiom boundary is clean.** We axiomatize exactly one thing: "a completed
   TLS handshake produces a SecureStream with these properties." Everything above
   (HTTP framing, request/response semantics) is proved from definitions.

4. **Refinement path is clear.** If someone later proves the SecureStream axioms
   from TLS internals, nothing above changes.

## Source Specs
- RFC 2818: HTTP Over TLS
- RFC 9110 Section 4.2: "https" URI Scheme
- RFC 8446: TLS 1.3
-/

namespace SWELib.Networking.Http

open SWELib.Basics
open SWELib.Networking.Tls

/-! ## HTTP Connection (insecure) -/

/-- An HTTP connection over a raw StreamPair (plain TCP).
    The HTTP protocol logic operates on the stream directly. -/
structure HttpConnection where
  /-- The underlying bidirectional byte stream (from TCP). -/
  stream : StreamPair
  /-- HTTP version and persistence state. -/
  persistence : ConnectionPersistence
  deriving Repr

/-! ## HTTPS Connection (secure) -/

/-- An HTTPS connection: HTTP protocol over a TLS-secured stream.
    The application reads/writes HTTP messages on the plaintext side.
    TLS handles encryption/authentication transparently.

    The ONLY structural difference from HttpConnection is that the
    stream is the plaintext side of a SecureStream, not a raw StreamPair. -/
structure HttpsConnection where
  /-- The secure stream (TLS-wrapped). -/
  secure : SecureStream
  /-- HTTP version and persistence state. -/
  persistence : ConnectionPersistence

/-- The application-facing stream for an HTTPS connection.
    This is the plaintext side of the SecureStream — identical in type
    to what HttpConnection uses directly. -/
def HttpsConnection.stream (conn : HttpsConnection) : StreamPair :=
  conn.secure.plaintext

/-- Construct an HTTPS connection from a completed TLS handshake. -/
def HttpsConnection.establish (ss : SecureStream) : HttpsConnection where
  secure := ss
  -- HTTP/1.1 is persistent by default (RFC 9112 Section 9.3)
  persistence := .persistent

/-- Write serialized HTTP bytes to the HTTPS connection.
    The bytes are written to the plaintext stream; TLS encrypts transparently. -/
def HttpsConnection.writeBytes (conn : HttpsConnection) (bytes : List UInt8)
    : HttpsConnection :=
  { conn with secure := conn.secure.write bytes }

/-- Read bytes from the HTTPS connection.
    The bytes come from the plaintext stream; TLS has decrypted them. -/
def HttpsConnection.readBytes (conn : HttpsConnection) (n : Nat)
    : List UInt8 × HttpsConnection :=
  let (bytes, secure') := conn.secure.read n
  (bytes, { conn with secure := secure' })

/-- Close the HTTPS connection (sends TLS close_notify + HTTP connection close). -/
def HttpsConnection.close (conn : HttpsConnection) : HttpsConnection :=
  { conn with
    secure := conn.secure.close
    persistence := .close_ }

/-! ## HTTPS Theorems -/

/-- The plaintext stream of an HTTPS connection is bidirectional
    (independent read/write directions). -/
theorem HttpsConnection.write_preserves_incoming (conn : HttpsConnection)
    (bytes : List UInt8) :
    (conn.writeBytes bytes).stream.incoming = conn.stream.incoming := by
  simp [writeBytes, stream, SecureStream.write, StreamPair.writeOutgoing]

/-- Reading from HTTPS doesn't affect the outgoing stream. -/
theorem HttpsConnection.read_preserves_outgoing (conn : HttpsConnection) (n : Nat) :
    (conn.readBytes n).2.stream.outgoing = conn.stream.outgoing := by
  simp [readBytes, stream, SecureStream.read, StreamPair.readIncoming]

/-- HTTPS request confidentiality: bytes written to an HTTPS connection
    are confidential on the wire.
    Follows directly from SecureStream's confidentiality axiom. -/
theorem HttpsConnection.request_confidential (conn : HttpsConnection) :
    Confidential conn.secure.ciphertext conn.secure.plaintext :=
  secureStream_confidential conn.secure conn.secure.handshakeComplete

/-- HTTPS request integrity: bytes on the wire cannot be tampered with
    without detection.
    Follows directly from SecureStream's integrity axiom. -/
theorem HttpsConnection.request_integrity (conn : HttpsConnection) :
    Integral conn.secure.ciphertext conn.secure.plaintext :=
  secureStream_integral conn.secure conn.secure.handshakeComplete

/-- HTTPS peer authentication: if the server's certificate chain validates,
    the server is authentic. -/
theorem HttpsConnection.peer_authenticated (conn : HttpsConnection)
    (chain : CertificateChain) (trustAnchors : List CertificateChain)
    (hCert : conn.secure.peerCertificate = some chain)
    (hValid : CertPathValid chain trustAnchors) :
    Authenticated conn.secure chain :=
  secureStream_authenticated conn.secure chain trustAnchors hCert hValid

/-! ## HTTP vs HTTPS: The Protocol Logic is Identical -/

/-- Extract the application-facing stream, abstracting over HTTP vs HTTPS.
    Both connection types provide a StreamPair for the HTTP protocol to operate on.
    The only difference is what carries the bytes:
    - HTTP:  StreamPair (raw TCP)
    - HTTPS: SecureStream.plaintext (TLS-wrapped TCP) -/
def HttpConnection.toStreamPair (conn : HttpConnection) : StreamPair :=
  conn.stream

def HttpsConnection.toStreamPair (conn : HttpsConnection) : StreamPair :=
  conn.secure.plaintext

end SWELib.Networking.Http
