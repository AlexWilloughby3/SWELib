import SWELib
import SWELibImpl.Bridge
import SWELibImpl.Ffi.Syscalls

/-!
# DNS Resolver

Resolves hostnames to IP addresses via getaddrinfo(3).
-/

namespace SWELibImpl.Networking.DnsResolver

open SWELib.OS
open SWELibImpl.Ffi.Syscalls

/-- A resolved address: address family + IP string. -/
structure ResolvedAddress where
  family : UInt32
  ip     : String
  deriving Repr

/-- Resolve a hostname to an array of addresses.
    Uses getaddrinfo with SOCK_STREAM hint.
    `service` can be a port number as string (e.g., "443") or empty. -/
def resolve (host : String) (service : String := "") :
    IO (Array ResolvedAddress) := do
  let result ← getaddrinfo host service
  match result with
  | .ok addrs =>
    return addrs.map fun (fam, ip) => ⟨fam, ip⟩
  | .error e =>
    throw <| IO.userError s!"DNS resolution failed for '{host}': {repr e}"

/-- Resolve a hostname and return just the first IPv4 address, if any. -/
def resolveIPv4 (host : String) : IO (Option String) := do
  let addrs ← resolve host
  return addrs.findSome? fun a =>
    if a.family == AF_INET then some a.ip else none

/-- Resolve a hostname and return the first address (any family). -/
def resolveFirst (host : String) : IO String := do
  let addrs ← resolve host
  if h : 0 < addrs.size then
    return addrs[0].ip
  else
    throw <| IO.userError s!"No addresses found for '{host}'"

end SWELibImpl.Networking.DnsResolver
