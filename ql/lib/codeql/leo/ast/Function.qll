/**
 * Leo function and parameter declarations
 */

import codeql.leo.ast.AstNode
import codeql.leo.ast.Type
import codeql.leo.ast.Program
import codeql.leo.ast.Statement

/**
 * A function declaration (function, transition, or inline)
 */
class Function extends AstNode, @leo_function {
  /**
   * Gets the name of this function
   */
  string getName() { leo_functions(this, result, _, _, _) }

  /**
   * Gets the kind of this function
   * 0=function, 1=transition, 2=inline
   */
  int getKind() { leo_functions(this, _, result, _, _) }

  /**
   * Checks if this is a transition function
   */
  predicate isTransition() { this.getKind() = 1 }

  /**
   * Checks if this is a regular function
   */
  predicate isFunction() { this.getKind() = 0 }

  /**
   * Checks if this is an inline function
   */
  predicate isInline() { this.getKind() = 2 }

  /**
   * Checks if this is an async function (returns a Future)
   */
  predicate isAsync() { leo_functions(this, _, _, 1, _) }

  /**
   * Gets the parameter at the given index
   */
  Parameter getParameter(int i) { leo_parameters(result, _, _, _, this, i) }

  /**
   * Gets any parameter
   */
  Parameter getAParameter() { result = this.getParameter(_) }

  /**
   * Gets the parameter with the given name
   */
  Parameter getParameterByName(string name) {
    result = this.getAParameter() and
    result.getName() = name
  }

  /**
   * Gets the number of parameters
   */
  int getNumberOfParameters() { result = count(this.getAParameter()) }

  /**
   * Gets the return type of this function
   */
  LeoType getReturnType() { leo_return_types(this, result) }

  /**
   * Gets the program containing this function
   */
  Program getProgram() { leo_functions(this, _, _, _, result) }

  /**
   * Checks if this function has any public parameters
   */
  predicate hasPublicParameter() { exists(Parameter p | p = this.getAParameter() and p.isPublic()) }

  /**
   * Checks if this function has any private parameters
   */
  predicate hasPrivateParameter() { exists(Parameter p | p = this.getAParameter() and p.isPrivate()) }

  /**
   * Checks if all parameters are public
   */
  predicate allParametersPublic() {
    forall(Parameter p | p = this.getAParameter() | p.isPublic())
  }

  /**
   * Checks if this function is externally callable (transitions only)
   */
  predicate isExternallyCallable() { this.isTransition() }

  /**
   * Checks if this function returns a Future type
   */
  predicate returnsFuture() { this.getReturnType().isFuture() }

  /**
   * Gets a statement in this function's body
   */
  Stmt getAStatement() { result.getEnclosingFunction() = this }

  override string toString() { result = this.getName() }
}

/**
 * A transition function (on-chain callable)
 */
class TransitionFunction extends Function {
  TransitionFunction() { this.isTransition() }

  /**
   * Checks if this transition requires finalization
   */
  predicate requiresFinalization() { this.isAsync() and this.returnsFuture() }

  override string toString() { result = "transition " + this.getName() }
}

/**
 * An inline function (inlined at call sites)
 */
class InlineFunction extends Function {
  InlineFunction() { this.isInline() }

  override string toString() { result = "inline " + this.getName() }
}

/**
 * A function parameter
 */
class Parameter extends AstNode, @leo_parameter {
  /**
   * Gets the name of this parameter
   */
  string getName() { leo_parameters(this, result, _, _, _, _) }

  /**
   * Gets the type of this parameter
   */
  LeoType getType() { leo_parameters(this, _, result, _, _, _) }

  /**
   * Gets the visibility of this parameter (0=private, 1=public)
   */
  int getVisibility() { leo_parameters(this, _, _, result, _, _) }

  /**
   * Gets the function containing this parameter
   */
  Function getFunction() { leo_parameters(this, _, _, _, result, _) }

  /**
   * Gets the parameter index
   */
  int getParameterIndex() { leo_parameters(this, _, _, _, _, result) }

  /**
   * Checks if this parameter is public
   */
  predicate isPublic() { this.getVisibility() = 1 }

  /**
   * Checks if this parameter is private
   */
  predicate isPrivate() { this.getVisibility() = 0 }

  /**
   * Checks if this parameter type may contain sensitive data
   */
  predicate mayContainSensitiveData() { this.getType().mayContainSensitiveData() }

  override string toString() { result = this.getName() + ": " + this.getType().getName() }
}
