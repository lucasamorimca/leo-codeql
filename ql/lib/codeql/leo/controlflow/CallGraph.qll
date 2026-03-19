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
 * A call edge from a call site to a target function.
 * Handles CallExpr (kind=5) and AssociatedFnCallExpr (kind=15).
 *
 * LIMITATION: Only resolves calls within the same program.
 * Cross-program calls (e.g., `token.aleo/transfer()`) are NOT resolved.
 * These appear as AssociatedFnCallExpr with 2+ path segments but the
 * target program's functions are not in scope unless both programs are
 * extracted into the same CodeQL database.
 *
 * Future: Add cross-program resolution when multi-file extraction is supported.
 */
predicate callEdge(Expr call, Function target) {
  target.getProgram() = call.getEnclosingFunction().getProgram() and
  (
    target.getName() = call.(CallExpr).getTarget()
    or
    target.getName() = call.(AssociatedFnCallExpr).getFunctionName()
  )
}

/**
 * Gets the enclosing function for any AST node
 */
Function getEnclosingFunction(AstNode n) {
  result = n.(Function) or
  result = getEnclosingFunction(n.getParent())
}

/**
 * Checks if there is a call path from caller to callee.
 * NOTE: Only tracks intra-program calls. See callEdge limitation.
 */
predicate reachableFrom(Function caller, Function callee) {
  // Direct call
  directlyCallsTo(caller, callee)
  or
  // Transitive call (left-linear recursion for better optimization)
  exists(Function intermediate |
    reachableFrom(caller, intermediate) and
    directlyCallsTo(intermediate, callee)
  )
}

/**
 * Async transition to finalize flow
 * Tracks flow from async transition to its finalize function
 */
predicate transitionToFinalize(TransitionFunction t, Function f) {
  t.requiresFinalization() and
  f.isFinalize() and
  f.getProgram() = t.getProgram() and
  exists(Expr call |
    getEnclosingFunction(call) = t and
    callEdge(call, f)
  )
}

/**
 * @deprecated This predicate uses lexical scope only and is NOT call-chain-aware.
 *
 * Checks if a node is in off-chain execution context (lexical scope only).
 *
 * WARNING: A regular function called from a transition executes on-chain at
 * runtime, but this predicate returns true based on the enclosing function
 * kind alone. Use `reachableFrom` for call-chain-aware classification.
 *
 * For accurate on-chain/off-chain analysis, traverse the call graph:
 * - Check if the function is reachable from a transition/finalize entry point
 * - Use `reachableFrom(transition, function)` to determine runtime context
 */
predicate isOffChain(AstNode n) {
  exists(Function f |
    f = getEnclosingFunction(n) and
    (f.isFunction() or f.isInline())
  )
}

/**
 * @deprecated This predicate uses lexical scope only and is NOT call-chain-aware.
 *
 * Checks if a node is in on-chain execution context (lexical scope only).
 * See `isOffChain` for caveats about cross-context calls.
 *
 * For accurate on-chain/off-chain analysis, use call-chain-aware predicates instead.
 */
predicate isOnChain(AstNode n) {
  exists(Function f |
    f = getEnclosingFunction(n) and
    (f.isTransition() or f.isFinalize())
  )
}

/**
 * Gets all functions that may be called from the given function
 */
Function getACallee(Function caller) {
  exists(Expr call |
    getEnclosingFunction(call) = caller and
    callEdge(call, result)
  )
}

/**
 * Gets all functions that may call the given function
 */
Function getACaller(Function callee) { callee = getACallee(result) }

/**
 * Gets all call sites in a function (CallExpr or AssociatedFnCallExpr)
 */
Expr getACallIn(Function f) {
  getEnclosingFunction(result) = f and
  (result instanceof CallExpr or result instanceof AssociatedFnCallExpr)
}

/**
 * Gets the target function of a call expression (if resolvable)
 */
Function resolveCall(Expr call) { callEdge(call, result) }

/**
 * Checks if a function is recursive (directly or indirectly)
 */
predicate isRecursive(Function f) { reachableFrom(f, f) }

/**
 * Checks if a function is an entry point (transition)
 */
predicate isEntryPoint(Function f) { f.isTransition() }

/**
 * Gets all functions reachable from entry points.
 * NOTE: Only tracks intra-program calls. See callEdge limitation.
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
  exists(Expr call |
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
predicate isSelfRecursiveCall(Expr call) {
  exists(Function f |
    getEnclosingFunction(call) = f and
    callEdge(call, f)
  )
}

/**
 * Checks if a call is a mutually recursive call
 */
predicate isMutuallyRecursiveCall(Expr call) {
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
    access.getBase().(VarRef).getName() = structName
  )
  or
  exists(StructInitExpr init |
    init.getStructName() = structName and
    getEnclosingFunction(init) = result
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
  not exists(MethodCallExpr call | getEnclosingFunction(call) = f) and
  not exists(AssociatedFnCallExpr call | getEnclosingFunction(call) = f)
}
