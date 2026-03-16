import Std

/-!
# CI/CD Pipeline Specification

Models CI/CD pipeline structure, DAG validation, execution ordering,
and status computation. Based on Tekton Pipeline concepts.
-/

namespace SWELib.Cicd.Pipeline

/-- Parameter type for pipeline parameters (Tekton Pipelines). -/
inductive ParamType
  | string_
  | array_
  | object_
  deriving DecidableEq, Repr

/-- A named parameter with type and optional default value. -/
structure Param where
  /-- Parameter name -/
  name : String
  /-- Parameter type -/
  type : ParamType
  /-- Optional default value -/
  default : Option String
  deriving DecidableEq, Repr

/-- Operator for conditional when expressions. -/
inductive WhenOperator
  | in_
  | notIn
  deriving DecidableEq, Repr

/-- A conditional expression that gates task execution.
    The `values` list must be non-empty. -/
structure WhenExpr where
  /-- Input variable or literal to evaluate -/
  input : String
  /-- Comparison operator -/
  operator : WhenOperator
  /-- Values to compare against -/
  values : List String
  /-- Values list must be non-empty -/
  h_nonempty : values ≠ []
  deriving Repr

/-- Error handling behavior when a task fails. -/
inductive OnError
  | stopAndFail
  | continue_
  deriving DecidableEq, Repr

/-- Reference to a task definition, either local or remote. -/
inductive TaskRef
  | local_ (name : String)
  | remote (resolver : String) (params : List Param)
  deriving DecidableEq, Repr

/-- Matrix specification for fan-out task execution. -/
structure MatrixSpec where
  /-- Parameters to fan out over -/
  params : List Param
  /-- Additional parameter combinations to include -/
  «include» : List (List Param)
  deriving DecidableEq, Repr

/-- A task within a pipeline. -/
structure PipelineTask where
  /-- Task name (must be unique within the pipeline) -/
  name : String
  /-- Reference to the task definition -/
  taskRef : TaskRef
  /-- Parameter bindings -/
  params : List Param
  /-- Workspace bindings -/
  workspaces : List String
  /-- Tasks that must complete before this one starts -/
  runAfter : List String
  /-- Number of retry attempts on failure -/
  retries : Nat
  /-- Conditional execution expressions -/
  when : List WhenExpr
  /-- Optional timeout in seconds -/
  timeout : Option Nat
  /-- Optional matrix for fan-out -/
  matrix : Option MatrixSpec
  /-- Error handling behavior -/
  onError : OnError
  deriving Repr

/-- A task in the finally block (no runAfter field). -/
structure FinallyTask where
  /-- Task name -/
  name : String
  /-- Reference to the task definition -/
  taskRef : TaskRef
  /-- Parameter bindings -/
  params : List Param
  /-- Workspace bindings -/
  workspaces : List String
  /-- Number of retry attempts on failure -/
  retries : Nat
  /-- Conditional execution expressions -/
  when : List WhenExpr
  /-- Optional timeout in seconds -/
  timeout : Option Nat
  /-- Optional matrix for fan-out -/
  matrix : Option MatrixSpec
  /-- Error handling behavior -/
  onError : OnError
  deriving Repr

/-- A pipeline result value. -/
structure PipelineResult where
  /-- Result name -/
  name : String
  /-- Result value expression -/
  value : String
  deriving DecidableEq, Repr

/-- Pipeline specification with tasks and optional finally block. -/
structure PipelineSpec where
  /-- Pipeline-level parameters -/
  params : List Param
  /-- Ordered list of tasks -/
  tasks : List PipelineTask
  /-- Pipeline must have at least one task -/
  h_tasks_nonempty : tasks ≠ []
  /-- Tasks to run after all other tasks complete -/
  «finally» : List FinallyTask
  /-- Workspace declarations -/
  workspaces : List String
  /-- Pipeline result declarations -/
  results : List PipelineResult
  deriving Repr

/-- Phase of a single task run. -/
inductive TaskRunPhase
  | started
  | pending
  | running
  | succeeded
  | failed
  | cancelled
  | timedOut
  | skipped
  deriving DecidableEq, Repr

/-- Overall pipeline run status. -/
inductive PipelineRunStatus
  | succeeded
  | failed
  | completed
  | running
  | cancelled
  deriving DecidableEq, Repr

/-- Reference to a child task run. -/
structure ChildReference where
  /-- Name of the task -/
  taskName : String
  /-- Optional display name -/
  displayName : Option String
  /-- Current phase of the task run -/
  status : TaskRunPhase
  deriving DecidableEq, Repr

/-- Result of a pipeline run. -/
structure PipelineRunResult where
  /-- Overall status -/
  status : PipelineRunStatus
  /-- Child task references -/
  children : List ChildReference
  /-- Names of skipped tasks -/
  skippedTasks : List String
  /-- Count of ignored failures (onError = continue) -/
  ignoredFailures : Nat
  deriving DecidableEq, Repr

/-- Errors that can occur when building a DAG from pipeline tasks. -/
inductive DagError
  | cycle
  | danglingRef (name : String)
  deriving DecidableEq, Repr

-- Helper: check if all names in `refs` exist in `taskNames`
private def allRefsExist (taskNames : List String) : List String → Option String
  | [] => none
  | r :: rs =>
    if taskNames.contains r then allRefsExist taskNames rs
    else some r

-- Helper: detect cycle via DFS
private def hasCycleDFS (adj : List (String × List String)) : Bool :=
  let names := adj.map (·.1)
  -- Simple cycle detection: for each node, check if DFS from it revisits a node on the current stack
  let rec visit (node : String) (stack : List String) (visited : List String) (fuel : Nat) : Bool × List String :=
    match fuel with
    | 0 => (true, visited) -- conservative: assume cycle if out of fuel
    | fuel + 1 =>
      if stack.contains node then (true, visited)
      else if visited.contains node then (false, visited)
      else
        let deps := match adj.find? (fun p => p.1 == node) with
          | some (_, ds) => ds
          | none => []
        let newStack := node :: stack
        let newVisited := node :: visited
        deps.foldl (fun (acc : Bool × List String) dep =>
          if acc.1 then acc
          else visit dep newStack acc.2 fuel
        ) (false, newVisited)
  let totalNodes := names.length
  let fuel := totalNodes * totalNodes + totalNodes + 1
  let (hasCycle, _) := names.foldl (fun (acc : Bool × List String) name =>
    if acc.1 then acc
    else visit name [] acc.2 fuel
  ) (false, [])
  hasCycle

/-- Build a DAG (adjacency list) from a pipeline spec.
    Returns `Except.error (.danglingRef name)` if a `runAfter` references
    a nonexistent task, `Except.error .cycle` if there is a cycle,
    and `Except.ok adj` otherwise. -/
def buildDag (spec : PipelineSpec) : Except DagError (List (String × List String)) :=
  let taskNames := spec.tasks.map (·.name)
  -- Check for dangling references
  let danglingCheck := spec.tasks.foldl (fun acc t =>
    match acc with
    | Except.error e => Except.error e
    | Except.ok () =>
      match allRefsExist taskNames t.runAfter with
      | none => Except.ok ()
      | some bad => Except.error (DagError.danglingRef bad)
  ) (Except.ok ())
  match danglingCheck with
  | Except.error e => Except.error e
  | Except.ok () =>
    let adj := spec.tasks.map (fun t => (t.name, t.runAfter))
    if hasCycleDFS adj then Except.error DagError.cycle
    else Except.ok adj

-- Helper: check if all elements in a list are distinct
private def allDistinct : List String → Bool
  | [] => true
  | x :: xs => !xs.contains x && allDistinct xs

/-- Validate a pipeline specification.
    Checks: all task names unique, all runAfter names exist,
    no task has retries > 0 with onError = continue_. -/
def validatePipeline (spec : PipelineSpec) : Bool :=
  let taskNames := spec.tasks.map (·.name)
  -- All task names unique
  allDistinct taskNames &&
  -- All runAfter names exist
  spec.tasks.all (fun t => t.runAfter.all (fun r => taskNames.contains r)) &&
  -- No task has retries > 0 with continue
  spec.tasks.all (fun t => !(t.retries > 0 && t.onError == .continue_))

/-- Extract topological layers from a DAG adjacency list.
    Each layer contains nodes whose dependencies are all in previous layers. -/
def resolveExecutionOrder (adj : List (String × List String)) : List (List String) :=
  let rec go (remaining : List (String × List String)) (fuel : Nat) : List (List String) :=
    match fuel with
    | 0 => []
    | fuel + 1 =>
      if remaining.isEmpty then []
      else
        let resolved := remaining.filter (fun (_, deps) => deps.all (fun d => !remaining.any (fun (n, _) => n == d)))
        let resolvedNames := resolved.map (·.1)
        if resolvedNames.isEmpty then [remaining.map (·.1)] -- stuck, emit rest
        else
          let newRemaining := remaining.filter (fun (n, _) => !resolvedNames.contains n)
          resolvedNames :: go newRemaining fuel
  go adj (adj.length + 1)

/-- Evaluate when expressions against an environment.
    Returns true if all expressions are satisfied (conjunction).
    An empty expression list evaluates to true. -/
def evaluateWhen (exprs : List WhenExpr) (env : List (String × String)) : Bool :=
  exprs.all fun expr =>
    let inputVal := match env.find? (fun p => p.1 == expr.input) with
      | some (_, v) => v
      | none => expr.input
    match expr.operator with
    | .in_ => expr.values.contains inputVal
    | .notIn => !expr.values.contains inputVal

/-- Compute the overall pipeline run status from child task statuses.
    All succeeded => .succeeded; any failed => .failed;
    any skipped but no failures => .completed; else .running. -/
def computePipelineRunStatus (children : List ChildReference) (finallyChildren : List ChildReference) : PipelineRunStatus :=
  let all_ := children ++ finallyChildren
  if all_.all (fun c => c.status == .succeeded) then .succeeded
  else if all_.any (fun c => c.status == .failed) then .failed
  else if all_.any (fun c => c.status == .skipped) then .completed
  else .running

/-- An empty when expression list always evaluates to true. -/
theorem evaluateWhen_empty : evaluateWhen [] env = true := by
  simp [evaluateWhen]

/-- When all children succeed, the pipeline status is succeeded. -/
theorem computeStatus_succeeded :
    (∀ c ∈ children, c.status = .succeeded) →
    (∀ c ∈ finallyChildren, c.status = .succeeded) →
    computePipelineRunStatus children finallyChildren = .succeeded := by
  sorry

/-- A valid pipeline has unique task names. -/
theorem taskNamesUnique :
    validatePipeline spec = true →
    (spec.tasks.map (·.name)).Nodup := by
  sorry

/-- A valid pipeline has no tasks with retries > 0 and onError = continue_. -/
theorem validatePipeline_noRetriesWithContinue :
    validatePipeline spec = true →
    ∀ t ∈ spec.tasks, t.retries > 0 → t.onError ≠ .continue_ := by
  sorry

end SWELib.Cicd.Pipeline
