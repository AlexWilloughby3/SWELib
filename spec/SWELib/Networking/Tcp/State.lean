/-!
# TCP Connection States

RFC 9293 Section 3.3.2: The 11 states of a TCP connection,
from CLOSED through TIME-WAIT.
-/

namespace SWELib.Networking.Tcp

/-- The 11 states of a TCP connection (RFC 9293 Section 3.3.2, Figure 5). -/
inductive TcpState where
  /-- No connection exists. -/
  | closed
  /-- Waiting for a connection request from any remote TCP peer. -/
  | listen
  /-- Waiting for a matching connection request after having sent SYN. -/
  | synSent
  /-- Waiting for a confirming connection request ack after both
      peers have sent SYN. -/
  | synReceived
  /-- An open connection; data transfer is possible. -/
  | established
  /-- Waiting for a connection termination request from the remote,
      or an ack of the previously sent FIN. -/
  | finWait1
  /-- Waiting for a connection termination request from the remote. -/
  | finWait2
  /-- Waiting for a connection termination request from the local user. -/
  | closeWait
  /-- Waiting for a connection termination request ack from the remote. -/
  | closing
  /-- Waiting for an ack of the previously sent FIN
      (which included an ack of the remote FIN). -/
  | lastAck
  /-- Waiting for enough time to pass to be sure the remote received
      the ack of its FIN. -/
  | timeWait
  deriving DecidableEq, Repr, Inhabited

/-- How SYN-RECEIVED was reached: from a passive LISTEN or
    an active open (simultaneous open scenario, RFC 9293 Section 3.5). -/
inductive SynRcvdOrigin where
  /-- Arrived at SYN-RECEIVED via passive open (LISTEN -> SYN-RECEIVED). -/
  | fromPassiveOpen
  /-- Arrived at SYN-RECEIVED via active open (SYN-SENT -> SYN-RECEIVED). -/
  | fromActiveOpen
  deriving DecidableEq, Repr

/-- Whether the connection is in a synchronized state (RFC 9293 Section 3.3.2).
    A connection is synchronized once a SYN has been acknowledged. -/
def TcpState.isSynchronized : TcpState -> Bool
  | .established | .finWait1 | .finWait2
  | .closeWait | .closing | .lastAck | .timeWait => true
  | _ => false

/-- Whether the connection state allows sending data.
    Only ESTABLISHED and CLOSE-WAIT permit the SEND operation
    (RFC 9293 Section 3.9.1). -/
def TcpState.canSendData : TcpState -> Bool
  | .established | .closeWait => true
  | _ => false

end SWELib.Networking.Tcp
