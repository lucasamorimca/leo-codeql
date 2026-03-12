/**
 * Leo type system representation
 */

import codeql.leo.ast.AstNode
import codeql.leo.ast.Declaration

/**
 * A Leo type
 */
class LeoType extends AstNode, @leo_type {
  /**
   * Gets the kind of this type
   * 0=bool, 1-5=unsigned, 6-10=signed, 11=field, 12=group,
   * 13=scalar, 14=address, 15=signature, 16=string,
   * 17=array, 18=tuple, 19=named, 20=future, 21=unit
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
   * Gets the struct declaration this type refers to
   */
  StructDeclaration getStructDeclaration() { result.getName() = this.getName() }

  override string toString() { result = this.getName() }
}

/**
 * A future type (for async transitions)
 */
class FutureType extends LeoType {
  FutureType() { this.isFuture() }

  override string toString() { result = "Future<" + this.getName() + ">" }
}
