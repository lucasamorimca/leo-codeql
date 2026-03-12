/**
 * Leo program and import declarations
 */

import codeql.leo.ast.AstNode
import codeql.leo.ast.Function
import codeql.leo.ast.Declaration

/**
 * A Leo program (main compilation unit)
 */
class Program extends AstNode, @leo_program {
  /**
   * Gets the name of this program
   */
  string getName() { leo_programs(this, result, _) }

  /**
   * Gets the network identifier (e.g., "aleo", "testnet")
   */
  string getNetwork() { leo_programs(this, _, result) }

  /**
   * Gets an import declaration in this program
   */
  Import getAnImport() { leo_imports(result, _, this) }

  /**
   * Gets the import with the given program ID
   */
  Import getImport(string programId) {
    result = this.getAnImport() and
    result.getProgramId() = programId
  }

  /**
   * Gets a function declared in this program
   */
  Function getAFunction() { leo_functions(result, _, _, _, this) }

  /**
   * Gets the function with the given name
   */
  Function getFunction(string name) {
    result = this.getAFunction() and
    result.getName() = name
  }

  /**
   * Gets a struct declaration in this program
   */
  StructDeclaration getAStruct() {
    leo_struct_declarations(result, _, _, this) and
    not result.isRecord()
  }

  /**
   * Gets a record declaration in this program
   */
  RecordDeclaration getARecord() {
    leo_struct_declarations(result, _, _, this) and
    result.isRecord()
  }

  /**
   * Gets a struct or record by name
   */
  StructDeclaration getStructByName(string name) {
    (result = this.getAStruct() or result = this.getARecord()) and
    result.getName() = name
  }

  /**
   * Gets a mapping declaration in this program
   */
  MappingDeclaration getAMapping() { leo_mappings(result, _, _, _, this) }

  /**
   * Gets the mapping with the given name
   */
  MappingDeclaration getMapping(string name) {
    result = this.getAMapping() and
    result.getName() = name
  }

  /**
   * Gets a transition function in this program
   */
  TransitionFunction getATransition() { result.getProgram() = this }

  /**
   * Checks if this program has async transitions
   */
  predicate hasAsyncTransitions() { exists(Function f | f.getProgram() = this and f.isAsync()) }

  override string toString() { result = "program " + this.getName() }
}

/**
 * An import statement
 */
class Import extends AstNode, @leo_import {
  /**
   * Gets the imported program identifier (e.g., "token.aleo")
   */
  string getProgramId() { leo_imports(this, result, _) }

  /**
   * Gets the parent program containing this import
   */
  Program getParentProgram() { leo_imports(this, _, result) }

  override string toString() { result = "import " + this.getProgramId() }
}
