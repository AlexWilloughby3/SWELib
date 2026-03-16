/-
Copyright (c) 2025 SWELib Authors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Team
-/

import Std.Net.Addr

/-!
# UDP Port Numbers

Formal specification of UDP port numbers (RFC 768).

Ports are 16-bit unsigned integers in the range 0-65535, where:
- Port 0: Unspecified (may be used when no port is needed)
- Ports 1-1023: Well-known ports (require system privileges)
- Ports 1024-49151: Registered ports
- Ports 49152-65535: Dynamic/private ports
-/

namespace SWELib.Networking.Udp

/-- UDP port number (16-bit unsigned integer, 0-65535) -/
abbrev Port := UInt16

/-- DNS server port (RFC 1035) -/
def PORT_DNS : Port := 53

/-- DHCP server port (RFC 2131) -/
def PORT_DHCP_SERVER : Port := 67

/-- DHCP client port (RFC 2131) -/
def PORT_DHCP_CLIENT : Port := 68

/-- NTP server port (RFC 5905) -/
def PORT_NTP : Port := 123

/-- SNMP agent port (RFC 3411) -/
def PORT_SNMP : Port := 161

/-- SNMP trap port (RFC 3411) -/
def PORT_SNMP_TRAP : Port := 162

/-- Syslog port (RFC 5424) -/
def PORT_SYSLOG : Port := 514

/-- RADIUS authentication port (RFC 2865) -/
def PORT_RADIUS : Port := 1812

/-- RADIUS accounting port (RFC 2866) -/
def PORT_RADIUS_ACCT : Port := 1813

/-- Check if a port is valid (0-65535, with 0 meaning "no port specified") -/
def isValidPort (p : Port) : Bool := true  -- All UInt16 values are valid

/-- Check if a port is a well-known port (1-1023) -/
def isWellKnownPort (p : Port) : Bool :=
  1 ≤ p ∧ p ≤ 1023

/-- Check if a port is a registered port (1024-49151) -/
def isRegisteredPort (p : Port) : Bool :=
  1024 ≤ p ∧ p ≤ 49151

/-- Check if a port is a dynamic/private port (49152-65535) -/
def isDynamicPort (p : Port) : Bool :=
  49152 ≤ p ∧ p ≤ 65535

end SWELib.Networking.Udp