"""AST to TRAP converter for Leo CodeQL extractor.

Walks the Leo AST and emits TRAP tuples matching the database schema.
"""

from typing import Optional
from .trap_writer import TrapWriter
from .ast_nodes import (
    # Types
    Type, IntegerType, FieldType, GroupType, ScalarType, BoolType,
    AddressType, SignatureType, StringType, ArrayType, TupleType,
    IdentifierType, FutureType,
    # Expressions
    Expression, LiteralExpr, IdentifierExpr, BinaryExpr, UnaryExpr,
    TernaryExpr, CastExpr, CallExpr, MethodCallExpr, FieldAccessExpr,
    IndexExpr, StructInitExpr, SelfAccessExpr, BlockAccessExpr, NetworkAccessExpr,
    # Statements
    Statement, LetStmt, ConstStmt, AssignStmt, IfStmt, ForStmt,
    ReturnStmt, AssertStmt, AssertEqStmt, AssertNeqStmt, ExprStmt, BlockStmt,
    # Declarations
    Parameter, FunctionDecl, StructField, StructDecl, RecordField, RecordDecl,
    MappingDecl, ConstDecl, ImportDecl, ProgramDecl,
    # Enums
    FunctionKind, BinaryOp, UnaryOp, AssignOp,
    # Location
    SourceLocation
)


class AstToTrap:
    """Converts Leo AST to TRAP format."""

    def __init__(self, writer: TrapWriter, source_root: str):
        """Initialize AST to TRAP converter.

        Args:
            writer: TRAP writer instance
            source_root: Root directory of source files
        """
        self.writer = writer
        self.source_root = source_root
        self._file_labels = {}      # path -> file label
        self._folder_labels = {}    # path -> folder label
        self._type_cache = {}       # (type_kind, type_name) -> type label

    def convert_program(self, program: ProgramDecl, source_path: str) -> None:
        """Convert entire program to TRAP.

        Args:
            program: Root program AST node
            source_path: Relative path to source file
        """
        # Emit source infrastructure
        self._emit_file_structure(source_path)

        # Emit program declaration
        program_label = self.writer.get_or_create_label(program.node_id)

        # Parse program_id (e.g., "hello.aleo" -> name="hello", network="aleo")
        program_id = program.program_id
        if "." in program_id:
            name, network = program_id.rsplit(".", 1)
        else:
            name = program_id
            network = "aleo"  # default network

        self.writer.emit("leo_programs", program_label, name, network)
        self._emit_location(program_label, program.location, source_path)

        # Emit imports
        for idx, imp in enumerate(program.imports):
            self._convert_import(imp, program_label, idx)

        # Emit structs
        for idx, struct in enumerate(program.structs):
            self._convert_struct(struct, program_label, idx)

        # Emit records
        for idx, record in enumerate(program.records):
            self._convert_record(record, program_label, idx)

        # Emit mappings
        for idx, mapping in enumerate(program.mappings):
            self._convert_mapping(mapping, program_label, idx)

        # Emit functions
        for idx, func in enumerate(program.functions):
            self._convert_function(func, program_label, idx)

    def _emit_file_structure(self, source_path: str) -> None:
        """Emit file, folder, and container parent tuples.

        Args:
            source_path: Relative path to source file
        """
        # Create file entity
        file_label = self.writer.fresh_id()
        self._file_labels[source_path] = file_label
        self.writer.emit("files", file_label, source_path)

        # Create folder hierarchy
        parts = source_path.split("/")
        if len(parts) > 1:
            # Has parent folders
            parent_path = "/".join(parts[:-1])
            parent_label = self._get_or_create_folder(parent_path)
            self.writer.emit("containerparent", parent_label, file_label)
        else:
            # File is in root, create root folder
            root_label = self._get_or_create_folder("")
            self.writer.emit("containerparent", root_label, file_label)

    def _get_or_create_folder(self, folder_path: str) -> str:
        """Get or create folder label, recursively creating parents.

        Args:
            folder_path: Relative folder path

        Returns:
            TRAP entity label for folder
        """
        if folder_path in self._folder_labels:
            return self._folder_labels[folder_path]

        # Create folder entity
        folder_label = self.writer.fresh_id()
        self._folder_labels[folder_path] = folder_label
        self.writer.emit("folders", folder_label, folder_path)

        # Create parent relationship if not root
        if folder_path and "/" in folder_path:
            parent_path = folder_path.rsplit("/", 1)[0]
            parent_label = self._get_or_create_folder(parent_path)
            self.writer.emit("containerparent", parent_label, folder_label)
        elif folder_path:
            # Single-level folder, parent is root
            root_label = self._get_or_create_folder("")
            self.writer.emit("containerparent", root_label, folder_label)

        return folder_label

    def _emit_location(self, node_label: str, location: Optional[SourceLocation], source_path: str) -> None:
        """Emit location tuple for a node.

        Args:
            node_label: TRAP label for the node
            location: Source location information
            source_path: Relative path to source file
        """
        if location is None:
            return

        loc_label = self.writer.fresh_id()
        file_label = self._file_labels.get(source_path)
        if not file_label:
            return

        self.writer.emit(
            "locations_default",
            loc_label,
            file_label,
            location.start_line,
            location.start_col,
            location.end_line,
            location.end_col
        )
        self.writer.emit("leo_ast_node_location", node_label, loc_label)

    def _emit_parent(self, node_label: str, parent_label: str, index: int) -> None:
        """Emit parent relationship tuple.

        Args:
            node_label: Child node TRAP label
            parent_label: Parent node TRAP label
            index: Index of child within parent
        """
        self.writer.emit("leo_ast_node_parent", node_label, parent_label, index)

    def _convert_import(self, imp: ImportDecl, program_label: str, index: int) -> None:
        """Convert import declaration to TRAP.

        Args:
            imp: Import declaration node
            program_label: Parent program label
            index: Import index within program
        """
        imp_label = self.writer.get_or_create_label(imp.node_id)
        self.writer.emit("leo_imports", imp_label, imp.program_id, program_label)
        self._emit_parent(imp_label, program_label, index)

    def _convert_type(self, typ: Type) -> str:
        """Convert type to TRAP and return its label.

        Args:
            typ: Type node

        Returns:
            TRAP entity label for the type
        """
        # Determine type kind and name
        kind = None
        name = ""

        if isinstance(typ, BoolType):
            kind = 0
            name = "bool"
        elif isinstance(typ, IntegerType):
            # u8-u128: kinds 1-5, i8-i128: kinds 6-10
            type_map = {
                "u8": (1, "u8"), "u16": (2, "u16"), "u32": (3, "u32"),
                "u64": (4, "u64"), "u128": (5, "u128"),
                "i8": (6, "i8"), "i16": (7, "i16"), "i32": (8, "i32"),
                "i64": (9, "i64"), "i128": (10, "i128")
            }
            kind, name = type_map.get(typ.type_name, (3, typ.type_name))  # default u32
        elif isinstance(typ, FieldType):
            kind = 11
            name = "field"
        elif isinstance(typ, GroupType):
            kind = 12
            name = "group"
        elif isinstance(typ, ScalarType):
            kind = 13
            name = "scalar"
        elif isinstance(typ, AddressType):
            kind = 14
            name = "address"
        elif isinstance(typ, SignatureType):
            kind = 15
            name = "signature"
        elif isinstance(typ, StringType):
            kind = 16
            name = "string"
        elif isinstance(typ, ArrayType):
            kind = 17
            name = "array"
        elif isinstance(typ, TupleType):
            kind = 18
            name = "tuple"
        elif isinstance(typ, IdentifierType):
            kind = 19
            name = typ.name
        elif isinstance(typ, FutureType):
            kind = 20
            name = "future"
        else:
            # Unknown type
            kind = 19
            name = "unknown"

        # Check cache for primitive types
        cache_key = (kind, name)
        if cache_key in self._type_cache and kind < 17:  # Primitives only
            return self._type_cache[cache_key]

        # Create type entity
        type_label = self.writer.get_or_create_label(typ.node_id)
        self.writer.emit("leo_types", type_label, kind, name)

        # Cache primitive types
        if kind < 17:
            self._type_cache[cache_key] = type_label

        # Emit additional details for complex types
        if isinstance(typ, ArrayType) and typ.element_type:
            elem_label = self._convert_type(typ.element_type)
            self.writer.emit("leo_array_types", type_label, elem_label, typ.size)
        elif isinstance(typ, TupleType):
            for idx, elem_type in enumerate(typ.element_types):
                elem_label = self._convert_type(elem_type)
                self.writer.emit("leo_tuple_type_elements", type_label, elem_label, idx)

        return type_label

    def _convert_struct(self, struct: StructDecl, program_label: str, index: int) -> None:
        """Convert struct declaration to TRAP.

        Args:
            struct: Struct declaration node
            program_label: Parent program label
            index: Struct index within program
        """
        struct_label = self.writer.get_or_create_label(struct.node_id)
        self.writer.emit("leo_struct_declarations", struct_label, struct.name, 0, program_label)
        self._emit_parent(struct_label, program_label, index)

        # Emit fields
        for field_idx, field in enumerate(struct.fields):
            self._convert_struct_field(field, struct_label, field_idx)

    def _convert_struct_field(self, field: StructField, struct_label: str, index: int) -> None:
        """Convert struct field to TRAP.

        Args:
            field: Struct field node
            struct_label: Parent struct label
            index: Field index within struct
        """
        field_label = self.writer.get_or_create_label(field.node_id)
        type_label = self._convert_type(field.field_type) if field.field_type else self.writer.fresh_id()

        # Struct fields have no visibility (use 0)
        self.writer.emit("leo_struct_fields", field_label, field.name, type_label, 0, struct_label, index)
        self._emit_parent(field_label, struct_label, index)

    def _convert_record(self, record: RecordDecl, program_label: str, index: int) -> None:
        """Convert record declaration to TRAP.

        Args:
            record: Record declaration node
            program_label: Parent program label
            index: Record index within program
        """
        record_label = self.writer.get_or_create_label(record.node_id)
        self.writer.emit("leo_struct_declarations", record_label, record.name, 1, program_label)
        self._emit_parent(record_label, program_label, index)

        # Emit fields
        for field_idx, field in enumerate(record.fields):
            self._convert_record_field(field, record_label, field_idx)

    def _convert_record_field(self, field: RecordField, record_label: str, index: int) -> None:
        """Convert record field to TRAP.

        Args:
            field: Record field node
            record_label: Parent record label
            index: Field index within record
        """
        field_label = self.writer.get_or_create_label(field.node_id)
        type_label = self._convert_type(field.field_type) if field.field_type else self.writer.fresh_id()

        # Map visibility: public=1, private=2, constant=3, none=0
        visibility_map = {"public": 1, "private": 2, "constant": 3}
        visibility = visibility_map.get(field.visibility, 0) if field.visibility else 0

        self.writer.emit("leo_struct_fields", field_label, field.name, type_label, visibility, record_label, index)
        self._emit_parent(field_label, record_label, index)

    def _convert_mapping(self, mapping: MappingDecl, program_label: str, index: int) -> None:
        """Convert mapping declaration to TRAP.

        Args:
            mapping: Mapping declaration node
            program_label: Parent program label
            index: Mapping index within program
        """
        mapping_label = self.writer.get_or_create_label(mapping.node_id)
        key_label = self._convert_type(mapping.key_type) if mapping.key_type else self.writer.fresh_id()
        value_label = self._convert_type(mapping.value_type) if mapping.value_type else self.writer.fresh_id()

        self.writer.emit("leo_mappings", mapping_label, mapping.name, key_label, value_label, program_label)
        self._emit_parent(mapping_label, program_label, index)

    def _convert_function(self, func: FunctionDecl, program_label: str, index: int) -> None:
        """Convert function declaration to TRAP.

        Args:
            func: Function declaration node
            program_label: Parent program label
            index: Function index within program
        """
        func_label = self.writer.get_or_create_label(func.node_id)

        # Map function kind: FUNCTION=0, TRANSITION=1, INLINE=2
        kind_map = {
            FunctionKind.FUNCTION: 0,
            FunctionKind.TRANSITION: 1,
            FunctionKind.INLINE: 2
        }
        kind = kind_map.get(func.kind, 0)
        is_async = 1 if func.is_async else 0

        self.writer.emit("leo_functions", func_label, func.name, kind, is_async, program_label)
        self._emit_parent(func_label, program_label, index)

        # Emit parameters
        for param_idx, param in enumerate(func.parameters):
            self._convert_parameter(param, func_label, param_idx)

        # Emit return type
        if func.return_type:
            return_type_label = self._convert_type(func.return_type)
            self.writer.emit("leo_return_types", func_label, return_type_label)

        # Emit body
        if func.body:
            self._convert_statement(func.body, func_label, 0)

    def _convert_parameter(self, param: Parameter, func_label: str, index: int) -> None:
        """Convert function parameter to TRAP.

        Args:
            param: Parameter node
            func_label: Parent function label
            index: Parameter index within function
        """
        param_label = self.writer.get_or_create_label(param.node_id)
        type_label = self._convert_type(param.param_type) if param.param_type else self.writer.fresh_id()

        # Parameters don't have visibility modifiers in current schema (use 0)
        self.writer.emit("leo_parameters", param_label, param.name, type_label, 0, func_label, index)
        self._emit_parent(param_label, func_label, index)

    def _convert_statement(self, stmt: Statement, parent_label: str, index: int) -> None:
        """Convert statement to TRAP.

        Args:
            stmt: Statement node
            parent_label: Parent node label
            index: Statement index within parent
        """
        stmt_label = self.writer.get_or_create_label(stmt.node_id)

        # Determine statement kind
        if isinstance(stmt, ExprStmt):
            self.writer.emit("leo_stmts", stmt_label, 0)
            if stmt.expr:
                expr_label = self._convert_expression(stmt.expr, stmt_label, 0)
        elif isinstance(stmt, ReturnStmt):
            self.writer.emit("leo_stmts", stmt_label, 1)
            if stmt.value:
                expr_label = self._convert_expression(stmt.value, stmt_label, 0)
        elif isinstance(stmt, LetStmt):
            self.writer.emit("leo_stmts", stmt_label, 2)
            type_label = self._convert_type(stmt.var_type) if stmt.var_type else self.writer.fresh_id()
            self.writer.emit("leo_variable_decls", stmt_label, stmt.var_name, type_label)
            if stmt.initializer:
                expr_label = self._convert_expression(stmt.initializer, stmt_label, 0)
        elif isinstance(stmt, ConstStmt):
            self.writer.emit("leo_stmts", stmt_label, 3)
            type_label = self._convert_type(stmt.var_type) if stmt.var_type else self.writer.fresh_id()
            self.writer.emit("leo_variable_decls", stmt_label, stmt.var_name, type_label)
            if stmt.initializer:
                expr_label = self._convert_expression(stmt.initializer, stmt_label, 0)
        elif isinstance(stmt, AssignStmt):
            self.writer.emit("leo_stmts", stmt_label, 4)
            # Map assign operator to integer
            op_value = stmt.op.value if stmt.op else 1  # ASSIGN = 1 (from enum auto())
            self.writer.emit("leo_assign_ops", stmt_label, op_value)
            if stmt.target:
                lhs_label = self._convert_expression(stmt.target, stmt_label, 0)
                self.writer.emit("leo_assign_lhs", stmt_label, lhs_label)
            if stmt.value:
                rhs_label = self._convert_expression(stmt.value, stmt_label, 1)
                self.writer.emit("leo_assign_rhs", stmt_label, rhs_label)
        elif isinstance(stmt, IfStmt):
            self.writer.emit("leo_stmts", stmt_label, 5)
            if stmt.condition:
                cond_label = self._convert_expression(stmt.condition, stmt_label, 0)
                self.writer.emit("leo_if_condition", stmt_label, cond_label)
            if stmt.then_block:
                then_label = self.writer.get_or_create_label(stmt.then_block.node_id)
                self._convert_statement(stmt.then_block, stmt_label, 1)
                self.writer.emit("leo_if_then", stmt_label, then_label)
            if stmt.else_block:
                else_label = self.writer.get_or_create_label(stmt.else_block.node_id)
                self._convert_statement(stmt.else_block, stmt_label, 2)
                self.writer.emit("leo_if_else", stmt_label, else_label)
        elif isinstance(stmt, ForStmt):
            self.writer.emit("leo_stmts", stmt_label, 6)
            self.writer.emit("leo_for_variable", stmt_label, stmt.var_name)
            if stmt.start and stmt.end:
                start_label = self._convert_expression(stmt.start, stmt_label, 0)
                end_label = self._convert_expression(stmt.end, stmt_label, 1)
                self.writer.emit("leo_for_range", stmt_label, start_label, end_label)
            if stmt.body:
                body_label = self.writer.get_or_create_label(stmt.body.node_id)
                self._convert_statement(stmt.body, stmt_label, 2)
                self.writer.emit("leo_for_body", stmt_label, body_label)
        elif isinstance(stmt, BlockStmt):
            self.writer.emit("leo_stmts", stmt_label, 7)
            for block_idx, child_stmt in enumerate(stmt.statements):
                self._convert_statement(child_stmt, stmt_label, block_idx)
        elif isinstance(stmt, (AssertStmt, AssertEqStmt, AssertNeqStmt)):
            self.writer.emit("leo_stmts", stmt_label, 8)
            # Convert assert expressions
            if isinstance(stmt, AssertStmt) and stmt.condition:
                self._convert_expression(stmt.condition, stmt_label, 0)
            elif isinstance(stmt, (AssertEqStmt, AssertNeqStmt)):
                if stmt.left:
                    self._convert_expression(stmt.left, stmt_label, 0)
                if stmt.right:
                    self._convert_expression(stmt.right, stmt_label, 1)

        self._emit_parent(stmt_label, parent_label, index)

    def _convert_expression(self, expr: Expression, parent_label: str, index: int) -> str:
        """Convert expression to TRAP.

        Args:
            expr: Expression node
            parent_label: Parent node label
            index: Expression index within parent

        Returns:
            TRAP entity label for the expression
        """
        expr_label = self.writer.get_or_create_label(expr.node_id)

        # Determine expression kind
        if isinstance(expr, LiteralExpr):
            self.writer.emit("leo_exprs", expr_label, 0)
            # Extract type suffix from value if present
            value = expr.value
            type_suffix = ""
            if expr.literal_type:
                if isinstance(expr.literal_type, IntegerType):
                    type_suffix = expr.literal_type.type_name
            self.writer.emit("leo_literal_values", expr_label, value, type_suffix)
        elif isinstance(expr, IdentifierExpr):
            self.writer.emit("leo_exprs", expr_label, 1)
            self.writer.emit("leo_variable_refs", expr_label, expr.name)
        elif isinstance(expr, BinaryExpr):
            self.writer.emit("leo_exprs", expr_label, 2)
            op_value = expr.op.value if expr.op else 1
            self.writer.emit("leo_binary_ops", expr_label, op_value)
            if expr.left:
                lhs_label = self._convert_expression(expr.left, expr_label, 0)
                self.writer.emit("leo_binary_lhs", expr_label, lhs_label)
            if expr.right:
                rhs_label = self._convert_expression(expr.right, expr_label, 1)
                self.writer.emit("leo_binary_rhs", expr_label, rhs_label)
        elif isinstance(expr, UnaryExpr):
            self.writer.emit("leo_exprs", expr_label, 3)
            op_value = expr.op.value if expr.op else 1
            self.writer.emit("leo_unary_ops", expr_label, op_value)
            if expr.operand:
                operand_label = self._convert_expression(expr.operand, expr_label, 0)
                self.writer.emit("leo_unary_operand", expr_label, operand_label)
        elif isinstance(expr, TernaryExpr):
            self.writer.emit("leo_exprs", expr_label, 4)
            if expr.condition:
                cond_label = self._convert_expression(expr.condition, expr_label, 0)
                self.writer.emit("leo_ternary_condition", expr_label, cond_label)
            if expr.then_expr:
                then_label = self._convert_expression(expr.then_expr, expr_label, 1)
                self.writer.emit("leo_ternary_then", expr_label, then_label)
            if expr.else_expr:
                else_label = self._convert_expression(expr.else_expr, expr_label, 2)
                self.writer.emit("leo_ternary_else", expr_label, else_label)
        elif isinstance(expr, CallExpr):
            self.writer.emit("leo_exprs", expr_label, 5)
            # Extract function name from callee
            if isinstance(expr.callee, IdentifierExpr):
                self.writer.emit("leo_call_targets", expr_label, expr.callee.name)
            for arg_idx, arg in enumerate(expr.arguments):
                arg_label = self._convert_expression(arg, expr_label, arg_idx)
                self.writer.emit("leo_call_args", expr_label, arg_label, arg_idx)
        elif isinstance(expr, MethodCallExpr):
            self.writer.emit("leo_exprs", expr_label, 6)
            self.writer.emit("leo_call_targets", expr_label, expr.method_name)
            if expr.receiver:
                self._convert_expression(expr.receiver, expr_label, 0)
            for arg_idx, arg in enumerate(expr.arguments):
                arg_label = self._convert_expression(arg, expr_label, arg_idx + 1)
                self.writer.emit("leo_call_args", expr_label, arg_label, arg_idx)
        elif isinstance(expr, FieldAccessExpr):
            self.writer.emit("leo_exprs", expr_label, 7)
            self.writer.emit("leo_field_access_name", expr_label, expr.field_name)
            if expr.receiver:
                base_label = self._convert_expression(expr.receiver, expr_label, 0)
                self.writer.emit("leo_field_access_base", expr_label, base_label)
        elif isinstance(expr, IndexExpr):
            self.writer.emit("leo_exprs", expr_label, 8)
            if expr.receiver:
                self._convert_expression(expr.receiver, expr_label, 0)
            if expr.index:
                self._convert_expression(expr.index, expr_label, 1)
        elif isinstance(expr, CastExpr):
            self.writer.emit("leo_exprs", expr_label, 10)
            if expr.target_type:
                type_label = self._convert_type(expr.target_type)
                self.writer.emit("leo_cast_type", expr_label, type_label)
            if expr.expr:
                self._convert_expression(expr.expr, expr_label, 0)
        elif isinstance(expr, StructInitExpr):
            self.writer.emit("leo_exprs", expr_label, 11)
            self.writer.emit("leo_struct_init_name", expr_label, expr.struct_name)
            for field_idx, (field_name, field_value) in enumerate(expr.fields):
                value_label = self._convert_expression(field_value, expr_label, field_idx)
                self.writer.emit("leo_struct_init_fields", expr_label, field_name, value_label, field_idx)
        elif isinstance(expr, (SelfAccessExpr, BlockAccessExpr, NetworkAccessExpr)):
            self.writer.emit("leo_exprs", expr_label, 12)
            # Self/block/network access - store member/property as variable ref
            if isinstance(expr, SelfAccessExpr):
                self.writer.emit("leo_variable_refs", expr_label, f"self.{expr.member}")
            elif isinstance(expr, BlockAccessExpr):
                self.writer.emit("leo_variable_refs", expr_label, f"block.{expr.property}")
            elif isinstance(expr, NetworkAccessExpr):
                self.writer.emit("leo_variable_refs", expr_label, f"network.{expr.property}")

        self._emit_parent(expr_label, parent_label, index)
        return expr_label
