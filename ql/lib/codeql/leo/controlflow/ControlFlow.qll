/**
 * Control flow graph for Leo programs
 * Provides intraprocedural control flow analysis
 */

import codeql.leo.ast.AstNode
import codeql.leo.ast.Statement
import codeql.leo.ast.Expression
import codeql.leo.ast.Function

/**
 * A control flow node (statement or expression that can be executed)
 */
class CfgNode extends AstNode {
  CfgNode() {
    this instanceof Stmt or
    this instanceof Expr
  }

  /**
   * Gets a successor node in the control flow
   */
  CfgNode getASuccessor() {
    // Sequential flow: next statement in block
    exists(BlockStmt block, int i |
      this = block.getStatement(i) and
      result = block.getStatement(i + 1)
    )
    or
    // If statement: previous statement flows to condition
    exists(IfStmt ifStmt, BlockStmt parent, int i |
      ifStmt = parent.getStatement(i) and
      i > 0 and
      this = parent.getStatement(i - 1) and
      result = ifStmt.getCondition()
    )
    or
    // If statement: condition flows to then or else
    exists(IfStmt ifStmt |
      this = ifStmt.getCondition() and
      (result = ifStmt.getThen() or result = ifStmt.getElse())
    )
    or
    // If then block flows to next statement after if
    exists(IfStmt ifStmt, BlockStmt parent, int i |
      this = ifStmt.getThen() and
      ifStmt = parent.getStatement(i) and
      result = parent.getStatement(i + 1)
    )
    or
    // If else block flows to next statement after if
    exists(IfStmt ifStmt, BlockStmt parent, int i |
      this = ifStmt.getElse() and
      ifStmt = parent.getStatement(i) and
      result = parent.getStatement(i + 1)
    )
    or
    // For loop: bounds flow to body, body flows back to itself (loop)
    exists(ForStmt forStmt |
      (this = forStmt.getLowerBound() or this = forStmt.getUpperBound()) and
      result = forStmt.getBody()
      or
      this = forStmt.getBody() and
      result = forStmt.getBody()
    )
    or
    // For loop exits to next statement (from bounds, not body)
    exists(ForStmt forStmt, BlockStmt parent, int i |
      (this = forStmt.getLowerBound() or this = forStmt.getUpperBound()) and
      forStmt = parent.getStatement(i) and
      result = parent.getStatement(i + 1)
    )
    or
    // Assignment flows to next
    exists(AssignStmt assign, BlockStmt parent, int i |
      this = assign and
      assign = parent.getStatement(i) and
      result = parent.getStatement(i + 1)
    )
    or
    // Let/const flows to next
    exists(Stmt varDecl, BlockStmt parent, int i |
      this = varDecl and
      (varDecl instanceof LetStmt or varDecl instanceof ConstStmt) and
      varDecl = parent.getStatement(i) and
      result = parent.getStatement(i + 1)
    )
  }

  /**
   * Gets a predecessor node in the control flow
   */
  CfgNode getAPredecessor() { result.getASuccessor() = this }

  /**
   * Checks if this node dominates another node (approximation via reachability)
   */
  predicate dominates(CfgNode other) {
    this = other or
    (
      cfgPath(this, other) and
      this.getEnclosingFunction() = other.getEnclosingFunction()
    )
  }

  /**
   * Gets the enclosing function
   */
  Function getEnclosingFunction() {
    result = this.(Stmt).getEnclosingFunction() or
    result = this.(Expr).getEnclosingFunction()
  }
}

/**
 * An entry node (function entry point)
 */
class EntryNode extends CfgNode {
  EntryNode() {
    exists(Function f |
      this.getEnclosingFunction() = f and
      this instanceof Stmt and
      not exists(CfgNode pred |
        pred.getASuccessor() = this and
        pred.getEnclosingFunction() = f
      ) and
      // Must be in a block (not nested in if/for)
      this.getParent() instanceof BlockStmt
    )
  }

  /**
   * Gets the function this is the entry for
   */
  Function getFunction() { result = this.getEnclosingFunction() }
}

/**
 * An exit node (return statement or end of function)
 */
class ExitNode extends CfgNode {
  ExitNode() {
    this instanceof ReturnStmt or
    (
      this instanceof Stmt and
      exists(Function f, BlockStmt topBlock |
        f = this.getEnclosingFunction() and
        // Get the top-level block of the function
        topBlock.getParent() = f and
        // This is the last statement in the top-level block
        exists(int lastIndex |
          this = topBlock.getStatement(lastIndex) and
          not exists(topBlock.getStatement(lastIndex + 1))
        )
      )
    )
  }

  /**
   * Gets the function this is an exit for
   */
  Function getFunction() { result = this.getEnclosingFunction() }
}

/**
 * A conditional node (if condition, ternary condition)
 */
class ConditionalNode extends CfgNode {
  ConditionalNode() {
    this = any(IfStmt ifStmt).getCondition() or
    this = any(TernaryExpr ternary).getCondition()
  }

  /**
   * Gets the true successor
   */
  CfgNode getTrueSuccessor() {
    exists(IfStmt ifStmt |
      this = ifStmt.getCondition() and
      result = ifStmt.getThen()
    )
    or
    exists(TernaryExpr ternary |
      this = ternary.getCondition() and
      result = ternary.getThenExpr()
    )
  }

  /**
   * Gets the false successor
   */
  CfgNode getFalseSuccessor() {
    exists(IfStmt ifStmt |
      this = ifStmt.getCondition() and
      result = ifStmt.getElse()
    )
    or
    exists(TernaryExpr ternary |
      this = ternary.getCondition() and
      result = ternary.getElseExpr()
    )
  }
}

/**
 * A loop node (for loop)
 */
class LoopNode extends CfgNode {
  LoopNode() { this instanceof ForStmt }

  /**
   * Gets the loop body
   */
  BlockStmt getBody() { result = this.(ForStmt).getBody() }

  /**
   * Gets a node that may exit the loop
   */
  CfgNode getAnExitNode() {
    result.getEnclosingFunction() = this.getEnclosingFunction() and
    this.dominates(result) and
    not result = this.getBody().getAChildStmt()
  }
}

/**
 * Checks if there is a path from source to sink in the CFG
 */
predicate cfgPath(CfgNode source, CfgNode sink) {
  source = sink or
  cfgPath(source.getASuccessor(), sink)
}

/**
 * Gets all nodes reachable from the given node
 */
CfgNode getReachableFrom(CfgNode source) {
  result = source or
  result = getReachableFrom(source.getASuccessor())
}
