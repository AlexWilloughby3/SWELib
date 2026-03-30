import SWELib.Networking.Http
import SWELib.Basics.Uri

/-!
# Proxy Type Definitions

Formal specification of proxy types and authentication methods.
References:
- RFC 7230 Section 5.7.1: Via header field
- RFC 7231 Section 4.3.6: CONNECT method
- RFC 1928: SOCKS5 Protocol
-/

namespace SWELib.Networking.Proxy

/-- Type of proxy based on its role in the network. -/
inductive ProxyType where
  /-- Forward proxy: sits between client and internet, forwards client requests. -/
  | forward : ProxyType
  /-- Reverse proxy: sits between internet and servers, forwards to backend servers. -/
  | reverse : ProxyType
  /-- Gateway proxy: protocol translation (e.g., HTTP to HTTPS). -/
  | gateway : ProxyType
  /-- Tunnel proxy: establishes TCP tunnels via CONNECT method. -/
  | tunnel : ProxyType
  deriving DecidableEq, Repr, Inhabited

/-- Proxy authentication credentials. -/
structure ProxyAuth where
  /-- Username for proxy authentication. -/
  username : String
  /-- Password for proxy authentication. -/
  password : String
  deriving DecidableEq, Repr

/-- A proxy server configuration. -/
structure Proxy where
  /-- Type of proxy (forward, reverse, gateway, tunnel). -/
  type : ProxyType
  /-- Proxy hostname or IP address. -/
  host : String
  /-- Proxy port number. -/
  port : Nat
  /-- Optional authentication credentials. -/
  auth : Option ProxyAuth := none
  /-- For CONNECT proxies: allowed destination ports (if none, all ports allowed). -/
  allowedPorts : Option (List Nat) := none
  deriving DecidableEq, Repr

/-- Basic properties about proxy types. -/
theorem proxy_type_finite : ∃ (types : List ProxyType), ∀ (t : ProxyType), t ∈ types := by
  refine ⟨[.forward, .reverse, .gateway, .tunnel], ?_⟩
  intro t
  cases t <;> simp

end SWELib.Networking.Proxy
