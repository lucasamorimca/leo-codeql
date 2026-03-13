/**
 * @name Privacy leak to finalize function
 * @description Detects when private record data or private parameters are passed to finalize functions, exposing sensitive data on-chain
 * @kind problem
 * @problem.severity error
 * @id leo/security/privacy-leak-to-finalize
 */

import codeql.leo.Leo

/**
 * Holds if the expression references a private parameter or private record field
 */
predicate isPrivateDataReference(Expr expr, Function enclosing) {
  exists(VarRef varRef, Parameter param |
    varRef = expr and
    varRef.getName() = param.getName() and
    param.getFunction() = enclosing and
    param.isPrivate()
  )
  or
  exists(FieldAccessExpr fieldAccess |
    fieldAccess = expr and
    exists(StructField field |
      field.getName() = fieldAccess.getFieldName() and
      field.isPrivate()
    )
  )
}

/**
 * Holds if the call is to a finalize function or mapping update operation
 */
predicate isPublicChainCall(CallExpr call) {
  call.getTarget() = "finalize"
  or
  exists(MethodCallExpr methodCall |
    methodCall = call and
    (
      methodCall.getMethodName() = "set" or
      methodCall.getMethodName() = "update" or
      methodCall.getMethodName() = "remove"
    )
  )
  or
  // Mapping operations are parsed as associated function calls (Mapping::set)
  exists(AssociatedFnCallExpr assocCall |
    assocCall = call and
    (
      assocCall.getFunctionName() = "set" or
      assocCall.getFunctionName() = "update" or
      assocCall.getFunctionName() = "remove"
    )
  )
}

from TransitionFunction transition, CallExpr call, Expr arg
where
  call.getEnclosingFunction() = transition and
  isPublicChainCall(call) and
  arg = call.getAnArgument() and
  (
    isPrivateDataReference(arg, transition)
    or
    // Also check if the argument is a variable that was assigned from private data
    exists(VarRef varRef, LetStmt letStmt |
      varRef = arg and
      letStmt.getVariableName() = varRef.getName() and
      letStmt.getEnclosingFunction() = transition and
      isPrivateDataReference(letStmt.getInitializer(), transition)
    )
  )
select call, "Transition function leaks private data to on-chain finalize or mapping operation at $@", arg, "this argument"
