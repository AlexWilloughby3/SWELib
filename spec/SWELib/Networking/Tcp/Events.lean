import SWELib.Networking.Tcp.Segment

/-!
# TCP Events and Actions

RFC 9293 Section 3.9: Events that drive the TCP state machine and
actions produced in response.
-/

namespace SWELib.Networking.Tcp

/-- Events that drive the TCP state machine (RFC 9293 Section 3.9).
    These represent both user calls and network-level events. -/
inductive TcpEvent where
  /-- OPEN call with passive mode (RFC 9293 Section 3.9.1). -/
  | passiveOpen (localPort : Port)
  /-- OPEN call with active mode (RFC 9293 Section 3.9.1). -/
  | activeOpen (localPort remotePort : Port)
  /-- SEND call with data (RFC 9293 Section 3.9.1). -/
  | send (data : ByteArray)
  /-- RECEIVE call (RFC 9293 Section 3.9.1). -/
  | receive
  /-- CLOSE call (RFC 9293 Section 3.9.1). -/
  | close
  /-- ABORT call (RFC 9293 Section 3.9.1). -/
  | abort
  /-- STATUS call (RFC 9293 Section 3.9.1). -/
  | status
  /-- An inbound segment arrives from the network (RFC 9293 Section 3.10). -/
  | segmentArrives (seg : TcpSegment)
  /-- Retransmission timer fires. -/
  | timeoutRetransmit
  /-- TIME-WAIT timer (2MSL) fires (RFC 9293 Section 3.4.1). -/
  | timeoutTimeWait

/-- Actions produced by the TCP state machine in response to events. -/
inductive TcpAction where
  /-- Emit a segment to the network. -/
  | sendSegment (seg : TcpSegment)
  /-- Deliver received data to the application. -/
  | deliverData (data : ByteArray)
  /-- Delete the TCB (connection fully closed). -/
  | deleteTcb
  /-- Signal an error to the application. -/
  | error (msg : String)
  /-- No action required. -/
  | noop

end SWELib.Networking.Tcp
