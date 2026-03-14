/// Operator code mappings matching the Python extractor's enum values.
///
/// These codes are hardcoded in the QL security queries
/// (e.g. TernaryPanicTrap checks operator == 15 for SUB).
/// Do NOT change these values without updating the queries.
use leo_ast::BinaryOperation;

/// Map a `leo_ast::BinaryOperation` to the integer code used in TRAP.
///
/// Matches the Python extractor's `BinaryOp(Enum)` auto() values:
///   OR=1, AND=2, EQ=3, NEQ=4, LT=5, LE=6, GT=7, GE=8,
///   BIT_XOR=9, BIT_OR=10, BIT_AND=11, SHL=12, SHR=13,
///   ADD=14, SUB=15, MUL=16, DIV=17, MOD=18, POW=19
pub fn binary_op_code(op: BinaryOperation) -> i64 {
    match op {
        // Logical
        BinaryOperation::Or => 1,
        BinaryOperation::And => 2,
        BinaryOperation::Nand => 2,  // treat as AND-family
        BinaryOperation::Nor => 1,   // treat as OR-family

        // Comparison
        BinaryOperation::Eq => 3,
        BinaryOperation::Neq => 4,
        BinaryOperation::Lt => 5,
        BinaryOperation::Lte => 6,
        BinaryOperation::Gt => 7,
        BinaryOperation::Gte => 8,

        // Bitwise
        BinaryOperation::Xor => 9,
        BinaryOperation::BitwiseOr => 10,
        BinaryOperation::BitwiseAnd => 11,
        BinaryOperation::Shl | BinaryOperation::ShlWrapped => 12,
        BinaryOperation::Shr | BinaryOperation::ShrWrapped => 13,

        // Arithmetic
        BinaryOperation::Add | BinaryOperation::AddWrapped => 14,
        BinaryOperation::Sub | BinaryOperation::SubWrapped => 15,
        BinaryOperation::Mul | BinaryOperation::MulWrapped => 16,
        BinaryOperation::Div | BinaryOperation::DivWrapped => 17,
        BinaryOperation::Rem | BinaryOperation::RemWrapped => 18,
        BinaryOperation::Mod => 18,
        BinaryOperation::Pow | BinaryOperation::PowWrapped => 19,
    }
}

/// Map a `leo_ast::UnaryOperation` to the integer code used in TRAP.
///
/// NOT=1, NEGATE=2
pub fn unary_op_code(op: leo_ast::UnaryOperation) -> i64 {
    match op {
        leo_ast::UnaryOperation::Not => 1,
        leo_ast::UnaryOperation::Negate => 2,
        _ => 0,
    }
}
