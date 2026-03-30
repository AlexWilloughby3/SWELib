import SWELib
import SWELibImpl.Bridge

/-!
# Libssh2 FFI

Raw `@[extern]` declarations for libssh2 SSH client operations.
Uses opaque types for session, channel, and known-host handles,
backed by `lean_alloc_external` with finalizers in the C shim.

## C Library
libssh2 (https://libssh2.org/) — linked via `-lssh2`

## Specification References
- RFC 4253: Transport Layer (session, handshake, disconnect)
- RFC 4252: Authentication (publickey, password)
- RFC 4254: Connection Protocol (channels, exec, read, write)
-/

namespace SWELibImpl.Ffi.Libssh

/-- Opaque handle to a libssh2 session (LIBSSH2_SESSION). Freed by finalizer. -/
opaque SshSession : Type := Unit

/-- Opaque handle to a libssh2 channel (LIBSSH2_CHANNEL). Freed by finalizer. -/
opaque SshChannel : Type := Unit

/-- Opaque handle to a libssh2 known-hosts collection (LIBSSH2_KNOWNHOSTS).
    Freed by finalizer. -/
opaque SshKnownHosts : Type := Unit

-- ── Session lifecycle ─────────────────────────────────────────────────

/-- Create a new SSH session object.
    Corresponds to `libssh2_session_init()`. -/
@[extern "swelib_ssh_session_new"]
opaque sshSessionNew : IO SshSession

/-- Perform SSH handshake over an established TCP socket fd.
    Completes version exchange, key exchange, and SSH_MSG_NEWKEYS.
    Returns 0 on success, negative on error.
    Corresponds to `libssh2_session_handshake()`. -/
@[extern "swelib_ssh_session_handshake"]
opaque sshSessionHandshake (session : @& SshSession) (fd : UInt32) : IO Int32

/-- Disconnect the SSH session with a reason and description.
    Sends SSH_MSG_DISCONNECT (RFC 4253 Section 11.1).
    Corresponds to `libssh2_session_disconnect_ex()`. -/
@[extern "swelib_ssh_session_disconnect"]
opaque sshSessionDisconnect (session : @& SshSession) (reason : UInt32)
    (description : @& String) : IO Unit

/-- Free the SSH session object. Called automatically by finalizer,
    but can be called explicitly for deterministic cleanup.
    Corresponds to `libssh2_session_free()`. -/
@[extern "swelib_ssh_session_free"]
opaque sshSessionFree (session : SshSession) : IO Unit

-- ── Host key verification ─────────────────────────────────────────────

/-- Get the server's host key after handshake.
    Returns the raw host key bytes and key type.
    Corresponds to `libssh2_session_hostkey()`. -/
@[extern "swelib_ssh_session_hostkey"]
opaque sshSessionHostkey (session : @& SshSession) : IO (ByteArray × UInt32)

/-- Initialize a known-hosts collection for host key verification.
    Corresponds to `libssh2_knownhost_init()`. -/
@[extern "swelib_ssh_knownhost_init"]
opaque sshKnownhostInit (session : @& SshSession) : IO SshKnownHosts

/-- Load known hosts from a file (e.g. ~/.ssh/known_hosts).
    Corresponds to `libssh2_knownhost_readfile()`. -/
@[extern "swelib_ssh_knownhost_readfile"]
opaque sshKnownhostReadfile (kh : @& SshKnownHosts) (path : @& String) : IO Int32

/-- Check the server's host key against known hosts.
    Returns 0 = match, 1 = mismatch, 2 = not found, 3 = failure.
    Corresponds to `libssh2_knownhost_checkp()`. -/
@[extern "swelib_ssh_knownhost_checkp"]
opaque sshKnownhostCheckp (kh : @& SshKnownHosts) (host : @& String)
    (port : UInt16) (key : @& ByteArray) (keyType : UInt32) : IO UInt32

-- ── Authentication ────────────────────────────────────────────────────

/-- Get the list of supported authentication methods for a user.
    Sends SSH_MSG_USERAUTH_REQUEST with method "none" (RFC 4252 Section 5.2).
    Returns a comma-separated string of method names.
    Corresponds to `libssh2_userauth_list()`. -/
@[extern "swelib_ssh_userauth_list"]
opaque sshUserauthList (session : @& SshSession)
    (username : @& String) : IO String

/-- Authenticate via public key from file.
    Sends SSH_MSG_USERAUTH_REQUEST with method "publickey" (RFC 4252 Section 7).
    Returns 0 on success.
    Corresponds to `libssh2_userauth_publickey_fromfile()`. -/
@[extern "swelib_ssh_userauth_publickey_fromfile"]
opaque sshUserauthPublickeyFromfile (session : @& SshSession)
    (username : @& String) (pubkeyPath : @& String)
    (privkeyPath : @& String) (passphrase : @& String) : IO Int32

/-- Authenticate via public key from memory (PEM or OpenSSH format).
    Returns 0 on success.
    Corresponds to `libssh2_userauth_publickey_frommemory()`. -/
@[extern "swelib_ssh_userauth_publickey_frommemory"]
opaque sshUserauthPublickeyFrommemory (session : @& SshSession)
    (username : @& String) (pubkey : @& ByteArray)
    (privkey : @& ByteArray) (passphrase : @& String) : IO Int32

/-- Authenticate via password.
    Sends SSH_MSG_USERAUTH_REQUEST with method "password" (RFC 4252 Section 8).
    Returns 0 on success.
    Corresponds to `libssh2_userauth_password()`. -/
@[extern "swelib_ssh_userauth_password"]
opaque sshUserauthPassword (session : @& SshSession) (username : @& String)
    (password : @& String) : IO Int32

/-- Check if the session is authenticated.
    Corresponds to `libssh2_userauth_authenticated()`. -/
@[extern "swelib_ssh_userauth_authenticated"]
opaque sshUserauthAuthenticated (session : @& SshSession) : IO Bool

-- ── Channel operations ────────────────────────────────────────────────

/-- Open a new session channel.
    Sends SSH_MSG_CHANNEL_OPEN with type "session" (RFC 4254 Section 6.1).
    Negotiates initial window size and max packet size.
    Corresponds to `libssh2_channel_open_session()`. -/
@[extern "swelib_ssh_channel_open_session"]
opaque sshChannelOpenSession (session : @& SshSession) : IO SshChannel

/-- Open a direct-tcpip channel for local port forwarding.
    Sends SSH_MSG_CHANNEL_OPEN with type "direct-tcpip" (RFC 4254 Section 7.2).
    Corresponds to `libssh2_channel_direct_tcpip()`. -/
@[extern "swelib_ssh_channel_direct_tcpip"]
opaque sshChannelDirectTcpip (session : @& SshSession) (host : @& String)
    (port : UInt16) : IO SshChannel

/-- Request execution of a command on the channel.
    Sends SSH_MSG_CHANNEL_REQUEST with type "exec" (RFC 4254 Section 6.5).
    Returns 0 on success.
    Corresponds to `libssh2_channel_exec()`. -/
@[extern "swelib_ssh_channel_exec"]
opaque sshChannelExec (channel : @& SshChannel)
    (command : @& String) : IO Int32

/-- Request a shell on the channel.
    Sends SSH_MSG_CHANNEL_REQUEST with type "shell" (RFC 4254 Section 6.5).
    Returns 0 on success.
    Corresponds to `libssh2_channel_shell()`. -/
@[extern "swelib_ssh_channel_shell"]
opaque sshChannelShell (channel : @& SshChannel) : IO Int32

/-- Request a subsystem on the channel (e.g., "sftp").
    Sends SSH_MSG_CHANNEL_REQUEST with type "subsystem" (RFC 4254 Section 6.5).
    Returns 0 on success.
    Corresponds to `libssh2_channel_subsystem()`. -/
@[extern "swelib_ssh_channel_subsystem"]
opaque sshChannelSubsystem (channel : @& SshChannel)
    (subsystem : @& String) : IO Int32

/-- Request a pseudo-terminal on the channel.
    Sends SSH_MSG_CHANNEL_REQUEST with type "pty-req" (RFC 4254 Section 6.2).
    Returns 0 on success.
    Corresponds to `libssh2_channel_request_pty()`. -/
@[extern "swelib_ssh_channel_request_pty"]
opaque sshChannelRequestPty (channel : @& SshChannel)
    (term : @& String) : IO Int32

/-- Send an environment variable to the channel.
    Sends SSH_MSG_CHANNEL_REQUEST with type "env" (RFC 4254 Section 6.4).
    Returns 0 on success.
    Corresponds to `libssh2_channel_setenv()`. -/
@[extern "swelib_ssh_channel_setenv"]
opaque sshChannelSetenv (channel : @& SshChannel) (name : @& String)
    (value : @& String) : IO Int32

/-- Read from the channel's stdout (stream_id = 0) or stderr (stream_id = 1).
    Receives SSH_MSG_CHANNEL_DATA or SSH_MSG_CHANNEL_EXTENDED_DATA
    (RFC 4254 Section 5.2).
    Returns data read; empty ByteArray on EOF.
    Corresponds to `libssh2_channel_read_ex()`. -/
@[extern "swelib_ssh_channel_read"]
opaque sshChannelRead (channel : @& SshChannel) (streamId : UInt32)
    (maxBytes : USize) : IO ByteArray

/-- Write data to the channel.
    Sends SSH_MSG_CHANNEL_DATA (RFC 4254 Section 5.2).
    Respects the remote window size — may write fewer bytes than requested.
    Returns bytes written.
    Corresponds to `libssh2_channel_write()`. -/
@[extern "swelib_ssh_channel_write"]
opaque sshChannelWrite (channel : @& SshChannel)
    (data : @& ByteArray) : IO USize

/-- Send EOF on the channel.
    Sends SSH_MSG_CHANNEL_EOF (RFC 4254 Section 5.3).
    No more data may be sent after this.
    Corresponds to `libssh2_channel_send_eof()`. -/
@[extern "swelib_ssh_channel_send_eof"]
opaque sshChannelSendEof (channel : @& SshChannel) : IO Int32

/-- Wait for the remote end to send EOF.
    Corresponds to `libssh2_channel_wait_eof()`. -/
@[extern "swelib_ssh_channel_wait_eof"]
opaque sshChannelWaitEof (channel : @& SshChannel) : IO Int32

/-- Wait for the remote end to close the channel.
    Corresponds to `libssh2_channel_wait_closed()`. -/
@[extern "swelib_ssh_channel_wait_closed"]
opaque sshChannelWaitClosed (channel : @& SshChannel) : IO Int32

/-- Close the channel. Sends SSH_MSG_CHANNEL_CLOSE (RFC 4254 Section 5.3).
    Corresponds to `libssh2_channel_close()`. -/
@[extern "swelib_ssh_channel_close"]
opaque sshChannelClose (channel : @& SshChannel) : IO Int32

/-- Get the exit status of the remote process.
    Valid after the channel receives exit-status request (RFC 4254 Section 6.10).
    Corresponds to `libssh2_channel_get_exit_status()`. -/
@[extern "swelib_ssh_channel_get_exit_status"]
opaque sshChannelGetExitStatus (channel : @& SshChannel) : IO Int32

/-- Free the channel object. Called automatically by finalizer.
    Corresponds to `libssh2_channel_free()`. -/
@[extern "swelib_ssh_channel_free"]
opaque sshChannelFree (channel : SshChannel) : IO Unit

-- ── Port forwarding ───────────────────────────────────────────────────

/-- Request the server to listen on a port for remote forwarding.
    Sends SSH_MSG_GLOBAL_REQUEST with type "tcpip-forward" (RFC 4254 Section 7.1).
    Returns the bound port (useful when requesting port 0).
    Corresponds to `libssh2_channel_forward_listen_ex()`. -/
@[extern "swelib_ssh_forward_listen"]
opaque sshForwardListen (session : @& SshSession) (host : @& String)
    (port : UInt16) : IO (UInt16 × SshChannel)

/-- Cancel remote port forwarding.
    Sends SSH_MSG_GLOBAL_REQUEST with type "cancel-tcpip-forward" (RFC 4254 Section 7.1).
    Corresponds to `libssh2_channel_forward_cancel()`. -/
@[extern "swelib_ssh_forward_cancel"]
opaque sshForwardCancel (listener : @& SshChannel) : IO Int32

end SWELibImpl.Ffi.Libssh
