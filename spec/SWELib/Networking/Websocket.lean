import SWELib.Networking.Websocket.Types
import SWELib.Networking.Websocket.Frame
import SWELib.Networking.Websocket.Handshake
import SWELib.Networking.Websocket.State
import SWELib.Networking.Websocket.Protocol

/-!
# WebSocket

Formal specification of the WebSocket protocol (RFC 6455) and W3C WebSocket API.

## Overview

WebSocket provides full-duplex communication channels over a single TCP connection.
This module specifies both the wire protocol (RFC 6455) and the JavaScript API
(W3C WebSocket API) used by web applications.

## Specification Coverage

- **Opening Handshake** (RFC 6455 Section 4): HTTP upgrade with Sec-WebSocket-Key
- **Data Framing** (RFC 6455 Section 5): Frame structure, masking, fragmentation
- **Control Frames** (RFC 6455 Section 5.5): Close, Ping, Pong
- **Closing Handshake** (RFC 6455 Section 7): Status codes and clean termination
- **API Operations** (W3C WebSocket API): `new()`, `send()`, `close()`, `readyState`

## Key Properties

1. **Client masking**: All client-to-server frames are masked (RFC 6455 Section 5.3)
2. **Control frame limits**: Control frames ≤125 bytes, not fragmented (RFC 6455 Section 5.5)
3. **State monotonicity**: CONNECTING → OPEN → CLOSING → CLOSED
4. **Close code validation**: 1000-1015 reserved, 3000-4999 application-defined
5. **Handshake integrity**: Sec-WebSocket-Accept = base64(sha1(key + GUID))

## References

- RFC 6455: The WebSocket Protocol
- W3C WebSocket API: https://www.w3.org/TR/websockets/
- IANA WebSocket Opcode Registry
- IANA WebSocket Close Code Registry
-/

namespace SWELib.Networking

export Websocket (ReadyState BinaryType Opcode CloseCode
  WebSocketFrame WebSocket WebSocketError ProtocolError
  isValidOpcode isValidCloseCode
  parseFrame serializeFrame maskPayload unmaskPayload
  computeWebSocketKey computeAcceptKey validateAcceptKey
  processIncomingFrame createCloseFrame)

end SWELib.Networking
