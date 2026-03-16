/-!
# XML

XML 1.0 and XML Information Set per W3C specifications.
Models the node tree structure: elements, text, CDATA, comments,
and processing instructions. Namespace-aware names.
-/

namespace SWELib.Basics

/-- A namespace-aware XML name (W3C Namespaces in XML). -/
structure XmlName where
  /-- Local part of the name. -/
  localName : String
  /-- Namespace prefix (e.g., "xsl"). -/
  «prefix» : Option String := none
  /-- Namespace URI. -/
  namespaceUri : Option String := none
  deriving DecidableEq, Repr

/-- An XML attribute: name-value pair. -/
structure XmlAttribute where
  /-- Attribute name. -/
  name : XmlName
  /-- Attribute value (after entity expansion). -/
  value : String
  deriving DecidableEq, Repr

/-- An XML node in the document tree (XML Infoset). -/
inductive XmlNode where
  /-- Element node with name, attributes, and child nodes. -/
  | element (name : XmlName) (attrs : List XmlAttribute) (children : List XmlNode)
  /-- Text content node. -/
  | text (content : String)
  /-- CDATA section node. -/
  | cdata (content : String)
  /-- Comment node. -/
  | comment (content : String)
  /-- Processing instruction node. -/
  | processingInstruction (target : String) (data : String)
  deriving Repr

/-- An XML document with root node and declaration attributes (XML 1.0 §2.8). -/
structure XmlDocument where
  /-- Root element of the document. -/
  root : XmlNode
  /-- XML version from the declaration. -/
  xmlVersion : String := "1.0"
  /-- Character encoding from the declaration. -/
  encoding : Option String := none
  deriving Repr

/-- True if the node is an element. -/
def XmlNode.isElement : XmlNode → Bool
  | .element .. => true
  | _           => false

/-- Filter children to element nodes only. -/
def XmlNode.childElements : XmlNode → List XmlNode
  | .element _ _ children => children.filter XmlNode.isElement
  | _                     => []

/-- Look up an attribute by local name on an element node. -/
def XmlNode.getAttribute (node : XmlNode) (name : String) : Option String :=
  match node with
  | .element _ attrs _ => (attrs.find? (·.name.localName == name)).map (·.value)
  | _                  => none

/-- True if the root of the document is an element node. -/
def XmlDocument.wellFormedRoot (doc : XmlDocument) : Bool :=
  doc.root.isElement

/-- Check that no two attributes in a list share the same local name
    (W3C well-formedness constraint: unique attribute names). -/
def XmlAttribute.uniqueNames (attrs : List XmlAttribute) : Bool :=
  let names := attrs.map (·.name.localName)
  names.length == names.eraseDups.length

/-- Text nodes have no child elements. -/
theorem XmlNode.text_has_no_children (s : String) :
    (XmlNode.text s).childElements = [] := by
  simp [childElements]

/-- CDATA nodes have no child elements. -/
theorem XmlNode.cdata_has_no_children (s : String) :
    (XmlNode.cdata s).childElements = [] := by
  simp [childElements]

end SWELib.Basics
