/**
 * @name Ternary expression with panic-prone branch
 * @description In Leo's ZK circuit, both branches of ternary expressions are always evaluated. Operations that can panic (like unsigned subtraction) will trap even in unused branches
 * @kind problem
 * @problem.severity warning
 * @id leo/security/ternary-panic-trap
 */

import codeql.leo.Leo

/**
 * Holds if expr contains a subtraction operation
 */
predicate containsSubtraction(Expr expr) {
  exists(BinaryExpr binExpr |
    binExpr.getOperator() = 1 and // subtraction
    (binExpr = expr or binExpr = expr.(BinaryExpr).getLeftOperand() or binExpr = expr.(BinaryExpr).getRightOperand())
  )
  or
  // Direct subtraction
  expr.(BinaryExpr).getOperator() = 1
}

from TernaryExpr ternary, Expr branch
where
  (branch = ternary.getThenExpr() or branch = ternary.getElseExpr()) and
  containsSubtraction(branch)
select ternary, "Ternary expression contains subtraction in $@ that will be evaluated regardless of condition, potentially causing panic", branch, "this branch"
