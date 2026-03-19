/**
 * Leo statement nodes
 */

import codeql.leo.ast.AstNode
import codeql.leo.ast.Type
import codeql.leo.ast.Expression
import codeql.leo.ast.Function

/**
 * A statement node
 * kind: 0=expr, 1=return, 2=let, 3=const, 4=assign, 5=if, 6=for, 7=block, 8=assert, 9=storage
 */
class Stmt extends AstNode, @leo_stmt {
  /**
   * Gets the kind of this statement
   */
  int getKind() { leo_stmts(this, result) }

  /**
   * Gets the enclosing function
   */
  Function getEnclosingFunction() {
    result = this.getParent().(Function) or
    result = this.getParent().(Stmt).getEnclosingFunction() or
    result = this.getParent().(Expr).getEnclosingFunction()
  }

  /**
   * Gets a direct child statement (non-recursive)
   */
  Stmt getAChildStmt() { result = this.getAChild().(Stmt) }

  /**
   * Gets all descendant statements recursively
   */
  Stmt getADescendantStmt() {
    result = this.getAChildStmt() or
    result = this.getAChildStmt().getADescendantStmt()
  }

  override string toString() { result = "Stmt" }
}

/**
 * An expression statement
 */
class ExprStmt extends Stmt {
  ExprStmt() { this.getKind() = 0 }

  /**
   * Gets the expression in this statement
   */
  Expr getExpr() { result = this.getAChild().(Expr) }

  override string toString() { result = "ExprStmt" }
}

/**
 * A return statement
 */
class ReturnStmt extends Stmt {
  ReturnStmt() { this.getKind() = 1 }

  /**
   * Gets the return expression (if any)
   */
  Expr getExpr() { result = this.getAChild().(Expr) }

  /**
   * Checks if this is a void return.
   * NOTE: Currently always false — the extractor emits Expression::Unit
   * for void returns, so getExpr() always returns a result.
   * Kept for API completeness; may become useful if extraction changes.
   */
  predicate isVoid() { not exists(this.getExpr()) }

  override string toString() { result = "return" }
}

/**
 * A let statement (variable declaration)
 */
class LetStmt extends Stmt {
  LetStmt() { this.getKind() = 2 }

  /**
   * Gets the variable name
   */
  string getVariableName() { leo_variable_decls(this, result, _) }

  /**
   * Gets the variable type
   */
  LeoType getVariableType() { leo_variable_decls(this, _, result) }

  /**
   * Gets the initialization expression
   */
  Expr getInitializer() { result = this.getAChild().(Expr) }

  override string toString() { result = "let " + this.getVariableName() }
}

/**
 * A const statement (constant declaration)
 */
class ConstStmt extends Stmt {
  ConstStmt() { this.getKind() = 3 }

  /**
   * Gets the constant name
   */
  string getConstantName() { leo_variable_decls(this, result, _) }

  /**
   * Gets the constant type
   */
  LeoType getConstantType() { leo_variable_decls(this, _, result) }

  /**
   * Gets the initialization expression
   */
  Expr getInitializer() { result = this.getAChild().(Expr) }

  override string toString() { result = "const " + this.getConstantName() }
}

/**
 * An assignment statement
 */
class AssignStmt extends Stmt {
  AssignStmt() { this.getKind() = 4 }

  /**
   * Gets the operator code
   */
  int getOperator() { leo_assign_ops(this, result) }

  /**
   * Gets the left-hand side expression
   */
  Expr getLhs() { leo_assign_lhs(this, result) }

  /**
   * Gets the right-hand side expression
   */
  Expr getRhs() { leo_assign_rhs(this, result) }

  /**
   * Checks if this is a simple assignment (=)
   */
  predicate isSimpleAssignment() { this.getOperator() = 0 }

  override string toString() { result = "assign" }
}

/**
 * An if statement
 */
class IfStmt extends Stmt {
  IfStmt() { this.getKind() = 5 }

  /**
   * Gets the condition expression
   */
  Expr getCondition() { leo_if_condition(this, result) }

  /**
   * Gets the then block
   */
  BlockStmt getThen() { leo_if_then(this, result) }

  /**
   * Gets the else block (if present)
   */
  BlockStmt getElse() { leo_if_else(this, result) }

  /**
   * Checks if this if statement has an else branch
   */
  predicate hasElse() { exists(this.getElse()) }

  override string toString() { result = "if" }
}

/**
 * A for loop statement
 */
class ForStmt extends Stmt {
  ForStmt() { this.getKind() = 6 }

  /**
   * Gets the loop variable name
   */
  string getVariableName() { leo_for_variable(this, result) }

  /**
   * Gets the lower bound expression
   */
  Expr getLowerBound() { leo_for_range(this, result, _) }

  /**
   * Gets the upper bound expression
   */
  Expr getUpperBound() { leo_for_range(this, _, result) }

  /**
   * Gets the loop body
   */
  BlockStmt getBody() { leo_for_body(this, result) }

  override string toString() { result = "for " + this.getVariableName() }
}

/**
 * A block statement (sequence of statements)
 */
class BlockStmt extends Stmt {
  BlockStmt() { this.getKind() = 7 }

  /**
   * Gets a statement in this block
   */
  Stmt getAStatement() { result.getParent() = this }

  /**
   * Gets the statement at the given index
   */
  Stmt getStatement(int i) {
    result = this.getAStatement() and
    result.getIndex() = i
  }

  /**
   * Gets the number of statements in this block
   */
  int getNumStatements() { result = count(this.getAStatement()) }

  /**
   * Gets direct child expressions of immediate statements in this block.
   * Does not recurse into IfStmt/ForStmt bodies.
   */
  Expr getAnExpr() {
    result = this.getAStatement().(ExprStmt).getExpr() or
    result = this.getAStatement().(ReturnStmt).getExpr() or
    result = this.getAStatement().(LetStmt).getInitializer() or
    result = this.getAStatement().(ConstStmt).getInitializer() or
    result = this.getAStatement().(AssignStmt).getLhs() or
    result = this.getAStatement().(AssignStmt).getRhs() or
    result = this.getAStatement().(IfStmt).getCondition() or
    result = this.getAStatement().(ForStmt).getLowerBound() or
    result = this.getAStatement().(ForStmt).getUpperBound() or
    result = this.getAStatement().(AssertStmt).getAnExpr() or
    result = this.getAStatement().(BlockStmt).getAnExpr()
  }

  override string toString() { result = "block" }
}

/**
 * An assert statement
 * variant: 0=assert, 1=assert_eq, 2=assert_neq
 */
class AssertStmt extends Stmt {
  AssertStmt() { this.getKind() = 8 }

  /**
   * Gets the assert variant (0=assert, 1=assert_eq, 2=assert_neq)
   */
  int getVariant() { leo_assert_variants(this, result) }

  /**
   * Checks if this is a plain assert(condition)
   */
  predicate isAssert() { this.getVariant() = 0 }

  /**
   * Checks if this is an assert_eq(left, right)
   */
  predicate isAssertEq() { this.getVariant() = 1 }

  /**
   * Checks if this is an assert_neq(left, right)
   */
  predicate isAssertNeq() { this.getVariant() = 2 }

  /**
   * Gets the assertion condition (for plain assert only)
   */
  Expr getCondition() {
    this.isAssert() and
    result = this.getChild(0).(Expr)
  }

  /**
   * Gets the left operand (for assert_eq/assert_neq)
   */
  Expr getLeftOperand() {
    (this.isAssertEq() or this.isAssertNeq()) and
    result = this.getChild(0).(Expr)
  }

  /**
   * Gets the right operand (for assert_eq/assert_neq)
   */
  Expr getRightOperand() {
    (this.isAssertEq() or this.isAssertNeq()) and
    result = this.getChild(1).(Expr)
  }

  /**
   * Gets any expression used in this assert (condition or operands)
   */
  Expr getAnExpr() { result = this.getAChild().(Expr) }

  override string toString() { result = "assert" }
}

/**
 * A storage variable declaration
 */
class StorageStmt extends Stmt {
  StorageStmt() { this.getKind() = 9 }

  /**
   * Gets the storage variable name
   */
  string getVariableName() { leo_variable_decls(this, result, _) }

  /**
   * Gets the storage variable type
   */
  LeoType getVariableType() { leo_variable_decls(this, _, result) }

  override string toString() { result = "storage " + this.getVariableName() }
}
