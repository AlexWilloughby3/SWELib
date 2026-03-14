/-!
# SWELib Bridge

Axioms asserting external functions satisfy spec properties.
The explicit trust boundary. Every unproven real-world assumption lives here.
Auditable as a single surface.

This module is the root of the bridge layer and imports all axiom modules.
-/

import SWELib

-- Syscalls
import SWELibBridge.Syscalls.Socket
import SWELibBridge.Syscalls.File
import SWELibBridge.Syscalls.Process
import SWELibBridge.Syscalls.Memory
import SWELibBridge.Syscalls.Epoll
import SWELibBridge.Syscalls.Namespace
import SWELibBridge.Syscalls.Cgroup
import SWELibBridge.Syscalls.Mount

-- Libssl
import SWELibBridge.Libssl.Handshake
import SWELibBridge.Libssl.Record
import SWELibBridge.Libssl.Cert

-- Libpq
import SWELibBridge.Libpq.Connect
import SWELibBridge.Libpq.Exec
import SWELibBridge.Libpq.Result

-- Libcurl (optional)
import SWELibBridge.Libcurl.Get
import SWELibBridge.Libcurl.Post
import SWELibBridge.Libcurl.Response

-- Oracles
import SWELibBridge.Oracles.Terraform
