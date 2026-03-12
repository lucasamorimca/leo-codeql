/**
 * Main Leo module - imports all QL library components
 * This is the primary entry point for Leo CodeQL queries
 */

// AST Core
import codeql.leo.ast.AstNode
import codeql.leo.ast.Program
import codeql.leo.ast.Function
import codeql.leo.ast.Declaration
import codeql.leo.ast.Statement
import codeql.leo.ast.Expression
import codeql.leo.ast.Literal
import codeql.leo.ast.Type

// Control Flow Analysis
import codeql.leo.controlflow.ControlFlow
import codeql.leo.controlflow.CallGraph
