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
    // Excludes ReturnStmt (no successor), IfStmt (branches), ForStmt (loops)
    not this instanceof ReturnStmt and
    not this instanceof IfStmt and
    not this instanceof ForStmt and
    exists(BlockStmt block, int i |
      this = block.getStatement(i) and
      result = block.getStatement(i + 1)
    )
    or
    // If statement flows to its condition
    exists(IfStmt ifStmt |
      this = ifStmt and
      result = ifStmt.getCondition()
    )
    or
    // If condition flows to then or else branch
    exists(IfStmt ifStmt |
      this = ifStmt.getCondition() and
      (result = ifStmt.getThen() or result = ifStmt.getElse())
    )
    or
    // If-without-else: false path flows to next statement after the if
    exists(IfStmt ifStmt, BlockStmt parent, int i |
      this = ifStmt.getCondition() and
      not ifStmt.hasElse() and
      ifStmt = parent.getStatement(i) and
      result = parent.getStatement(i + 1)
    )
    or
    // If then/else block flows to next statement after the if
    exists(IfStmt ifStmt, BlockStmt parent, int i |
      (this = ifStmt.getThen() or this = ifStmt.getElse()) and
      ifStmt = parent.getStatement(i) and
      result = parent.getStatement(i + 1)
    )
    or
    // For loop flows to its body
    exists(ForStmt forStmt |
      this = forStmt and
      result = forStmt.getBody()
    )
    or
    // For loop body flows back (loop iteration)
    exists(ForStmt forStmt |
      this = forStmt.getBody() and
      result = forStmt.getBody()
    )
    or
    // For loop body exits to next statement after the for
    // (Leo for loops always execute due to fixed bounds)
    exists(ForStmt forStmt, BlockStmt parent, int i |
      this = forStmt.getBody() and
      forStmt = parent.getStatement(i) and
      result = parent.getStatement(i + 1)
    )
    or
    // Assert passes: flows to next statement
    exists(AssertStmt assertStmt, BlockStmt parent, int i |
      this = assertStmt and
      assertStmt = parent.getStatement(i) and
      result = parent.getStatement(i + 1)
    )
  }

  /**
   * Gets a predecessor node in the control flow
   */
  CfgNode getAPredecessor() { result.getASuccessor() = this }

  /**
   * @deprecated This is O(n^3) and incorrect for loops. Do not use
   * for precise analysis. Use cfgPath for reachability instead.
   *
   * APPROXIMATION: checks if this node dominates other.
   * WARNING: This is O(n^3) and not true dominance for loops or complex
   * branching. Results are conservative (may over-report dominance).
   * Do not rely on this for precise analysis — use for heuristics only.
   */
  deprecated predicate dominates(CfgNode other) {
    this = other or
    (
      cfgPath(this, other) and
      this.getEnclosingFunction() = other.getEnclosingFunction() and
      not exists(CfgNode alt |
        alt != this and
        cfgPath(alt, other) and
        not cfgPath(this, alt) and
        alt.getEnclosingFunction() = other.getEnclosingFunction()
      )
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
 * An exit node (return statement or last statement in function body)
 */
class ExitNode extends CfgNode {
  ExitNode() {
    this instanceof ReturnStmt
    or
    // Last statement in function's top-level block (including terminals in branches)
    exists(Function f, BlockStmt topBlock |
      f = this.getEnclosingFunction() and
      topBlock.getParent() = f and
      this = getTerminalStmt(topBlock)
    )
  }

  /**
   * Gets the function this is an exit for
   */
  Function getFunction() { result = this.getEnclosingFunction() }
}

/**
 * Gets a terminal statement of a block — either the last statement
 * if it's not branching, or recursively the terminals of if branches.
 */
private Stmt getTerminalStmt(BlockStmt block) {
  exists(int lastIdx |
    result = block.getStatement(lastIdx) and
    not exists(block.getStatement(lastIdx + 1)) and
    not result instanceof IfStmt and
    not result instanceof ForStmt and
    not result instanceof BlockStmt
  )
  or
  exists(IfStmt ifStmt, int lastIdx |
    ifStmt = block.getStatement(lastIdx) and
    not exists(block.getStatement(lastIdx + 1)) |
    result = getTerminalStmt(ifStmt.getThen())
    or
    result = getTerminalStmt(ifStmt.getElse())
    or
    // If no else, the IfStmt itself is a potential exit (control falls through)
    not ifStmt.hasElse() and result = ifStmt
  )
  or
  // ForStmt as last statement: the for itself is a terminal
  // (loop always completes in Leo's fixed-bound model)
  exists(ForStmt forStmt, int lastIdx |
    forStmt = block.getStatement(lastIdx) and
    not exists(block.getStatement(lastIdx + 1)) and
    result = forStmt
  )
  or
  // Nested BlockStmt as last statement: recurse into it
  exists(BlockStmt nested, int lastIdx |
    nested = block.getStatement(lastIdx) and
    not exists(block.getStatement(lastIdx + 1)) and
    result = getTerminalStmt(nested)
  )
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
   * Gets the statement that executes after the loop completes.
   * In Leo, for loops always execute (fixed bounds), so exit
   * is always the next sequential statement.
   */
  CfgNode getAnExitNode() {
    exists(BlockStmt parent, int i |
      this.(ForStmt) = parent.getStatement(i) and
      result = parent.getStatement(i + 1)
    )
  }
}

/**
 * Left-linear recursion to avoid non-termination on cyclic CFGs.
 * Scoped to function boundaries — prevents cross-function reachability.
 */
predicate cfgPath(CfgNode source, CfgNode sink) {
  source = sink or
  exists(CfgNode mid |
    cfgPath(source, mid) and
    sink = mid.getASuccessor() and
    source.getEnclosingFunction() = sink.getEnclosingFunction()
  )
}

