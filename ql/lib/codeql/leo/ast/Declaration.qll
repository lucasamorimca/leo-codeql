/**
 * Leo struct, record, and mapping declarations
 */

import codeql.leo.ast.AstNode
import codeql.leo.ast.Type
import codeql.leo.ast.Program

/**
 * A struct declaration (struct or record)
 */
class StructDeclaration extends AstNode, @leo_struct {
  /**
   * Gets the name of this struct
   */
  string getName() { leo_struct_declarations(this, result, _, _) }

  /**
   * Checks if this is a record (on-chain state)
   */
  predicate isRecord() { leo_struct_declarations(this, _, 1, _) }

  /**
   * Gets the field at the given index
   */
  StructField getField(int i) { leo_struct_fields(result, _, _, _, this, i) }

  /**
   * Gets any field
   */
  StructField getAField() { result = this.getField(_) }

  /**
   * Gets the field with the given name
   */
  StructField getFieldByName(string name) {
    result = this.getAField() and
    result.getName() = name
  }

  /**
   * Gets the number of fields
   */
  int getNumberOfFields() { result = count(this.getAField()) }

  /**
   * Gets the program containing this struct
   */
  Program getProgram() { leo_struct_declarations(this, _, _, result) }

  /**
   * Checks if this struct has any public fields
   */
  predicate hasPublicField() { exists(StructField f | f = this.getAField() and f.isPublic()) }

  /**
   * Checks if this struct has any private fields
   */
  predicate hasPrivateField() { exists(StructField f | f = this.getAField() and f.isPrivate()) }

  /**
   * Checks if all fields are public
   */
  predicate allFieldsPublic() {
    forall(StructField f | f = this.getAField() | f.isPublic())
  }

  /**
   * Checks if all fields are private
   */
  predicate allFieldsPrivate() {
    forall(StructField f | f = this.getAField() | f.isPrivate())
  }

  override string toString() { result = "struct " + this.getName() }
}

/**
 * A record declaration (on-chain data structure)
 */
class RecordDeclaration extends StructDeclaration {
  RecordDeclaration() { this.isRecord() }

  /**
   * Checks if this record has a private field with the given name
   */
  predicate hasPrivateField(string fieldName) {
    exists(StructField f | f = this.getFieldByName(fieldName) and f.isPrivate())
  }

  /**
   * Checks if this record has a public field with the given name
   */
  predicate hasPublicField(string fieldName) {
    exists(StructField f | f = this.getFieldByName(fieldName) and f.isPublic())
  }

  /**
   * Gets private fields (sensitive data in records)
   */
  StructField getAPrivateField() {
    result = this.getAField() and
    result.isPrivate()
  }

  override string toString() { result = "record " + this.getName() }
}

/**
 * A struct or record field
 */
class StructField extends AstNode, @leo_struct_field {
  /**
   * Gets the name of this field
   */
  string getName() { leo_struct_fields(this, result, _, _, _, _) }

  /**
   * Gets the type of this field
   */
  LeoType getType() { leo_struct_fields(this, _, result, _, _, _) }

  /**
   * Gets the visibility of this field (0=private, 1=public)
   */
  int getVisibility() { leo_struct_fields(this, _, _, result, _, _) }

  /**
   * Gets the struct containing this field
   */
  StructDeclaration getStruct() { leo_struct_fields(this, _, _, _, result, _) }

  /**
   * Gets the field index
   */
  int getFieldIndex() { leo_struct_fields(this, _, _, _, _, result) }

  /**
   * Checks if this field is public
   */
  predicate isPublic() { this.getVisibility() = 1 }

  /**
   * Checks if this field is private
   */
  predicate isPrivate() { this.getVisibility() = 0 }

  /**
   * Checks if this field belongs to a record
   */
  predicate isRecordField() { this.getStruct().isRecord() }

  /**
   * Checks if this field type may contain sensitive data
   */
  predicate mayContainSensitiveData() { this.getType().mayContainSensitiveData() }

  override string toString() { result = this.getName() + ": " + this.getType().getName() }
}

/**
 * A mapping declaration (on-chain key-value store)
 */
class MappingDeclaration extends AstNode, @leo_mapping {
  /**
   * Gets the name of this mapping
   */
  string getName() { leo_mappings(this, result, _, _, _) }

  /**
   * Gets the key type of this mapping
   */
  LeoType getKeyType() { leo_mappings(this, _, result, _, _) }

  /**
   * Gets the value type of this mapping
   */
  LeoType getValueType() { leo_mappings(this, _, _, result, _) }

  /**
   * Gets the program containing this mapping
   */
  Program getProgram() { leo_mappings(this, _, _, _, result) }

  /**
   * Checks if the key type may contain sensitive data
   */
  predicate keyMayContainSensitiveData() { this.getKeyType().mayContainSensitiveData() }

  /**
   * Checks if the value type may contain sensitive data
   */
  predicate valueMayContainSensitiveData() { this.getValueType().mayContainSensitiveData() }

  override string toString() { result = "mapping " + this.getName() }
}
