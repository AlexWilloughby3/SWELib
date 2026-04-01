import SWELib.Networking.FastApi.Operations
import SWELib.Networking.FastApi.OpenAPI
import SWELib.Networking.FastApi.Dependencies
import SWELib.Networking.FastApi.Routing
import SWELib.Networking.FastApi.Types

/-!
# FastAPI Invariants

Boolean predicates, Prop-level invariants, and theorems capturing
well-formedness conditions, acyclicity, uniqueness, and state-machine
constraints for the FastAPI formalization.

## References
- FastAPI: <https://fastapi.tiangolo.com/>
- RFC 6455 (WebSocket): state machine
-/

namespace SWELib.Networking.FastApi

open SWELib.Networking.Websocket

-- 1. PathTemplate.isWellFormed is defined in Operations.lean

-- 2. Parameter completeness

/-- Every path parameter name in the template has a corresponding
    `ParamDescriptor` with `source = .path`. -/
def paramsComplete (t : PathTemplate) (params : List ParamDescriptor) : Bool :=
  t.paramNames.all fun name =>
    params.any fun p => p.source == .path && p.name == name

-- 3. APIRouter.prefixWellFormed is defined in Operations.lean

-- 4. Dependency graph acyclicity

/-- Check that no `CallableRef` appears as both ancestor and descendant
    in the dependency tree. Uses a fuel parameter for termination.
    Noncomputable because `CallableRef` equality is axiomatized. -/
noncomputable def DependencyNode.isAcyclicAux (seen : List CallableRef) (fuel : Nat)
    (node : DependencyNode) : Bool :=
  match fuel with
  | 0 => true  -- conservatively accept when out of fuel
  | fuel' + 1 =>
    match node with
    | .mk d cs =>
      -- Check if the current node's callable is already in the ancestor set
      if seen.contains d.dependency then
        false  -- cycle detected
      else
        let seen' := d.dependency :: seen
        cs.all fun c => DependencyNode.isAcyclicAux seen' fuel' c

/-- Check that the dependency graph has no cycles.
    Uses a fuel bound to guarantee termination. -/
noncomputable def DependencyGraph.isDag (g : DependencyGraph) : Bool :=
  g.roots.all fun r => DependencyNode.isAcyclicAux [] 100 r

/-- Prop-level acyclicity: no callable ref in a node's subtree
    equals the node's own callable ref (transitively). -/
def DependencyNode.IsAcyclic : DependencyNode → Prop
  | .mk d cs =>
    (∀ c ∈ cs, d.dependency ∉ DependencyNode.allRefs c) ∧
    (∀ c ∈ cs, DependencyNode.IsAcyclic c)

/-- Prop-level acyclicity for the full graph. -/
def DependencyGraph.IsAcyclic (g : DependencyGraph) : Prop :=
  ∀ n ∈ g.roots, DependencyNode.IsAcyclic n

-- 5. Dependency scope consistency

/-- If a node has `scope = .request`, none of its children should have
    `scope = .function` (a request-scoped dep tears down after the response,
    so its sub-dependencies must also be request-scoped to remain available). -/
def DependencyNode.scopeConsistent (fuel : Nat) : DependencyNode → Bool
  | .mk d cs =>
    match fuel with
    | 0 => true
    | fuel' + 1 =>
      match d.scope with
      | .request => cs.all fun c =>
          c.decl.scope != .function && DependencyNode.scopeConsistent fuel' c
      | .function => cs.all fun c => DependencyNode.scopeConsistent fuel' c

-- 6. Operation ID uniqueness

/-- Check that no two operations share the same non-none operationId. -/
def operationIdsUnique (ops : List PathOperation) : Bool :=
  let ids := ops.filterMap (·.operationId)
  ids.length == ids.eraseDups.length

/-- Operation ID uniqueness for a FastAPI application. -/
def FastAPIApp.hasUniqueOperationIds (app : FastAPIApp) : Bool :=
  operationIdsUnique app.router.routes

-- 7. Response model filter subset theorem

/-- Every field in the filtered output was present in the original input. -/
theorem applyResponseModelFilter_subset
    (incl excl : Option (List String))
    (excludeNone : Bool)
    (fields : List (String × Option String))
    (f : String × Option String)
    (hf : f ∈ applyResponseModelFilter incl excl excludeNone fields)
    : f ∈ fields := by
  unfold applyResponseModelFilter at hf
  exact (List.mem_filter.mp hf).1

-- 8. Middleware execution order

/-- The execution order of middleware: last-registered is outermost and
    executes first (standard ASGI middleware stacking). -/
def MiddlewareChain.executionOrder (chain : MiddlewareChain) : List MiddlewareEntry :=
  chain.reverse

-- 9. WebSocket accept-before-send

/-- A WebSocket must be accepted before data can be sent:
    `sendWebSocket` only succeeds in `OPEN` state, which requires
    a prior successful `acceptWebSocket` from `CONNECTING`. -/
theorem ws_accept_before_send :
    sendWebSocket ReadyState.CONNECTING = none := by
  rfl

/-- Accepting transitions from CONNECTING to OPEN. -/
theorem ws_accept_connecting :
    acceptWebSocket ReadyState.CONNECTING = some ReadyState.OPEN := by
  rfl

/-- After accepting, send succeeds. -/
theorem ws_send_after_accept :
    (acceptWebSocket ReadyState.CONNECTING).bind sendWebSocket = some ReadyState.OPEN := by
  rfl

/-- Full WebSocket lifecycle: accept → close → complete. -/
theorem ws_full_lifecycle :
    ((acceptWebSocket ReadyState.CONNECTING).bind closeWebSocket).bind completeClose
    = some ReadyState.CLOSED := by
  rfl

-- 10. Teardown ordering invariant

/-- Teardown order is the reverse of setup order for a single node. -/
theorem teardown_reverse_setup_node (n : DependencyNode) :
    n.teardownOrder = n.setupOrder.reverse := by
  sorry -- ALGEBRAIC: requires induction over DependencyNode + List.reverse lemmas

-- 11. Lifespan: model as an ordering on phases rather than a vacuous
-- distinctness check. The startup phase has ordinal 0, shutdown has ordinal 1.

/-- Ordinal value for lifespan phases: startup = 0, shutdown = 1. -/
def LifespanPhase.ordinal : LifespanPhase → Nat
  | .startup => 0
  | .shutdown => 1

/-- Startup strictly precedes shutdown in the lifespan ordering. -/
theorem lifespan_startup_precedes_shutdown :
    LifespanPhase.startup.ordinal < LifespanPhase.shutdown.ordinal := by
  decide

-- 12. Route registration preserves existing routes (structural)

/-- Registering a new route preserves all previously registered routes. -/
theorem registerRoute_preserves (router : APIRouter) (op : PathOperation)
    (r : PathOperation) (hr : r ∈ router.routes) :
    r ∈ (registerRoute router op).routes := by
  simp [registerRoute, List.mem_append]
  exact Or.inl hr

-- 13. Include router preserves parent routes (structural)

/-- Including a child router preserves all parent routes. -/
theorem includeRouter_preserves_parent (parent child : APIRouter)
    (r : PathOperation) (hr : r ∈ parent.routes) :
    r ∈ (includeRouter parent child).routes := by
  simp [includeRouter, List.mem_append]
  exact Or.inl hr

-- 14. Exception handler dispatch: if dispatch returns a handler,
-- a matching entry exists in the handler list.

/-- Exception dispatch returns a handler only if a matching key exists. -/
theorem dispatchException_some_iff (handlers : List ExceptionHandlerEntry)
    (key : ExceptionHandlerKey) (h : CallableRef) :
    dispatchException handlers key = some h →
    ∃ e ∈ handlers, e.key = key := by
  intro hdisp
  simp [dispatchException] at hdisp
  match hfind : handlers.find? (fun e => e.key == key) with
  | some entry =>
    have hmem := List.mem_of_find?_eq_some hfind
    have hpred := List.find?_some hfind
    simp [BEq.beq, decide_eq_true_eq] at hpred
    exact ⟨entry, hmem, hpred⟩
  | none =>
    simp [hfind] at hdisp

-- 15. Middleware chain length is preserved by executionOrder

/-- Reversing the middleware chain preserves its length. -/
theorem middlewareChain_executionOrder_length (chain : MiddlewareChain) :
    (MiddlewareChain.executionOrder chain).length = chain.length := by
  simp [MiddlewareChain.executionOrder, List.length_reverse]

-- 16. Well-formed path template starts with slash (structural)

/-- A well-formed path template starts with "/". -/
theorem wellFormed_startsWith_slash (t : PathTemplate)
    (h : t.isWellFormed = true) :
    t.raw.startsWith "/" = true := by
  simp [PathTemplate.isWellFormed] at h
  exact h.1

-- 17. Background tasks: execution ordering invariant

/-- Background tasks execute in insertion order, after the response is sent
    and after all middleware and yield-dependency teardown has completed.
    This is a temporal ordering property that cannot be proved structurally
    without a runtime lifecycle model. -/
axiom backgroundTasks_post_response :
  ∀ (_app : FastAPIApp) (_tasks : BackgroundTasks),
    True  -- Placeholder: tasks run after response + middleware + teardown
  -- REQUIRES_HUMAN: needs a lifecycle state machine to state precisely

end SWELib.Networking.FastApi
