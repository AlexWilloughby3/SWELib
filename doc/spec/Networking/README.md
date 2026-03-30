# Networking

Protocol specifications covering the full stack from transport to application layer. The largest spec module by file count (~78 files).

## Modules

### HTTP (16 files)

Full formalization of HTTP semantics per RFC 9110.

| File | Spec Source | Key Types |
|------|-----------|-----------|
| `Http/Method.lean` | RFC 9110 Section 9 | `Method` (GET/HEAD/POST/PUT/PATCH/DELETE/CONNECT/OPTIONS/TRACE/extension) |
| `Http/StatusCode.lean` | RFC 9110 Section 15 | `StatusCode` (Nat + range proof 100-999), status classes |
| `Http/Message.lean` | RFC 9110 Section 6 | `Request`, `Response`, `Version` (1.0/1.1/2/3) |
| `Http/Field.lean` | RFC 9110 | Header field structures |
| `Http/Target.lean` | RFC 9110 | Request target (URI-based) |
| `Http/Representation.lean` | RFC 9110 | Content negotiation, media types |
| `Http/Contract.lean` | RFC 9110 | Request/response contracts |
| `Http/Conditional.lean` | RFC 9110 | If-Match, If-None-Match, ETags |
| `Http/ContentNegotiation.lean` | RFC 9110 | Accept header negotiation |
| `Http/Auth.lean` | RFC 9110 | Authentication schemes |
| `Http/Caching.lean` | RFC 9110 | Cache directives, revalidation |
| `Http/Connection.lean` | RFC 9110 | Connection management, keep-alive |
| `Http/Expect.lean` | RFC 9110 | Expect header handling |
| `Http/Framing.lean` | RFC 9110 | Message framing, chunked encoding |
| `Http/Https.lean` | RFC 9110 | HTTPS (TLS over HTTP) |

### TCP (12 files)

RFC 9293 state machine with 11 states.

| File | Key Content |
|------|-------------|
| `Tcp/State.lean` | 11 states: CLOSED, LISTEN, SYN-SENT, SYN-RECEIVED, ESTABLISHED, FIN-WAIT-1, FIN-WAIT-2, CLOSE-WAIT, CLOSING, TIME-WAIT, LAST-ACK |
| `Tcp/SeqNum.lean` | Sequence number arithmetic |
| `Tcp/Segment.lean` | TCP segment structure |
| `Tcp/Tcb.lean` | Transmission Control Block |
| `Tcp/Events.lean` | State transition events |
| `Tcp/Transition.lean` | State machine transitions |
| `Tcp/ByteStreamRefinement.lean` | Refinement to ByteStream abstraction |

### UDP (7 files)

RFC 768: connectionless, unreliable, lightweight datagrams.

| File | Key Content |
|------|-------------|
| `Udp/Port.lean` | Port numbers and well-known ports |
| `Udp/Header.lean` | 8-byte UDP header structure |
| `Udp/Datagram.lean` | Complete datagrams |
| `Udp/Checksum.lean` | Optional end-to-end error detection |
| `Udp/Socket.lean` | Socket operations |
| `Udp/Properties.lean` | Protocol properties and validation |

### TLS (12 files)

RFC 5246 (TLS 1.2) and RFC 8446 (TLS 1.3).

| File | Key Content |
|------|-------------|
| `Tls/Types.lean` | Core type definitions |
| `Tls/BasicStructures.lean` | Basic data structures |
| `Tls/Extensions.lean` | Extension definitions |
| `Tls/HandshakeMessages.lean` | Handshake messages (ClientHello, ServerHello, etc.) |
| `Tls/RecordLayer.lean` | Record layer structures |
| `Tls/ConnectionState.lean` | Connection state management |
| `Tls/StateMachine.lean` | State machine specification |
| `Tls/Operations.lean` | Core operations |
| `Tls/Invariants.lean` | Protocol invariants |
| `Tls/Tls12.lean` | TLS 1.2 specifics |
| `Tls/Tls13.lean` | TLS 1.3 specifics |
| `Tls/SecureStream.lean` | Secure stream abstraction |

### DNS (3 files)

RFC 1034/1035/2181/3596.

| File | Key Content |
|------|-------------|
| `Dns/Types.lean` | Record types (A, AAAA, CNAME, MX, SOA, NS, TXT, PTR) |
| `Dns/Message.lean` | DNS message structure |
| `Dns/Invariants.lean` | Protocol invariants |

### WebSocket (5 files)

RFC 6455. States: CONNECTING, OPEN, CLOSING, CLOSED.

| File | Key Content |
|------|-------------|
| `Websocket/Types.lean` | Core types |
| `Websocket/Frame.lean` | Frame structure, masking, fragmentation |
| `Websocket/Handshake.lean` | HTTP upgrade, Sec-WebSocket-Key |
| `Websocket/State.lean` | Connection state machine |
| `Websocket/Protocol.lean` | Protocol operations |

### SSH (3 files)

RFC 4252 authentication protocol.

| File | Key Content |
|------|-------------|
| `Ssh/Types.lean` | Auth types |
| `Ssh/Auth.lean` | Auth state machine (SUCCESS is terminal, publickey signatures bound to session ID) |
| `Ssh/Invariants.lean` | Protocol invariants |

### REST (9 files)

Roy Fielding's architectural style. Six constraints: Client-Server, Stateless, Cache, Uniform Interface, Layered System, Code-On-Demand.

### Proxy (5 files)

RFC 7230/7231 (HTTP proxy), RFC 1928 (SOCKS5). HTTP proxy with Via headers, TCP tunnel via CONNECT, SOCKS5 authentication.

### Stubs

| File | Status |
|------|--------|
| `Graphql.lean` | TODO |
| `Grpc.lean` | TODO |

## Design Decisions

- HTTP methods use an inductive with `extension` constructor for RFC extensibility (see [D-005](../Basics/representation-decisions.md))
- HTTP status codes use Nat with range proof (see [D-006](../Basics/representation-decisions.md))
- TCP modeled as a state machine with dependent types preventing invalid operations (see [D-003](../Basics/representation-decisions.md))
