import SWELib.Networking.FastApi.Preamble
import SWELib.Networking.FastApi.Types

/-!
# FastAPI Dependency Injection

Recursive dependency graph model for FastAPI's `Depends()` mechanism.

## References
- FastAPI: <https://fastapi.tiangolo.com/tutorial/dependencies/>
- FastAPI: <https://fastapi.tiangolo.com/advanced/advanced-dependencies/>
-/

namespace SWELib.Networking.FastApi

/-- A single dependency declaration corresponding to `Depends(...)`.
    `hasYield` distinguishes yield-based dependencies (with teardown code
    after the yield point) from plain return dependencies. -/
structure DependsDecl where
  dependency : CallableRef
  useCache : Bool := true
  scope : DependencyScope := .request
  hasYield : Bool := false

/-- A node in the dependency tree. Recursive because dependencies
    can themselves declare sub-dependencies. -/
inductive DependencyNode where
  | mk (decl : DependsDecl) (children : List DependencyNode)

/-- The full dependency graph for a route or application. -/
structure DependencyGraph where
  roots : List DependencyNode

/-- Application state modelled as a simple key-value store. -/
abbrev AppState := List (String × String)

-- Accessors

/-- Extract the declaration from a dependency node. -/
def DependencyNode.decl : DependencyNode → DependsDecl
  | .mk d _ => d

/-- Extract the children from a dependency node. -/
def DependencyNode.children : DependencyNode → List DependencyNode
  | .mk _ cs => cs

/-- Collect all `CallableRef` values in a dependency subtree. -/
def DependencyNode.allRefs : DependencyNode → List CallableRef
  | .mk d cs => d.dependency :: (cs.map DependencyNode.allRefs).flatten

/-- Collect all `CallableRef` values across all roots. -/
def DependencyGraph.allRefs (g : DependencyGraph) : List CallableRef :=
  (g.roots.map DependencyNode.allRefs).flatten

/-- Compute the setup order (pre-order traversal): each node before its children. -/
def DependencyNode.setupOrder : DependencyNode → List DependsDecl
  | .mk d cs => d :: (cs.map DependencyNode.setupOrder).flatten

/-- Compute the teardown order (post-order traversal): children before parent.
    This is the reverse of setup order — deepest dependencies torn down first. -/
def DependencyNode.teardownOrder : DependencyNode → List DependsDecl
  | .mk d cs => (cs.map DependencyNode.teardownOrder).flatten ++ [d]

/-- Setup order for the full graph (all roots). -/
def DependencyGraph.setupOrder (g : DependencyGraph) : List DependsDecl :=
  (g.roots.map DependencyNode.setupOrder).flatten

/-- Teardown order for the full graph (all roots). -/
def DependencyGraph.teardownOrder (g : DependencyGraph) : List DependsDecl :=
  (g.roots.map DependencyNode.teardownOrder).flatten

/-- Filter yield dependencies from a dependency list (only yield deps have teardown). -/
def filterYieldDeps (deps : List DependsDecl) : List DependsDecl :=
  deps.filter (·.hasYield)

end SWELib.Networking.FastApi
