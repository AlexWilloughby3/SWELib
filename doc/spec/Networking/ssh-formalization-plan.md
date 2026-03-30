# SSH Protocol Formalization Plan

Full spec-layer formalization of SSH (RFCs 4251–4254) for `spec/SWELib/Networking/Ssh/`.

## Protocol Layers

1. **Transport** (RFC 4253) — binary packet protocol, key exchange, encryption, re-keying
2. **Authentication** (RFC 4252) — publickey, password, hostbased auth
3. **Connection** (RFC 4254) — channel multiplexing, sessions, port forwarding

## Planned File Structure

```
spec/SWELib/Networking/
  Ssh.lean                          -- root: imports + high-level API
  Ssh/
    Types.lean                      -- wire types, message numbers (1–100), algorithm names, disconnect reasons
    Packet.lean                     -- binary packet format (RFC 4253 §6), sequence numbers, version exchange
    KeyExchange.lean                -- KEXINIT (10 name-lists), DH exchange, key derivation A–F, NEWKEYS
    TransportState.lean             -- transport state machine: versionExchange → kexInit → established → rekeying
    Auth.lean                       -- auth protocol (RFC 4252): publickey, password, hostbased, partial success
    Channel.lean                    -- channel lifecycle + window-based flow control (RFC 4254 §5)
    Session.lean                    -- session requests: pty-req, exec, shell, subsystem, signals (RFC 4254 §6)
    Forwarding.lean                 -- port forwarding: tcpip-forward, direct-tcpip (RFC 4254 §7)
    Operations.lean                 -- high-level operations with axiomatized crypto
    Invariants.lean                 -- protocol safety theorems
```

## Key Invariants to Formalize

### Transport (RFC 4253)
- Session ID immutability across re-keys
- Sequence numbers never reset (wrap at 2^32)
- During kex, only messages 1–49 allowed
- NEWKEYS sent with old keys, subsequent messages use new keys
- DH values e,f must be in [1, p-1]
- Packet alignment: total size multiple of max(block_size, 8)
- Padding bounds: 4 ≤ padding_length ≤ 255

### Auth (RFC 4252)
- One outstanding request at a time
- Username/service binding (change flushes state)
- SUCCESS is terminal (sent at most once)
- "none" never listed in can_continue
- Publickey signature covers session_id (binds to session)
- Messages ≥ 80 before auth complete → disconnect

### Connection (RFC 4254)
- Window size ≤ 2^32-1, no overflow on adjust
- Data bounded by min(window, max_packet_size)
- No data after EOF
- CLOSE requires mutual exchange
- forwarded-tcpip rejected without prior tcpip-forward request
- Channel IDs are local to each endpoint
- Global request replies in FIFO order

## Source Specifications

- RFC 4251 — SSH Protocol Architecture
- RFC 4253 — SSH Transport Layer Protocol
- RFC 4252 — SSH Authentication Protocol
- RFC 4254 — SSH Connection Protocol
