import SWELib.Networking.Udp.Port
import SWELib.Networking.Udp.Header
import SWELib.Networking.Udp.Datagram
import SWELib.Networking.Udp.Checksum
import SWELib.Networking.Udp.Socket
import SWELib.Networking.Udp.Validation
import SWELib.Networking.Udp.Properties

/-!
# UDP

Formal specification of the User Datagram Protocol (RFC 768).

UDP is a connectionless transport protocol that provides a simple
interface for sending datagrams between applications.

## Key Features

- **Connectionless**: No handshake or connection establishment
- **Unreliable**: No delivery guarantees, no retransmission
- **Lightweight**: Minimal header overhead (8 bytes)
- **Multiplexing**: Port-based application multiplexing
- **Checksum**: Optional end-to-end error detection

## Specification Structure

This module imports all UDP submodules:
- `Udp.Port`: Port numbers and constants
- `Udp.Header`: UDP header structure
- `Udp.Datagram`: Complete datagrams and pseudo-headers
- `Udp.Checksum`: Checksum computation and validation
- `Udp.Socket`: Socket state and operations
- `Udp.Validation`: Datagram validation functions
- `Udp.Properties`: Theorems and invariants

## RFC Compliance

This specification follows RFC 768 (User Datagram Protocol) with
references to related RFCs for specific applications (DNS, DHCP, etc.).
-/

namespace SWELib.Networking

end SWELib.Networking
