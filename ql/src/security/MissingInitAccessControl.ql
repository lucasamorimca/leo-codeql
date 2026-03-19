/**
 * @name Missing access control in initialization function
 * @description Initialization functions should verify the caller's identity to prevent unauthorized initialization
 * @kind problem
 * @problem.severity error
 * @id leo/security/missing-init-access-control
 */

import codeql.leo.Leo
import codeql.leo.controlflow.CallGraph

/**
 * Holds if the function is an initialization function based on its name
 */
predicate isInitFunction(Function func) {
  exists(string name |
    name = func.getName().toLowerCase() and
    (
      name = "initialize" or
      name = "init" or
      name = "setup" or
      name = "constructor" or
      name.matches("init_%") or
      name.matches("setup_%")
    )
  )
}

/**
 * Holds if the expression is a self.caller or self.signer access.
 * Matches FieldAccessExpr with base SelfExpr and field "caller" or "signer".
 */
predicate referencesCallerOrSigner(Expr expr) {
  exists(FieldAccessExpr fa |
    fa = expr and
    fa.getBase() instanceof SelfExpr and
    (fa.getFieldName() = "caller" or fa.getFieldName() = "signer")
  )
}

/**
 * Holds if an expression tree contains a reference to self.caller or self.signer
 */
predicate containsCallerCheck(Expr expr) {
  referencesCallerOrSigner(expr)
  or
  containsCallerCheck(expr.getAChildExpr())
}

/**
 * Holds if the expression contains an address literal comparison
 */
predicate containsAddressLiteral(Expr expr) {
  expr.(LiteralExpr).getTypeSuffix() = "address"
  or
  containsAddressLiteral(expr.getAChildExpr())
}

/**
 * Holds if the function contains an access-control assert (checks caller/signer
 * or compares against address literals).
 * assert_neq is only excluded when neither operand references caller/signer,
 * since "assert_neq(self.caller, zero_address)" IS valid access control.
 */
predicate hasAccessControlAssert(Function func) {
  exists(AssertStmt assert |
    assert.getEnclosingFunction() = func and
    (
      // Plain assert: assert(self.caller == admin)
      assert.isAssert() and
      containsCallerCheck(assert.getCondition())
      or
      // assert_eq: assert_eq(self.caller, admin)
      assert.isAssertEq() and
      (
        containsCallerCheck(assert.getLeftOperand()) or
        containsCallerCheck(assert.getRightOperand())
      )
      or
      // assert_neq: only valid if one operand is caller/signer (e.g., != zero_address)
      assert.isAssertNeq() and
      (
        containsCallerCheck(assert.getLeftOperand()) or
        containsCallerCheck(assert.getRightOperand())
      )
      or
      // Address literal comparison WITH caller/signer check in same assert
      assert.isAssert() and
      containsAddressLiteral(assert.getCondition()) and
      containsCallerCheck(assert.getCondition())
      or
      (assert.isAssertEq() or assert.isAssertNeq()) and
      (containsAddressLiteral(assert.getLeftOperand()) or
       containsAddressLiteral(assert.getRightOperand())) and
      (containsCallerCheck(assert.getLeftOperand()) or
       containsCallerCheck(assert.getRightOperand()))
    )
  )
}

/**
 * Holds if the function calls a helper that has access control
 */
predicate callsHelperWithAccessControl(Function func) {
  exists(Expr call, Function helper |
    call.getEnclosingFunction() = func and
    callEdge(call, helper) and
    hasAccessControlAssert(helper)
  )
}

/**
 * Holds if the function checks caller identity via conditional return
 * (e.g., if (self.caller != admin) { return ...; })
 */
predicate hasConditionalReturnAccessControl(Function func) {
  exists(IfStmt ifStmt, ReturnStmt ret |
    ifStmt.getEnclosingFunction() = func and
    containsCallerCheck(ifStmt.getCondition()) and
    ret.getParent+() = ifStmt.getThen()
  )
}

/**
 * Holds if an assert references a parameter by name (direct or nested)
 */
predicate assertReferencesParam(AssertStmt assert, string paramName) {
  assert.getCondition().(VarRef).getName() = paramName or
  assert.getCondition().getADescendantExpr().(VarRef).getName() = paramName or
  assert.getLeftOperand().(VarRef).getName() = paramName or
  assert.getLeftOperand().getADescendantExpr().(VarRef).getName() = paramName or
  assert.getRightOperand().(VarRef).getName() = paramName or
  assert.getRightOperand().getADescendantExpr().(VarRef).getName() = paramName
}

/**
 * Holds if the transition forwards self.caller/self.signer to finalize
 * and finalize asserts on the corresponding parameter.
 */
predicate transitionForwardsCallerToFinalize(TransitionFunction t) {
  exists(
    CallExpr call, FinalizeFunction finalize, int i, AssertStmt assert, Parameter param
  |
    call.getEnclosingFunction() = t and
    finalize.getName() = call.getTarget() and
    finalize.getProgram() = t.getProgram() and
    referencesCallerOrSigner(call.getArgument(i)) and
    param.getFunction() = finalize and
    param.getParameterIndex() = i and
    assert.getEnclosingFunction() = finalize and
    assertReferencesParam(assert, param.getName())
  )
}

/**
 * Holds if the transition function calls finalize, and finalize has an assert
 */
predicate finalizeHasAccessControl(TransitionFunction t) {
  exists(FinalizeFunction finalize, CallExpr call |
    call.getEnclosingFunction() = t and
    finalize.getName() = call.getTarget() and
    finalize.getProgram() = t.getProgram() and
    (
      hasAccessControlAssert(finalize) or
      callsHelperWithAccessControl(finalize)
    )
  )
  or
  transitionForwardsCallerToFinalize(t)
}

from Function func
where
  isInitFunction(func) and
  not hasAccessControlAssert(func) and
  not callsHelperWithAccessControl(func) and
  not hasConditionalReturnAccessControl(func) and
  not (func instanceof TransitionFunction and finalizeHasAccessControl(func)) and
  // Only flag transitions — private functions can't be called externally
  func.isTransition()
select func,
  "Initialization function '" + func.getName() +
    "' lacks access control assertion to verify caller identity"
