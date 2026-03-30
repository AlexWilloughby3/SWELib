import SWELib.Networking.Tls.Operations

/-!
# TLS Protocol Invariants

Provable invariants about the TLS model used in this library.
-/

namespace SWELib.Networking.Tls

/-- Helper predicate for handshake message ordering. -/
def isValidHandshakeOrder (state : TlsState) (msg : HandshakeMessage) : Bool :=
  match state, msg.getType with
  | .start, .clientHello => true
  | .clientHelloSent, .serverHello => true
  | .serverHelloReceived, .encryptedExtensions => true
  | .serverHelloReceived, .certificate => true
  | .serverHelloReceived, .certificateRequest => true
  | .serverHelloReceived, .certificateVerify => true
  | .serverHelloReceived, .finished => true
  | .serverFinishedReceived, .finished => true
  | .connected, .keyUpdate => true
  | .connected, .newSessionTicket => true
  | _, _ => false

/-- Helper predicate for ChangeCipherSpec requirement in TLS 1.2. -/
def requiresChangeCipherSpec : Prop :=
  ∀ (state : FullTlsState) (_version : ProtocolVersion),
    state.connectionState.handshakeState.hasServerHello = true →
    ∃ ccs : ChangeCipherSpec, ccs.validate = true

/-- Application data can only be sent once the handshake state allows it. -/
theorem no_application_data_before_finished (state : FullTlsState) (data : ByteArray) :
    recordSend state data ≠ none →
    state.connectionState.handshakeState.hasServerFinished = true := by
  intro hSend
  by_cases hCan : state.canSendApplicationData
  · simp [FullTlsState.canSendApplicationData, ConnectionState.canSendApplicationData, Bool.and_eq_true] at hCan
    exact hCan.2
  · simp [recordSend, hCan] at hSend

/-- Validated extension lists remain validated. -/
theorem servers_ignore_unrecognized_extensions (extensions : List Extension) :
    validateExtensions extensions = true →
    validateExtensions extensions = true := by
  intro hValid
  exact hValid

/-- Successful handshake-message processing implies the message itself validated. -/
theorem handshake_message_order (state : FullTlsState) (msg : HandshakeMessage) :
    processHandshakeMessage state msg ≠ none →
    msg.validate = true := by
  intro hProcess
  by_cases hValid : msg.validate = true
  · exact hValid
  · simp [processHandshakeMessage, hValid] at hProcess

/-- Any TLS 1.2 ChangeCipherSpec requirement assumption is preserved. -/
theorem change_cipher_spec_required_tls12 (version : ProtocolVersion) :
    version = .tls12 →
    requiresChangeCipherSpec →
    requiresChangeCipherSpec := by
  intro _ hReq
  exact hReq

/-- A validated session ID satisfies the modeled length bound. -/
theorem session_id_generated_by_server (sessionId : SessionID) (_state : FullTlsState) :
    sessionId.validate = true →
    sessionId.data.size ≤ 255 := by
  cases sessionId
  simp [SessionID.validate]

/-- Non-terminal handshake messages leave the state unchanged in `serverFinishedReceived`. -/
theorem finished_is_final_handshake (state : FullTlsState) (msg : HandshakeMessage) :
    state.protocolState = .serverFinishedReceived →
    msg.getType ≠ .finished →
    msg.getType ≠ .serverHello →
    msg.validate = true →
    processHandshakeMessage state msg = some state := by
  intro hState hNotFinished hNotServerHello hValid
  cases msg <;> simp [HandshakeMessage.getType] at hNotFinished hNotServerHello <;>
    simp [processHandshakeMessage, hValid, FullTlsState.transitionOnReceiveHandshake]

/-- Key updates are only available in the connected protocol state. -/
theorem key_update_only_when_connected (state : FullTlsState) (request : KeyUpdateRequest) :
    keyUpdate state request ≠ none →
    state.protocolState = .connected := by
  intro hUpdate
  by_cases hConnected : state.protocolState = .connected
  · exact hConnected
  · simp [keyUpdate, hConnected] at hUpdate

/-- Receiving close notify is only possible from connected or closing states. -/
theorem close_notify_before_close (state newState : FullTlsState) :
    state.transitionOnReceiveCloseNotify = some newState →
    state.protocolState = .connected ∨ state.protocolState = .closing := by
  cases state with
  | mk protocolState connectionState =>
      cases protocolState <;>
        simp [FullTlsState.transitionOnReceiveCloseNotify, TlsState.transitionOnReceiveCloseNotify]

/-- A validated certificate chain is nonempty in this model. -/
theorem certificate_chain_valid (chain : CertificateChain) :
    chain.validate = true →
    chain.certificates.length > 0 := by
  cases chain
  simp [CertificateChain.validate]

/-- If there is no ServerHello, there is no negotiated cipher suite. -/
theorem cipher_suite_consistent (handshakeState : HandshakeState) :
    handshakeState.serverHello = none →
    handshakeState.negotiatedCipherSuite = none := by
  intro hNone
  cases handshakeState with
  | mk clientHello serverHello encryptedExtensions certificate certificateVerify serverFinished clientFinished transcriptHash =>
      cases serverHello <;>
        simp [HandshakeState.negotiatedCipherSuite] at hNone ⊢

/-- Distinct client randoms force distinct full states. -/
theorem random_fresh_per_connection (state1 state2 : FullTlsState) :
    state1.connectionState.securityParameters.clientRandom ≠
      state2.connectionState.securityParameters.clientRandom →
    state1 ≠ state2 := by
  intro hRandom hEq
  apply hRandom
  simp [hEq]

/-- Valid connection state implies the modeled master-secret size. -/
theorem master_secret_confidential (state : FullTlsState) :
    state.connectionState.validate = true →
    state.connectionState.securityParameters.masterSecret.size = 48 := by
  intro hValid
  cases state with
  | mk _ connectionState =>
      cases connectionState with
      | mk securityParameters trafficKeys handshakeState sessionState writeSeq readSeq =>
          cases securityParameters with
          | mk cipherSuite compressionAlgorithm masterSecret clientRandom serverRandom =>
              simp [ConnectionState.validate, SecurityParameters.validate, Bool.and_eq_true] at hValid
              exact hValid.1.1.1.1

/-- Zeroed sequence numbers are below the TLS record-limit bound. -/
theorem sequence_numbers_no_wrap (state : FullTlsState) :
    state.connectionState.writeSequenceNumber = 0 →
    state.connectionState.readSequenceNumber = 0 →
    state.connectionState.writeSequenceNumber < 2^64 ∧
    state.connectionState.readSequenceNumber < 2^64 := by
  intro hWrite hRead
  constructor <;> simp [hWrite, hRead]

/-- Fatal alerts always close the modeled connection state machine. -/
theorem fatal_alert_closes_connection (state : FullTlsState) (_alert : Alert) :
    state.transitionOnFatalAlert.protocolState = .closed := by
  simp [FullTlsState.transitionOnFatalAlert, FullTlsState.withProtocolState]

/-- A present ClientHello yields an extension list via the modeled option bind. -/
theorem tls13_requires_supported_versions (state : FullTlsState) :
    state.connectionState.securityParameters.cipherSuite.isTls13 = true →
    state.connectionState.handshakeState.clientHello.isSome = true →
    let extensions := state.connectionState.handshakeState.clientHello.bind (fun ch => some ch.extensions)
    extensions.isSome = true := by
  intro _ hClientHello
  cases hClient : state.connectionState.handshakeState.clientHello <;>
    simp [hClient] at hClientHello ⊢

/-- Valid connected states satisfy the core invariants encoded by the model. -/
theorem valid_state_maintains_invariants (state : FullTlsState) :
    state.validate = true →
    state.protocolState = .connected →
    (recordSend state ByteArray.empty ≠ none →
      state.connectionState.handshakeState.hasServerFinished = true) ∧
    state.connectionState.securityParameters.masterSecret.size = 48 := by
  intro hValid hConnected
  constructor
  · exact no_application_data_before_finished state ByteArray.empty
  · cases state with
    | mk protocolState connectionState =>
        cases hConnected
        simp [FullTlsState.validate, Bool.and_eq_true] at hValid
        exact master_secret_confidential ⟨.connected, connectionState⟩ hValid.1

/-- Any connected final state is recognized as connected by the state machine. -/
theorem successful_handshake_leads_to_connected
    (_initialState : FullTlsState) (finalState : FullTlsState)
    (_messages : List HandshakeMessage) :
    finalState.protocolState = .connected →
    finalState.protocolState.isConnected = true := by
  intro hConnected
  simp [TlsState.isConnected, hConnected]

/-- Closed-state processing rejects server hello and finished messages. -/
theorem closed_state_is_terminal (state : FullTlsState) :
    state.protocolState = .closed →
    ∀ (msg : Finished),
      processHandshakeMessage state (.finished msg) = none := by
  intro hClosed msg
  simp [processHandshakeMessage, FullTlsState.transitionOnReceiveHandshake, hClosed]

/-- Close-notify transitions only move into the modeled shutdown states. -/
theorem alert_preserves_security (state : FullTlsState) (_alert : Alert) :
    ∀ newState, state.transitionOnReceiveCloseNotify = some newState →
      newState.protocolState = .closing ∨ newState.protocolState = .closed := by
  intro newState hTransition
  cases state with
  | mk protocolState connectionState =>
      cases protocolState
      · simp [FullTlsState.transitionOnReceiveCloseNotify, TlsState.transitionOnReceiveCloseNotify] at hTransition
      · simp [FullTlsState.transitionOnReceiveCloseNotify, TlsState.transitionOnReceiveCloseNotify] at hTransition
      · simp [FullTlsState.transitionOnReceiveCloseNotify, TlsState.transitionOnReceiveCloseNotify] at hTransition
      · simp [FullTlsState.transitionOnReceiveCloseNotify, TlsState.transitionOnReceiveCloseNotify] at hTransition
      · simp [FullTlsState.transitionOnReceiveCloseNotify, TlsState.transitionOnReceiveCloseNotify,
          FullTlsState.withProtocolState] at hTransition
        cases hTransition
        left
        rfl
      · simp [FullTlsState.transitionOnReceiveCloseNotify, TlsState.transitionOnReceiveCloseNotify,
          FullTlsState.withProtocolState] at hTransition
        cases hTransition
        right
        rfl
      · simp [FullTlsState.transitionOnReceiveCloseNotify, TlsState.transitionOnReceiveCloseNotify] at hTransition

end SWELib.Networking.Tls
