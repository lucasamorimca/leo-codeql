/**
 * @name Privacy leak to finalize function
 * @description Detects when private record data or private parameters are passed to finalize functions, exposing sensitive data on-chain
 * @kind problem
 * @problem.severity error
 * @id leo/security/privacy-leak-to-finalize
 */

import codeql.leo.Leo
import codeql.leo.controlflow.CallGraph

/**
 * Holds if the parameter is private in the given function
 */
predicate isPrivateParam(Parameter param, Function func) {
  param.getFunction() = func and
  param.isPrivate()
}

/**
 * Holds if the expression directly references a private parameter.
 * NOTE: Name-based variable tracking (no SSA) means we cannot detect
 * overwritten variables across different scopes or complex control flow.
 * This is a fundamental limitation until SSA/dataflow infrastructure is added.
 */
predicate isPrivateParamRef(VarRef ref, Function enclosing) {
  exists(Parameter param |
    isPrivateParam(param, enclosing) and
    ref.getName() = param.getName()
  )
}

/**
 * Holds if the expression accesses a private field of a record or struct.
 * Matches patterns like `record.private_field` and nested struct access.
 */
predicate isPrivateFieldAccess(FieldAccessExpr fa) {
  exists(StructField field, StructDeclaration sd |
    field.getName() = fa.getFieldName() and
    field.isPrivate() and
    field.getStruct() = sd and
    sd.getProgram() = fa.getEnclosingFunction().getProgram() and
    (
      // Type-aware: resolve parameter type to struct
      exists(Parameter p |
        fa.getBase().(VarRef).getName() = p.getName() and
        p.getFunction() = fa.getEnclosingFunction() and
        p.getType().(NamedType).getName() = sd.getName()
      )
      or
      // Fallback: unresolvable base, keep current behavior
      not exists(Parameter p |
        fa.getBase().(VarRef).getName() = p.getName() and
        p.getFunction() = fa.getEnclosingFunction()
      )
    )
  )
}

/**
 * Holds if the expression is a call to a finalize function or mapping operation.
 * Note: Without receiver tracking in the AST, we conservatively flag all set/update/remove
 * method calls. To reduce false positives, we only flag if a mapping is declared in the same program.
 */
predicate isPublicChainCall(Expr call) {
  // Finalize function call
  call instanceof CallExpr and
  exists(FinalizeFunction target |
    target.getName() = call.(CallExpr).getTarget() and
    target.getProgram() = call.getEnclosingFunction().getProgram()
  )
  or
  // Mapping method call - only flag if program has mappings declared
  call instanceof MethodCallExpr and
  call.(MethodCallExpr).getMethodName() in ["set", "update", "remove"] and
  exists(MappingDeclaration mapping |
    mapping.getProgram() = call.getEnclosingFunction().getProgram()
  )
  or
  // Mapping associated function call
  call instanceof AssociatedFnCallExpr and
  call.(AssociatedFnCallExpr).getFunctionName() in ["set", "update", "remove"]
}

/**
 * Gets the arguments of any callable expression.
 */
Expr getACallArgument(Expr call) {
  result = call.(CallExpr).getAnArgument()
  or
  result = call.(MethodCallExpr).getAnArgument()
  or
  result = call.(AssociatedFnCallExpr).getAnArgument()
}

/**
 * Holds if the expression is or contains a direct private data reference.
 */
predicate containsPrivateData(Expr expr, Function enclosing) {
  isPrivateParamRef(expr, enclosing)
  or
  isPrivateFieldAccess(expr)
  or
  // Track through field access base (nested struct chains)
  containsPrivateData(expr.(FieldAccessExpr).getBase(), enclosing)
  or
  containsPrivateData(expr.(BinaryExpr).getLeftOperand(), enclosing)
  or
  containsPrivateData(expr.(BinaryExpr).getRightOperand(), enclosing)
  or
  containsPrivateData(expr.(UnaryExpr).getOperand(), enclosing)
  or
  containsPrivateData(expr.(TernaryExpr).getThenExpr(), enclosing)
  or
  containsPrivateData(expr.(TernaryExpr).getElseExpr(), enclosing)
  or
  exists(Expr child |
    child = expr.(CastExpr).getAChildExpr() and
    containsPrivateData(child, enclosing)
  )
  or
  containsPrivateData(expr.(StructInitExpr).getAFieldInit(), enclosing)
  or
  // Track through index access (array[idx])
  containsPrivateData(expr.(IndexAccessExpr).getAChildExpr(), enclosing)
  or
  // Track through tuple access (tuple.0)
  containsPrivateData(expr.(TupleAccessExpr).getAChildExpr(), enclosing)
}

/**
 * Holds if varName is assigned from private data in the given function,
 * AND is not subsequently overwritten with non-private data.
 */
predicate varHoldsPrivateData(string varName, Function enclosing) {
  (
    exists(LetStmt letStmt |
      letStmt.getEnclosingFunction() = enclosing and
      letStmt.getVariableName() = varName and
      tracesToPrivateData(letStmt.getInitializer(), enclosing)
    )
    or
    exists(AssignStmt assignStmt |
      assignStmt.getEnclosingFunction() = enclosing and
      assignStmt.getLhs().(VarRef).getName() = varName and
      tracesToPrivateData(assignStmt.getRhs(), enclosing)
    )
  ) and
  not varOverwrittenWithPublicData(varName, enclosing)
}

/**
 * Holds if the variable is reassigned with non-private data after all
 * private assignments. Uses containsPrivateData (non-recursive base)
 * instead of tracesToPrivateData to avoid non-monotonic recursion.
 * NOTE: This is intra-block only. Cross-block overwrite detection requires
 * proper dominance analysis (Phase 3).
 */
predicate varOverwrittenWithPublicData(string varName, Function enclosing) {
  exists(AssignStmt publicAssign, int publicIdx, BlockStmt block |
    publicAssign.getEnclosingFunction() = enclosing and
    publicAssign.getLhs().(VarRef).getName() = varName and
    block.getStatement(publicIdx) = publicAssign and
    not containsPrivateData(publicAssign.getRhs(), enclosing) and
    // No private assignment after this public one in the same block
    not exists(AssignStmt laterPrivate, int laterIdx |
      laterPrivate.getEnclosingFunction() = enclosing and
      laterPrivate.getLhs().(VarRef).getName() = varName and
      laterPrivate.getParent() = block and
      block.getStatement(laterIdx) = laterPrivate and
      laterIdx > publicIdx and
      containsPrivateData(laterPrivate.getRhs(), enclosing)
    ) and
    // Every use of this var in a chain call comes AFTER the public overwrite
    forall(Expr use, Expr chainCall, int useIdx, Stmt callStmt |
      chainCall.getEnclosingFunction() = enclosing and
      isPublicChainCall(chainCall) and
      use = getACallArgument(chainCall) and
      use.(VarRef).getName() = varName and
      callStmt = chainCall.getParent+().(Stmt) and
      callStmt.getParent() = block and
      block.getStatement(useIdx) = callStmt |
      useIdx > publicIdx
    )
  )
}

/**
 * Holds if the expression traces to private data through variable
 * assignments within the same function scope.
 */
predicate tracesToPrivateData(Expr expr, Function enclosing) {
  containsPrivateData(expr, enclosing)
  or
  exists(VarRef varRef |
    varRef = expr and
    varHoldsPrivateData(varRef.getName(), enclosing)
  )
}

/**
 * Holds if the expression traces to a specific parameter through
 * variable assignments within the same function scope.
 */
predicate tracesToSpecificParam(Expr expr, Function func, string paramName) {
  expr.(VarRef).getName() = paramName and expr.getEnclosingFunction() = func
  or
  exists(string varName |
    expr.(VarRef).getName() = varName and
    expr.getEnclosingFunction() = func and
    varName != paramName and
    exists(LetStmt letStmt |
      letStmt.getEnclosingFunction() = func and
      letStmt.getVariableName() = varName and
      tracesToSpecificParam(letStmt.getInitializer(), func, paramName)
    )
  )
  or
  exists(string varName |
    expr.(VarRef).getName() = varName and
    expr.getEnclosingFunction() = func and
    varName != paramName and
    exists(AssignStmt assignStmt |
      assignStmt.getEnclosingFunction() = func and
      assignStmt.getLhs().(VarRef).getName() = varName and
      tracesToSpecificParam(assignStmt.getRhs(), func, paramName)
    )
  )
  or
  tracesToSpecificParam(expr.(BinaryExpr).getLeftOperand(), func, paramName)
  or
  tracesToSpecificParam(expr.(BinaryExpr).getRightOperand(), func, paramName)
  or
  tracesToSpecificParam(expr.(UnaryExpr).getOperand(), func, paramName)
}

/**
 * Holds if a called function receives data via paramIdx and passes it
 * to a public chain call (recursive inter-function tracking).
 */
predicate calledFunctionLeaksArg(Function callee, int paramIdx) {
  exists(Expr innerCall, Expr innerArg, Parameter param |
    innerCall.getEnclosingFunction() = callee and
    isPublicChainCall(innerCall) and
    innerArg = getACallArgument(innerCall) and
    param.getFunction() = callee and
    param.getParameterIndex() = paramIdx and
    tracesToSpecificParam(innerArg, callee, param.getName())
  )
  or
  // Recursive: callee passes param to another function that leaks
  exists(CallExpr innerCall, int j, Parameter param |
    innerCall.getEnclosingFunction() = callee and
    param.getFunction() = callee and
    param.getParameterIndex() = paramIdx and
    tracesToSpecificParam(innerCall.getArgument(j), callee, param.getName()) and
    calledFunctionLeaksArg(innerCall.getTargetFunction(), j)
  )
  or
  // Recursive: callee passes param through associated function call
  exists(AssociatedFnCallExpr innerCall, int j, Parameter param, Function target |
    innerCall.getEnclosingFunction() = callee and
    param.getFunction() = callee and
    param.getParameterIndex() = paramIdx and
    tracesToSpecificParam(innerCall.getArgument(j), callee, param.getName()) and
    callEdge(innerCall, target) and
    calledFunctionLeaksArg(target, j)
  )
}

from TransitionFunction transition, Expr call, Expr arg, string reason
where
  call.getEnclosingFunction() = transition and
  isPublicChainCall(call) and
  arg = getACallArgument(call) and
  (
    // Direct: private data flows to finalize/mapping call
    tracesToPrivateData(arg, transition) and
    reason = "this argument"
    or
    // Inter-function: private data passed to helper that leaks it
    // Find helper calls where private data is passed
    exists(CallExpr helperCall, int i, Expr helperArg |
      helperCall.getEnclosingFunction() = transition and
      helperArg = helperCall.getArgument(i) and
      tracesToPrivateData(helperArg, transition) and
      calledFunctionLeaksArg(helperCall.getTargetFunction(), i) and
      // The public chain call must be the helper call itself or a call it makes
      (call = helperCall or call.getEnclosingFunction() = helperCall.getTargetFunction()) and
      arg = getACallArgument(call) and
      reason = "this argument (via helper function)"
    )
  )
select call,
  "Transition function leaks private data to on-chain finalize or mapping operation at $@",
  arg, reason
