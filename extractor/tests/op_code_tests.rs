use leo_ast::{BinaryOperation, UnaryOperation};
use leo_extractor::op_codes::{binary_op_code, unary_op_code};

#[test]
fn test_binary_op_codes_match_dbscheme() {
    // Unwrapped operations
    assert_eq!(binary_op_code(BinaryOperation::Or), 1);
    assert_eq!(binary_op_code(BinaryOperation::And), 2);
    assert_eq!(binary_op_code(BinaryOperation::Eq), 3);
    assert_eq!(binary_op_code(BinaryOperation::Neq), 4);
    assert_eq!(binary_op_code(BinaryOperation::Lt), 5);
    assert_eq!(binary_op_code(BinaryOperation::Lte), 6);
    assert_eq!(binary_op_code(BinaryOperation::Gt), 7);
    assert_eq!(binary_op_code(BinaryOperation::Gte), 8);
    assert_eq!(binary_op_code(BinaryOperation::Xor), 9);
    assert_eq!(binary_op_code(BinaryOperation::BitwiseOr), 10);
    assert_eq!(binary_op_code(BinaryOperation::BitwiseAnd), 11);
    assert_eq!(binary_op_code(BinaryOperation::Shl), 12);
    assert_eq!(binary_op_code(BinaryOperation::Shr), 13);
    assert_eq!(binary_op_code(BinaryOperation::Add), 14);
    assert_eq!(binary_op_code(BinaryOperation::Sub), 15);
    assert_eq!(binary_op_code(BinaryOperation::Mul), 16);
    assert_eq!(binary_op_code(BinaryOperation::Div), 17);
    assert_eq!(binary_op_code(BinaryOperation::Mod), 18);
    assert_eq!(binary_op_code(BinaryOperation::Pow), 19);
    assert_eq!(binary_op_code(BinaryOperation::Nand), 20);
    assert_eq!(binary_op_code(BinaryOperation::Nor), 21);

    // Wrapped operations
    assert_eq!(binary_op_code(BinaryOperation::ShlWrapped), 22);
    assert_eq!(binary_op_code(BinaryOperation::ShrWrapped), 23);
    assert_eq!(binary_op_code(BinaryOperation::AddWrapped), 24);
    assert_eq!(binary_op_code(BinaryOperation::SubWrapped), 25);
    assert_eq!(binary_op_code(BinaryOperation::MulWrapped), 26);
    assert_eq!(binary_op_code(BinaryOperation::DivWrapped), 27);
    assert_eq!(binary_op_code(BinaryOperation::RemWrapped), 28);
    assert_eq!(binary_op_code(BinaryOperation::PowWrapped), 29);
}

#[test]
fn test_unary_op_codes_match_dbscheme() {
    assert_eq!(unary_op_code(UnaryOperation::Not), 1);
    assert_eq!(unary_op_code(UnaryOperation::Negate), 2);
    assert_eq!(unary_op_code(UnaryOperation::Abs), 3);
    assert_eq!(unary_op_code(UnaryOperation::AbsWrapped), 4);
    assert_eq!(unary_op_code(UnaryOperation::Double), 5);
    assert_eq!(unary_op_code(UnaryOperation::Inverse), 6);
    assert_eq!(unary_op_code(UnaryOperation::Square), 7);
    assert_eq!(unary_op_code(UnaryOperation::SquareRoot), 8);
    assert_eq!(unary_op_code(UnaryOperation::ToXCoordinate), 9);
    assert_eq!(unary_op_code(UnaryOperation::ToYCoordinate), 10);
}
