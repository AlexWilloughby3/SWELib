import SWELib.Networking.Proxy.Types
import SWELib.Networking.Proxy.Config
import SWELib.Networking.Proxy.Http
import SWELib.Networking.Proxy.Tunnel
import SWELib.Networking.Proxy.Socks5
import SWELib.Networking.Proxy.Properties

/-!
# Proxy Specification

Formal specification of HTTP and SOCKS5 proxies per RFC 7230, RFC 7231, and RFC 1928.

## Overview

This module provides formal specifications for:
- HTTP proxy behavior (Via headers, request forwarding)
- TCP tunnel establishment via CONNECT method
- SOCKS5 protocol (authentication, request parsing)
- Proxy configuration validation
- Security properties and theorems

## References

- RFC 7230 Section 5.7.1: Via header field
- RFC 7231 Section 4.3.6: CONNECT method
- RFC 1928: SOCKS5 Protocol
-/

namespace SWELib.Networking

end SWELib.Networking
