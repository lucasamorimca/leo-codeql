/**
 * @name Missing access control in initialization function
 * @description Initialization functions should verify the caller's identity to prevent unauthorized initialization
 * @kind problem
 * @problem.severity error
 * @id leo/security/missing-init-access-control
 */

import codeql.leo.Leo

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
      name.matches("init_%") or
      name.matches("setup_%")
    )
  )
}

/**
 * Holds if the function contains an assert statement (access control check)
 */
predicate hasAssertStatement(Function func) {
  exists(AssertStmt assert |
    assert.getEnclosingFunction() = func
  )
}

/**
 * Holds if the transition function calls finalize, and finalize has an assert
 */
predicate finalizeHasAssert(TransitionFunction t) {
  exists(Function finalize, CallExpr call |
    call.getEnclosingFunction() = t and
    call.getTarget() = "finalize" and
    finalize.getName() = "finalize" and
    finalize.getProgram() = t.getProgram() and
    hasAssertStatement(finalize)
  )
}

from Function func
where
  isInitFunction(func) and
  not hasAssertStatement(func) and
  not (func instanceof TransitionFunction and finalizeHasAssert(func)) and
  // Only flag transitions and public functions, not inline helpers
  (func.isTransition() or func.isFunction())
select func, "Initialization function '" + func.getName() + "' lacks access control assertion to verify caller identity"
