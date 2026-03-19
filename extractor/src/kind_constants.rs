/// Kind code constants matching `leo.dbscheme`.
///
/// These constants map AST node variants to their integer representations
/// in the `CodeQL` database schema.
/// Statement kind codes.
pub mod stmt {
    pub const EXPR: i32 = 0;
    pub const RETURN: i32 = 1;
    pub const LET: i32 = 2;
    pub const CONST: i32 = 3;
    pub const ASSIGN: i32 = 4;
    pub const IF: i32 = 5;
    pub const FOR: i32 = 6;
    pub const BLOCK: i32 = 7;
    pub const ASSERT: i32 = 8;
    pub const STORAGE: i32 = 9;
}

/// Expression kind codes.
pub mod expr {
    pub const LITERAL: i32 = 0;
    pub const VARIABLE: i32 = 1;
    pub const BINARY: i32 = 2;
    pub const UNARY: i32 = 3;
    pub const TERNARY: i32 = 4;
    pub const CALL: i32 = 5;
    pub const METHOD_CALL: i32 = 6;
    pub const FIELD_ACCESS: i32 = 7;
    pub const INDEX_ACCESS: i32 = 8;
    pub const TUPLE_ACCESS: i32 = 9;
    pub const CAST: i32 = 10;
    pub const STRUCT_INIT: i32 = 11;
    pub const SELF_EXPR: i32 = 12;
    pub const BLOCK_EXPR: i32 = 13;
    pub const ASSOCIATED_CONST: i32 = 14;
    pub const ASSOCIATED_FN_CALL: i32 = 15;
    pub const REPEAT: i32 = 16;
    pub const ASYNC: i32 = 17;
    pub const ARRAY: i32 = 18;
    pub const TUPLE: i32 = 19;
}

/// Function kind codes.
pub mod func {
    pub const FUNCTION: i32 = 0;
    pub const TRANSITION: i32 = 1;
    pub const INLINE: i32 = 2;
    pub const FINALIZE: i32 = 3;
    pub const CONSTRUCTOR: i32 = 4;
}

/// Assert variant codes.
pub mod assert_variant {
    pub const ASSERT: i32 = 0;
    pub const ASSERT_EQ: i32 = 1;
    pub const ASSERT_NEQ: i32 = 2;
}

/// Type kind codes.
pub mod type_kind {
    pub const BOOL: i32 = 0;
    pub const U8: i32 = 1;
    pub const U16: i32 = 2;
    pub const U32: i32 = 3;
    pub const U64: i32 = 4;
    pub const U128: i32 = 5;
    pub const I8: i32 = 6;
    pub const I16: i32 = 7;
    pub const I32: i32 = 8;
    pub const I64: i32 = 9;
    pub const I128: i32 = 10;
    pub const FIELD: i32 = 11;
    pub const GROUP: i32 = 12;
    pub const SCALAR: i32 = 13;
    pub const ADDRESS: i32 = 14;
    pub const SIGNATURE: i32 = 15;
    pub const STRING: i32 = 16;
    pub const ARRAY: i32 = 17;
    pub const TUPLE: i32 = 18;
    pub const COMPOSITE: i32 = 19;
    pub const FUTURE: i32 = 20;
    pub const UNIT: i32 = 21;
    pub const MAPPING: i32 = 22;
    pub const OPTIONAL: i32 = 23;
    pub const VECTOR: i32 = 24;
    pub const NUMERIC: i32 = 25;
    pub const ERROR: i32 = 26;
}

/// Assignment operator codes.
pub mod assign_op {
    pub const ASSIGN: i32 = 0;
}
