/**
 * Base class for all Leo AST nodes
 * Provides common functionality for navigation and location tracking
 */

/**
 * A source location in the database
 */
class Location extends @location_default {
  int getStartLine() { locations_default(this, _, result, _, _, _) }

  int getStartColumn() { locations_default(this, _, _, result, _, _) }

  int getEndLine() { locations_default(this, _, _, _, result, _) }

  int getEndColumn() { locations_default(this, _, _, _, _, result) }

  File getFile() { locations_default(this, result, _, _, _, _) }

  string toString() {
    result = this.getFile().toString() + ":" + this.getStartLine().toString()
  }
}

/**
 * A source file in the database
 */
class File extends @file_default {
  string getName() { files(this, result) }

  string toString() { result = this.getName() }
}

/**
 * Base class for all Leo AST nodes
 */
class AstNode extends @leo_ast_node {
  /** Gets the source location of this AST node */
  Location getLocation() { leo_ast_node_location(this, result) }

  /** Gets the parent node in the AST */
  AstNode getParent() { leo_ast_node_parent(this, result, _) }

  /** Gets the index of this node within its parent's children */
  int getIndex() { leo_ast_node_parent(this, _, result) }

  /** Gets the child node at the given index */
  AstNode getChild(int i) { leo_ast_node_parent(result, this, i) }

  /** Gets any child node */
  AstNode getAChild() { result = this.getChild(_) }

  /** Gets all descendants recursively */
  AstNode getADescendant() {
    result = this.getAChild() or
    result = this.getAChild().getADescendant()
  }

  string toString() { result = "AstNode" }
}
