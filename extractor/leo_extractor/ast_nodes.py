"""AST node definitions for Leo language parser.

All nodes include unique IDs and source location spans.
"""

from dataclasses import dataclass, field
from typing import Optional
from enum import Enum, auto


# Global counter for unique node IDs
_node_id_counter = 0


def next_node_id() -> int:
    """Generate next unique node ID."""
    global _node_id_counter
    _node_id_counter += 1
    return _node_id_counter


@dataclass
class SourceLocation:
    """Source code location span."""
    file_path: str
    start_line: int
    start_col: int
    end_line: int
    end_col: int


class FunctionKind(Enum):
    """Leo function kinds."""
    INLINE = auto()
    FUNCTION = auto()
    TRANSITION = auto()
    FINALIZE = auto()


class UnaryOp(Enum):
    """Unary operators."""
    NOT = auto()      # !
    NEGATE = auto()   # -


class BinaryOp(Enum):
    """Binary operators."""
    # Logical
    OR = auto()       # ||
    AND = auto()      # &&
    # Comparison
    EQ = auto()       # ==
    NEQ = auto()      # !=
    LT = auto()       # <
    LE = auto()       # <=
    GT = auto()       # >
    GE = auto()       # >=
    # Bitwise
    BIT_XOR = auto()  # ^
    BIT_OR = auto()   # |
    BIT_AND = auto()  # &
    SHL = auto()      # <<
    SHR = auto()      # >>
    # Arithmetic
    ADD = auto()      # +
    SUB = auto()      # -
    MUL = auto()      # *
    DIV = auto()      # /
    MOD = auto()      # %
    POW = auto()      # **


class AssignOp(Enum):
    """Assignment operators."""
    ASSIGN = auto()     # =
    ADD_ASSIGN = auto() # +=
    SUB_ASSIGN = auto() # -=
    MUL_ASSIGN = auto() # *=
    DIV_ASSIGN = auto() # /=
    MOD_ASSIGN = auto() # %=
    SHL_ASSIGN = auto() # <<=
    SHR_ASSIGN = auto() # >>=
    AND_ASSIGN = auto() # &=
    OR_ASSIGN = auto()  # |=
    XOR_ASSIGN = auto() # ^=
    POW_ASSIGN = auto() # **=


# ===== Type Nodes =====

@dataclass
class Type:
    """Base class for type nodes."""
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class IntegerType(Type):
    """Integer type: u8, u16, u32, u64, u128, i8, i16, i32, i64, i128."""
    type_name: str = ""  # e.g., "u32", "i128"


@dataclass
class FieldType(Type):
    """Field element type."""
    pass


@dataclass
class GroupType(Type):
    """Group element type."""
    pass


@dataclass
class ScalarType(Type):
    """Scalar type."""
    pass


@dataclass
class BoolType(Type):
    """Boolean type."""
    pass


@dataclass
class AddressType(Type):
    """Address type."""
    pass


@dataclass
class SignatureType(Type):
    """Signature type."""
    pass


@dataclass
class StringType(Type):
    """String type."""
    pass


@dataclass
class ArrayType(Type):
    """Array type: [T; N]."""
    element_type: Optional[Type] = None
    size: int = 0


@dataclass
class TupleType(Type):
    """Tuple type: (T1, T2, ...)."""
    element_types: list[Type] = field(default_factory=list)


@dataclass
class IdentifierType(Type):
    """Named type (struct, record, etc.)."""
    name: str = ""


@dataclass
class FutureType(Type):
    """Future<T> type for async functions."""
    inner_type: Optional[Type] = None


# ===== Expression Nodes =====

@dataclass
class Expression:
    """Base class for expression nodes."""
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class LiteralExpr(Expression):
    """Literal expression."""
    value: str = ""
    literal_type: Optional[Type] = None


@dataclass
class IdentifierExpr(Expression):
    """Identifier expression."""
    name: str = ""


@dataclass
class BinaryExpr(Expression):
    """Binary operation."""
    left: Optional[Expression] = None
    op: Optional[BinaryOp] = None
    right: Optional[Expression] = None


@dataclass
class UnaryExpr(Expression):
    """Unary operation."""
    op: Optional[UnaryOp] = None
    operand: Optional[Expression] = None


@dataclass
class TernaryExpr(Expression):
    """Ternary conditional: condition ? then_expr : else_expr."""
    condition: Optional[Expression] = None
    then_expr: Optional[Expression] = None
    else_expr: Optional[Expression] = None


@dataclass
class CastExpr(Expression):
    """Type cast: expr as Type."""
    expr: Optional[Expression] = None
    target_type: Optional[Type] = None


@dataclass
class CallExpr(Expression):
    """Function call: func(args) or Type::method(args)."""
    callee: Optional[Expression] = None
    arguments: list[Expression] = field(default_factory=list)


@dataclass
class MethodCallExpr(Expression):
    """Method call: expr.method(args)."""
    receiver: Optional[Expression] = None
    method_name: str = ""
    arguments: list[Expression] = field(default_factory=list)


@dataclass
class FieldAccessExpr(Expression):
    """Field access: expr.field."""
    receiver: Optional[Expression] = None
    field_name: str = ""


@dataclass
class IndexExpr(Expression):
    """Array/tuple indexing: expr[index] or expr.0."""
    receiver: Optional[Expression] = None
    index: Optional[Expression] = None  # Can be integer literal or identifier


@dataclass
class StructInitExpr(Expression):
    """Struct initialization: Name { field: value, ... }."""
    struct_name: str = ""
    fields: list[tuple[str, Expression]] = field(default_factory=list)  # (field_name, value)


@dataclass
class SelfAccessExpr(Expression):
    """Self member access: self.caller, self.signer, self.address."""
    member: str = ""  # "caller", "signer", or "address"


@dataclass
class BlockAccessExpr(Expression):
    """Block property access: block.height."""
    property: str = ""  # "height"


@dataclass
class NetworkAccessExpr(Expression):
    """Network property access: network.id."""
    property: str = ""  # "id"


# ===== Statement Nodes =====

@dataclass
class Statement:
    """Base class for statement nodes."""
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class LetStmt(Statement):
    """Let declaration: let var: Type = expr;"""
    var_name: str = ""
    var_type: Optional[Type] = None
    initializer: Optional[Expression] = None


@dataclass
class ConstStmt(Statement):
    """Const declaration: const VAR: Type = expr;"""
    var_name: str = ""
    var_type: Optional[Type] = None
    initializer: Optional[Expression] = None


@dataclass
class AssignStmt(Statement):
    """Assignment: target op= expr;"""
    target: Optional[Expression] = None  # Can be identifier, field access, or index
    op: Optional[AssignOp] = None
    value: Optional[Expression] = None


@dataclass
class IfStmt(Statement):
    """If statement with optional else."""
    condition: Optional[Expression] = None
    then_block: Optional['BlockStmt'] = None
    else_block: Optional['BlockStmt'] = None


@dataclass
class ForStmt(Statement):
    """For loop: for var in start..end { ... }"""
    var_name: str = ""
    start: Optional[Expression] = None
    end: Optional[Expression] = None
    body: Optional['BlockStmt'] = None


@dataclass
class ReturnStmt(Statement):
    """Return statement."""
    value: Optional[Expression] = None


@dataclass
class AssertStmt(Statement):
    """Assert statement: assert(expr);"""
    condition: Optional[Expression] = None


@dataclass
class AssertEqStmt(Statement):
    """Assert equal: assert_eq(left, right);"""
    left: Optional[Expression] = None
    right: Optional[Expression] = None


@dataclass
class AssertNeqStmt(Statement):
    """Assert not equal: assert_neq(left, right);"""
    left: Optional[Expression] = None
    right: Optional[Expression] = None


@dataclass
class ExprStmt(Statement):
    """Expression statement."""
    expr: Optional[Expression] = None


@dataclass
class BlockStmt(Statement):
    """Block statement: { stmts... }"""
    statements: list[Statement] = field(default_factory=list)


# ===== Declaration Nodes =====

@dataclass
class Parameter:
    """Function parameter."""
    name: str = ""
    param_type: Optional[Type] = None
    visibility: Optional[str] = None  # "public", "private", or None
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class FunctionDecl:
    """Function declaration."""
    kind: Optional[FunctionKind] = None  # inline, function, transition
    is_async: bool = False
    name: str = ""
    parameters: list[Parameter] = field(default_factory=list)
    return_type: Optional[Type] = None
    body: Optional[BlockStmt] = None
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class StructField:
    """Struct field."""
    name: str = ""
    field_type: Optional[Type] = None
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class StructDecl:
    """Struct declaration."""
    name: str = ""
    fields: list[StructField] = field(default_factory=list)
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class RecordField:
    """Record field with visibility."""
    name: str = ""
    field_type: Optional[Type] = None
    visibility: Optional[str] = None  # "public", "private", "constant", or None
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class RecordDecl:
    """Record declaration."""
    name: str = ""
    fields: list[RecordField] = field(default_factory=list)
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class MappingDecl:
    """Mapping declaration: mapping name: KeyType => ValueType;"""
    name: str = ""
    key_type: Optional[Type] = None
    value_type: Optional[Type] = None
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class ConstDecl:
    """Top-level const declaration."""
    name: str = ""
    const_type: Optional[Type] = None
    value: Optional[Expression] = None
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class ImportDecl:
    """Import declaration: import program_id;"""
    program_id: str = ""
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None


@dataclass
class ProgramDecl:
    """Program declaration."""
    program_id: str = ""  # e.g., "name.aleo"
    imports: list[ImportDecl] = field(default_factory=list)
    structs: list[StructDecl] = field(default_factory=list)
    records: list[RecordDecl] = field(default_factory=list)
    mappings: list[MappingDecl] = field(default_factory=list)
    constants: list[ConstDecl] = field(default_factory=list)
    functions: list[FunctionDecl] = field(default_factory=list)
    node_id: int = field(default_factory=next_node_id)
    location: Optional[SourceLocation] = None
