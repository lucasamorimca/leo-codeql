"""Expression parser for Leo language.

Handles expression parsing with correct operator precedence.
"""

from typing import Optional
from .lexer import Token, TokenType
from .ast_nodes import (
    Expression, LiteralExpr, IdentifierExpr, BinaryExpr, UnaryExpr,
    TernaryExpr, CastExpr, CallExpr, MethodCallExpr, FieldAccessExpr,
    IndexExpr, StructInitExpr, SelfAccessExpr, BlockAccessExpr,
    NetworkAccessExpr, Type, BinaryOp, UnaryOp, SourceLocation
)


class ExpressionParser:
    """Handles expression parsing with precedence climbing."""

    def __init__(self, tokens: list[Token], pos: int, parse_type_callback):
        """Initialize expression parser.

        Args:
            tokens: List of tokens
            pos: Current position in token list
            parse_type_callback: Callback to parse_type from main parser
        """
        self.tokens = tokens
        self.pos = pos
        self.parse_type_callback = parse_type_callback

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

    def parse_expression(self) -> tuple[Optional[Expression], int]:
        """Parse expression (entry point).

        Returns:
            (expression, new_position)
        """
        return self.parse_ternary()

    def parse_ternary(self) -> tuple[Optional[Expression], int]:
        """Parse ternary conditional: cond ? then : else."""
        expr, new_pos = self.parse_logical_or()
        if expr is None:
            return None, self.pos

        self.pos = new_pos
        if self.current_token().type == TokenType.QUESTION:
            self.advance()  # ?
            then_expr, new_pos = self.parse_expression()
            if then_expr is None:
                return None, self.pos

            self.pos = new_pos
            if self.current_token().type != TokenType.COLON:
                return None, self.pos
            self.advance()  # :

            else_expr, new_pos = self.parse_expression()
            if else_expr is None:
                return None, self.pos

            ternary = TernaryExpr(
                condition=expr,
                then_expr=then_expr,
                else_expr=else_expr
            )
            return ternary, new_pos

        return expr, new_pos

    def parse_logical_or(self) -> tuple[Optional[Expression], int]:
        """Parse logical OR: expr || expr."""
        left, new_pos = self.parse_logical_and()
        if left is None:
            return None, self.pos

        self.pos = new_pos
        while self.current_token().type == TokenType.OR:
            self.advance()
            right, new_pos = self.parse_logical_and()
            if right is None:
                return None, self.pos
            left = BinaryExpr(left=left, op=BinaryOp.OR, right=right)
            self.pos = new_pos

        return left, self.pos

    def parse_logical_and(self) -> tuple[Optional[Expression], int]:
        """Parse logical AND: expr && expr."""
        left, new_pos = self.parse_equality()
        if left is None:
            return None, self.pos

        self.pos = new_pos
        while self.current_token().type == TokenType.AND:
            self.advance()
            right, new_pos = self.parse_equality()
            if right is None:
                return None, self.pos
            left = BinaryExpr(left=left, op=BinaryOp.AND, right=right)
            self.pos = new_pos

        return left, self.pos

    def parse_equality(self) -> tuple[Optional[Expression], int]:
        """Parse equality: expr == expr, expr != expr."""
        left, new_pos = self.parse_comparison()
        if left is None:
            return None, self.pos

        self.pos = new_pos
        while self.current_token().type in (TokenType.EQ, TokenType.NEQ):
            op = BinaryOp.EQ if self.current_token().type == TokenType.EQ else BinaryOp.NEQ
            self.advance()
            right, new_pos = self.parse_comparison()
            if right is None:
                return None, self.pos
            left = BinaryExpr(left=left, op=op, right=right)
            self.pos = new_pos

        return left, self.pos

    def parse_comparison(self) -> tuple[Optional[Expression], int]:
        """Parse comparison: <, >, <=, >=."""
        left, new_pos = self.parse_bitwise_xor()
        if left is None:
            return None, self.pos

        self.pos = new_pos
        op_map = {
            TokenType.LT: BinaryOp.LT,
            TokenType.GT: BinaryOp.GT,
            TokenType.LE: BinaryOp.LE,
            TokenType.GE: BinaryOp.GE,
        }

        while self.current_token().type in op_map:
            op = op_map[self.current_token().type]
            self.advance()
            right, new_pos = self.parse_bitwise_xor()
            if right is None:
                return None, self.pos
            left = BinaryExpr(left=left, op=op, right=right)
            self.pos = new_pos

        return left, self.pos

    def parse_bitwise_xor(self) -> tuple[Optional[Expression], int]:
        """Parse bitwise XOR: expr ^ expr."""
        left, new_pos = self.parse_bitwise_or()
        if left is None:
            return None, self.pos

        self.pos = new_pos
        while self.current_token().type == TokenType.BIT_XOR:
            self.advance()
            right, new_pos = self.parse_bitwise_or()
            if right is None:
                return None, self.pos
            left = BinaryExpr(left=left, op=BinaryOp.BIT_XOR, right=right)
            self.pos = new_pos

        return left, self.pos

    def parse_bitwise_or(self) -> tuple[Optional[Expression], int]:
        """Parse bitwise OR: expr | expr."""
        left, new_pos = self.parse_bitwise_and()
        if left is None:
            return None, self.pos

        self.pos = new_pos
        while self.current_token().type == TokenType.BIT_OR:
            self.advance()
            right, new_pos = self.parse_bitwise_and()
            if right is None:
                return None, self.pos
            left = BinaryExpr(left=left, op=BinaryOp.BIT_OR, right=right)
            self.pos = new_pos

        return left, self.pos

    def parse_bitwise_and(self) -> tuple[Optional[Expression], int]:
        """Parse bitwise AND: expr & expr."""
        left, new_pos = self.parse_shift()
        if left is None:
            return None, self.pos

        self.pos = new_pos
        while self.current_token().type == TokenType.BIT_AND:
            self.advance()
            right, new_pos = self.parse_shift()
            if right is None:
                return None, self.pos
            left = BinaryExpr(left=left, op=BinaryOp.BIT_AND, right=right)
            self.pos = new_pos

        return left, self.pos

    def parse_shift(self) -> tuple[Optional[Expression], int]:
        """Parse shift: <<, >>."""
        left, new_pos = self.parse_additive()
        if left is None:
            return None, self.pos

        self.pos = new_pos
        op_map = {
            TokenType.SHL: BinaryOp.SHL,
            TokenType.SHR: BinaryOp.SHR,
        }

        while self.current_token().type in op_map:
            op = op_map[self.current_token().type]
            self.advance()
            right, new_pos = self.parse_additive()
            if right is None:
                return None, self.pos
            left = BinaryExpr(left=left, op=op, right=right)
            self.pos = new_pos

        return left, self.pos

    def parse_additive(self) -> tuple[Optional[Expression], int]:
        """Parse addition/subtraction: +, -."""
        left, new_pos = self.parse_multiplicative()
        if left is None:
            return None, self.pos

        self.pos = new_pos
        op_map = {
            TokenType.PLUS: BinaryOp.ADD,
            TokenType.MINUS: BinaryOp.SUB,
        }

        while self.current_token().type in op_map:
            op = op_map[self.current_token().type]
            self.advance()
            right, new_pos = self.parse_multiplicative()
            if right is None:
                return None, self.pos
            left = BinaryExpr(left=left, op=op, right=right)
            self.pos = new_pos

        return left, self.pos

    def parse_multiplicative(self) -> tuple[Optional[Expression], int]:
        """Parse multiplication/division/modulo: *, /, %."""
        left, new_pos = self.parse_power()
        if left is None:
            return None, self.pos

        self.pos = new_pos
        op_map = {
            TokenType.STAR: BinaryOp.MUL,
            TokenType.SLASH: BinaryOp.DIV,
            TokenType.PERCENT: BinaryOp.MOD,
        }

        while self.current_token().type in op_map:
            op = op_map[self.current_token().type]
            self.advance()
            right, new_pos = self.parse_power()
            if right is None:
                return None, self.pos
            left = BinaryExpr(left=left, op=op, right=right)
            self.pos = new_pos

        return left, self.pos

    def parse_power(self) -> tuple[Optional[Expression], int]:
        """Parse power: **."""
        left, new_pos = self.parse_cast()
        if left is None:
            return None, self.pos

        self.pos = new_pos
        if self.current_token().type == TokenType.STARSTAR:
            self.advance()
            right, new_pos = self.parse_power()  # Right associative
            if right is None:
                return None, self.pos
            left = BinaryExpr(left=left, op=BinaryOp.POW, right=right)
            self.pos = new_pos

        return left, self.pos

    def parse_cast(self) -> tuple[Optional[Expression], int]:
        """Parse type cast: expr as Type."""
        expr, new_pos = self.parse_unary()
        if expr is None:
            return None, self.pos

        self.pos = new_pos
        if self.current_token().type == TokenType.AS:
            self.advance()
            target_type, new_pos = self.parse_type_callback(self.tokens, self.pos)
            if target_type is None:
                return None, self.pos
            expr = CastExpr(expr=expr, target_type=target_type)
            self.pos = new_pos

        return expr, self.pos

    def parse_unary(self) -> tuple[Optional[Expression], int]:
        """Parse unary: !, -."""
        if self.current_token().type == TokenType.NOT:
            self.advance()
            operand, new_pos = self.parse_unary()
            if operand is None:
                return None, self.pos
            return UnaryExpr(op=UnaryOp.NOT, operand=operand), new_pos

        if self.current_token().type == TokenType.MINUS:
            self.advance()
            operand, new_pos = self.parse_unary()
            if operand is None:
                return None, self.pos
            return UnaryExpr(op=UnaryOp.NEGATE, operand=operand), new_pos

        return self.parse_postfix()

    def parse_postfix(self) -> tuple[Optional[Expression], int]:
        """Parse postfix: function calls, method calls, field access, indexing."""
        expr, new_pos = self.parse_primary()
        if expr is None:
            return None, self.pos

        self.pos = new_pos
        while True:
            # Function call: expr(args)
            if self.current_token().type == TokenType.LPAREN:
                self.advance()
                args = []
                while self.current_token().type != TokenType.RPAREN:
                    arg, new_pos = self.parse_expression()
                    if arg is None:
                        return None, self.pos
                    args.append(arg)
                    self.pos = new_pos

                    if self.current_token().type == TokenType.COMMA:
                        self.advance()
                    elif self.current_token().type != TokenType.RPAREN:
                        return None, self.pos

                if self.current_token().type != TokenType.RPAREN:
                    return None, self.pos
                self.advance()
                expr = CallExpr(callee=expr, arguments=args)
                continue

            # Field access or method call: expr.field or expr.method(args)
            if self.current_token().type == TokenType.DOT:
                self.advance()
                if self.current_token().type != TokenType.IDENTIFIER:
                    # Could be tuple index like .0
                    if self.current_token().type == TokenType.INTEGER:
                        index = LiteralExpr(value=self.current_token().value)
                        self.advance()
                        expr = IndexExpr(receiver=expr, index=index)
                        continue
                    return None, self.pos

                field_name = self.current_token().value
                self.advance()

                # Check if it's a method call
                if self.current_token().type == TokenType.LPAREN:
                    self.advance()
                    args = []
                    while self.current_token().type != TokenType.RPAREN:
                        arg, new_pos = self.parse_expression()
                        if arg is None:
                            return None, self.pos
                        args.append(arg)
                        self.pos = new_pos

                        if self.current_token().type == TokenType.COMMA:
                            self.advance()
                        elif self.current_token().type != TokenType.RPAREN:
                            return None, self.pos

                    if self.current_token().type != TokenType.RPAREN:
                        return None, self.pos
                    self.advance()
                    expr = MethodCallExpr(receiver=expr, method_name=field_name, arguments=args)
                else:
                    expr = FieldAccessExpr(receiver=expr, field_name=field_name)
                continue

            # Array/tuple indexing: expr[index]
            if self.current_token().type == TokenType.LBRACKET:
                self.advance()
                index, new_pos = self.parse_expression()
                if index is None:
                    return None, self.pos
                self.pos = new_pos

                if self.current_token().type != TokenType.RBRACKET:
                    return None, self.pos
                self.advance()
                expr = IndexExpr(receiver=expr, index=index)
                continue

            # No more postfix operators
            break

        return expr, self.pos

    def parse_primary(self) -> tuple[Optional[Expression], int]:
        """Parse primary expression."""
        token = self.current_token()

        # Literals
        if token.type in (TokenType.INTEGER, TokenType.FIELD, TokenType.GROUP,
                         TokenType.SCALAR, TokenType.BOOL, TokenType.ADDRESS,
                         TokenType.STRING):
            self.advance()
            return LiteralExpr(value=token.value), self.pos

        # Identifier (could be struct init or associated function)
        if token.type == TokenType.IDENTIFIER:
            name = token.value
            self.advance()

            # Associated function: Type::method
            if self.current_token().type == TokenType.COLONCOLON:
                self.advance()
                if self.current_token().type != TokenType.IDENTIFIER:
                    return None, self.pos
                method_name = self.current_token().value
                self.advance()

                # Must be followed by call
                if self.current_token().type == TokenType.LPAREN:
                    self.advance()
                    args = []
                    while self.current_token().type != TokenType.RPAREN:
                        arg, new_pos = self.parse_expression()
                        if arg is None:
                            return None, self.pos
                        args.append(arg)
                        self.pos = new_pos

                        if self.current_token().type == TokenType.COMMA:
                            self.advance()
                        elif self.current_token().type != TokenType.RPAREN:
                            return None, self.pos

                    if self.current_token().type != TokenType.RPAREN:
                        return None, self.pos
                    self.advance()
                    # Create qualified name for callee
                    callee = IdentifierExpr(name=f"{name}::{method_name}")
                    return CallExpr(callee=callee, arguments=args), self.pos

            # Struct initialization: Name { field: value, ... }
            # Only try to parse as struct init if it looks like one
            if self.current_token().type == TokenType.LBRACE:
                # Peek ahead to see if this looks like a struct init
                # Struct init: `Name { field: value }` or `Name {}`
                # Check pattern: LBRACE + (RBRACE | IDENTIFIER + COLON)
                next_tok = self.peek_token(1)
                if next_tok.type == TokenType.RBRACE:
                    # Empty struct init: Name {}
                    self.advance()  # consume LBRACE
                    self.advance()  # consume RBRACE
                    return StructInitExpr(struct_name=name, fields=[]), self.pos
                elif next_tok.type == TokenType.IDENTIFIER:
                    # Check if followed by colon (field: value pattern)
                    next_next_tok = self.peek_token(2)
                    if next_next_tok.type == TokenType.COLON:
                        # Looks like struct init, parse it
                        self.advance()  # consume LBRACE
                        fields = []
                        while self.current_token().type != TokenType.RBRACE:
                            if self.current_token().type != TokenType.IDENTIFIER:
                                return None, self.pos
                            field_name = self.current_token().value
                            self.advance()

                            if self.current_token().type != TokenType.COLON:
                                return None, self.pos
                            self.advance()

                            field_value, new_pos = self.parse_expression()
                            if field_value is None:
                                return None, self.pos
                            fields.append((field_name, field_value))
                            self.pos = new_pos

                            if self.current_token().type == TokenType.COMMA:
                                self.advance()
                            elif self.current_token().type != TokenType.RBRACE:
                                return None, self.pos

                        if self.current_token().type != TokenType.RBRACE:
                            return None, self.pos
                        self.advance()
                        return StructInitExpr(struct_name=name, fields=fields), self.pos

            # Plain identifier (not followed by struct init or associated call)
            return IdentifierExpr(name=name), self.pos

        # self.caller, self.signer, self.address
        if token.type == TokenType.SELF:
            self.advance()
            if self.current_token().type == TokenType.DOT:
                self.advance()
                if self.current_token().type == TokenType.IDENTIFIER:
                    member = self.current_token().value
                    self.advance()
                    return SelfAccessExpr(member=member), self.pos
            return None, self.pos

        # block.height
        if token.type == TokenType.BLOCK:
            self.advance()
            if self.current_token().type == TokenType.DOT:
                self.advance()
                if self.current_token().type == TokenType.IDENTIFIER:
                    prop = self.current_token().value
                    self.advance()
                    return BlockAccessExpr(property=prop), self.pos
            return None, self.pos

        # network.id
        if token.type == TokenType.NETWORK:
            self.advance()
            if self.current_token().type == TokenType.DOT:
                self.advance()
                if self.current_token().type == TokenType.IDENTIFIER:
                    prop = self.current_token().value
                    self.advance()
                    return NetworkAccessExpr(property=prop), self.pos
            return None, self.pos

        # Parenthesized expression
        if token.type == TokenType.LPAREN:
            self.advance()
            expr, new_pos = self.parse_expression()
            if expr is None:
                return None, self.pos
            self.pos = new_pos

            if self.current_token().type != TokenType.RPAREN:
                return None, self.pos
            self.advance()
            return expr, self.pos

        return None, self.pos
