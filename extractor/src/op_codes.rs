/// Operator code mappings matching the Python extractor's enum values.
///
/// These codes are hardcoded in the QL security queries
/// (e.g. `TernaryPanicTrap` checks operator == 15 for `SUB`).
/// Do NOT change these values without updating the queries.
use leo_ast::BinaryOperation;

/// Map a `leo_ast::BinaryOperation` to the integer code used in `TRAP`.
///
/// Unwrapped (panic-on-overflow):
/// - `OR`=1, `AND`=2, `EQ`=3, `NEQ`=4, `LT`=5, `LE`=6, `GT`=7, `GE`=8
/// - `BIT_XOR`=9, `BIT_OR`=10, `BIT_AND`=11, `SHL`=12, `SHR`=13
/// - `ADD`=14, `SUB`=15, `MUL`=16, `DIV`=17, `MOD`=18, `POW`=19
/// - `NAND`=20, `NOR`=21
///
/// Wrapped (safe, wraps on overflow):
/// - `SHL_WRAPPED`=22, `SHR_WRAPPED`=23
/// - `ADD_WRAPPED`=24, `SUB_WRAPPED`=25, `MUL_WRAPPED`=26
/// - `DIV_WRAPPED`=27, `REM_WRAPPED`=28, `POW_WRAPPED`=29
#[must_use]
pub fn binary_op_code(op: BinaryOperation) -> i64 {
    match op {
        // Logical
        BinaryOperation::Or => 1,
        BinaryOperation::And => 2,
        BinaryOperation::Nand => 20,
        BinaryOperation::Nor => 21,

        // Comparison
        BinaryOperation::Eq => 3,
        BinaryOperation::Neq => 4,
        BinaryOperation::Lt => 5,
        BinaryOperation::Lte => 6,
        BinaryOperation::Gt => 7,
        BinaryOperation::Gte => 8,

        // Bitwise (unwrapped)
        BinaryOperation::Xor => 9,
        BinaryOperation::BitwiseOr => 10,
        BinaryOperation::BitwiseAnd => 11,
        BinaryOperation::Shl => 12,
        BinaryOperation::Shr => 13,

        // Arithmetic (unwrapped — panics on overflow)
        BinaryOperation::Add => 14,
        BinaryOperation::Sub => 15,
        BinaryOperation::Mul => 16,
        BinaryOperation::Div => 17,
        BinaryOperation::Rem | BinaryOperation::Mod => 18,
        BinaryOperation::Pow => 19,

        // Bitwise (wrapped — safe, wraps on overflow)
        BinaryOperation::ShlWrapped => 22,
        BinaryOperation::ShrWrapped => 23,

        // Arithmetic (wrapped — safe, wraps on overflow)
        BinaryOperation::AddWrapped => 24,
        BinaryOperation::SubWrapped => 25,
        BinaryOperation::MulWrapped => 26,
        BinaryOperation::DivWrapped => 27,
        BinaryOperation::RemWrapped => 28,
        BinaryOperation::PowWrapped => 29,
    }
}

/// Map a `leo_ast::UnaryOperation` to the integer code used in `TRAP`.
///
/// - `NOT`=1, `NEGATE`=2, `ABS`=3, `ABS_WRAPPED`=4, `DOUBLE`=5
/// - `INVERSE`=6, `SQUARE`=7, `SQUARE_ROOT`=8
/// - `TO_X_COORDINATE`=9, `TO_Y_COORDINATE`=10
#[must_use]
pub fn unary_op_code(op: leo_ast::UnaryOperation) -> i64 {
    match op {
        leo_ast::UnaryOperation::Not => 1,
        leo_ast::UnaryOperation::Negate => 2,
        leo_ast::UnaryOperation::Abs => 3,
        leo_ast::UnaryOperation::AbsWrapped => 4,
        leo_ast::UnaryOperation::Double => 5,
        leo_ast::UnaryOperation::Inverse => 6,
        leo_ast::UnaryOperation::Square => 7,
        leo_ast::UnaryOperation::SquareRoot => 8,
        leo_ast::UnaryOperation::ToXCoordinate => 9,
        leo_ast::UnaryOperation::ToYCoordinate => 10,
    }
}
