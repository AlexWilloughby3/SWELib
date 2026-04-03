import SWELib.Cloud.Docker.Types

/-!
# Docker Network Types

Data model for Docker networking: `docker network create/rm/ls/inspect/connect/disconnect`.

## Source Specs
- Docker network reference: https://docs.docker.com/reference/cli/docker/network/
- Docker networking overview: https://docs.docker.com/engine/network/
-/

namespace SWELib.Cloud.Docker

/-! ## Network Driver -/

/-- Docker network driver. -/
inductive NetworkDriver where
  | bridge
  | host
  | overlay
  | macvlan
  | ipvlan
  | none
  | custom (name : String)
  deriving DecidableEq, Repr, Inhabited

instance : ToString NetworkDriver where
  toString
    | .bridge => "bridge"
    | .host => "host"
    | .overlay => "overlay"
    | .macvlan => "macvlan"
    | .ipvlan => "ipvlan"
    | .none => "none"
    | .custom name => name

/-! ## IPAM Configuration -/

/-- IP Address Management (IPAM) subnet configuration. -/
structure IpamSubnet where
  /-- Subnet in CIDR notation (e.g., "172.18.0.0/16"). -/
  subnet : String
  /-- Gateway IP (e.g., "172.18.0.1"). -/
  gateway : String := ""
  /-- IP range for allocation (CIDR). -/
  ipRange : String := ""
  deriving DecidableEq, Repr, Inhabited

/-! ## Network Types -/

/-- Docker network information (from `docker network inspect`). -/
structure DockerNetwork where
  /-- Network ID. -/
  id : String
  /-- Network name. -/
  name : String
  /-- Network driver. -/
  driver : NetworkDriver := .bridge
  /-- Network scope (local, swarm, global). -/
  scope : String := "local"
  /-- Whether the network is internal (no external connectivity). -/
  internal : Bool := false
  /-- Whether IPv6 is enabled. -/
  enableIPv6 : Bool := false
  /-- IPAM subnets. -/
  ipam : Array IpamSubnet := #[]
  /-- Network options (driver-specific key=value pairs). -/
  options : Array String := #[]
  /-- Labels. -/
  labels : Array String := #[]
  /-- Container IDs connected to this network. -/
  containers : Array String := #[]
  deriving Repr, Inhabited

/-- Configuration for `docker network create`. -/
structure NetworkCreateConfig where
  /-- Network name. -/
  name : String
  /-- Network driver. -/
  driver : NetworkDriver := .bridge
  /-- IPAM subnets. -/
  subnets : Array IpamSubnet := #[]
  /-- Internal network (no external access). -/
  internal : Bool := false
  /-- Enable IPv6. -/
  enableIPv6 : Bool := false
  /-- Driver-specific options (`--opt key=value`). -/
  options : Array String := #[]
  /-- Labels (`--label key=value`). -/
  labels : Array String := #[]
  /-- Attachable (for swarm overlay networks). -/
  attachable : Bool := false
  deriving Repr, Inhabited

/-! ## Network Store -/

/-- Network store mapping network names/IDs to network info. -/
def NetworkStore := String → Option DockerNetwork

/-- The empty network store. -/
def NetworkStore.empty : NetworkStore := fun _ => none

/-- Look up a network by name or ID. -/
def NetworkStore.lookup (store : NetworkStore) (nameOrId : String) : Option DockerNetwork :=
  store nameOrId

/-- Insert a network into the store (indexed by both ID and name). -/
def NetworkStore.insert (store : NetworkStore) (net : DockerNetwork) : NetworkStore :=
  fun key =>
    if key = net.id then some net
    else if key = net.name then some net
    else store key

/-- Remove a network from the store. -/
def NetworkStore.remove (store : NetworkStore) (id : String) (name : String := "") : NetworkStore :=
  fun key =>
    if key = id then none
    else if !name.isEmpty && key = name then none
    else store key

/-- Check if a network exists. -/
def NetworkStore.contains (store : NetworkStore) (nameOrId : String) : Bool :=
  (store.lookup nameOrId).isSome

/-! ## Network Flag Serialization -/

/-- Serialize a `NetworkCreateConfig` into CLI arguments for `docker network create`. -/
def serializeNetworkCreateFlags (config : NetworkCreateConfig) : Array String := Id.run do
  let mut args : Array String := #[]

  -- Driver
  args := args ++ #["--driver", toString config.driver]

  -- Subnets
  for sub in config.subnets do
    args := args ++ #["--subnet", sub.subnet]
    if !sub.gateway.isEmpty then
      args := args ++ #["--gateway", sub.gateway]
    if !sub.ipRange.isEmpty then
      args := args ++ #["--ip-range", sub.ipRange]

  -- Internal
  if config.internal then
    args := args.push "--internal"

  -- IPv6
  if config.enableIPv6 then
    args := args.push "--ipv6"

  -- Options
  for opt in config.options do
    args := args ++ #["--opt", opt]

  -- Labels
  for label in config.labels do
    args := args ++ #["--label", label]

  -- Attachable
  if config.attachable then
    args := args.push "--attachable"

  -- Network name (positional, last)
  args := args.push config.name

  return args

/-! ## Network Validation -/

/-- Check if a network create config is valid. -/
def NetworkCreateConfig.isValid (config : NetworkCreateConfig) : Bool :=
  !config.name.isEmpty

end SWELib.Cloud.Docker
