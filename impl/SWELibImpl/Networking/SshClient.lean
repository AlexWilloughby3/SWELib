import SWELib
import SWELibImpl.Bridge
import SWELibImpl.Ffi.Syscalls
import SWELibImpl.Ffi.Libssh
import SWELibImpl.Networking.TcpClient

/-!
# SSH Client

An SSH client wrapping libssh2 over a TCP connection.
Provides connect/authenticate/exec/forward with the full SSH
protocol handled by the C library.

## Protocol References
- RFC 4253: Transport Layer (handshake, encryption)
- RFC 4252: Authentication (publickey, password)
- RFC 4254: Connection Protocol (channels, exec, forwarding)
-/

namespace SWELibImpl.Networking.SshClient

open SWELibImpl.Ffi.Libssh
open SWELibImpl.Networking.TcpClient

/-- A connected, authenticated SSH session over a TCP socket. -/
structure SshStream where
  tcp     : TcpStream
  session : SshSession
  user    : String

/-- An open SSH channel on a session (for exec, shell, or forwarding). -/
structure SshChannelStream where
  ssh     : SshStream
  channel : SshChannel

/-- Establish an SSH connection and authenticate with a public key.
    1. Opens a TCP connection to host:port
    2. Performs SSH handshake (version exchange, key exchange, NEWKEYS)
    3. Authenticates with the given key files -/
def connectWithKey (host : String) (port : UInt16 := 22) (user : String)
    (privkeyPath : String) (pubkeyPath : String := "")
    (passphrase : String := "") : IO SshStream := do
  let tcp ← TcpClient.connect host port
  let session ← sshSessionNew
  let rc ← sshSessionHandshake session tcp.fd
  if rc != 0 then
    tcp.close
    throw <| IO.userError s!"SSH handshake failed for {host}:{port} (rc={rc})"
  let authRc ← sshUserauthPublickeyFromfile session user pubkeyPath
      privkeyPath passphrase
  if authRc != 0 then
    sshSessionDisconnect session 14 "auth failed"  -- NO_MORE_AUTH_METHODS
    tcp.close
    throw <| IO.userError s!"SSH pubkey auth failed for {user}@{host} (rc={authRc})"
  return { tcp, session, user }

/-- Establish an SSH connection and authenticate with a password. -/
def connectWithPassword (host : String) (port : UInt16 := 22)
    (user : String) (password : String) : IO SshStream := do
  let tcp ← TcpClient.connect host port
  let session ← sshSessionNew
  let rc ← sshSessionHandshake session tcp.fd
  if rc != 0 then
    tcp.close
    throw <| IO.userError s!"SSH handshake failed for {host}:{port} (rc={rc})"
  let authRc ← sshUserauthPassword session user password
  if authRc != 0 then
    sshSessionDisconnect session 14 "auth failed"
    tcp.close
    throw <| IO.userError s!"SSH password auth failed for {user}@{host} (rc={authRc})"
  return { tcp, session, user }

/-- Execute a command on the remote host and return its stdout output.
    Opens a session channel, runs exec, reads all output, returns it
    along with the exit status. -/
def exec (ssh : SshStream) (command : String) : IO (ByteArray × Int32) := do
  let channel ← sshChannelOpenSession ssh.session
  let rc ← sshChannelExec channel command
  if rc != 0 then
    let _ ← sshChannelClose channel
    throw <| IO.userError s!"SSH exec failed: {command} (rc={rc})"
  -- Read all stdout
  let mut output := ByteArray.empty
  let mut done := false
  while !done do
    let chunk ← sshChannelRead channel 0 65536
    if chunk.isEmpty then
      done := true
    else
      output := output ++ chunk
  let _ ← sshChannelSendEof channel
  let _ ← sshChannelWaitEof channel
  let _ ← sshChannelClose channel
  let _ ← sshChannelWaitClosed channel
  let exitStatus ← sshChannelGetExitStatus channel
  sshChannelFree channel
  return (output, exitStatus)

/-- Execute a command and return stdout as a String. -/
def execString (ssh : SshStream) (command : String) : IO (String × Int32) := do
  let (output, status) ← exec ssh command
  return (String.fromUTF8! output, status)

/-- Open an interactive shell channel with a pseudo-terminal. -/
def openShell (ssh : SshStream) (term : String := "xterm") :
    IO SshChannelStream := do
  let channel ← sshChannelOpenSession ssh.session
  let ptyRc ← sshChannelRequestPty channel term
  if ptyRc != 0 then
    let _ ← sshChannelClose channel
    throw <| IO.userError s!"SSH pty request failed (rc={ptyRc})"
  let shellRc ← sshChannelShell channel
  if shellRc != 0 then
    let _ ← sshChannelClose channel
    throw <| IO.userError s!"SSH shell request failed (rc={shellRc})"
  return { ssh, channel }

/-- Open a direct-tcpip channel for local port forwarding.
    Tunnels a connection to remoteHost:remotePort through the SSH server. -/
def openTunnel (ssh : SshStream) (remoteHost : String)
    (remotePort : UInt16) : IO SshChannelStream := do
  let channel ← sshChannelDirectTcpip ssh.session remoteHost remotePort
  return { ssh, channel }

/-- Read from a channel (stdout by default, or stderr with streamId=1). -/
def SshChannelStream.read (ch : SshChannelStream) (maxBytes : USize := 65536)
    (streamId : UInt32 := 0) : IO ByteArray :=
  sshChannelRead ch.channel streamId maxBytes

/-- Write data to a channel. Returns bytes written. -/
def SshChannelStream.write (ch : SshChannelStream) (data : ByteArray) : IO USize :=
  sshChannelWrite ch.channel data

/-- Close a channel stream. -/
def SshChannelStream.close (ch : SshChannelStream) : IO Unit := do
  let _ ← sshChannelSendEof ch.channel
  let _ ← sshChannelClose ch.channel
  sshChannelFree ch.channel

/-- Disconnect the SSH session and close the TCP connection. -/
def SshStream.close (ssh : SshStream) : IO Unit := do
  sshSessionDisconnect ssh.session 11 "normal shutdown"  -- BY_APPLICATION
  sshSessionFree ssh.session
  ssh.tcp.close

end SWELibImpl.Networking.SshClient
