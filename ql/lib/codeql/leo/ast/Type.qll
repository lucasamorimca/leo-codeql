/**
 * Leo type system representation
 */

import codeql.leo.ast.AstNode
import codeql.leo.ast.Declaration
import codeql.leo.ast.Statement
import codeql.leo.ast.Expression
import codeql.leo.ast.Function
import codeql.leo.ast.Program

/**
 * A Leo type
 */
class LeoType extends AstNode, @leo_type {
  /**
   * Gets the kind of this type
   * 0=bool, 1-5=unsigned, 6-10=signed, 11=field, 12=group,
   * 13=scalar, 14=address, 15=signature, 16=string,
   * 17=array, 18=tuple, 19=named, 20=future, 21=unit,
   * 22=mapping, 23=optional, 24=vector, 25=numeric, 26=error
   */
  int getKind() { leo_types(this, result, _) }

  /**
   * Gets the name of this type
   */
  string getName() { leo_types(this, _, result) }

  /**
   * Checks if this is a boolean type
   */
  predicate isBool() { this.getKind() = 0 }

  /**
   * Checks if this is an unsigned integer type
   */
  predicate isUnsigned() { this.getKind() in [1, 2, 3, 4, 5] }

  /**
   * Checks if this is a signed integer type
   */
  predicate isSigned() { this.getKind() in [6, 7, 8, 9, 10] }

  /**
   * Checks if this is an integer type (signed or unsigned)
   */
  predicate isInteger() { this.isUnsigned() or this.isSigned() }

  /**
   * Checks if this is a field type
   */
  predicate isField() { this.getKind() = 11 }

  /**
   * Checks if this is a group type
   */
  predicate isGroup() { this.getKind() = 12 }

  /**
   * Checks if this is a scalar type
   */
  predicate isScalar() { this.getKind() = 13 }

  /**
   * Checks if this is an address type
   */
  predicate isAddress() { this.getKind() = 14 }

  /**
   * Checks if this is a signature type
   */
  predicate isSignature() { this.getKind() = 15 }

  /**
   * Checks if this is a string type
   */
  predicate isString() { this.getKind() = 16 }

  /**
   * Checks if this is an array type
   */
  predicate isArray() { this.getKind() = 17 }

  /**
   * Checks if this is a tuple type
   */
  predicate isTuple() { this.getKind() = 18 }

  /**
   * Checks if this is a named type (struct/record reference)
   */
  predicate isNamed() { this.getKind() = 19 }

  /**
   * Checks if this is a future type
   */
  predicate isFuture() { this.getKind() = 20 }

  /**
   * Checks if this is a unit type
   */
  predicate isUnit() { this.getKind() = 21 }

  /**
   * Checks if this is a mapping type
   */
  predicate isMapping() { this.getKind() = 22 }

  /**
   * Checks if this is an optional type
   */
  predicate isOptional() { this.getKind() = 23 }

  /**
   * Checks if this is a vector type
   */
  predicate isVector() { this.getKind() = 24 }

  /**
   * Checks if this is a primitive type
   */
  predicate isPrimitive() {
    this.isBool() or
    this.isInteger() or
    this.isField() or
    this.isGroup() or
    this.isScalar() or
    this.isAddress() or
    this.isSignature() or
    this.isString()
  }

  /**
   * Checks if this type can contain sensitive data
   */
  predicate mayContainSensitiveData() {
    this.isAddress() or
    this.isSignature() or
    this.isField() or
    this.isGroup() or
    this.isScalar()
  }

  override string toString() { result = this.getName() }
}

/**
 * An array type
 */
class ArrayType extends LeoType {
  ArrayType() { this.isArray() }

  /**
   * Gets the element type of this array
   */
  LeoType getElementType() { leo_array_types(this, result, _) }

  /**
   * Gets the size of this array
   */
  int getSize() { leo_array_types(this, _, result) }

  override string toString() { result = "[" + this.getElementType().getName() + "; " + this.getSize() + "]" }
}

/**
 * A tuple type
 */
class TupleType extends LeoType {
  TupleType() { this.isTuple() }

  /**
   * Gets the element type at the given index
   */
  LeoType getElement(int index) { leo_tuple_type_elements(this, result, index) }

  /**
   * Gets any element type
   */
  LeoType getAnElement() { result = this.getElement(_) }

  /**
   * Gets the number of elements in this tuple
   */
  int getNumElements() { result = count(this.getAnElement()) }

  override string toString() { result = "(" + this.getName() + ")" }
}

/**
 * A named type (struct or record reference)
 */
class NamedType extends LeoType {
  NamedType() { this.isNamed() }

  /**
   * Gets the enclosing program for this type reference
   */
  Program getEnclosingProgram() {
    exists(Parameter p | p.getType() = this | result = p.getFunction().getProgram())
    or
    exists(StructField f | f.getType() = this | result = f.getStruct().getProgram())
    or
    exists(Function f | f.getReturnType() = this | result = f.getProgram())
    or
    exists(MappingDeclaration m |
      m.getKeyType() = this or m.getValueType() = this |
      result = m.getProgram()
    )
    or
    // Variable declaration types (LetStmt, ConstStmt)
    exists(LetStmt let | let.getVariableType() = this |
      result = let.getEnclosingFunction().getProgram()
    )
    or
    exists(ConstStmt const | const.getConstantType() = this |
      result = const.getEnclosingFunction().getProgram()
    )
    or
    // Cast expression types
    exists(CastExpr cast | cast.getTargetType() = this |
      result = cast.getEnclosingFunction().getProgram()
    )
    or
    // General fallback via parent traversal
    exists(AstNode parent | parent = this.getParent() |
      result = parent.(Program) or
      result = parent.(Function).getProgram() or
      result = parent.(Stmt).getEnclosingFunction().getProgram() or
      result = parent.(Expr).getEnclosingFunction().getProgram()
    )
  }

  /**
   * Gets the struct declaration this type refers to, scoped to the same program
   */
  StructDeclaration getStructDeclaration() {
    result.getName() = this.getName() and
    result.getProgram() = this.getEnclosingProgram()
  }

  /**
   * Gets the struct declaration scoped to a specific program
   */
  StructDeclaration getStructDeclarationInProgram(Program p) {
    result.getName() = this.getName() and
    result.getProgram() = p
  }

  override string toString() { result = this.getName() }
}

/**
 * A future type (for async transitions)
 */
class FutureType extends LeoType {
  FutureType() { this.isFuture() }

  /**
   * Gets an input type at the given index
   */
  LeoType getInputType(int index) { leo_future_input_types(this, result, index) }

  /**
   * Gets any input type
   */
  LeoType getAnInputType() { result = this.getInputType(_) }

  override string toString() { result = "Future<" + this.getName() + ">" }
}

/**
 * An optional type
 */
class OptionalType extends LeoType {
  OptionalType() { this.isOptional() }

  /**
   * Gets the inner type of this optional
   */
  LeoType getInnerType() { leo_optional_inner_type(this, result) }

  override string toString() { result = this.getInnerType().getName() + "?" }
}

/**
 * A vector type
 */
class VectorType extends LeoType {
  VectorType() { this.isVector() }

  /**
   * Gets the element type of this vector
   */
  LeoType getElementType() { leo_vector_element_type(this, result) }

  override string toString() { result = "[" + this.getElementType().getName() + "]" }
}

/**
 * A mapping type
 */
class MappingType extends LeoType {
  MappingType() { this.isMapping() }

  /**
   * Gets the key type of this mapping
   */
  LeoType getKeyType() { leo_mapping_key_value_types(this, result, _) }

  /**
   * Gets the value type of this mapping
   */
  LeoType getValueType() { leo_mapping_key_value_types(this, _, result) }

  override string toString() {
    result = "Mapping<" + this.getKeyType().getName() + ", " + this.getValueType().getName() + ">"
  }
}
