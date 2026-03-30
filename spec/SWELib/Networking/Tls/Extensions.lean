import SWELib.Basics.Bytes
import SWELib.Networking.Tls.BasicStructures

/-!
# TLS Extensions

Extension definitions for TLS protocol (RFC 8446 Section 4.2).
-/

namespace SWELib.Networking.Tls

private instance : Repr ByteArray where
  reprPrec b _ := repr b.toList

/-- Extension type identifier (RFC 8446 Section 4.2). -/
inductive ExtensionType where
  /-- server_name (RFC 6066) -/
  | serverName : ExtensionType
  /-- supported_groups (RFC 8446 Section 4.2.7) -/
  | supportedGroups : ExtensionType
  /-- signature_algorithms (RFC 8446 Section 4.2.3) -/
  | signatureAlgorithms : ExtensionType
  /-- application_layer_protocol_negotiation (RFC 7301) -/
  | applicationLayerProtocolNegotiation : ExtensionType
  /-- supported_versions (RFC 8446 Section 4.2.1) -/
  | supportedVersions : ExtensionType
  /-- key_share (RFC 8446 Section 4.2.8) -/
  | keyShare : ExtensionType
  /-- pre_shared_key (RFC 8446 Section 4.2.11) -/
  | preSharedKey : ExtensionType
  /-- early_data (RFC 8446 Section 4.2.10) -/
  | earlyData : ExtensionType
  /-- cookie (RFC 8446 Section 4.2.2) -/
  | cookie : ExtensionType
  /-- psk_key_exchange_modes (RFC 8446 Section 4.2.9) -/
  | pskKeyExchangeModes : ExtensionType
  deriving DecidableEq, Repr

/-- Convert extension type to wire representation (RFC 8446 Section 4.2). -/
def ExtensionType.toUInt16 : ExtensionType → UInt16
  | .serverName => 0x0000
  | .supportedGroups => 0x000A
  | .signatureAlgorithms => 0x000D
  | .applicationLayerProtocolNegotiation => 0x0010
  | .supportedVersions => 0x002B
  | .keyShare => 0x0033
  | .preSharedKey => 0x0029
  | .earlyData => 0x002A
  | .cookie => 0x002C
  | .pskKeyExchangeModes => 0x002D

/-- Parse extension type from wire representation (RFC 8446 Section 4.2). -/
def ExtensionType.fromUInt16 : UInt16 → Option ExtensionType
  | 0x0000 => some .serverName
  | 0x000A => some .supportedGroups
  | 0x000D => some .signatureAlgorithms
  | 0x0010 => some .applicationLayerProtocolNegotiation
  | 0x002B => some .supportedVersions
  | 0x0033 => some .keyShare
  | 0x0029 => some .preSharedKey
  | 0x002A => some .earlyData
  | 0x002C => some .cookie
  | 0x002D => some .pskKeyExchangeModes
  | _ => none

/-- Server Name Indication extension (RFC 6066 Section 3). -/
structure ServerNameExtension where
  /-- Server name as UTF-8 string -/
  serverName : String
  deriving DecidableEq, Repr

/-- Supported Groups extension (RFC 8446 Section 4.2.7). -/
structure SupportedGroupsExtension where
  /-- List of named groups -/
  groups : List NamedGroup
  deriving DecidableEq, Repr

/-- Signature Algorithms extension (RFC 8446 Section 4.2.3). -/
structure SignatureAlgorithmsExtension where
  /-- List of signature schemes -/
  schemes : List SignatureScheme
  deriving DecidableEq, Repr

/-- ALPN extension (RFC 7301). -/
structure AlpnExtension where
  /-- List of protocol names -/
  protocols : List String
  deriving DecidableEq, Repr

/-- Supported Versions extension (RFC 8446 Section 4.2.1). -/
structure SupportedVersionsExtension where
  /-- List of protocol versions -/
  versions : List ProtocolVersion
  deriving DecidableEq, Repr

/-- Key Share extension (RFC 8446 Section 4.2.8). -/
structure KeyShareExtension where
  /-- List of key share entries (group + key exchange data) -/
  shares : List (NamedGroup × ByteArray)
  deriving DecidableEq, Repr

/-- Pre-Shared Key extension (RFC 8446 Section 4.2.11). -/
structure PreSharedKeyExtension where
  /-- List of PSK identities -/
  identities : List ByteArray
  /-- List of binders (HMAC values) -/
  binders : List ByteArray
  deriving DecidableEq, Repr

/-- Early Data extension (RFC 8446 Section 4.2.10). -/
structure EarlyDataExtension where
  deriving DecidableEq, Repr

/-- Cookie extension (RFC 8446 Section 4.2.2). -/
structure CookieExtension where
  /-- Cookie value -/
  cookie : ByteArray
  deriving DecidableEq, Repr

/-- PSK Key Exchange Modes extension (RFC 8446 Section 4.2.9). -/
inductive PskKeyExchangeMode where
  /-- PSK-only key establishment (RFC 8446 Section 4.2.9) -/
  | pskKe : PskKeyExchangeMode
  /-- PSK with (EC)DHE key establishment (RFC 8446 Section 4.2.9) -/
  | pskDheKe : PskKeyExchangeMode
  deriving DecidableEq, Repr

structure PskKeyExchangeModesExtension where
  /-- List of PSK key exchange modes -/
  modes : List PskKeyExchangeMode
  deriving DecidableEq, Repr

/-- TLS Extension (RFC 8446 Section 4.2). -/
inductive Extension where
  /-- Server Name extension (RFC 6066) -/
  | serverName : ServerNameExtension → Extension
  /-- Supported Groups extension (RFC 8446 Section 4.2.7) -/
  | supportedGroups : SupportedGroupsExtension → Extension
  /-- Signature Algorithms extension (RFC 8446 Section 4.2.3) -/
  | signatureAlgorithms : SignatureAlgorithmsExtension → Extension
  /-- ALPN extension (RFC 7301) -/
  | applicationLayerProtocolNegotiation : AlpnExtension → Extension
  /-- Supported Versions extension (RFC 8446 Section 4.2.1) -/
  | supportedVersions : SupportedVersionsExtension → Extension
  /-- Key Share extension (RFC 8446 Section 4.2.8) -/
  | keyShare : KeyShareExtension → Extension
  /-- Pre-Shared Key extension (RFC 8446 Section 4.2.11) -/
  | preSharedKey : PreSharedKeyExtension → Extension
  /-- Early Data extension (RFC 8446 Section 4.2.10) -/
  | earlyData : EarlyDataExtension → Extension
  /-- Cookie extension (RFC 8446 Section 4.2.2) -/
  | cookie : CookieExtension → Extension
  /-- PSK Key Exchange Modes extension (RFC 8446 Section 4.2.9) -/
  | pskKeyExchangeModes : PskKeyExchangeModesExtension → Extension
  deriving DecidableEq, Repr

/-- Get the extension type from an extension. -/
def Extension.getType : Extension → ExtensionType
  | .serverName _ => .serverName
  | .supportedGroups _ => .supportedGroups
  | .signatureAlgorithms _ => .signatureAlgorithms
  | .applicationLayerProtocolNegotiation _ => .applicationLayerProtocolNegotiation
  | .supportedVersions _ => .supportedVersions
  | .keyShare _ => .keyShare
  | .preSharedKey _ => .preSharedKey
  | .earlyData _ => .earlyData
  | .cookie _ => .cookie
  | .pskKeyExchangeModes _ => .pskKeyExchangeModes

instance : ToString ExtensionType where
  toString et := match et with
    | .serverName => "server_name"
    | .supportedGroups => "supported_groups"
    | .signatureAlgorithms => "signature_algorithms"
    | .applicationLayerProtocolNegotiation => "application_layer_protocol_negotiation"
    | .supportedVersions => "supported_versions"
    | .keyShare => "key_share"
    | .preSharedKey => "pre_shared_key"
    | .earlyData => "early_data"
    | .cookie => "cookie"
    | .pskKeyExchangeModes => "psk_key_exchange_modes"

instance : ToString PskKeyExchangeMode where
  toString mode := match mode with
    | .pskKe => "psk_ke"
    | .pskDheKe => "psk_dhe_ke"

/-- Check if an extension is mandatory for TLS 1.3 (RFC 8446 Section 4.2). -/
def Extension.isMandatoryForTls13 : Extension → Bool
  | .supportedVersions _ => true
  | .keyShare _ => true
  | _ => false

/-- Validate that a ServerNameExtension has a valid server name (RFC 6066 Section 3). -/
def ServerNameExtension.validate : ServerNameExtension → Bool
  | ⟨serverName⟩ => serverName.length > 0 && serverName.length ≤ 255

/-- Validate that a SupportedGroupsExtension has at least one group (RFC 8446 Section 4.2.7). -/
def SupportedGroupsExtension.validate : SupportedGroupsExtension → Bool
  | ⟨groups⟩ => groups.length > 0

/-- Validate that a SignatureAlgorithmsExtension has at least one scheme (RFC 8446 Section 4.2.3). -/
def SignatureAlgorithmsExtension.validate : SignatureAlgorithmsExtension → Bool
  | ⟨schemes⟩ => schemes.length > 0

/-- Validate that an AlpnExtension has at least one protocol (RFC 7301). -/
def AlpnExtension.validate : AlpnExtension → Bool
  | ⟨protocols⟩ => protocols.length > 0

/-- Validate that a SupportedVersionsExtension has at least one version (RFC 8446 Section 4.2.1). -/
def SupportedVersionsExtension.validate : SupportedVersionsExtension → Bool
  | ⟨versions⟩ => versions.length > 0

/-- Validate that a KeyShareExtension has at least one share (RFC 8446 Section 4.2.8). -/
def KeyShareExtension.validate : KeyShareExtension → Bool
  | ⟨shares⟩ => shares.length > 0

/-- Validate that a PreSharedKeyExtension has matching identity and binder counts (RFC 8446 Section 4.2.11). -/
def PreSharedKeyExtension.validate : PreSharedKeyExtension → Bool
  | ⟨identities, binders⟩ => identities.length = binders.length && identities.length > 0

/-- Validate that a CookieExtension has a non-empty cookie (RFC 8446 Section 4.2.2). -/
def CookieExtension.validate : CookieExtension → Bool
  | ⟨cookie⟩ => cookie.size > 0

/-- Validate that a PskKeyExchangeModesExtension has at least one mode (RFC 8446 Section 4.2.9). -/
def PskKeyExchangeModesExtension.validate : PskKeyExchangeModesExtension → Bool
  | ⟨modes⟩ => modes.length > 0

/-- Validate an extension based on its type. -/
def Extension.validate : Extension → Bool
  | .serverName ext => ext.validate
  | .supportedGroups ext => ext.validate
  | .signatureAlgorithms ext => ext.validate
  | .applicationLayerProtocolNegotiation ext => ext.validate
  | .supportedVersions ext => ext.validate
  | .keyShare ext => ext.validate
  | .preSharedKey ext => ext.validate
  | .earlyData _ => true  -- Empty extension is valid
  | .cookie ext => ext.validate
  | .pskKeyExchangeModes ext => ext.validate

end SWELib.Networking.Tls
