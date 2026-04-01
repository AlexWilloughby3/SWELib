import SWELib

-- Bridge: axioms asserting external functions satisfy spec properties
import SWELibImpl.Bridge.Syscalls.Socket
import SWELibImpl.Bridge.Syscalls.File
import SWELibImpl.Bridge.Syscalls.Process
import SWELibImpl.Bridge.Syscalls.Signal
import SWELibImpl.Bridge.Syscalls.Memory
import SWELibImpl.Bridge.Syscalls.Epoll
import SWELibImpl.Bridge.Syscalls.Namespace
import SWELibImpl.Bridge.Syscalls.Cgroup
import SWELibImpl.Bridge.Syscalls.Mount

import SWELibImpl.Bridge.Libssl.Handshake
import SWELibImpl.Bridge.Libssl.ServerHandshake
import SWELibImpl.Bridge.Libssl.Record
import SWELibImpl.Bridge.Libssl.Cert
import SWELibImpl.Bridge.Libssl.Hash

import SWELibImpl.Bridge.Libpq.Connect
import SWELibImpl.Bridge.Libpq.Exec
import SWELibImpl.Bridge.Libpq.Result
import SWELibImpl.Bridge.Libpq.Validation

import SWELibImpl.Bridge.Libcurl.Get
import SWELibImpl.Bridge.Libcurl.Post
import SWELibImpl.Bridge.Libcurl.Response
import SWELibImpl.Bridge.Libcurl.HttpServer

import SWELibImpl.Bridge.Libssh.Session

import SWELibImpl.Bridge.Encoding.Base64url

import SWELibImpl.Bridge.Oracles.Terraform

import SWELibImpl.Bridge.Docker.Cli
import SWELibImpl.Bridge.Docker.ImagePull

-- FFI
import SWELibImpl.Ffi.Syscalls
import SWELibImpl.Ffi.Memory
import SWELibImpl.Ffi.Libssl
import SWELibImpl.Ffi.Libpq
import SWELibImpl.Ffi.Libssh
import SWELibImpl.Ffi.Libcurl
import SWELibImpl.Ffi.Docker

-- Basics
import SWELibImpl.Basics.UriParser

-- Networking
import SWELibImpl.Networking.SshClient
import SWELibImpl.Networking.TcpClient
import SWELibImpl.Networking.TcpServer
import SWELibImpl.Networking.TlsClient
import SWELibImpl.Networking.HttpClient
import SWELibImpl.Networking.HttpServer
import SWELibImpl.Networking.HttpsServer
import SWELibImpl.Networking.DnsResolver
import SWELibImpl.Networking.FastApi

-- Database
import SWELibImpl.Db.PgClient
import SWELibImpl.Db.ConnectionPool
import SWELibImpl.Db.QueryBuilder

-- Cloud
import SWELibImpl.Cloud.K8sClient
import SWELibImpl.Cloud.GcpClient
import SWELibImpl.Cloud.TerraformPlan
import SWELibImpl.Cloud.OciRuntime
import SWELibImpl.Cloud.DockerClient

-- OS
import SWELibImpl.OS.FileOps
import SWELibImpl.OS.ProcessOps
import SWELibImpl.OS.SocketOps
import SWELibImpl.OS.SignalOps
import SWELibImpl.OS.MemoryOps

-- Security
import SWELibImpl.Security.JwtValidator
import SWELibImpl.Security.HashOps

-- Validators
import SWELibImpl.Validators.K8sManifestValidator
import SWELibImpl.Validators.TerraformPlanValidator
import SWELibImpl.Validators.HttpContractValidator

/-!
# SWELib Sample Implementation

Reference implementation of SWELib specs. Combines:
- **Bridge**: axioms asserting external (FFI) functions satisfy spec properties — the explicit trust boundary
- **Code**: executable Lean that imports spec types and bridge axioms to produce running programs
-/
