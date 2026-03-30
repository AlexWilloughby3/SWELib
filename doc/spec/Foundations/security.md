# Sketch: Security

## What This Sketch Defines

How security properties — confidentiality, integrity, authentication, authorization — are formalized within the Node/System/Network/ByteStream framework from sketches 01-06. Security is not a separate layer bolted on top; it emerges from the interaction of three things:

1. **Secure channels** — ChannelProcesses (sketch 05) with cryptographic properties, implemented as ByteStream transformers (sketch 06)
2. **Node authentication** — establishing that a Node is who it claims to be, before composing it into a System (sketch 02)
3. **Adversary models** — what the attacker can do, formalized as an additional Node (or set of Nodes) in the System's CCS composition

The existing SWELib security modules (JWT, PKI, TLS types, HMAC, RSA, ECDSA, ECDH) provide the *cryptographic building blocks*. This sketch connects those building blocks to the distributed systems framework, so security properties become theorems about Systems, not just standalone type definitions.

## The Central Insight: Security = Channel + Adversary

In sketches 01-05, a System is `(Node₁ | Channel₁₂ | Channel₂₁ | Node₂) \ internal`. Network properties (reliability, FIFO, lossiness) are theorems about the ChannelProcess's LTS.

Security follows the same pattern. A **secure channel** is a ChannelProcess whose LTS guarantees additional properties *in the presence of an adversary*. Without an adversary, security properties are vacuous — "no one reads the message" is trivially true if there's no one to read it.

```
-- Insecure System (sketch 05):
System = (Alice | Channel | Bob) \ internal

-- Secure System (this sketch):
-- The adversary is an explicit Node in the CCS composition
-- The secure channel prevents the adversary from interfering
System = (Alice | SecureChannel | Bob | Adversary) \ internal

-- Security property: despite Adversary being composed in parallel,
-- certain properties still hold (confidentiality, integrity, authentication)
```

The adversary is just another Node — an LTS with its own actions. The Dolev-Yao adversary can intercept, replay, and forge on unrestricted channels. A secure channel restricts what the adversary can observe and do.

## ByteStream ↔ Security: The Layering

Sketch 06 defines ByteStream as the concrete realization of a reliable FIFO channel. Security enters through **ByteStream transformation** — TLS wraps a plaintext ByteStream, producing an encrypted ByteStream on the wire.

### The Stack

```
Application            MessageStream α              (HTTP requests, WebSocket frames)
    │                      │
    │ FramingProtocol α    │   (HTTP framing, WebSocket framing)
    ▼                      ▼
Plaintext              ByteStream                    (unencrypted bytes)
    │                      │
    │ TLS Record Layer     │   (framing + AEAD encryption per record)
    ▼                      ▼
Ciphertext             ByteStream                    (encrypted bytes on the wire)
    │                      │
    │ TCP                  │   (reliable delivery)
    ▼                      ▼
Network                ChannelProcess (List UInt8)   (sketch 05: lossy/reliable/etc.)
```

Each layer is a ByteStream transformer: it consumes one ByteStream and produces another. The key insight: **the plaintext ByteStream and the ciphertext ByteStream are both `ByteStream` — same type, different security properties.** The TLS layer is the thing that connects them, and the security theorems are about what properties the ciphertext ByteStream has that the plaintext one doesn't.

### TLS as ByteStream Transformer

TLS has two phases, both of which operate on ByteStreams:

**Phase 1: Handshake** — a protocol (state machine / LTS) that runs over the ciphertext ByteStream to establish shared keys. Uses the existing `TlsState` state machine from `Networking/Tls/StateMachine.lean`. The handshake produces:
- A shared secret (master secret / traffic keys)
- Mutual authentication (via certificates — connects to `Security/Pki`)
- Agreed cipher suite (connects to `Security/Crypto`)

**Phase 2: Record layer** — a `FramingProtocol TlsRecord` over the ciphertext ByteStream. Each TLS record is:
- Framed (5-byte header: content type + version + length)
- Encrypted (AEAD — produces ciphertext + authentication tag)
- Sequenced (implicit sequence number prevents replay/reorder)

```
/-- TLS transforms a plaintext ByteStream into a ciphertext ByteStream
    with security guarantees. -/
structure TlsTransform where
  /-- The plaintext stream (application sees this). -/
  plaintext : StreamPair
  /-- The ciphertext stream (network carries this). -/
  ciphertext : StreamPair
  /-- The TLS connection state (keys, sequence numbers). -/
  connState : ConnectionState
  /-- The handshake completed successfully. -/
  handshakeComplete : TlsState = .connected
  /-- Peer identity established during handshake. -/
  peerIdentity : Option Certificate
```

### The Refinement

A TLS-wrapped connection refines a plaintext connection. From the application's perspective, it's still a StreamPair (bidirectional byte stream). From the network's perspective, it's encrypted bytes. The refinement:

```
-- Application-level view: plaintext StreamPair
-- Network-level view: ciphertext StreamPair with TLS framing
-- TLS refinement: the plaintext written by Alice appears (in order, complete)
-- as plaintext read by Bob, despite the ciphertext being visible to Adversary

theorem tls_refines_plaintext_stream :
  ∀ (t : TlsTransform),
    t.handshakeComplete →
    stream_fifo t.plaintext.outgoing (tlsDecrypt t.connState t.ciphertext.incoming) ∧
    stream_reliable t.plaintext.outgoing (tlsDecrypt t.connState t.ciphertext.incoming)
```

This mirrors sketch 06's `tcp_implements_bytestream` — TCP refines ByteStream for reliability, TLS refines ByteStream for security. Both are refinement theorems connecting an abstract interface to a concrete mechanism.

## Key Types to Formalize

### SecureChannel (extending ChannelProcess from sketch 05)

```
/-- A secure channel is a ChannelProcess with additional security properties.
    It wraps a ChannelProcess and adds confidentiality, integrity, and
    authentication guarantees against a specified adversary model. -/
structure SecureChannel (α : Type) where
  /-- The underlying channel process (may be lossy, reordering, etc). -/
  transport : ChannelProcess (List UInt8)
  /-- The security transform applied (TLS, DTLS, IPsec, etc). -/
  transform : SecurityTransform α
  /-- The adversary model this channel is secure against. -/
  adversary : AdversaryModel

/-- Security properties are predicates on the secure channel + adversary. -/
structure SecurityProperties (sc : SecureChannel α) where
  confidentiality : Confidential sc
  integrity : Integral sc
  authentication : Authenticated sc
```

### AdversaryModel

The adversary is an LTS — a Node with specific capabilities:

```
/-- The Dolev-Yao adversary: can intercept, replay, forge on public channels.
    This is the standard network adversary model from protocol verification. -/
inductive AdversaryCapability where
  | intercept : Channel → AdversaryCapability      -- read messages
  | inject : Channel → AdversaryCapability          -- write arbitrary messages
  | drop : Channel → AdversaryCapability            -- prevent delivery
  | replay : Channel → AdversaryCapability          -- re-send observed messages
  | reorder : Channel → AdversaryCapability         -- change delivery order
  -- Cannot: break cryptographic primitives, read Node-internal state,
  --         guess random values with non-negligible probability

structure AdversaryModel where
  capabilities : List AdversaryCapability
  /-- Which channels the adversary can operate on. -/
  controlledChannels : Set Channel
  /-- Computational bound (for reduction-based security). -/
  computationalBound : Option Nat    -- None = unbounded (information-theoretic)

/-- Standard Dolev-Yao: controls all network channels. -/
def dolevYao (networkChannels : Set Channel) : AdversaryModel where
  capabilities := networkChannels.toList.bind fun ch =>
    [.intercept ch, .inject ch, .drop ch, .replay ch, .reorder ch]
  controlledChannels := networkChannels
  computationalBound := none    -- symbolic model, no computational bound

/-- The adversary as a Node in the CCS composition. -/
def AdversaryModel.asNode (adv : AdversaryModel) : LTS AdversaryState AdversaryAction :=
  -- The adversary can perform any sequence of its capabilities
  -- on its controlled channels, in any order
  adversaryLTS adv.capabilities
```

### Security Properties as LTS Predicates

Security properties are stated as predicates on the System's LTS, in the presence of the adversary:

```
/-- Confidentiality: the adversary cannot distinguish between two different
    plaintext messages. Formalized as observational equivalence (bisimulation)
    from the adversary's view. -/
def Confidential (sc : SecureChannel α) : Prop :=
  ∀ (m₁ m₂ : α),
    -- The adversary's view of the system when Alice sends m₁
    -- is bisimilar to the adversary's view when Alice sends m₂
    WeakBisimulation
      (systemWith sc.adversary (aliceSends m₁ sc))
      (systemWith sc.adversary (aliceSends m₂ sc))
    -- Projected onto the adversary's observable actions

/-- Integrity: if Bob receives message m, then Alice sent m.
    No message modification by the adversary. -/
def Integral (sc : SecureChannel α) : Prop :=
  ∀ (trace : SystemTrace),
    (bobReceives m) ∈ trace →
    (aliceSent m) ∈ trace ∧ (aliceSent m).before (bobReceives m) trace

/-- Authentication: if Bob believes he's talking to Alice,
    then Alice is indeed participating. -/
def Authenticated (sc : SecureChannel α) : Prop :=
  ∀ (trace : SystemTrace),
    (bobAcceptsIdentity alice) ∈ trace →
    (aliceParticipates) ∈ trace

/-- Forward secrecy: compromise of long-term keys doesn't compromise
    past session keys. Modeled as: adversary gains the long-term key
    AFTER the session, but the session's confidentiality still holds. -/
def ForwardSecrecy (sc : SecureChannel α) : Prop :=
  ∀ (session : CompletedSession) (ltk : LongTermKey),
    let adv' := sc.adversary.withCapability (.knowsKey ltk)
    Confidential { sc with adversary := adv' }
    -- Still confidential even with the long-term key
```

### SecurityTransform

Abstracting over TLS, DTLS, IPsec, etc.:

```
/-- A security transform wraps a ByteStream, providing security properties.
    Different transforms have different properties and operate at different layers. -/
structure SecurityTransform (α : Type) where
  /-- Encrypt/authenticate a plaintext record, producing ciphertext bytes. -/
  protect : α → SecurityState → List UInt8 × SecurityState
  /-- Decrypt/verify ciphertext bytes, producing a plaintext record or error. -/
  unprotect : List UInt8 → SecurityState → Option α × SecurityState
  /-- Round-trip correctness. -/
  roundtrip : ∀ msg st,
    let (ct, st') := protect msg st
    (unprotect ct st').1 = some msg

/-- TLS 1.3 as a SecurityTransform. -/
def tls13Transform : SecurityTransform TlsRecord where
  protect := tlsEncryptRecord    -- AEAD encrypt with traffic key + sequence number
  unprotect := tlsDecryptRecord  -- AEAD decrypt, verify tag, check sequence
  roundtrip := tls13_roundtrip   -- correctness follows from AEAD correctness
```

### Connecting to Existing SWELib Modules

The existing security modules provide the building blocks:

```
-- Hashing (Security/Hashing.lean):
-- hmac is the MAC used inside TLS for key derivation and Finished messages
-- sha256Hash/sha384Hash are used in transcript hashing

-- RSA (Security/Crypto/Rsa.lean):
-- rsasp1/rsavp1 are used in TLS RSA signature for CertificateVerify
-- rsaep/rsadp are used in TLS RSA key exchange (TLS 1.2 only)

-- ECDSA (Security/Crypto/Ecdsa.lean):
-- ecdsaSign/ecdsaVerify are used in TLS ECDSA signature for CertificateVerify

-- ECDH (Security/Crypto/Ecdh.lean):
-- ecdhSharedSecret25519/448 are used in TLS 1.3 key exchange

-- PKI (Security/Pki):
-- validateCertificatePath is used during TLS handshake to verify peer certificate
-- The trust chain from certificate → trust anchor establishes Node identity

-- JWT (Security/Jwt):
-- JWT operates at the MessageStream level (above TLS)
-- A JWT is a message-level authentication token carried over a secure channel
-- JWT validation = verifying a claim about Node identity at the application layer
```

## TLS Handshake as LTS

The TLS handshake is itself an LTS that composes with the adversary. The existing `TlsState` in `Networking/Tls/StateMachine.lean` defines the control-flow states. The full handshake LTS includes message exchange:

```
-- TLS 1.3 handshake as CCS process:
--
-- Client                    Server
--   |--- ClientHello -------->|     (key shares, supported versions)
--   |<-- ServerHello ---------|     (selected key share, selected version)
--   |<-- EncryptedExtensions -|     [encrypted from here on]
--   |<-- Certificate ---------|     (server's cert chain)
--   |<-- CertificateVerify ---|     (signature over transcript)
--   |<-- Finished ------------|     (MAC over transcript)
--   |--- Finished ----------->|     (MAC over transcript)
--   |<== Application Data ===>|     [bidirectional secure channel]

-- In CCS terms:
TlsHandshake = Client | Channel | Server
-- where Client and Server are LTS with states from TlsState
-- and actions are handshake messages

-- The handshake ESTABLISHES the SecureChannel.
-- Before: Channel is a plain ByteStream (insecure)
-- After: Channel is wrapped with TLS (secure)
-- The transition from insecure to secure IS the handshake protocol
```

### Handshake Security Theorems

```
-- If the handshake completes, the established keys are known only to
-- Client and Server (not the adversary), assuming:
-- 1. The adversary is Dolev-Yao (can intercept/inject, can't break crypto)
-- 2. The server's private key is not compromised
-- 3. The client validates the certificate chain to a trusted root

theorem tls13_key_secrecy
  (h_adv : adv = dolevYao networkChannels)
  (h_key : serverPrivateKey ∉ adv.knowledge)
  (h_cert : validCertPath serverCert trustAnchors) :
  handshakeCompletes client server adv →
  trafficKeys ∉ adv.derivableKnowledge

-- TLS 1.3 forward secrecy: compromising the server's long-term key
-- after the handshake doesn't compromise the session keys
-- (because key exchange uses ephemeral ECDH)
theorem tls13_forward_secrecy
  (h_ephemeral : usesEphemeralKeyExchange handshake)
  (h_completed : handshakeCompleted handshake) :
  let adv' := adv.withLateKeyCompromise serverPrivateKey
  sessionKeys ∉ adv'.derivableKnowledge
```

## Secure System Composition

### System with TLS Channels

When Nodes in a System communicate over TLS, the System's CCS term includes the TLS transform:

```
-- Insecure System (from sketch 02):
InsecureSystem = (AppServer | reliableFIFO | Database) \ internal

-- Secure System:
-- The channel includes TLS encryption
-- The adversary is explicitly present but cannot read/modify traffic
SecureSystem = (AppServer | tlsChannel | Database | Adversary) \ internal

-- where:
-- tlsChannel = reliableFIFO composed with TLS record layer
-- tlsChannel.deliver_to_receiver msg =
--   reliableFIFO.deliver_to_receiver (tlsEncrypt msg)
-- then receiver does tlsDecrypt to get msg back

-- The adversary CAN observe the ciphertext on the reliableFIFO channel
-- The adversary CANNOT derive the plaintext (confidentiality)
-- The adversary CANNOT modify the plaintext undetected (integrity)
```

### Authentication Composes with Node Identity

Node identity (sketch 01) gains a cryptographic grounding through certificates:

```
/-- A Node's cryptographic identity, established by PKI. -/
structure NodeIdentity where
  /-- The Node's certificate (from Security/Pki). -/
  certificate : Certificate
  /-- The private key corresponding to the certificate's public key. -/
  privateKey : PrivateKey
  /-- The certificate is valid (path validates to a trust anchor). -/
  certValid : PathValidationResult

/-- Authentication at the System level:
    a Node's identity is verified before it joins the System. -/
def authenticatedSystem (nodes : List (NodeId × NodeIdentity × Node))
  (trustAnchors : List TrustAnchor) : System :=
  -- Only include Nodes whose certificates validate
  let verified := nodes.filter fun (_, id, _) =>
    validateCertificatePath id.certificate trustAnchors
  -- Compose verified Nodes with secure channels
  composeWithTls verified
```

### Authorization as Channel Restriction

Authorization determines which channels a Node can use. In CCS terms, authorization = restricting a Node's action alphabet based on its identity:

```
-- Without authorization: AppServer can talk to Database on any channel
System = (AppServer | Database) \ internal

-- With authorization: AppServer can only use authorized channels
-- This is CCS restriction applied based on identity/role
AuthorizedSystem = (AppServer | Database) \ unauthorized_channels \ internal

-- JWT-based authorization (existing Security/Jwt):
-- A request carries a JWT; the receiving Node validates it
-- and only processes the request if the JWT grants the required permission

-- In LTS terms: the receiving Node's transition relation includes
-- a guard on the JWT claims
-- recv_request(req) → if validateJwt(req.jwt) then process else reject
```

## Connection to Existing SWELib Modules

### Direct Relationships

| Module | Role in Security Framework |
|--------|---------------------------|
| `Security/Crypto/Rsa` | Key operations for TLS handshake (signing CertificateVerify) |
| `Security/Crypto/Ecdsa` | Key operations for TLS handshake (ECDSA CertificateVerify) |
| `Security/Crypto/Ecdh` | Key exchange for TLS 1.3 (ephemeral ECDH → forward secrecy) |
| `Security/Crypto/EllipticCurve` | Curve operations underlying ECDSA and ECDH |
| `Security/Hashing` | HMAC for TLS key derivation, transcript hashing |
| `Security/Pki` | Certificate validation during TLS handshake → Node authentication |
| `Security/Jwt` | Application-layer authentication over a secure channel |
| `Security/Iam/Gcp` | Authorization policies → channel restriction at Node level |
| `Networking/Tls` | TLS state machine and types → the SecurityTransform implementation |
| `Networking/Http/Auth` | HTTP-layer auth challenges → application protocol over secure channel |
| `OS/Capabilities` | Node-internal privilege restriction (defense in depth within a Node) |

### Layering

```
Layer 4: Authorization    JWT validation, IAM policies, capability checks
         (who can do what)
         ↕ uses secure channel established by layer 3
Layer 3: Transport Security    TLS/DTLS (SecureChannel over ByteStream)
         (encrypted pipe)
         ↕ transforms ByteStream from layer 2
Layer 2: ByteStream       TCP byte stream (sketch 06)
         (reliable bytes)
         ↕ implements ChannelProcess from layer 1
Layer 1: Channel          CCS ChannelProcess (sketch 05)
         (abstract comm)
```

Each layer adds properties:
- Layer 1: delivery semantics (reliable, lossy, FIFO, etc.)
- Layer 2: byte-level abstraction (boundary erasure, fd binding)
- Layer 3: confidentiality + integrity + authentication
- Layer 4: authorization (which authenticated entity can do what)

### What's Already Formalized vs What This Sketch Adds

**Already formalized** (in existing SWELib modules):
- Cryptographic primitives (RSA, ECDSA, ECDH, HMAC, hashing)
- Certificate structures and path validation (PKI)
- JWT creation, parsing, validation
- TLS type definitions and state machine skeleton
- HTTP auth challenges
- OS capabilities

**This sketch adds**:
- Adversary model as an LTS Node in the System
- Security properties (confidentiality, integrity, authentication) as LTS predicates
- SecureChannel connecting existing crypto to the Channel/ByteStream framework
- TLS handshake as a composed LTS that establishes a SecureChannel
- Authentication grounding Node identity in PKI certificates
- Authorization as CCS channel restriction

## Key Theorems Sketch

### Channel Security

- A TLS 1.3 channel is confidential against a Dolev-Yao adversary (assuming AEAD security)
- A TLS 1.3 channel is integral — the adversary cannot modify plaintext undetected (AEAD authentication tag)
- A TLS 1.3 channel provides forward secrecy (ephemeral ECDH key exchange)
- Downgrade protection: TLS 1.3 handshake detects if the adversary forces a weaker protocol version (transcript hash covers version negotiation)

### Authentication

- If TLS handshake completes with mutual auth, both Nodes have verified each other's identity via PKI certificate chain
- Node identity established by TLS is as strong as the weakest link in the certificate path (if any intermediate CA is compromised, the identity is meaningless)
- JWT validation over a TLS channel provides end-to-end authentication at the application layer (the TLS channel authenticates the transport; the JWT authenticates the user/service)

### Composition

- A System where all inter-Node channels are TLS-protected is secure against a Dolev-Yao adversary controlling the network (standard secure channel composition)
- Replacing a plaintext channel with a TLS channel in a System preserves all functional properties (TLS is transparent to the application — same ByteStream interface)
- Adding an adversary Node to a System with all-TLS channels doesn't break safety properties (the adversary can't interfere with secure channels)

### Authorization

- If authorization restricts a Node's channels, the Node cannot perform actions on restricted channels (CCS restriction + authorization check)
- JWT-based authorization is sound: if the JWT validates, the claims are authentic (signature verification + claim checking from `Security/Jwt/Validate`)

## Extension Points

### Formal Protocol Verification (future)

Full symbolic protocol verification a la ProVerif/Tamarin:

```
-- Today: security properties stated as LTS predicates with crypto axioms
-- Future: mechanized protocol verification using equational theories
--
-- The Dolev-Yao model + algebraic properties of crypto primitives
-- (e.g., decrypt(encrypt(m, k), k) = m) enable automated reasoning
-- about protocol security.
--
-- This requires:
-- 1. An equational theory for cryptographic primitives (in CSLib)
-- 2. A term algebra for messages (nonces, keys, encryptions, hashes)
-- 3. An intruder deduction system (Dolev-Yao closure)
-- 4. Reachability/equivalence checking over the protocol's LTS
```

### Quantitative Security (future, needs probabilistic models)

```
-- Today: "adversary cannot break the scheme" (symbolic/all-or-nothing)
-- Future: "adversary breaks the scheme with probability ≤ 2^{-128}"
-- Requires probabilistic LTS and computational security definitions
-- Connects to: advantage definitions, reduction proofs, concrete security bounds
```

### Side Channels (future, needs timed models)

```
-- Today: adversary observes messages on channels (content only)
-- Future: adversary observes timing of messages (timing side channels)
-- Requires timed CCS/LTS
-- Relevant for: constant-time crypto, traffic analysis, padding oracle attacks
```

## Byzantine Fault Tolerance: Security at the Distributed Systems Level

The security model above focuses on **channel-level security**: protecting communication between honest Nodes against an external adversary. Byzantine fault tolerance (BFT) addresses a different threat: **compromised Nodes** — Nodes that have been taken over by the adversary and can send arbitrary (malicious) messages.

### How Byzantine Nodes Fit the Framework

In sketch 01, a Byzantine Node is already defined:

```
-- From sketch 01: a Node is Byzantine if after a fault action,
-- any transition is possible
def Node.isByzantine (n : Node S α) : Prop :=
  ∃ s_fault, ∀ a s', n.lts.Tr s_fault a s'
```

This means: after entering a fault state, the Node can produce *any* output on *any* channel. It can lie, equivocate (say different things to different Nodes), stay silent, or perfectly impersonate an honest Node. This is strictly stronger than the channel-level adversary — it's an adversary *inside* the System's trust boundary.

### The Relationship Between Channel Security and BFT

Channel security and BFT are complementary:

```
Channel security (TLS):
  - Honest Nodes, adversarial network
  - Adversary controls channels between Nodes
  - Guarantee: adversary can't read/modify/forge messages
  - Solved by: cryptography (TLS, signatures, MACs)

Byzantine fault tolerance:
  - Some Nodes are adversarial (compromised / buggy / malicious)
  - Adversary controls up to f out of n Nodes
  - Guarantee: System-level properties hold despite Byzantine Nodes
  - Solved by: redundancy + voting (BFT consensus protocols)

Combined:
  - Some Nodes are Byzantine AND the network is adversarial
  - This is the realistic threat model for internet-scale systems
  - Requires both TLS (to protect honest-to-honest communication)
  - AND BFT protocols (to tolerate compromised Nodes)
```

### BFT as a System-Level Security Property

BFT safety is already expressible in the sketch 02 framework:

```
-- "The System is BFT-safe with threshold f"
-- = the System's safety properties hold for ANY behavior of up to f Nodes

theorem bft_safety (sys : System) (P : SafetyProperty)
  (h_protocol : implementsBFTProtocol sys)
  (h_threshold : byzantineCount sys ≤ f)
  (h_bound : f < sys.nodes.card / 3) :       -- BFT requires f < n/3
  P sys

-- Compare to crash-fault tolerance (sketch 02):
-- f < n/2 for crash faults (Paxos/Raft)
-- f < n/3 for Byzantine faults (PBFT, HotStuff, Tendermint)
-- The difference: Byzantine nodes can equivocate, crash-stop nodes can't
```

### Formalization Plan for BFT

BFT formalization builds on the existing framework in stages:

**Stage 1: Byzantine Node model** (already sketched in 01)
- Byzantine Node = LTS where fault state enables arbitrary transitions
- `Node.isByzantine` predicate already defined
- Extends naturally: partial Byzantine (limited equivocation), rational Byzantine (game-theoretic)

**Stage 2: BFT protocol specifications** (extends existing `Distributed/`)
- PBFT as a CCS composition of Nodes with Byzantine fault assumptions
- HotStuff / Tendermint as optimized variants with different round structures
- Safety: agreement + validity hold with f < n/3 Byzantine Nodes
- Liveness: termination holds under partial synchrony (needs timed CCS — future)

**Stage 3: BFT + authenticated channels**
- Byzantine Nodes with TLS: a Byzantine Node can use its own private key to sign arbitrary messages, but cannot forge another honest Node's signature
- Digital signatures prevent equivocation (send-to-all is verifiable)
- This reduces the BFT threshold: with signatures, some results improve from f < n/3 to f < n/2 (DLS result)

**Stage 4: Blockchain / permissionless BFT** (further future)
- Nakamoto consensus: probabilistic BFT with proof-of-work
- Proof-of-stake: BFT where f is measured in stake, not nodes
- These need probabilistic LTS (not yet in CSLib)

### Key BFT Theorems (Sketch)

```
-- PBFT safety: agreement holds with f < n/3
theorem pbft_agreement (sys : PBFTSystem)
  (h_bound : byzantineCount sys < sys.nodes.card / 3) :
  ∀ (honest₁ honest₂ : Node), honest₁.decided = honest₂.decided

-- BFT impossibility: no deterministic BFT protocol with f ≥ n/3
-- (Fischer-Lynch-Paterson for Byzantine case)
theorem bft_impossibility :
  ∀ (protocol : BFTProtocol),
    deterministic protocol →
    asynchronousNetwork protocol →
    f ≥ n / 3 →
    ¬ (safe protocol ∧ live protocol)

-- Authenticated BFT: with digital signatures, crash tolerance improves
-- DLS (Dwork-Lynch-Stockmeyer): f < n/2 with signatures + partial sync
theorem dls_authenticated_bft
  (h_signatures : allNodesSigned sys)
  (h_partialsync : partiallySynchronous sys.network)
  (h_bound : byzantineCount sys < sys.nodes.card / 2) :
  safe sys ∧ live sys
```

### BFT Source Specs

- **Lamport, Shostak, Pease, "The Byzantine Generals Problem"** (1982): the original BFT definition and f < n/3 bound
- **Castro & Liskov, "Practical Byzantine Fault Tolerance"** (1999): PBFT — first practical BFT protocol
- **Yin et al., "HotStuff"** (2019): linear BFT with pipelining
- **Buchman et al., "Tendermint"** (2018): BFT for blockchains
- **Dwork, Lynch, Stockmeyer** (1988): authenticated BFT under partial synchrony
- **Nakamoto, "Bitcoin"** (2008): probabilistic BFT via proof-of-work
- **CSLib**: LTS composition with Byzantine fault transitions — the formal foundation

## Module Structure

```
spec/SWELib/
├── Security/
│   ├── Crypto/                         -- (existing) cryptographic primitives
│   │   ├── Rsa.lean
│   │   ├── EllipticCurve.lean
│   │   ├── Ecdsa.lean
│   │   ├── Ecdh.lean
│   │   └── Montgomery.lean
│   ├── Hashing.lean                    -- (existing) SHA, HMAC
│   ├── Pki/                            -- (existing) X.509, trust anchors
│   ├── Jwt/                            -- (existing) JWT creation/validation
│   ├── Iam/                            -- (existing) IAM/authorization
│   ├── Adversary.lean                  -- NEW: AdversaryModel, Dolev-Yao, capabilities
│   ├── Properties.lean                 -- NEW: Confidential, Integral, Authenticated, ForwardSecrecy
│   └── SecureChannel.lean              -- NEW: SecureChannel, SecurityTransform
│
├── Networking/
│   ├── Tls/                            -- (existing, extend)
│   │   ├── ...                         -- existing type definitions
│   │   ├── HandshakeLTS.lean           -- NEW: TLS handshake as LTS for composition
│   │   └── SecurityProofs.lean         -- NEW: TLS security theorems (uses Adversary + Properties)
│   └── ...
│
├── Distributed/
│   ├── Byzantine/                      -- NEW (future): BFT protocol formalizations
│   │   ├── Types.lean                  -- Byzantine Node predicates (from sketch 01)
│   │   ├── PBFT.lean                   -- PBFT protocol specification
│   │   └── Theorems.lean               -- BFT safety/liveness/impossibility
│   └── ...
│
└── Foundations/
    └── Security/                       -- NEW: foundational security types
        ├── AdversaryModel.lean         -- Dolev-Yao and computational adversaries
        └── SecurityProperties.lean     -- Abstract confidentiality/integrity/auth definitions
```

The new modules are leaves that import from existing ones. `Security/Adversary.lean` imports nothing from SWELib (it defines abstract adversary models). `Security/SecureChannel.lean` imports `Adversary`, `Properties`, and the existing crypto modules. `Networking/Tls/SecurityProofs.lean` imports everything and connects the pieces.

## Source Specs / Prior Art

### Channel Security
- **Dolev & Yao, "On the security of public key protocols"** (1983): the standard network adversary model
- **RFC 8446** (TLS 1.3): the concrete secure channel protocol
- **RFC 5246** (TLS 1.2): predecessor protocol
- **Blanchet, "An Efficient Cryptographic Protocol Verifier Based on Prolog Rules"** (2001): ProVerif — automated protocol verification in the symbolic model
- **Meier et al., "The TAMARIN Prover"** (2013): protocol verification with equational theories

### Byzantine Fault Tolerance
- **Lamport, Shostak, Pease** (1982): Byzantine Generals, f < n/3 bound
- **Fischer, Lynch, Paterson** (1985): FLP impossibility (async + 1 crash fault)
- **Dwork, Lynch, Stockmeyer** (1988): consensus under partial synchrony, authenticated BFT
- **Castro & Liskov** (1999): PBFT
- **Yin et al.** (2019): HotStuff

### Formal Foundations
- **CSLib**: LTS for protocol state machines, bisimulation for security equivalences, CCS for adversary composition
- **Abadi & Rogaway, "Reconciling Two Views of Cryptography"** (2000): connecting symbolic and computational security models
- **Canetti, "Universally Composable Security"** (2001): UC framework for composable security proofs (future target for compositional security in the System framework)
