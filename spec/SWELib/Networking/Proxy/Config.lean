import SWELib.Networking.Proxy.Types

/-!
# Proxy Configuration Validation

Validation functions for proxy configuration.
References:
- RFC 7230 Section 5.7.1: Via header field requirements
- RFC 7231 Section 4.3.6: CONNECT method restrictions
-/

namespace SWELib.Networking.Proxy

/-- Check if a proxy configuration is valid. -/
def Proxy.isValid (p : Proxy) : Bool :=
  -- Basic validation: host non-empty, port in valid range
  p.host ≠ "" ∧ p.port > 0 ∧ p.port < 65536

/-- Check if a proxy allows connections to a specific port. -/
def Proxy.allowsPort (p : Proxy) (port : Nat) : Bool :=
  match p.allowedPorts with
  | none => true  -- No restrictions
  | some ports => port ∈ ports

/-- Validate proxy authentication credentials. -/
def ProxyAuth.isValid (auth : ProxyAuth) : Bool :=
  -- Basic validation: username and password non-empty
  auth.username ≠ "" ∧ auth.password ≠ ""

/-- Check if proxy requires authentication. -/
def Proxy.requiresAuth (p : Proxy) : Bool :=
  p.auth.isSome

/-- Validate that a proxy can forward to a given target port. -/
def Proxy.canForwardTo (p : Proxy) (targetPort : Nat) : Bool :=
  p.isValid ∧ p.allowsPort targetPort

/-- Theorems about proxy configuration validation. -/
theorem valid_proxy_has_valid_port (p : Proxy) (h : p.isValid) : 0 < p.port ∧ p.port < 65536 := by
  simp [Proxy.isValid] at h
  exact h.2

theorem no_restrictions_implies_all_ports_allowed (p : Proxy) (h : p.allowedPorts = none) :
    ∀ port, p.allowsPort port := by
  intro port
  simp [Proxy.allowsPort, h]

end SWELib.Networking.Proxy
