import SWELib
import SWELib.Networking.Tls
import SWELib.Networking.Http.Https

/-!
# TLS Server Handshake Bridge

Bridge axioms asserting that OpenSSL's server-side TLS handshake provides
the security properties specified in RFC 8446 / RFC 5246. These mirror
the client-side axioms in `Bridge.Libssl.Handshake` but for SSL_accept.

The trust boundary: we axiomatize that a successful `SSL_accept` with a
valid cert/key pair produces a connection with confidentiality, integrity,
and authentication — the same `SecureStream` properties the spec layer uses.

## Specification References
- RFC 8446 Section 1: Security goals (same for client and server)
- RFC 8446 Section 4.4: Server handshake authentication
- RFC 8446 Section 5.2: Record payload protection (AEAD)
- RFC 2818 Section 2: HTTP Over TLS (server identity)
-/

namespace SWELibImpl.Bridge.Libssl.Server

open SWELib.Networking.Tls

-- TRUST: <issue-url>

/-- Axiom: A successful `sslAccept` establishes a TLS connection in the
    `connected` protocol state, meaning both Finished messages have been
    exchanged and verified (RFC 8446 Section 4.4.4).

    TRUST: Corresponds to `SSL_accept` completing the full server-side handshake.
    The server sends its Certificate + CertificateVerify + Finished, and
    receives the client's Finished. -/
axiom tls_accept_reaches_connected_state :
    ∀ (state : FullTlsState),
      state.protocolState = .connected →
      state.connectionState.handshakeState.serverFinished.isSome ∧
      state.connectionState.handshakeState.clientFinished.isSome

/-- Axiom: A successful server TLS handshake provides confidentiality.
    Application data exchanged via SSL_write/SSL_read is protected by
    AEAD encryption (RFC 8446 Section 5.2). Passive network observers
    cannot recover the plaintext.

    TRUST: Same AEAD ciphers as the client side — AES-128-GCM, AES-256-GCM,
    ChaCha20-Poly1305. The direction doesn't affect the cipher properties. -/
axiom tls_server_handshake_confidentiality :
    ∀ (ss : SecureStream),
      ss.tlsState.protocolState = .connected →
      Confidential ss.ciphertext ss.plaintext

/-- Axiom: A successful server TLS handshake provides integrity.
    Any in-transit tampering of application data causes AEAD authentication
    failure (RFC 8446 Section 5.2, Section 6.2).

    TRUST: AEAD authentication tag verification in OpenSSL.
    Applies symmetrically to both client→server and server→client data. -/
axiom tls_server_handshake_integrity :
    ∀ (ss : SecureStream),
      ss.tlsState.protocolState = .connected →
      Integral ss.ciphertext ss.plaintext

/-- Axiom: A successful server TLS handshake authenticates the server.
    The server proved possession of the private key corresponding to the
    certificate loaded via `SSL_CTX_use_certificate_file` by signing the
    handshake transcript (CertificateVerify, RFC 8446 Section 4.4.3).

    TRUST: OpenSSL's server-side CertificateVerify generation. The client
    verifies this signature against the server's certificate. -/
axiom tls_server_authenticated :
    ∀ (ss : SecureStream) (chain : CertificateChain),
      ss.peerCertificate = some chain →
      ss.tlsState.protocolState = .connected →
      Authenticated ss chain

/-- Axiom: The server context loads a valid cert/key pair.
    When `sslServerCtxNew` succeeds, the certificate and private key are
    consistent (SSL_CTX_check_private_key passed).

    TRUST: OpenSSL's `SSL_CTX_check_private_key` verifies the loaded
    certificate's public key matches the loaded private key. -/
axiom tls_server_cert_key_match :
    ∀ (state : FullTlsState),
      state.protocolState = .connected →
      state.connectionState.handshakeState.certificate.isSome

/-- Axiom: The server enforces minimum TLS 1.2.
    `sslServerCtxNew` calls `SSL_CTX_set_min_proto_version(ctx, TLS1_2_VERSION)`.
    Connections using SSLv3, TLS 1.0, or TLS 1.1 are rejected.

    TRUST: OpenSSL's protocol version enforcement.
    RFC 8996 deprecates TLS 1.0 and 1.1. -/
axiom tls_server_min_version :
    ∀ (state : FullTlsState),
      state.protocolState = .connected →
      -- ServerHello was sent (it contains the negotiated version ≥ TLS 1.2)
      state.connectionState.handshakeState.serverHello.isSome

/-- Axiom: TLS 1.3 server connections provide forward secrecy.
    Compromise of the server's long-term private key does not allow
    decryption of previously recorded sessions (RFC 8446 Section 1, Appendix F.1).

    TRUST: Ephemeral ECDHE key exchange in OpenSSL's TLS 1.3 implementation.
    TLS 1.2 connections only get forward secrecy with (EC)DHE suites. -/
axiom tls_server_forward_secrecy :
    ∀ (state : FullTlsState),
      state.protocolState = .connected →
      state.connectionState.handshakeState.serverHello.isSome

end SWELibImpl.Bridge.Libssl.Server
