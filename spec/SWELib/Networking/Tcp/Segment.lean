import SWELib.Networking.Tcp.SeqNum

/-!
# TCP Segments

RFC 9293 Section 3.1: TCP segment header format and segment length computation.
-/

namespace SWELib.Networking.Tcp

private instance : Repr ByteArray where
  reprPrec ba _ := repr ba.toList

/-- TCP port number (RFC 9293 Section 3.1). -/
abbrev Port := UInt16

/-- TCP control flags (RFC 9293 Section 3.1, Figure 1).
    Each flag occupies one bit in the TCP header. -/
structure ControlFlags where
  /-- Congestion Window Reduced (RFC 3168). -/
  cwr : Bool := false
  /-- ECN-Echo (RFC 3168). -/
  ece : Bool := false
  /-- Urgent pointer field is significant. -/
  urg : Bool := false
  /-- Acknowledgment field is significant. -/
  ack : Bool := false
  /-- Push function. -/
  psh : Bool := false
  /-- Reset the connection. -/
  rst : Bool := false
  /-- Synchronize sequence numbers. -/
  syn : Bool := false
  /-- No more data from sender. -/
  fin : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- TCP header options (RFC 9293 Section 3.1, simplified). -/
inductive TcpOption where
  /-- End of option list. -/
  | eol
  /-- No operation (padding). -/
  | nop
  /-- Maximum segment size (RFC 9293 Section 3.7.1). -/
  | mss (value : UInt16)
  deriving DecidableEq, Repr

/-- A TCP segment consisting of header fields and payload
    (RFC 9293 Section 3.1, Figure 1). -/
structure TcpSegment where
  /-- Source port. -/
  srcPort : Port
  /-- Destination port. -/
  dstPort : Port
  /-- Sequence number. -/
  seqNum : SeqNum
  /-- Acknowledgment number. -/
  ackNum : SeqNum
  /-- Data offset (number of 32-bit words in the header). -/
  dataOffset : Nat
  /-- Control flags. -/
  flags : ControlFlags
  /-- Window size. -/
  window : UInt16
  /-- Checksum. -/
  checksum : UInt16
  /-- Urgent pointer. -/
  urgentPointer : UInt16
  /-- Header options. -/
  options : List TcpOption := []
  /-- Segment payload. -/
  payload : ByteArray := ByteArray.empty
  deriving Repr

/-- Segment variables extracted from a TCP segment for use in
    protocol processing (RFC 9293 Section 3.4). -/
structure SegmentVariables where
  /-- First sequence number of the segment. -/
  seg_seq : SeqNum
  /-- Acknowledgment from the segment. -/
  seg_ack : SeqNum
  /-- Segment length including SYN/FIN. -/
  seg_len : Nat
  /-- Segment window. -/
  seg_wnd : Nat
  /-- Segment urgent pointer. -/
  seg_up : SeqNum
  deriving Repr

/-- Compute the logical length of a segment (RFC 9293 Section 3.4).
    SYN and FIN each occupy one sequence number. -/
def segLen (seg : TcpSegment) : Nat :=
  seg.payload.size + (if seg.flags.syn then 1 else 0) + (if seg.flags.fin then 1 else 0)

/-- Extract segment variables from a TCP segment for protocol processing. -/
def segmentVariables (seg : TcpSegment) : SegmentVariables :=
  { seg_seq := seg.seqNum
    seg_ack := seg.ackNum
    seg_len := segLen seg
    seg_wnd := seg.window.toNat
    seg_up  := ⟨UInt32.ofNat seg.urgentPointer.toNat⟩ }

-- Theorems

/-- A SYN segment (without FIN) has logical length = payload size + 1. -/
theorem segLen_syn (seg : TcpSegment) (hs : seg.flags.syn = true) (hf : seg.flags.fin = false) :
    segLen seg = seg.payload.size + 1 := by
  simp [segLen, hs, hf]

/-- A FIN segment (without SYN) has logical length = payload size + 1. -/
theorem segLen_fin (seg : TcpSegment) (hf : seg.flags.fin = true) (hs : seg.flags.syn = false) :
    segLen seg = seg.payload.size + 1 := by
  simp [segLen, hs, hf]

/-- A SYN+FIN segment has logical length = payload size + 2. -/
theorem segLen_syn_fin (seg : TcpSegment) (hs : seg.flags.syn = true) (hf : seg.flags.fin = true) :
    segLen seg = seg.payload.size + 2 := by
  simp [segLen, hs, hf]

/-- INV-7: A FIN segment always occupies at least one sequence number. -/
theorem fin_occupies_one_seqnum (seg : TcpSegment) (h : seg.flags.fin = true) :
    segLen seg >= 1 := by
  simp [segLen, h]

end SWELib.Networking.Tcp
