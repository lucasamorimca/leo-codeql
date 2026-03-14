"""Lexer/tokenizer for Leo programming language.

Tokenizes Leo source code with full source location tracking.
"""

from dataclasses import dataclass
from enum import Enum, auto
from typing import Optional
from .ast_nodes import SourceLocation


class TokenType(Enum):
    """Token types for Leo language."""
    # Literals
    INTEGER = auto()
    FIELD = auto()
    GROUP = auto()
    SCALAR = auto()
    BOOL = auto()
    ADDRESS = auto()
    STRING = auto()

    # Identifiers and keywords
    IDENTIFIER = auto()

    # Keywords - declarations
    PROGRAM = auto()
    IMPORT = auto()
    STRUCT = auto()
    RECORD = auto()
    MAPPING = auto()
    FUNCTION = auto()
    TRANSITION = auto()
    INLINE = auto()
    FINALIZE = auto()
    ASYNC = auto()
    CONST = auto()
    LET = auto()

    # Keywords - control flow
    IF = auto()
    ELSE = auto()
    FOR = auto()
    IN = auto()
    RETURN = auto()

    # Keywords - assertions
    ASSERT = auto()
    ASSERT_EQ = auto()
    ASSERT_NEQ = auto()

    # Keywords - types
    BOOL_TYPE = auto()
    U8 = auto()
    U16 = auto()
    U32 = auto()
    U64 = auto()
    U128 = auto()
    I8 = auto()
    I16 = auto()
    I32 = auto()
    I64 = auto()
    I128 = auto()
    FIELD_TYPE = auto()
    GROUP_TYPE = auto()
    SCALAR_TYPE = auto()
    ADDRESS_TYPE = auto()
    SIGNATURE = auto()
    STRING_TYPE = auto()
    FUTURE = auto()

    # Keywords - visibility
    PUBLIC = auto()
    PRIVATE = auto()
    CONSTANT = auto()

    # Keywords - special
    SELF = auto()
    BLOCK = auto()
    NETWORK = auto()
    AS = auto()

    # Operators - arithmetic
    PLUS = auto()          # +
    MINUS = auto()         # -
    STAR = auto()          # *
    SLASH = auto()         # /
    PERCENT = auto()       # %
    STARSTAR = auto()      # **

    # Operators - comparison
    EQ = auto()            # ==
    NEQ = auto()           # !=
    LT = auto()            # <
    LE = auto()            # <=
    GT = auto()            # >
    GE = auto()            # >=

    # Operators - logical
    AND = auto()           # &&
    OR = auto()            # ||
    NOT = auto()           # !

    # Operators - bitwise
    BIT_AND = auto()       # &
    BIT_OR = auto()        # |
    BIT_XOR = auto()       # ^
    SHL = auto()           # <<
    SHR = auto()           # >>

    # Operators - assignment
    ASSIGN = auto()        # =
    PLUS_ASSIGN = auto()   # +=
    MINUS_ASSIGN = auto()  # -=
    STAR_ASSIGN = auto()   # *=
    SLASH_ASSIGN = auto()  # /=
    PERCENT_ASSIGN = auto() # %=
    SHL_ASSIGN = auto()    # <<=
    SHR_ASSIGN = auto()    # >>=
    AND_ASSIGN = auto()    # &=
    OR_ASSIGN = auto()     # |=
    XOR_ASSIGN = auto()    # ^=
    POW_ASSIGN = auto()    # **=

    # Operators - other
    QUESTION = auto()      # ?

    # Delimiters
    LPAREN = auto()        # (
    RPAREN = auto()        # )
    LBRACE = auto()        # {
    RBRACE = auto()        # }
    LBRACKET = auto()      # [
    RBRACKET = auto()      # ]
    SEMICOLON = auto()     # ;
    COLON = auto()         # :
    COMMA = auto()         # ,
    DOT = auto()           # .
    DOTDOT = auto()        # ..
    ARROW = auto()         # =>
    RARROW = auto()        # ->
    COLONCOLON = auto()    # ::

    # Special
    EOF = auto()
    ERROR = auto()


# Keywords mapping
KEYWORDS = {
    "program": TokenType.PROGRAM,
    "import": TokenType.IMPORT,
    "struct": TokenType.STRUCT,
    "record": TokenType.RECORD,
    "mapping": TokenType.MAPPING,
    "function": TokenType.FUNCTION,
    "transition": TokenType.TRANSITION,
    "inline": TokenType.INLINE,
    "finalize": TokenType.FINALIZE,
    "async": TokenType.ASYNC,
    "const": TokenType.CONST,
    "let": TokenType.LET,
    "if": TokenType.IF,
    "else": TokenType.ELSE,
    "for": TokenType.FOR,
    "in": TokenType.IN,
    "return": TokenType.RETURN,
    "assert": TokenType.ASSERT,
    "assert_eq": TokenType.ASSERT_EQ,
    "assert_neq": TokenType.ASSERT_NEQ,
    "bool": TokenType.BOOL_TYPE,
    "u8": TokenType.U8,
    "u16": TokenType.U16,
    "u32": TokenType.U32,
    "u64": TokenType.U64,
    "u128": TokenType.U128,
    "i8": TokenType.I8,
    "i16": TokenType.I16,
    "i32": TokenType.I32,
    "i64": TokenType.I64,
    "i128": TokenType.I128,
    "field": TokenType.FIELD_TYPE,
    "group": TokenType.GROUP_TYPE,
    "scalar": TokenType.SCALAR_TYPE,
    "address": TokenType.ADDRESS_TYPE,
    "signature": TokenType.SIGNATURE,
    "string": TokenType.STRING_TYPE,
    "Future": TokenType.FUTURE,
    "public": TokenType.PUBLIC,
    "private": TokenType.PRIVATE,
    "constant": TokenType.CONSTANT,
    "self": TokenType.SELF,
    "block": TokenType.BLOCK,
    "network": TokenType.NETWORK,
    "as": TokenType.AS,
    "true": TokenType.BOOL,
    "false": TokenType.BOOL,
}


@dataclass
class Token:
    """A lexical token with location information."""
    type: TokenType
    value: str
    location: SourceLocation


class Lexer:
    """Lexer for Leo programming language."""

    def __init__(self, source: str, file_path: str = "<input>"):
        """Initialize lexer with source code.

        Args:
            source: Leo source code to tokenize
            file_path: Source file path for error reporting
        """
        self.source = source
        self.file_path = file_path
        self.pos = 0
        self.line = 1
        self.col = 1
        self.tokens: list[Token] = []

    def current_char(self) -> Optional[str]:
        """Get current character without advancing."""
        if self.pos >= len(self.source):
            return None
        return self.source[self.pos]

    def peek_char(self, offset: int = 1) -> Optional[str]:
        """Peek ahead at character."""
        pos = self.pos + offset
        if pos >= len(self.source):
            return None
        return self.source[pos]

    def advance(self) -> Optional[str]:
        """Advance to next character."""
        if self.pos >= len(self.source):
            return None
        char = self.source[self.pos]
        self.pos += 1
        if char == '\n':
            self.line += 1
            self.col = 1
        else:
            self.col += 1
        return char

    def skip_whitespace(self):
        """Skip whitespace characters."""
        while self.current_char() and self.current_char() in ' \t\n\r':
            self.advance()

    def skip_line_comment(self):
        """Skip line comment: // ..."""
        self.advance()  # /
        self.advance()  # /
        while self.current_char() and self.current_char() != '\n':
            self.advance()

    def skip_block_comment(self) -> Optional[Token]:
        """Skip block comment: /* ... */

        Returns:
            None if comment is properly closed, error token if unterminated
        """
        start_line = self.line
        start_col = self.col
        self.advance()  # /
        self.advance()  # *
        while self.current_char():
            if self.current_char() == '*' and self.peek_char() == '/':
                self.advance()  # *
                self.advance()  # /
                return None  # Successfully closed
            self.advance()

        # EOF reached before closing */
        location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
        return Token(TokenType.ERROR, "/* unterminated block comment", location)

    def read_string(self, start_line: int, start_col: int) -> Token:
        """Read string literal."""
        self.advance()  # opening "
        value = '"'
        while self.current_char() and self.current_char() != '"':
            if self.current_char() == '\\':
                value += self.advance()
                if self.current_char():
                    value += self.advance()
            else:
                value += self.advance()

        location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)

        if self.current_char() == '"':
            value += self.advance()  # closing "
            return Token(TokenType.STRING, value, location)
        else:
            # Unterminated string - emit error token
            return Token(TokenType.ERROR, value, location)

    def read_number_or_typed_literal(self, start_line: int, start_col: int) -> Token:
        """Read number literal with optional type suffix."""
        value = ''
        while self.current_char() and self.current_char().isdigit():
            value += self.advance()

        # Check for type suffix
        if self.current_char() and self.current_char().isalpha():
            suffix = ''
            while self.current_char() and (self.current_char().isalnum() or self.current_char() == '_'):
                suffix += self.advance()

            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)

            # Determine token type based on suffix
            if suffix in ('u8', 'u16', 'u32', 'u64', 'u128', 'i8', 'i16', 'i32', 'i64', 'i128'):
                return Token(TokenType.INTEGER, value + suffix, location)
            elif suffix == 'field':
                return Token(TokenType.FIELD, value + suffix, location)
            elif suffix == 'group':
                return Token(TokenType.GROUP, value + suffix, location)
            elif suffix == 'scalar':
                return Token(TokenType.SCALAR, value + suffix, location)
            else:
                return Token(TokenType.ERROR, value + suffix, location)

        location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
        return Token(TokenType.INTEGER, value, location)

    def read_identifier_or_keyword(self, start_line: int, start_col: int) -> Token:
        """Read identifier or keyword."""
        value = ''

        # Handle address literal: aleo1...
        if self.current_char() == 'a' and self.peek_char() == 'l' and \
           self.peek_char(2) == 'e' and self.peek_char(3) == 'o' and \
           self.peek_char(4) == '1':
            # Read full address (aleo1 + 58 chars)
            while self.current_char() and (self.current_char().isalnum() or self.current_char() == '_'):
                value += self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            if value.startswith('aleo1') and len(value) >= 63:
                return Token(TokenType.ADDRESS, value, location)

        # Regular identifier/keyword
        while self.current_char() and (self.current_char().isalnum() or self.current_char() == '_'):
            value += self.advance()

        # Check for .aleo suffix (program ID)
        if self.current_char() == '.' and self.peek_char() == 'a':
            pos_save = self.pos
            self.advance()  # .
            suffix = self.advance()  # a
            if self.current_char() == 'l':
                suffix += self.advance()  # l
                if self.current_char() == 'e':
                    suffix += self.advance()  # e
                    if self.current_char() == 'o':
                        suffix += self.advance()  # o
                        if suffix == 'aleo':
                            value += '.' + suffix

        location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)

        # Check if it's a keyword
        token_type = KEYWORDS.get(value, TokenType.IDENTIFIER)
        return Token(token_type, value, location)

    def next_token(self) -> Token:
        """Get next token from source."""
        self.skip_whitespace()

        if not self.current_char():
            location = SourceLocation(self.file_path, self.line, self.col, self.line, self.col)
            return Token(TokenType.EOF, "", location)

        start_line = self.line
        start_col = self.col
        char = self.current_char()

        # Comments
        if char == '/' and self.peek_char() == '/':
            self.skip_line_comment()
            return self.next_token()
        if char == '/' and self.peek_char() == '*':
            error_token = self.skip_block_comment()
            if error_token:
                return error_token  # Return error for unterminated block comment
            return self.next_token()

        # String literals
        if char == '"':
            return self.read_string(start_line, start_col)

        # Numbers
        if char.isdigit():
            return self.read_number_or_typed_literal(start_line, start_col)

        # Identifiers and keywords
        if char.isalpha() or char == '_':
            return self.read_identifier_or_keyword(start_line, start_col)

        # Multi-character operators
        if char == '=' and self.peek_char() == '=':
            self.advance()
            self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.EQ, "==", location)

        if char == '!' and self.peek_char() == '=':
            self.advance()
            self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.NEQ, "!=", location)

        if char == '<' and self.peek_char() == '=':
            self.advance()
            self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.LE, "<=", location)

        if char == '>' and self.peek_char() == '=':
            self.advance()
            self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.GE, ">=", location)

        if char == '<' and self.peek_char() == '<':
            self.advance()
            self.advance()
            if self.current_char() == '=':
                self.advance()
                location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
                return Token(TokenType.SHL_ASSIGN, "<<=", location)
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.SHL, "<<", location)

        if char == '>' and self.peek_char() == '>':
            self.advance()
            self.advance()
            if self.current_char() == '=':
                self.advance()
                location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
                return Token(TokenType.SHR_ASSIGN, ">>=", location)
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.SHR, ">>", location)

        if char == '&' and self.peek_char() == '&':
            self.advance()
            self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.AND, "&&", location)

        if char == '|' and self.peek_char() == '|':
            self.advance()
            self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.OR, "||", location)

        if char == '*' and self.peek_char() == '*':
            self.advance()
            self.advance()
            if self.current_char() == '=':
                self.advance()
                location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
                return Token(TokenType.POW_ASSIGN, "**=", location)
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.STARSTAR, "**", location)

        if char == '.' and self.peek_char() == '.':
            self.advance()
            self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.DOTDOT, "..", location)

        if char == '=' and self.peek_char() == '>':
            self.advance()
            self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.ARROW, "=>", location)

        if char == ':' and self.peek_char() == ':':
            self.advance()
            self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.COLONCOLON, "::", location)

        if char == '-' and self.peek_char() == '>':
            self.advance()
            self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(TokenType.RARROW, "->", location)

        # Compound assignment operators
        compound_ops = {
            '+=': TokenType.PLUS_ASSIGN,
            '-=': TokenType.MINUS_ASSIGN,
            '*=': TokenType.STAR_ASSIGN,
            '/=': TokenType.SLASH_ASSIGN,
            '%=': TokenType.PERCENT_ASSIGN,
            '&=': TokenType.AND_ASSIGN,
            '|=': TokenType.OR_ASSIGN,
            '^=': TokenType.XOR_ASSIGN,
        }

        for op_str, op_type in compound_ops.items():
            if char == op_str[0] and self.peek_char() == op_str[1]:
                self.advance()
                self.advance()
                location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
                return Token(op_type, op_str, location)

        # Single-character tokens
        single_char_tokens = {
            '+': TokenType.PLUS,
            '-': TokenType.MINUS,
            '*': TokenType.STAR,
            '/': TokenType.SLASH,
            '%': TokenType.PERCENT,
            '<': TokenType.LT,
            '>': TokenType.GT,
            '=': TokenType.ASSIGN,
            '!': TokenType.NOT,
            '&': TokenType.BIT_AND,
            '|': TokenType.BIT_OR,
            '^': TokenType.BIT_XOR,
            '?': TokenType.QUESTION,
            '(': TokenType.LPAREN,
            ')': TokenType.RPAREN,
            '{': TokenType.LBRACE,
            '}': TokenType.RBRACE,
            '[': TokenType.LBRACKET,
            ']': TokenType.RBRACKET,
            ';': TokenType.SEMICOLON,
            ':': TokenType.COLON,
            ',': TokenType.COMMA,
            '.': TokenType.DOT,
        }

        if char in single_char_tokens:
            self.advance()
            location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
            return Token(single_char_tokens[char], char, location)

        # Unknown character
        self.advance()
        location = SourceLocation(self.file_path, start_line, start_col, self.line, self.col)
        return Token(TokenType.ERROR, char, location)

    def tokenize(self) -> list[Token]:
        """Tokenize entire source into list of tokens."""
        tokens = []
        while True:
            token = self.next_token()
            tokens.append(token)
            if token.type == TokenType.EOF:
                break
        return tokens
