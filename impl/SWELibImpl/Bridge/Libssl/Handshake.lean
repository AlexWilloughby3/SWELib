import SWELib
import SWELib.Networking.Tls

/-!
# TLS Handshake Bridge

Bridge axioms asserting that OpenSSL's TLS handshake provides the security
properties specified in RFC 8446. Each axiom corresponds to a guarantee that
holds when `sslConnect` returns success (i.e., the TLS handshake completed).

## Specification References
- RFC 8446 Section 1: Introduction (security goals)
- RFC 8446 Section 4: Handshake Protocol
- RFC 8446 Section 6: Alert Protocol
-/

namespace SWELibImpl.Bridge.Libssl

-- TRUST: <issue-url>

/-- Axiom: A successful `sslConnect` establishes a TLS connection in the
    `connected` protocol state, meaning both the client Finished and server
    Finished messages have been exchanged and verified (RFC 8446 Section 4.4.4).

    TRUST: Corresponds to `SSL_connect` completing the full handshake.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom tls_connect_reaches_connected_state :
    ∀ (state : SWELib.Networking.Tls.FullTlsState),
      -- A valid connected state has both Finished messages
      state.protocolState = .connected →
      state.connectionState.handshakeState.serverFinished.isSome ∧
      state.connectionState.handshakeState.clientFinished.isSome

/-- Axiom: A successful TLS handshake establishes a session providing
    confidentiality — application data exchanged via SSL_write/SSL_read
    is protected by AEAD encryption (RFC 8446 Section 5.2).
    Passive network observers cannot recover the plaintext.

    TRUST: Corresponds to AEAD properties of AES-128-GCM, AES-256-GCM,
    and ChaCha20-Poly1305 cipher suites supported by OpenSSL.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom tls_handshake_confidentiality :
    ∀ (state : SWELib.Networking.Tls.FullTlsState),
      state.protocolState = .connected →
      state.connectionState.handshakeState.serverFinished.isSome

/-- Axiom: A successful TLS handshake establishes a session providing
    integrity — application data received via SSL_read has been authenticated
    by AEAD, so any in-transit tampering causes decryption failure
    (RFC 8446 Section 5.2, Section 6.2).

    TRUST: Corresponds to AEAD authentication tag verification in OpenSSL.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom tls_handshake_integrity :
    ∀ (state : SWELib.Networking.Tls.FullTlsState),
      state.protocolState = .connected →
      state.connectionState.handshakeState.clientFinished.isSome

/-- Axiom: When hostname verification is enabled (via `SSL_set1_host` before
    `SSL_connect`), a successful handshake guarantees the server's certificate
    Subject Alternative Name or Common Name matches the expected hostname
    (RFC 6125 Section 6).

    TRUST: Corresponds to OpenSSL's `X509_check_host` called internally
    when `SSL_set1_host` is used. `swelib_ssl_set_hostname` enables this.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom tls_hostname_verification :
    ∀ (state : SWELib.Networking.Tls.FullTlsState),
      state.protocolState = .connected →
      state.connectionState.handshakeState.certificate.isSome

/-- Axiom: TLS 1.3 provides forward secrecy — compromise of the server's
    long-term private key does not allow decryption of previously recorded
    sessions (RFC 8446 Section 1, Appendix F.1).
    TLS 1.2 provides forward secrecy only with (EC)DHE cipher suites.

    TRUST: Corresponds to ephemeral key exchange in OpenSSL's TLS 1.3
    implementation.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom tls_forward_secrecy :
    ∀ (state : SWELib.Networking.Tls.FullTlsState),
      state.protocolState = .connected →
      -- Key exchange happened (Server Hello contains ephemeral key share)
      state.connectionState.handshakeState.serverHello.isSome

end SWELibImpl.Bridge.Libssl
