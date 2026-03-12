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
  func.getName().toLowerCase().matches("%init%")
}

/**
 * Holds if the function contains an assert statement (access control check)
 */
predicate hasAssertStatement(Function func) {
  exists(AssertStmt assert |
    assert.getEnclosingFunction() = func
  )
}

from Function func
where
  isInitFunction(func) and
  not hasAssertStatement(func) and
  // Only flag transitions and public functions, not inline helpers
  (func.isTransition() or func.isFunction())
select func, "Initialization function '" + func.getName() + "' lacks access control assertion to verify caller identity"
