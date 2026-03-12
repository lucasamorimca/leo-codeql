/**
 * Call graph for Leo programs
 * Provides interprocedural analysis and call resolution
 */

import codeql.leo.ast.AstNode
import codeql.leo.ast.Function
import codeql.leo.ast.Expression
import codeql.leo.ast.Statement
import codeql.leo.ast.Declaration
import codeql.leo.ast.Program

/**
 * A call edge from a call site to a target function
 */
predicate callEdge(CallExpr call, Function target) {
  target.getName() = call.getTarget() and
  target.getProgram() = call.getEnclosingFunction().getProgram()
}

/**
 * Gets the enclosing function for any AST node
 */
Function getEnclosingFunction(AstNode n) {
  result = n.(Function) or
  result = getEnclosingFunction(n.getParent())
}

/**
 * Checks if there is a call path from caller to callee
 */
predicate reachableFrom(Function caller, Function callee) {
  // Direct call
  exists(CallExpr call |
    getEnclosingFunction(call) = caller and
    callEdge(call, callee)
  )
  or
  // Transitive call
  exists(Function intermediate |
    reachableFrom(caller, intermediate) and
    reachableFrom(intermediate, callee)
  )
}

/**
 * Async transition to finalize flow
 * Tracks flow from async transition to its finalize function
 */
predicate transitionToFinalize(TransitionFunction t, Function f) {
  t.requiresFinalization() and
  f.getName() = "finalize" and
  f.getProgram() = t.getProgram() and
  exists(CallExpr call |
    getEnclosingFunction(call) = t and
    call.getTarget() = "finalize"
  )
}

/**
 * Checks if a node is in off-chain execution context
 */
predicate isOffChain(AstNode n) {
  exists(Function f |
    f = getEnclosingFunction(n) and
    (f.isFunction() or f.isInline())
  )
}

/**
 * Checks if a node is in on-chain execution context
 */
predicate isOnChain(AstNode n) {
  exists(Function f |
    f = getEnclosingFunction(n) and
    f.isTransition()
  )
}

/**
 * Gets all functions that may be called from the given function
 */
Function getACallee(Function caller) {
  exists(CallExpr call |
    getEnclosingFunction(call) = caller and
    callEdge(call, result)
  )
}

/**
 * Gets all functions that may call the given function
 */
Function getACaller(Function callee) { callee = getACallee(result) }

/**
 * Gets all call sites in a function
 */
CallExpr getACallIn(Function f) { getEnclosingFunction(result) = f }

/**
 * Gets the target function of a call expression (if resolvable)
 */
Function resolveCall(CallExpr call) { callEdge(call, result) }

/**
 * Checks if a function is recursive (directly or indirectly)
 */
predicate isRecursive(Function f) { reachableFrom(f, f) }

/**
 * Checks if a function is an entry point (transition)
 */
predicate isEntryPoint(Function f) { f.isTransition() }

/**
 * Gets all functions reachable from entry points
 */
Function getReachableFunction() {
  isEntryPoint(result) or
  exists(Function entry |
    isEntryPoint(entry) and
    reachableFrom(entry, result)
  )
}

/**
 * Checks if caller directly calls callee (non-transitive)
 */
predicate directlyCallsTo(Function caller, Function callee) {
  exists(CallExpr call |
    getEnclosingFunction(call) = caller and
    callEdge(call, callee)
  )
}

/**
 * Checks if a function may execute in async context
 */
predicate mayExecuteAsync(Function f) {
  exists(TransitionFunction t |
    t.isAsync() and
    (f = t or reachableFrom(t, f))
  )
}

/**
 * Gets functions that may be called with public inputs
 */
Function getPublicInputFunction() {
  result.isTransition() and
  result.hasPublicParameter()
}

/**
 * Gets functions that may be called with private inputs
 */
Function getPrivateInputFunction() {
  result.isTransition() and
  result.hasPrivateParameter()
}

/**
 * Checks if a call is a self-recursive call
 */
predicate isSelfRecursiveCall(CallExpr call) {
  exists(Function f |
    getEnclosingFunction(call) = f and
    callEdge(call, f)
  )
}

/**
 * Checks if a call is a mutually recursive call
 */
predicate isMutuallyRecursiveCall(CallExpr call) {
  exists(Function caller, Function callee |
    getEnclosingFunction(call) = caller and
    callEdge(call, callee) and
    reachableFrom(callee, caller) and
    caller != callee
  )
}

/**
 * Gets all method calls in a function
 */
MethodCallExpr getAMethodCallIn(Function f) {
  getEnclosingFunction(result) = f
}

/**
 * Gets functions that contain field access to a specific struct
 */
Function accessesStruct(string structName) {
  exists(FieldAccessExpr access |
    getEnclosingFunction(access) = result and
    exists(StructInitExpr init |
      init.getStructName() = structName and
      getEnclosingFunction(init) = result
    )
  )
}

/**
 * Checks if a function modifies state (has assignments)
 */
predicate modifiesState(Function f) {
  exists(AssignStmt assign | getEnclosingFunction(assign) = f)
}

/**
 * Checks if a function is pure (no state modifications, no external calls)
 */
predicate isPure(Function f) {
  not modifiesState(f) and
  not exists(CallExpr call | getEnclosingFunction(call) = f) and
  not exists(MethodCallExpr call | getEnclosingFunction(call) = f)
}
