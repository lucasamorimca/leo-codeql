/**
 * Leo expression nodes
 */

import codeql.leo.ast.AstNode
import codeql.leo.ast.Type
import codeql.leo.ast.Function
import codeql.leo.ast.Statement

/**
 * An expression node
 * kind: 0=literal, 1=variable, 2=binary, 3=unary, 4=ternary,
 *       5=call, 6=method_call, 7=field_access, 8=index_access,
 *       9=tuple_access, 10=cast, 11=struct_init, 12=self_expr,
 *       13=block_expr, 14=associated_const, 15=associated_fn_call
 */
class Expr extends AstNode, @leo_expr {
  /**
   * Gets the kind of this expression
   */
  int getKind() { leo_exprs(this, result) }

  /**
   * Gets the enclosing function
   */
  Function getEnclosingFunction() {
    result = this.getParent().(Function) or
    result = this.getParent().(Expr).getEnclosingFunction() or
    result = this.getParent().(Stmt).getEnclosingFunction()
  }

  /**
   * Gets all child expressions recursively
   */
  Expr getAChildExpr() {
    result = this.getAChild().(Expr) or
    result = this.getAChild().(Expr).getAChildExpr()
  }

  override string toString() { result = "Expr" }
}

/**
 * A literal expression
 */
class LiteralExpr extends Expr {
  LiteralExpr() { this.getKind() = 0 }

  /**
   * Gets the literal value as a string
   */
  string getValue() { leo_literal_values(this, result, _) }

  /**
   * Gets the type suffix (e.g., "u32", "field")
   */
  string getTypeSuffix() { leo_literal_values(this, _, result) }

  override string toString() { result = this.getValue() }
}

/**
 * A variable reference
 */
class VarRef extends Expr {
  VarRef() { this.getKind() = 1 }

  /**
   * Gets the variable name
   */
  string getName() { leo_variable_refs(this, result) }

  override string toString() { result = this.getName() }
}

/**
 * A binary expression
 */
class BinaryExpr extends Expr {
  BinaryExpr() { this.getKind() = 2 }

  /**
   * Gets the operator code
   */
  int getOperator() { leo_binary_ops(this, result) }

  /**
   * Gets the left operand
   */
  Expr getLeftOperand() { leo_binary_lhs(this, result) }

  /**
   * Gets the right operand
   */
  Expr getRightOperand() { leo_binary_rhs(this, result) }

  /**
   * Gets an operand
   */
  Expr getAnOperand() { result = this.getLeftOperand() or result = this.getRightOperand() }

  override string toString() { result = "BinaryExpr" }
}

/**
 * A unary expression
 */
class UnaryExpr extends Expr {
  UnaryExpr() { this.getKind() = 3 }

  /**
   * Gets the operator code
   */
  int getOperator() { leo_unary_ops(this, result) }

  /**
   * Gets the operand
   */
  Expr getOperand() { leo_unary_operand(this, result) }

  override string toString() { result = "UnaryExpr" }
}

/**
 * A ternary conditional expression (cond ? then : else)
 */
class TernaryExpr extends Expr {
  TernaryExpr() { this.getKind() = 4 }

  /**
   * Gets the condition expression
   */
  Expr getCondition() { leo_ternary_condition(this, result) }

  /**
   * Gets the then expression
   */
  Expr getThenExpr() { leo_ternary_then(this, result) }

  /**
   * Gets the else expression
   */
  Expr getElseExpr() { leo_ternary_else(this, result) }

  override string toString() { result = "TernaryExpr" }
}

/**
 * A function call expression
 */
class CallExpr extends Expr {
  CallExpr() { this.getKind() = 5 }

  /**
   * Gets the function name being called
   */
  string getTarget() { leo_call_targets(this, result) }

  /**
   * Gets the argument at the given index
   */
  Expr getArgument(int i) { leo_call_args(this, result, i) }

  /**
   * Gets any argument
   */
  Expr getAnArgument() { result = this.getArgument(_) }

  /**
   * Gets the number of arguments
   */
  int getNumberOfArguments() { result = count(this.getAnArgument()) }

  /**
   * Gets the target function (if resolvable)
   */
  Function getTargetFunction() {
    result.getName() = this.getTarget() and
    result.getProgram() = this.getEnclosingFunction().getProgram()
  }

  override string toString() { result = "call " + this.getTarget() }
}

/**
 * A method call expression
 */
class MethodCallExpr extends Expr {
  MethodCallExpr() { this.getKind() = 6 }

  /**
   * Gets the method name
   */
  string getMethodName() { leo_call_targets(this, result) }

  /**
   * Gets the argument at the given index
   */
  Expr getArgument(int i) { leo_call_args(this, result, i) }

  /**
   * Gets any argument
   */
  Expr getAnArgument() { result = this.getArgument(_) }

  override string toString() { result = "method call " + this.getMethodName() }
}

/**
 * A field access expression (struct.field)
 */
class FieldAccessExpr extends Expr {
  FieldAccessExpr() { this.getKind() = 7 }

  /**
   * Gets the field name being accessed
   */
  string getFieldName() { leo_field_access_name(this, result) }

  /**
   * Gets the base expression
   */
  Expr getBase() { leo_field_access_base(this, result) }

  override string toString() { result = "field access " + this.getFieldName() }
}

/**
 * An index access expression (array[index])
 */
class IndexAccessExpr extends Expr {
  IndexAccessExpr() { this.getKind() = 8 }

  override string toString() { result = "IndexAccessExpr" }
}

/**
 * A tuple access expression (tuple.0)
 */
class TupleAccessExpr extends Expr {
  TupleAccessExpr() { this.getKind() = 9 }

  override string toString() { result = "TupleAccessExpr" }
}

/**
 * A cast expression (value as Type)
 */
class CastExpr extends Expr {
  CastExpr() { this.getKind() = 10 }

  /**
   * Gets the target type
   */
  LeoType getTargetType() { leo_cast_type(this, result) }

  override string toString() { result = "cast to " + this.getTargetType().getName() }
}

/**
 * A struct initialization expression
 */
class StructInitExpr extends Expr {
  StructInitExpr() { this.getKind() = 11 }

  /**
   * Gets the struct name being initialized
   */
  string getStructName() { leo_struct_init_name(this, result) }

  /**
   * Gets the field initialization value at the given index
   */
  Expr getFieldInit(int i) { leo_struct_init_fields(this, _, result, i) }

  /**
   * Gets any field initialization value
   */
  Expr getAFieldInit() { result = this.getFieldInit(_) }

  /**
   * Gets the field name at the given index
   */
  string getFieldName(int i) { leo_struct_init_fields(this, result, _, i) }

  /**
   * Gets the value for a named field
   */
  Expr getFieldValue(string fieldName) {
    exists(int i |
      this.getFieldName(i) = fieldName and
      result = this.getFieldInit(i)
    )
  }

  override string toString() { result = "struct init " + this.getStructName() }
}

/**
 * A self expression (self keyword)
 */
class SelfExpr extends Expr {
  SelfExpr() { this.getKind() = 12 }

  override string toString() { result = "self" }
}

/**
 * A block expression
 */
class BlockExpr extends Expr {
  BlockExpr() { this.getKind() = 13 }

  override string toString() { result = "BlockExpr" }
}

/**
 * An associated constant access (Type::CONST)
 */
class AssociatedConstExpr extends Expr {
  AssociatedConstExpr() { this.getKind() = 14 }

  override string toString() { result = "AssociatedConstExpr" }
}

/**
 * An associated function call (Type::function())
 */
class AssociatedFnCallExpr extends Expr {
  AssociatedFnCallExpr() { this.getKind() = 15 }

  /**
   * Gets the function name
   */
  string getFunctionName() { leo_call_targets(this, result) }

  /**
   * Gets the argument at the given index
   */
  Expr getArgument(int i) { leo_call_args(this, result, i) }

  /**
   * Gets any argument
   */
  Expr getAnArgument() { result = this.getArgument(_) }

  override string toString() { result = "associated fn call " + this.getFunctionName() }
}
