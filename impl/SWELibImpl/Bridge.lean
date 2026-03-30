import SWELib

-- Syscalls
import SWELibImpl.Bridge.Syscalls.Socket
import SWELibImpl.Bridge.Syscalls.File
import SWELibImpl.Bridge.Syscalls.Process
import SWELibImpl.Bridge.Syscalls.Signal
import SWELibImpl.Bridge.Syscalls.Memory
import SWELibImpl.Bridge.Syscalls.Epoll
import SWELibImpl.Bridge.Syscalls.Namespace
import SWELibImpl.Bridge.Syscalls.Cgroup
import SWELibImpl.Bridge.Syscalls.Mount

-- Libssl
import SWELibImpl.Bridge.Libssl.Handshake
import SWELibImpl.Bridge.Libssl.ServerHandshake
import SWELibImpl.Bridge.Libssl.Record
import SWELibImpl.Bridge.Libssl.Cert
import SWELibImpl.Bridge.Libssl.Hash

-- Libpq
import SWELibImpl.Bridge.Libpq.Connect
import SWELibImpl.Bridge.Libpq.Exec
import SWELibImpl.Bridge.Libpq.Result
import SWELibImpl.Bridge.Libpq.Validation

-- Libcurl
import SWELibImpl.Bridge.Libcurl.Get
import SWELibImpl.Bridge.Libcurl.Post
import SWELibImpl.Bridge.Libcurl.Response
import SWELibImpl.Bridge.Libcurl.HttpServer

-- Libssh
import SWELibImpl.Bridge.Libssh.Session

-- Encoding
import SWELibImpl.Bridge.Encoding.Base64url

-- Oracles
import SWELibImpl.Bridge.Oracles.Terraform

-- Cloud
import SWELibImpl.Bridge.Cloud.GceVm

-- Docker
import SWELibImpl.Bridge.Docker.Cli
import SWELibImpl.Bridge.Docker.ImagePull

/-!
# SWELibImpl Bridge

Axioms asserting external functions satisfy spec properties.
The explicit trust boundary. Every unproven real-world assumption lives here.
Auditable as a single surface.
-/
