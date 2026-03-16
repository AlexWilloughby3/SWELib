import SWELib.Networking.Tcp.SeqNum
import SWELib.Networking.Tcp.Segment
import SWELib.Networking.Tcp.State

/-!
# Transmission Control Block (TCB)

RFC 9293 Section 3.3.1: The TCB holds all state for a TCP connection,
including send and receive sequence variables.
-/

namespace SWELib.Networking.Tcp

/-- The Transmission Control Block (TCB) stores all connection state
    (RFC 9293 Section 3.3.1).

    Send Sequence Variables (Section 3.3.1):
    - `snd_una`: oldest unacknowledged sequence number
    - `snd_nxt`: next sequence number to send
    - `snd_wnd`: send window size
    - `snd_up`:  send urgent pointer
    - `snd_wl1`: segment sequence number used for last window update
    - `snd_wl2`: segment acknowledgment number used for last window update
    - `iss`:     initial send sequence number

    Receive Sequence Variables (Section 3.3.1):
    - `rcv_nxt`: next sequence number expected on incoming segments
    - `rcv_wnd`: receive window size
    - `rcv_up`:  receive urgent pointer
    - `irs`:     initial receive sequence number -/
structure TCB where
  -- Send sequence variables
  /-- Oldest unacknowledged sequence number. -/
  snd_una : SeqNum
  /-- Next sequence number to send. -/
  snd_nxt : SeqNum
  /-- Send window size. -/
  snd_wnd : Nat
  /-- Send urgent pointer. -/
  snd_up : SeqNum
  /-- Segment sequence number used for last window update. -/
  snd_wl1 : SeqNum
  /-- Segment acknowledgment number used for last window update. -/
  snd_wl2 : SeqNum
  /-- Initial send sequence number. -/
  iss : SeqNum
  -- Receive sequence variables
  /-- Next expected receive sequence number. -/
  rcv_nxt : SeqNum
  /-- Receive window size. -/
  rcv_wnd : Nat
  /-- Receive urgent pointer. -/
  rcv_up : SeqNum
  /-- Initial receive sequence number. -/
  irs : SeqNum
  -- Connection identity
  /-- Local port. -/
  localPort : Port
  /-- Remote port. -/
  remotePort : Port
  -- State tracking
  /-- Current connection state. -/
  state : TcpState
  /-- How SYN-RECEIVED was reached, if applicable. -/
  synRcvdOrigin : Option SynRcvdOrigin := none
  deriving Repr

end SWELib.Networking.Tcp
