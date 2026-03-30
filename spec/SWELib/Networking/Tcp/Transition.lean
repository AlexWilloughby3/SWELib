import SWELib.Networking.Tcp.SeqNum
import SWELib.Networking.Tcp.Segment
import SWELib.Networking.Tcp.State
import SWELib.Networking.Tcp.Tcb
import SWELib.Networking.Tcp.Events

/-!
# TCP State Transitions

RFC 9293 Section 3.6 (Figure 5) and Section 3.10: The TCP state machine
transition function, driven by events and segment arrivals.
-/

namespace SWELib.Networking.Tcp

/-- Check whether an ACK is acceptable: SND.UNA < SEG.ACK <= SND.NXT
    (RFC 9293 Section 3.10.7.4). -/
def acceptableAck (tcb : TCB) (seg_ack : SeqNum) : Bool :=
  seqLt tcb.snd_una seg_ack && seqLe seg_ack tcb.snd_nxt

/-- Check whether an incoming segment is acceptable based on sequence number
    and window (RFC 9293 Section 3.10.7.4, Table 5). -/
def acceptableSegment (tcb : TCB) (sv : SegmentVariables) : Bool :=
  match sv.seg_len == 0, tcb.rcv_wnd == 0 with
  | true, true   => sv.seg_seq == tcb.rcv_nxt
  | true, false  => seqLe tcb.rcv_nxt sv.seg_seq &&
                     seqLt sv.seg_seq (seqAddNat tcb.rcv_nxt tcb.rcv_wnd)
  | false, true  => false
  | false, false => (seqLe tcb.rcv_nxt sv.seg_seq &&
                      seqLt sv.seg_seq (seqAddNat tcb.rcv_nxt tcb.rcv_wnd)) ||
                     (seqLe tcb.rcv_nxt (seqAddNat sv.seg_seq (sv.seg_len - 1)) &&
                      seqLt (seqAddNat sv.seg_seq (sv.seg_len - 1))
                             (seqAddNat tcb.rcv_nxt tcb.rcv_wnd))

/-- Right edge of the send window: SND.UNA + SND.WND
    (RFC 9293 Section 3.3.1). -/
def sendWindowRight (tcb : TCB) : SeqNum :=
  seqAddNat tcb.snd_una tcb.snd_wnd

/-- Right edge of the receive window: RCV.NXT + RCV.WND
    (RFC 9293 Section 3.3.1). -/
def recvWindowRight (tcb : TCB) : SeqNum :=
  seqAddNat tcb.rcv_nxt tcb.rcv_wnd

/-- Helper: construct a minimal segment with given flags and sequence numbers. -/
private def mkSegment (srcPort dstPort : Port) (seqN ackN : SeqNum)
    (fl : ControlFlags) : TcpSegment :=
  { srcPort := srcPort
    dstPort := dstPort
    seqNum := seqN
    ackNum := ackN
    dataOffset := 5
    flags := fl
    window := 0
    checksum := 0
    urgentPointer := 0 }

/-- Default initial sequence number (placeholder; real implementations
    use a clock-based ISN generator per RFC 9293 Section 3.4.1). -/
private def defaultISN : SeqNum := SeqNum.ofNat 0

/-- Default TCB for a newly created connection. -/
private def defaultTCB (lp rp : Port) (st : TcpState) : TCB :=
  { snd_una := defaultISN
    snd_nxt := defaultISN
    snd_wnd := 0
    snd_up := defaultISN
    snd_wl1 := defaultISN
    snd_wl2 := defaultISN
    iss := defaultISN
    rcv_nxt := defaultISN
    rcv_wnd := 65535
    rcv_up := defaultISN
    irs := defaultISN
    localPort := lp
    remotePort := rp
    state := st }

/-- TCP state machine transition function (RFC 9293 Section 3.10).

    Given the current state, an event, and the TCB, returns the new state,
    a list of actions to perform, and the updated TCB.

    This implements the key transitions from RFC 9293 Figure 5.
    Transitions not explicitly handled return the current state with no action. -/
def tcpTransition (st : TcpState) (ev : TcpEvent) (tcb : TCB)
    : TcpState × List TcpAction × TCB :=
  match st, ev with
  -- CLOSED + PassiveOpen -> LISTEN (RFC 9293 Section 3.9.1)
  | .closed, .passiveOpen lp =>
    let tcb' := defaultTCB lp 0 .listen
    (.listen, [.noop], tcb')

  -- CLOSED + ActiveOpen -> SYN_SENT (RFC 9293 Section 3.9.1)
  | .closed, .activeOpen lp rp =>
    let iss := defaultISN
    let synSeg := mkSegment lp rp iss (SeqNum.ofNat 0) { syn := true }
    let tcb' := { defaultTCB lp rp .synSent with
                   iss := iss
                   snd_una := iss
                   snd_nxt := seqAddNat iss 1 }
    (.synSent, [.sendSegment synSeg], tcb')

  -- LISTEN + SegmentArrives(SYN) -> SYN_RECEIVED (RFC 9293 Section 3.10.7.2)
  | .listen, .segmentArrives seg =>
    if seg.flags.syn then
      let iss := defaultISN
      let synAckSeg := mkSegment tcb.localPort seg.srcPort iss
                          (seqAddNat seg.seqNum 1) { syn := true, ack := true }
      let tcb' := { tcb with
                      irs := seg.seqNum
                      rcv_nxt := seqAddNat seg.seqNum 1
                      iss := iss
                      snd_una := iss
                      snd_nxt := seqAddNat iss 1
                      remotePort := seg.srcPort
                      state := .synReceived
                      synRcvdOrigin := some .fromPassiveOpen }
      (.synReceived, [.sendSegment synAckSeg], tcb')
    else
      (st, [.noop], tcb)

  -- SYN_SENT + SegmentArrives (RFC 9293 Section 3.10.7.3)
  | .synSent, .segmentArrives seg =>
    if seg.flags.syn && seg.flags.ack then
      -- SYN+ACK: complete three-way handshake -> ESTABLISHED
      if acceptableAck tcb seg.ackNum then
        let ackSeg := mkSegment tcb.localPort tcb.remotePort
                        tcb.snd_nxt (seqAddNat seg.seqNum 1) { ack := true }
        let tcb' := { tcb with
                        irs := seg.seqNum
                        rcv_nxt := seqAddNat seg.seqNum 1
                        snd_una := seg.ackNum
                        snd_wnd := seg.window.toNat
                        snd_wl1 := seg.seqNum
                        snd_wl2 := seg.ackNum
                        state := .established }
        (.established, [.sendSegment ackSeg], tcb')
      else
        -- Unacceptable ACK: send RST
        let rstSeg := mkSegment tcb.localPort tcb.remotePort
                        seg.ackNum (SeqNum.ofNat 0) { rst := true }
        (.synSent, [.sendSegment rstSeg], tcb)
    else if seg.flags.syn && !seg.flags.ack then
      -- Bare SYN: simultaneous open -> SYN_RECEIVED
      let synAckSeg := mkSegment tcb.localPort tcb.remotePort
                        tcb.iss (seqAddNat seg.seqNum 1) { syn := true, ack := true }
      let tcb' := { tcb with
                      irs := seg.seqNum
                      rcv_nxt := seqAddNat seg.seqNum 1
                      state := .synReceived
                      synRcvdOrigin := some .fromActiveOpen }
      (.synReceived, [.sendSegment synAckSeg], tcb')
    else
      (.synSent, [.noop], tcb)

  -- SYN_RECEIVED + SegmentArrives(ACK) -> ESTABLISHED (RFC 9293 Section 3.10.7.4)
  | .synReceived, .segmentArrives seg =>
    if seg.flags.ack && !seg.flags.syn && !seg.flags.rst then
      if acceptableAck tcb seg.ackNum then
        let tcb' := { tcb with
                        snd_una := seg.ackNum
                        snd_wnd := seg.window.toNat
                        snd_wl1 := seg.seqNum
                        snd_wl2 := seg.ackNum
                        state := .established }
        (.established, [.noop], tcb')
      else
        (.synReceived, [.noop], tcb)
    else
      (.synReceived, [.noop], tcb)

  -- ESTABLISHED + SegmentArrives(FIN) -> CLOSE_WAIT (RFC 9293 Section 3.10.7.4)
  | .established, .segmentArrives seg =>
    if seg.flags.fin then
      let ackSeg := mkSegment tcb.localPort tcb.remotePort
                      tcb.snd_nxt (seqAddNat seg.seqNum (segLen seg)) { ack := true }
      let tcb' := { tcb with
                      rcv_nxt := seqAddNat seg.seqNum (segLen seg)
                      state := .closeWait }
      (.closeWait, [.sendSegment ackSeg], tcb')
    else
      -- Data segment in ESTABLISHED: simplified handling
      (.established, [.noop], tcb)

  -- ESTABLISHED + Close -> FIN_WAIT_1 (RFC 9293 Section 3.9.1)
  | .established, .close =>
    let finSeg := mkSegment tcb.localPort tcb.remotePort
                    tcb.snd_nxt (SeqNum.ofNat 0) { fin := true, ack := true }
    let tcb' := { tcb with
                    snd_nxt := seqAddNat tcb.snd_nxt 1
                    state := .finWait1 }
    (.finWait1, [.sendSegment finSeg], tcb')

  -- FIN_WAIT_1 + SegmentArrives(ACK of FIN) -> FIN_WAIT_2
  | .finWait1, .segmentArrives seg =>
    if seg.flags.ack && !seg.flags.fin then
      let tcb' := { tcb with
                      snd_una := seg.ackNum
                      state := .finWait2 }
      (.finWait2, [.noop], tcb')
    else if seg.flags.fin && seg.flags.ack then
      -- FIN+ACK: go to TIME_WAIT (our FIN was also acked)
      let ackSeg := mkSegment tcb.localPort tcb.remotePort
                      tcb.snd_nxt (seqAddNat seg.seqNum (segLen seg)) { ack := true }
      let tcb' := { tcb with
                      rcv_nxt := seqAddNat seg.seqNum (segLen seg)
                      snd_una := seg.ackNum
                      state := .timeWait }
      (.timeWait, [.sendSegment ackSeg], tcb')
    else if seg.flags.fin then
      -- FIN without ACK of our FIN: simultaneous close -> CLOSING
      let ackSeg := mkSegment tcb.localPort tcb.remotePort
                      tcb.snd_nxt (seqAddNat seg.seqNum (segLen seg)) { ack := true }
      let tcb' := { tcb with
                      rcv_nxt := seqAddNat seg.seqNum (segLen seg)
                      state := .closing }
      (.closing, [.sendSegment ackSeg], tcb')
    else
      (.finWait1, [.noop], tcb)

  -- FIN_WAIT_2 + SegmentArrives(FIN) -> TIME_WAIT
  | .finWait2, .segmentArrives seg =>
    if seg.flags.fin then
      let ackSeg := mkSegment tcb.localPort tcb.remotePort
                      tcb.snd_nxt (seqAddNat seg.seqNum (segLen seg)) { ack := true }
      let tcb' := { tcb with
                      rcv_nxt := seqAddNat seg.seqNum (segLen seg)
                      state := .timeWait }
      (.timeWait, [.sendSegment ackSeg], tcb')
    else
      (.finWait2, [.noop], tcb)

  -- CLOSE_WAIT + Close -> LAST_ACK (RFC 9293 Section 3.9.1)
  | .closeWait, .close =>
    let finSeg := mkSegment tcb.localPort tcb.remotePort
                    tcb.snd_nxt (SeqNum.ofNat 0) { fin := true, ack := true }
    let tcb' := { tcb with
                    snd_nxt := seqAddNat tcb.snd_nxt 1
                    state := .lastAck }
    (.lastAck, [.sendSegment finSeg], tcb')

  -- LAST_ACK + SegmentArrives(ACK) -> CLOSED
  | .lastAck, .segmentArrives seg =>
    if seg.flags.ack then
      let tcb' := { tcb with state := .closed }
      (.closed, [.deleteTcb], tcb')
    else
      (.lastAck, [.noop], tcb)

  -- CLOSING + SegmentArrives(ACK) -> TIME_WAIT
  | .closing, .segmentArrives seg =>
    if seg.flags.ack then
      let tcb' := { tcb with
                      snd_una := seg.ackNum
                      state := .timeWait }
      (.timeWait, [.noop], tcb')
    else
      (.closing, [.noop], tcb)

  -- TIME_WAIT + TimeoutTimeWait -> CLOSED
  | .timeWait, .timeoutTimeWait =>
    let tcb' := { tcb with state := .closed }
    (.closed, [.deleteTcb], tcb')

  -- Default: no transition
  | _, _ => (st, [.noop], tcb)

-- Theorems

/-- Three-way handshake client side: SYN_SENT + SYN+ACK -> ESTABLISHED
    (RFC 9293 Section 3.5, Figure 6). -/
theorem three_way_handshake_client (tcb : TCB) (synack : TcpSegment)
    (h_syn : synack.flags.syn = true) (h_ack : synack.flags.ack = true)
    (h_acceptable : acceptableAck tcb synack.ackNum = true) :
    (tcpTransition TcpState.synSent (TcpEvent.segmentArrives synack) tcb).1
      = TcpState.established := by
  simp [tcpTransition, h_syn, h_ack, h_acceptable]

/-- Three-way handshake server side: SYN_RECEIVED + ACK -> ESTABLISHED
    (RFC 9293 Section 3.5, Figure 6). -/
theorem three_way_handshake_server (tcb : TCB) (ack_seg : TcpSegment)
    (h_ack : ack_seg.flags.ack = true) (h_no_syn : ack_seg.flags.syn = false)
    (h_no_rst : ack_seg.flags.rst = false)
    (h_acceptable : acceptableAck tcb ack_seg.ackNum = true) :
    (tcpTransition TcpState.synReceived (TcpEvent.segmentArrives ack_seg) tcb).1
      = TcpState.established := by
  simp [tcpTransition, h_ack, h_no_syn, h_no_rst, h_acceptable]

/-- Simultaneous open: SYN_SENT + bare SYN -> SYN_RECEIVED
    (RFC 9293 Section 3.5). -/
theorem simultaneous_open_step (tcb : TCB) (syn : TcpSegment)
    (h_syn : syn.flags.syn = true) (h_no_ack : syn.flags.ack = false) :
    (tcpTransition TcpState.synSent (TcpEvent.segmentArrives syn) tcb).1
      = TcpState.synReceived := by
  simp [tcpTransition, h_syn, h_no_ack]

/-- CLOSED + PassiveOpen -> LISTEN (RFC 9293 Section 3.9.1). -/
theorem passive_open_transitions (tcb : TCB) (p : Port) :
    (tcpTransition TcpState.closed (TcpEvent.passiveOpen p) tcb).1
      = TcpState.listen := by
  simp [tcpTransition]

/-- ESTABLISHED + Close -> FIN_WAIT_1 (RFC 9293 Section 3.9.1). -/
theorem close_established (tcb : TCB) :
    (tcpTransition TcpState.established TcpEvent.close tcb).1
      = TcpState.finWait1 := by
  simp [tcpTransition]

/-- TIME_WAIT + TimeoutTimeWait -> CLOSED (RFC 9293 Section 3.4.1). -/
theorem time_wait_expires (tcb : TCB) :
    (tcpTransition TcpState.timeWait TcpEvent.timeoutTimeWait tcb).1
      = TcpState.closed := by
  simp [tcpTransition]

end SWELib.Networking.Tcp
