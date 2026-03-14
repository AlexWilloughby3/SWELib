/-!
# SWELib Specification

Pure Lean definitions, theorems, and proofs describing software engineering concepts.
No @[extern], no IO, no FFI. The Mathlib-like artifact.

This module is the root of the spec layer and imports all sub-modules.
-/

-- Basics
import SWELib.Basics.Bytes
import SWELib.Basics.Strings
import SWELib.Basics.Json
import SWELib.Basics.Yaml
import SWELib.Basics.Protobuf
import SWELib.Basics.Toml
import SWELib.Basics.Csv
import SWELib.Basics.Xml
import SWELib.Basics.Regex
import SWELib.Basics.Time
import SWELib.Basics.Uuid
import SWELib.Basics.Semver
import SWELib.Basics.Uri

-- Networking
import SWELib.Networking.Tcp
import SWELib.Networking.Udp
import SWELib.Networking.Dns
import SWELib.Networking.Tls
import SWELib.Networking.Http
import SWELib.Networking.Rest
import SWELib.Networking.Grpc
import SWELib.Networking.Graphql
import SWELib.Networking.Websocket
import SWELib.Networking.Ip
import SWELib.Networking.Proxy

-- Distributed
import SWELib.Distributed.Consensus
import SWELib.Distributed.Consistency
import SWELib.Distributed.Clocks
import SWELib.Distributed.CRDTs
import SWELib.Distributed.Cap
import SWELib.Distributed.TwoPhaseCommit
import SWELib.Distributed.Replication
import SWELib.Distributed.Partitioning
import SWELib.Distributed.MessageQueues
import SWELib.Distributed.Saga
import SWELib.Distributed.CircuitBreaker

-- Database
import SWELib.Db.Relational
import SWELib.Db.Sql
import SWELib.Db.Transactions
import SWELib.Db.Indexes
import SWELib.Db.Migrations
import SWELib.Db.KeyValue
import SWELib.Db.Document
import SWELib.Db.ConnectionPool

-- Cloud
import SWELib.Cloud.Terraform
import SWELib.Cloud.K8s
import SWELib.Cloud.Gcp
import SWELib.Cloud.Workflow
import SWELib.Cloud.Oci

-- Operating System
import SWELib.OS.FileSystem
import SWELib.OS.Process
import SWELib.OS.Memory
import SWELib.OS.Io
import SWELib.OS.Environment
import SWELib.OS.Sockets
import SWELib.OS.Users
import SWELib.OS.Cgroups
import SWELib.OS.Namespaces
import SWELib.OS.Systemd

-- Security
import SWELib.Security.Hashing
import SWELib.Security.Encryption
import SWELib.Security.Certificates
import SWELib.Security.Oauth
import SWELib.Security.Jwt
import SWELib.Security.Cors
import SWELib.Security.Rbac

-- Observability
import SWELib.Observability.Logging
import SWELib.Observability.Metrics
import SWELib.Observability.Tracing
import SWELib.Observability.Alerting
import SWELib.Observability.HealthCheck

-- CI/CD
import SWELib.Cicd.Pipeline
import SWELib.Cicd.Deployment
import SWELib.Cicd.Rollback
import SWELib.Cicd.GitOps

-- Integration
import SWELib.Integration.RequestResponse
import SWELib.Integration.DeploymentLiveness
import SWELib.Integration.ConfigConsistency
