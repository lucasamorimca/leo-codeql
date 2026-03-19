/**
 * @name Ternary expression with panic-prone branch
 * @description In Leo's ZK circuit, both branches of ternary expressions are always evaluated. Unwrapped arithmetic operations (add/sub/mul/div/mod/pow) can panic and will trap even in unused branches
 * @kind problem
 * @problem.severity warning
 * @id leo/security/ternary-panic-trap
 */

import codeql.leo.Leo
import codeql.leo.controlflow.ControlFlow

/**
 * Holds if the binary expression is an unwrapped arithmetic op that can panic.
 * Uses semantic predicate instead of raw operator codes.
 */
predicate isPanickingBinaryOp(BinaryExpr bin) {
  bin.isUnwrappedArithmetic()
}

/**
 * Holds if the binary expression is a panic-prone operation (sub/div/mod).
 * These operations can panic based on operand values, unlike add/mul which wrap safely.
 * Operator codes: SUB=15, DIV=17, MOD=18
 */
predicate isPanicProneOp(BinaryExpr bin) {
  bin.getOperator() in [15, 17, 18]
}

/**
 * Holds if the unary expression can panic (negate on unsigned).
 */
predicate isPanickingUnaryOp(UnaryExpr unary) {
  unary.isNegate()
}

/**
 * Holds if the function body contains a panicking operation on a path
 * reachable from function entry to a return statement.
 * Uses CFG reachability to avoid flagging unreachable dead code.
 *
 * This eliminates false positives from functions that happen to contain
 * unwrapped arithmetic in unreachable code paths (e.g., early returns,
 * dead branches after panic). Only operations that can actually execute
 * and return their result will be flagged.
 */
predicate functionContainsPanickingOp(Function f) {
  exists(Expr e, ReturnStmt ret |
    e.getEnclosingFunction() = f and
    ret.getEnclosingFunction() = f and
    (isPanickingBinaryOp(e) or isPanickingUnaryOp(e)) and
    // The panicking op must be in a statement that can reach a return
    exists(Stmt panickingStmt |
      panickingStmt = e.getParent+().(Stmt) and
      panickingStmt.getEnclosingFunction() = f and
      cfgPath(panickingStmt, ret)
    )
  )
}

/**
 * Holds if expr contains an unwrapped operation that can panic,
 * including through function calls to functions with panicking ops.
 */
predicate containsPanickingOp(Expr expr) {
  isPanickingBinaryOp(expr)
  or
  isPanickingUnaryOp(expr)
  or
  exists(BinaryExpr descendant |
    isPanickingBinaryOp(descendant) and
    descendant = expr.getADescendantExpr()
  )
  or
  exists(UnaryExpr descendant |
    isPanickingUnaryOp(descendant) and
    descendant = expr.getADescendantExpr()
  )
  or
  // Track through function calls that contain panicking ops
  exists(CallExpr call |
    call = expr or call = expr.getADescendantExpr() |
    functionContainsPanickingOp(call.getTargetFunction())
  )
}

from AstNode node, Expr branch, string message, string branchLabel
where
  // Ternary case
  (
    exists(TernaryExpr ternary |
      node = ternary and
      (branch = ternary.getThenExpr() or branch = ternary.getElseExpr()) and
      containsPanickingOp(branch) and
      message = "Ternary expression" and
      branchLabel = "this branch"
    )
  )
  or
  // If-else case (circuit context only - not finalize)
  // Only flag sub/div/mod operations that use variables from the condition
  (
    exists(IfStmt ifStmt, BlockStmt branchBlock, BinaryExpr panicking |
      node = ifStmt and
      not ifStmt.getEnclosingFunction().isFinalize() and
      (
        (branchBlock = ifStmt.getThen() and branchLabel = "then branch")
        or
        (branchBlock = ifStmt.getElse() and branchLabel = "else branch")
      ) and
      panicking.getParent+() = branchBlock and
      isPanicProneOp(panicking) and
      // At least one operand of the panicking op appears in the condition
      exists(VarRef condVar, VarRef opVar |
        condVar.getParent+() = ifStmt.getCondition() and
        (
          opVar = panicking.getLeftOperand() or
          opVar = panicking.getRightOperand() or
          opVar.getParent+() = panicking.getLeftOperand() or
          opVar.getParent+() = panicking.getRightOperand()
        ) and
        opVar.getName() = condVar.getName()
      ) and
      branch = panicking and
      message = "If-else statement"
    )
  )
select node,
  message + " contains panic-prone operation (add/sub/mul/div/mod/pow/negate) in $@ " +
    "that will be evaluated regardless of condition in ZK circuits",
  branch, branchLabel
