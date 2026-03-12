/**
 * Leo literal expression details
 */

import codeql.leo.ast.Expression

/**
 * A boolean literal (true or false)
 */
class BoolLiteral extends LiteralExpr {
  BoolLiteral() { this.getTypeSuffix() = "bool" }

  /**
   * Checks if this is true
   */
  predicate isTrue() { this.getValue() = "true" }

  /**
   * Checks if this is false
   */
  predicate isFalse() { this.getValue() = "false" }

  override string toString() { result = this.getValue() }
}

/**
 * An integer literal
 */
class IntegerLiteral extends LiteralExpr {
  IntegerLiteral() {
    this.getTypeSuffix() in ["u8", "u16", "u32", "u64", "u128", "i8", "i16", "i32", "i64", "i128"]
  }

  /**
   * Checks if this is an unsigned integer
   */
  predicate isUnsigned() { this.getTypeSuffix().matches("u%") }

  /**
   * Checks if this is a signed integer
   */
  predicate isSigned() { this.getTypeSuffix().matches("i%") }

  /**
   * Gets the bit width of this integer
   */
  int getBitWidth() {
    this.getTypeSuffix() in ["u8", "i8"] and result = 8
    or
    this.getTypeSuffix() in ["u16", "i16"] and result = 16
    or
    this.getTypeSuffix() in ["u32", "i32"] and result = 32
    or
    this.getTypeSuffix() in ["u64", "i64"] and result = 64
    or
    this.getTypeSuffix() in ["u128", "i128"] and result = 128
  }

  override string toString() { result = this.getValue() + this.getTypeSuffix() }
}

/**
 * A field literal (finite field element)
 */
class FieldLiteral extends LiteralExpr {
  FieldLiteral() { this.getTypeSuffix() = "field" }

  override string toString() { result = this.getValue() + "field" }
}

/**
 * A group literal (elliptic curve point)
 */
class GroupLiteral extends LiteralExpr {
  GroupLiteral() { this.getTypeSuffix() = "group" }

  override string toString() { result = this.getValue() + "group" }
}

/**
 * A scalar literal
 */
class ScalarLiteral extends LiteralExpr {
  ScalarLiteral() { this.getTypeSuffix() = "scalar" }

  override string toString() { result = this.getValue() + "scalar" }
}

/**
 * An address literal (Aleo address)
 */
class AddressLiteral extends LiteralExpr {
  AddressLiteral() { this.getTypeSuffix() = "address" }

  /**
   * Checks if this is a well-formed address (starts with "aleo1")
   */
  predicate isWellFormed() { this.getValue().matches("aleo1%") }

  override string toString() { result = this.getValue() }
}

/**
 * A signature literal
 */
class SignatureLiteral extends LiteralExpr {
  SignatureLiteral() { this.getTypeSuffix() = "signature" }

  override string toString() { result = "signature" }
}

/**
 * A string literal
 */
class StringLiteral extends LiteralExpr {
  StringLiteral() { this.getTypeSuffix() = "string" }

  /**
   * Gets the string content without quotes
   */
  string getContent() {
    result = this.getValue().substring(1, this.getValue().length() - 1)
  }

  override string toString() { result = this.getValue() }
}

/**
 * A numeric literal (integer, field, group, or scalar)
 */
class NumericLiteral extends LiteralExpr {
  NumericLiteral() {
    this instanceof IntegerLiteral or
    this instanceof FieldLiteral or
    this instanceof GroupLiteral or
    this instanceof ScalarLiteral
  }
}

/**
 * A cryptographic literal (address, signature, field, group, scalar)
 */
class CryptoLiteral extends LiteralExpr {
  CryptoLiteral() {
    this instanceof AddressLiteral or
    this instanceof SignatureLiteral or
    this instanceof FieldLiteral or
    this instanceof GroupLiteral or
    this instanceof ScalarLiteral
  }

  /**
   * Checks if this literal may contain sensitive data
   */
  predicate mayContainSensitiveData() { any() }
}
