import SWELib.Networking.Tcp.SeqNum
import SWELib.Networking.Tcp.Segment
import SWELib.Networking.Tcp.State
import SWELib.Networking.Tcp.Tcb
import SWELib.Networking.Tcp.Events
import SWELib.Networking.Tcp.Transition

/-!
# TCP

Formal specification of the Transmission Control Protocol (RFC 9293).

TCP is modeled as a state machine with 11 states. Operations are
defined on valid states via the `tcpTransition` function.
-/
