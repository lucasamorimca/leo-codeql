"""Recursive-descent parser for Leo programming language.

Parses Leo source code into an Abstract Syntax Tree (AST).
"""

from typing import Optional
from .lexer import Lexer, Token, TokenType
from .expression_parser import ExpressionParser
from .ast_nodes import (
    # Types
    Type, IntegerType, FieldType, GroupType, ScalarType, BoolType,
    AddressType, SignatureType, StringType, ArrayType, TupleType,
    IdentifierType, FutureType,
    # Expressions
    Expression,
    # Statements
    Statement, LetStmt, ConstStmt, AssignStmt, IfStmt, ForStmt,
    ReturnStmt, AssertStmt, AssertEqStmt, AssertNeqStmt, ExprStmt, BlockStmt,
    # Declarations
    Parameter, FunctionDecl, StructField, StructDecl, RecordField, RecordDecl,
    MappingDecl, ConstDecl, ImportDecl, ProgramDecl,
    # Enums
    FunctionKind, AssignOp,
    # Location
    SourceLocation
)


class ParseError(Exception):
    """Parser error with location information."""
    def __init__(self, message: str, location: Optional[SourceLocation] = None):
        self.message = message
        self.location = location
        super().__init__(f"{location.file_path}:{location.start_line}:{location.start_col}: {message}" if location else message)


class Parser:
    """Recursive-descent parser for Leo language."""

    def __init__(self, source: str, file_path: str = "<input>"):
        """Initialize parser.

        Args:
            source: Leo source code
            file_path: Source file path for error reporting
        """
        self.file_path = file_path
        lexer = Lexer(source, file_path)
        self.tokens = lexer.tokenize()
        self.pos = 0

    def current_token(self) -> Token:
        """Get current token."""
        if self.pos >= len(self.tokens):
            return self.tokens[-1]  # EOF
        return self.tokens[self.pos]

    def peek_token(self, offset: int = 1) -> Token:
        """Peek ahead at token."""
        pos = self.pos + offset
        if pos >= len(self.tokens):
            return self.tokens[-1]  # EOF
        return self.tokens[pos]

    def advance(self) -> Token:
        """Consume and return current token."""
        token = self.current_token()
        if self.pos < len(self.tokens) - 1:
            self.pos += 1
        return token

    def expect(self, token_type: TokenType) -> Optional[Token]:
        """Expect specific token type and consume it."""
        if self.current_token().type != token_type:
            return None
        return self.advance()

    def synchronize(self):
        """Recover from parse error by skipping to next safe point."""
        while self.current_token().type != TokenType.EOF:
            if self.current_token().type in (TokenType.SEMICOLON, TokenType.RBRACE):
                self.advance()
                return
            self.advance()

    def parse_type(self, tokens: list[Token], pos: int) -> tuple[Optional[Type], int]:
        """Parse type expression.

        Args:
            tokens: Token list (for expression parser callback)
            pos: Current position

        Returns:
            (type, new_position)
        """
        saved_pos = self.pos
        self.pos = pos
        result = self._parse_type_internal()
        new_pos = self.pos
        self.pos = saved_pos
        return result, new_pos

    def _parse_type_internal(self) -> Optional[Type]:
        """Internal type parsing."""
        token = self.current_token()

        # Integer types
        if token.type in (TokenType.U8, TokenType.U16, TokenType.U32, TokenType.U64, TokenType.U128,
                         TokenType.I8, TokenType.I16, TokenType.I32, TokenType.I64, TokenType.I128):
            self.advance()
            return IntegerType(type_name=token.value)

        # Field type
        if token.type == TokenType.FIELD_TYPE:
            self.advance()
            return FieldType()

        # Group type
        if token.type == TokenType.GROUP_TYPE:
            self.advance()
            return GroupType()

        # Scalar type
        if token.type == TokenType.SCALAR_TYPE:
            self.advance()
            return ScalarType()

        # Bool type
        if token.type == TokenType.BOOL_TYPE:
            self.advance()
            return BoolType()

        # Address type
        if token.type == TokenType.ADDRESS_TYPE:
            self.advance()
            return AddressType()

        # Signature type
        if token.type == TokenType.SIGNATURE:
            self.advance()
            return SignatureType()

        # String type
        if token.type == TokenType.STRING_TYPE:
            self.advance()
            return StringType()

        # Future type: Future<T> or Future
        if token.type == TokenType.FUTURE:
            self.advance()
            if self.current_token().type == TokenType.LT:
                self.advance()
                inner = self._parse_type_internal()
                if self.current_token().type != TokenType.GT:
                    return None
                self.advance()
                return FutureType(inner_type=inner)
            return FutureType()

        # Array type: [T; N]
        if token.type == TokenType.LBRACKET:
            self.advance()
            elem_type = self._parse_type_internal()
            if elem_type is None:
                return None
            if self.current_token().type != TokenType.SEMICOLON:
                return None
            self.advance()
            if self.current_token().type != TokenType.INTEGER:
                return None
            size = int(self.current_token().value)
            self.advance()
            if self.current_token().type != TokenType.RBRACKET:
                return None
            self.advance()
            return ArrayType(element_type=elem_type, size=size)

        # Tuple type: (T1, T2, ...)
        if token.type == TokenType.LPAREN:
            self.advance()
            types = []
            while self.current_token().type != TokenType.RPAREN:
                t = self._parse_type_internal()
                if t is None:
                    return None
                types.append(t)
                if self.current_token().type == TokenType.COMMA:
                    self.advance()
                elif self.current_token().type != TokenType.RPAREN:
                    return None
            if self.current_token().type != TokenType.RPAREN:
                return None
            self.advance()
            return TupleType(element_types=types)

        # Named type (struct, record)
        if token.type == TokenType.IDENTIFIER:
            name = token.value
            self.advance()
            return IdentifierType(name=name)

        return None

    def parse_expression(self) -> Optional[Expression]:
        """Parse expression using expression parser."""
        expr_parser = ExpressionParser(self.tokens, self.pos, self.parse_type)
        expr, new_pos = expr_parser.parse_expression()
        self.pos = new_pos
        return expr

    def parse_statement(self) -> Optional[Statement]:
        """Parse statement."""
        token = self.current_token()

        # Let statement
        if token.type == TokenType.LET:
            return self.parse_let_stmt()

        # Const statement
        if token.type == TokenType.CONST:
            return self.parse_const_stmt()

        # If statement
        if token.type == TokenType.IF:
            return self.parse_if_stmt()

        # For statement
        if token.type == TokenType.FOR:
            return self.parse_for_stmt()

        # Return statement
        if token.type == TokenType.RETURN:
            return self.parse_return_stmt()

        # Assert statements
        if token.type == TokenType.ASSERT:
            return self.parse_assert_stmt()
        if token.type == TokenType.ASSERT_EQ:
            return self.parse_assert_eq_stmt()
        if token.type == TokenType.ASSERT_NEQ:
            return self.parse_assert_neq_stmt()

        # Block statement
        if token.type == TokenType.LBRACE:
            return self.parse_block_stmt()

        # Expression or assignment statement
        return self.parse_expr_or_assign_stmt()

    def parse_let_stmt(self) -> Optional[LetStmt]:
        """Parse let statement: let var: Type = expr;"""
        self.expect(TokenType.LET)
        if self.current_token().type != TokenType.IDENTIFIER:
            return None
        var_name = self.current_token().value
        self.advance()

        var_type = None
        if self.current_token().type == TokenType.COLON:
            self.advance()
            var_type, new_pos = self.parse_type(self.tokens, self.pos)
            self.pos = new_pos

        initializer = None
        if self.current_token().type == TokenType.ASSIGN:
            self.advance()
            initializer = self.parse_expression()
            if initializer is None:
                return None

        self.expect(TokenType.SEMICOLON)
        return LetStmt(var_name=var_name, var_type=var_type, initializer=initializer)

    def parse_const_stmt(self) -> Optional[ConstStmt]:
        """Parse const statement: const VAR: Type = expr;"""
        self.expect(TokenType.CONST)
        if self.current_token().type != TokenType.IDENTIFIER:
            return None
        var_name = self.current_token().value
        self.advance()

        var_type = None
        if self.current_token().type == TokenType.COLON:
            self.advance()
            var_type, new_pos = self.parse_type(self.tokens, self.pos)
            self.pos = new_pos

        if self.current_token().type != TokenType.ASSIGN:
            return None
        self.advance()

        initializer = self.parse_expression()
        if initializer is None:
            return None

        self.expect(TokenType.SEMICOLON)
        return ConstStmt(var_name=var_name, var_type=var_type, initializer=initializer)

    def parse_if_stmt(self) -> Optional[IfStmt]:
        """Parse if statement."""
        self.expect(TokenType.IF)
        condition = self.parse_expression()
        if condition is None:
            return None

        then_block = self.parse_block_stmt()
        if then_block is None:
            return None

        else_block = None
        if self.current_token().type == TokenType.ELSE:
            self.advance()
            else_block = self.parse_block_stmt()
            if else_block is None:
                return None

        return IfStmt(condition=condition, then_block=then_block, else_block=else_block)

    def parse_for_stmt(self) -> Optional[ForStmt]:
        """Parse for statement: for var in start..end { ... }"""
        self.expect(TokenType.FOR)
        if self.current_token().type != TokenType.IDENTIFIER:
            return None
        var_name = self.current_token().value
        self.advance()

        if self.current_token().type != TokenType.IN:
            return None
        self.advance()

        start = self.parse_expression()
        if start is None:
            return None

        if self.current_token().type != TokenType.DOTDOT:
            return None
        self.advance()

        end = self.parse_expression()
        if end is None:
            return None

        body = self.parse_block_stmt()
        if body is None:
            return None

        return ForStmt(var_name=var_name, start=start, end=end, body=body)

    def parse_return_stmt(self) -> Optional[ReturnStmt]:
        """Parse return statement."""
        self.expect(TokenType.RETURN)
        value = None
        if self.current_token().type != TokenType.SEMICOLON:
            value = self.parse_expression()
        self.expect(TokenType.SEMICOLON)
        return ReturnStmt(value=value)

    def parse_assert_stmt(self) -> Optional[AssertStmt]:
        """Parse assert statement."""
        self.expect(TokenType.ASSERT)
        if self.current_token().type != TokenType.LPAREN:
            return None
        self.advance()
        condition = self.parse_expression()
        if condition is None:
            return None
        if self.current_token().type != TokenType.RPAREN:
            return None
        self.advance()
        self.expect(TokenType.SEMICOLON)
        return AssertStmt(condition=condition)

    def parse_assert_eq_stmt(self) -> Optional[AssertEqStmt]:
        """Parse assert_eq statement."""
        self.expect(TokenType.ASSERT_EQ)
        if self.current_token().type != TokenType.LPAREN:
            return None
        self.advance()
        left = self.parse_expression()
        if left is None:
            return None
        if self.current_token().type != TokenType.COMMA:
            return None
        self.advance()
        right = self.parse_expression()
        if right is None:
            return None
        if self.current_token().type != TokenType.RPAREN:
            return None
        self.advance()
        self.expect(TokenType.SEMICOLON)
        return AssertEqStmt(left=left, right=right)

    def parse_assert_neq_stmt(self) -> Optional[AssertNeqStmt]:
        """Parse assert_neq statement."""
        self.expect(TokenType.ASSERT_NEQ)
        if self.current_token().type != TokenType.LPAREN:
            return None
        self.advance()
        left = self.parse_expression()
        if left is None:
            return None
        if self.current_token().type != TokenType.COMMA:
            return None
        self.advance()
        right = self.parse_expression()
        if right is None:
            return None
        if self.current_token().type != TokenType.RPAREN:
            return None
        self.advance()
        self.expect(TokenType.SEMICOLON)
        return AssertNeqStmt(left=left, right=right)

    def parse_block_stmt(self) -> Optional[BlockStmt]:
        """Parse block statement: { stmts... }"""
        if self.current_token().type != TokenType.LBRACE:
            return None
        self.advance()

        statements = []
        while self.current_token().type != TokenType.RBRACE and self.current_token().type != TokenType.EOF:
            stmt = self.parse_statement()
            if stmt is None:
                self.synchronize()
                continue
            statements.append(stmt)

        if self.current_token().type != TokenType.RBRACE:
            return None
        self.advance()

        return BlockStmt(statements=statements)

    def parse_expr_or_assign_stmt(self) -> Optional[Statement]:
        """Parse expression or assignment statement."""
        expr = self.parse_expression()
        if expr is None:
            return None

        # Check for assignment operators
        assign_ops = {
            TokenType.ASSIGN: AssignOp.ASSIGN,
            TokenType.PLUS_ASSIGN: AssignOp.ADD_ASSIGN,
            TokenType.MINUS_ASSIGN: AssignOp.SUB_ASSIGN,
            TokenType.STAR_ASSIGN: AssignOp.MUL_ASSIGN,
            TokenType.SLASH_ASSIGN: AssignOp.DIV_ASSIGN,
            TokenType.PERCENT_ASSIGN: AssignOp.MOD_ASSIGN,
            TokenType.SHL_ASSIGN: AssignOp.SHL_ASSIGN,
            TokenType.SHR_ASSIGN: AssignOp.SHR_ASSIGN,
            TokenType.AND_ASSIGN: AssignOp.AND_ASSIGN,
            TokenType.OR_ASSIGN: AssignOp.OR_ASSIGN,
            TokenType.XOR_ASSIGN: AssignOp.XOR_ASSIGN,
            TokenType.POW_ASSIGN: AssignOp.POW_ASSIGN,
        }

        if self.current_token().type in assign_ops:
            op = assign_ops[self.current_token().type]
            self.advance()
            value = self.parse_expression()
            if value is None:
                return None
            self.expect(TokenType.SEMICOLON)
            return AssignStmt(target=expr, op=op, value=value)

        # Expression statement
        self.expect(TokenType.SEMICOLON)
        return ExprStmt(expr=expr)

    def parse_parameter(self) -> Optional[Parameter]:
        """Parse function parameter."""
        if self.current_token().type == TokenType.PUBLIC or self.current_token().type == TokenType.PRIVATE:
            self.advance()  # Skip visibility modifier

        if self.current_token().type != TokenType.IDENTIFIER:
            return None
        name = self.current_token().value
        self.advance()

        if self.current_token().type != TokenType.COLON:
            return None
        self.advance()

        param_type, new_pos = self.parse_type(self.tokens, self.pos)
        if param_type is None:
            return None
        self.pos = new_pos

        return Parameter(name=name, param_type=param_type)

    def parse_function(self) -> Optional[FunctionDecl]:
        """Parse function declaration."""
        # Parse function kind
        is_async = False
        if self.current_token().type == TokenType.ASYNC:
            is_async = True
            self.advance()

        kind_map = {
            TokenType.INLINE: FunctionKind.INLINE,
            TokenType.FUNCTION: FunctionKind.FUNCTION,
            TokenType.TRANSITION: FunctionKind.TRANSITION,
        }

        if self.current_token().type not in kind_map:
            return None
        kind = kind_map[self.current_token().type]
        self.advance()

        if self.current_token().type != TokenType.IDENTIFIER:
            return None
        name = self.current_token().value
        self.advance()

        # Parse parameters
        if self.current_token().type != TokenType.LPAREN:
            return None
        self.advance()

        parameters = []
        while self.current_token().type != TokenType.RPAREN:
            param = self.parse_parameter()
            if param is None:
                return None
            parameters.append(param)

            if self.current_token().type == TokenType.COMMA:
                self.advance()
            elif self.current_token().type != TokenType.RPAREN:
                return None

        if self.current_token().type != TokenType.RPAREN:
            return None
        self.advance()

        # Parse return type
        return_type = None
        if self.current_token().type == TokenType.RARROW:
            self.advance()
            return_type, new_pos = self.parse_type(self.tokens, self.pos)
            if return_type is None:
                return None
            self.pos = new_pos

        # Parse body
        body = self.parse_block_stmt()
        if body is None:
            return None

        return FunctionDecl(
            kind=kind,
            is_async=is_async,
            name=name,
            parameters=parameters,
            return_type=return_type,
            body=body
        )

    def parse_struct(self) -> Optional[StructDecl]:
        """Parse struct declaration."""
        self.expect(TokenType.STRUCT)
        if self.current_token().type != TokenType.IDENTIFIER:
            return None
        name = self.current_token().value
        self.advance()

        if self.current_token().type != TokenType.LBRACE:
            return None
        self.advance()

        fields = []
        while self.current_token().type != TokenType.RBRACE:
            if self.current_token().type != TokenType.IDENTIFIER:
                return None
            field_name = self.current_token().value
            self.advance()

            if self.current_token().type != TokenType.COLON:
                return None
            self.advance()

            field_type, new_pos = self.parse_type(self.tokens, self.pos)
            if field_type is None:
                return None
            self.pos = new_pos

            fields.append(StructField(name=field_name, field_type=field_type))

            if self.current_token().type == TokenType.COMMA:
                self.advance()
            elif self.current_token().type != TokenType.RBRACE:
                return None

        if self.current_token().type != TokenType.RBRACE:
            return None
        self.advance()

        return StructDecl(name=name, fields=fields)

    def parse_record(self) -> Optional[RecordDecl]:
        """Parse record declaration."""
        self.expect(TokenType.RECORD)
        if self.current_token().type != TokenType.IDENTIFIER:
            return None
        name = self.current_token().value
        self.advance()

        if self.current_token().type != TokenType.LBRACE:
            return None
        self.advance()

        fields = []
        while self.current_token().type != TokenType.RBRACE:
            # Parse visibility modifier
            visibility = None
            if self.current_token().type in (TokenType.PUBLIC, TokenType.PRIVATE, TokenType.CONSTANT):
                visibility = self.current_token().value
                self.advance()

            if self.current_token().type != TokenType.IDENTIFIER:
                return None
            field_name = self.current_token().value
            self.advance()

            if self.current_token().type != TokenType.COLON:
                return None
            self.advance()

            field_type, new_pos = self.parse_type(self.tokens, self.pos)
            if field_type is None:
                return None
            self.pos = new_pos

            fields.append(RecordField(name=field_name, field_type=field_type, visibility=visibility))

            if self.current_token().type == TokenType.COMMA:
                self.advance()
            elif self.current_token().type != TokenType.RBRACE:
                return None

        if self.current_token().type != TokenType.RBRACE:
            return None
        self.advance()

        return RecordDecl(name=name, fields=fields)

    def parse_mapping(self) -> Optional[MappingDecl]:
        """Parse mapping declaration."""
        self.expect(TokenType.MAPPING)
        if self.current_token().type != TokenType.IDENTIFIER:
            return None
        name = self.current_token().value
        self.advance()

        if self.current_token().type != TokenType.COLON:
            return None
        self.advance()

        key_type, new_pos = self.parse_type(self.tokens, self.pos)
        if key_type is None:
            return None
        self.pos = new_pos

        if self.current_token().type != TokenType.ARROW:
            return None
        self.advance()

        value_type, new_pos = self.parse_type(self.tokens, self.pos)
        if value_type is None:
            return None
        self.pos = new_pos

        self.expect(TokenType.SEMICOLON)
        return MappingDecl(name=name, key_type=key_type, value_type=value_type)

    def parse_const_decl(self) -> Optional[ConstDecl]:
        """Parse top-level const declaration."""
        self.expect(TokenType.CONST)
        if self.current_token().type != TokenType.IDENTIFIER:
            return None
        name = self.current_token().value
        self.advance()

        if self.current_token().type != TokenType.COLON:
            return None
        self.advance()

        const_type, new_pos = self.parse_type(self.tokens, self.pos)
        if const_type is None:
            return None
        self.pos = new_pos

        if self.current_token().type != TokenType.ASSIGN:
            return None
        self.advance()

        value = self.parse_expression()
        if value is None:
            return None

        self.expect(TokenType.SEMICOLON)
        return ConstDecl(name=name, const_type=const_type, value=value)

    def parse_import(self) -> Optional[ImportDecl]:
        """Parse import declaration."""
        self.expect(TokenType.IMPORT)
        if self.current_token().type != TokenType.IDENTIFIER:
            return None
        program_id = self.current_token().value
        self.advance()

        self.expect(TokenType.SEMICOLON)
        return ImportDecl(program_id=program_id)

    def parse_program(self) -> Optional[ProgramDecl]:
        """Parse program declaration (top-level)."""
        # Parse imports
        imports = []
        while self.current_token().type == TokenType.IMPORT:
            imp = self.parse_import()
            if imp:
                imports.append(imp)

        # Expect program declaration
        if self.current_token().type != TokenType.PROGRAM:
            return None
        self.advance()

        if self.current_token().type != TokenType.IDENTIFIER:
            return None
        program_id = self.current_token().value
        self.advance()

        if self.current_token().type != TokenType.LBRACE:
            return None
        self.advance()

        # Parse program body
        structs = []
        records = []
        mappings = []
        constants = []
        functions = []

        while self.current_token().type != TokenType.RBRACE and self.current_token().type != TokenType.EOF:
            token = self.current_token()

            if token.type == TokenType.STRUCT:
                struct = self.parse_struct()
                if struct:
                    structs.append(struct)
            elif token.type == TokenType.RECORD:
                record = self.parse_record()
                if record:
                    records.append(record)
            elif token.type == TokenType.MAPPING:
                mapping = self.parse_mapping()
                if mapping:
                    mappings.append(mapping)
            elif token.type == TokenType.CONST:
                const = self.parse_const_decl()
                if const:
                    constants.append(const)
            elif token.type in (TokenType.INLINE, TokenType.FUNCTION, TokenType.TRANSITION, TokenType.ASYNC):
                func = self.parse_function()
                if func:
                    functions.append(func)
            else:
                self.synchronize()

        if self.current_token().type != TokenType.RBRACE:
            return None
        self.advance()

        return ProgramDecl(
            program_id=program_id,
            imports=imports,
            structs=structs,
            records=records,
            mappings=mappings,
            constants=constants,
            functions=functions
        )

    def parse(self) -> Optional[ProgramDecl]:
        """Parse Leo source code into AST.

        Returns:
            ProgramDecl or None on error
        """
        try:
            return self.parse_program()
        except Exception as e:
            print(f"Parse error: {e}")
            return None
