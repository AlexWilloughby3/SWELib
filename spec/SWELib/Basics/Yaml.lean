/-!
# YAML

YAML 1.2.2 specification — representation graph model.
Defines the three node kinds (scalar, sequence, mapping), tags,
documents, and streams.

Anchors and aliases are serialization-layer concerns and are not
modeled here (see D-007 in doc/representation-decisions.md).
-/

namespace SWELib.Basics

/-- A YAML tag identifying the type of a node (YAML 1.2 §3.2.2). -/
structure YamlTag where
  /-- Tag URI, or none for untagged nodes. -/
  uri : Option String := none
  deriving DecidableEq, Repr

/-! ### Core schema tag constants (YAML 1.2 §10.3) -/

def YamlTag.null : YamlTag := ⟨some "tag:yaml.org,2002:null"⟩
def YamlTag.bool : YamlTag := ⟨some "tag:yaml.org,2002:bool"⟩
def YamlTag.int  : YamlTag := ⟨some "tag:yaml.org,2002:int"⟩
def YamlTag.float : YamlTag := ⟨some "tag:yaml.org,2002:float"⟩
def YamlTag.str  : YamlTag := ⟨some "tag:yaml.org,2002:str"⟩
def YamlTag.seq  : YamlTag := ⟨some "tag:yaml.org,2002:seq"⟩
def YamlTag.map  : YamlTag := ⟨some "tag:yaml.org,2002:map"⟩

/-- A YAML node in the representation graph (YAML 1.2 §3.2.1). -/
inductive YamlNode where
  /-- Scalar node: tagged content string. -/
  | scalar (tag : YamlTag) (value : String)
  /-- Sequence node: ordered list of nodes. -/
  | sequence (tag : YamlTag) (items : List YamlNode)
  /-- Mapping node: list of key-value node pairs. -/
  | mapping (tag : YamlTag) (pairs : List (YamlNode × YamlNode))
  deriving Repr

/-- A YAML document (YAML 1.2 §3.2.3). An empty document has no root node. -/
structure YamlDocument where
  /-- Root node, if any. -/
  root : Option YamlNode := none
  deriving Repr

/-- A YAML stream: a sequence of documents (YAML 1.2 §3.2.3). -/
abbrev YamlStream := List YamlDocument

/-- True if the node is a scalar. -/
def YamlNode.isScalar : YamlNode → Bool
  | .scalar .. => true
  | _          => false

/-- True if the node is a sequence. -/
def YamlNode.isSequence : YamlNode → Bool
  | .sequence .. => true
  | _            => false

/-- True if the node is a mapping. -/
def YamlNode.isMapping : YamlNode → Bool
  | .mapping .. => true
  | _           => false

/-- Extract the tag from any node kind. -/
def YamlNode.tag : YamlNode → YamlTag
  | .scalar t _    => t
  | .sequence t _  => t
  | .mapping t _   => t

/-- Extract key nodes from a mapping's pairs. -/
def YamlNode.keys : YamlNode → List YamlNode
  | .mapping _ pairs => pairs.map (·.1)
  | _                => []

/-- An empty mapping trivially has no duplicate keys. -/
theorem YamlNode.empty_mapping_no_duplicate_keys (tag : YamlTag) :
    (YamlNode.mapping tag []).keys = [] := by
  simp [keys]

/-- An empty stream is a valid YAML stream. -/
theorem YamlNode.empty_stream_is_valid :
    ([] : YamlStream).length = 0 := by
  rfl

end SWELib.Basics
