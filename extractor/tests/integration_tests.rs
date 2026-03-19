#![allow(clippy::expect_used, clippy::needless_raw_string_hashes)]

use leo_ast::NodeBuilder;
use leo_errors::Handler;
use leo_extractor::ast_to_trap::AstToTrap;
use leo_span::source_map::SourceMap;

#[test]
fn test_hello_program_extraction() {
    let source = r###"program hello.aleo {
    transition main(a: u32, b: u32) -> u32 {
        return a + b;
    }
}"###;

    // Initialize leo_span session
    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        // Convert the program
        for (_sym, scope) in &ast.ast.program_scopes {
            converter.convert_program(scope, "hello.aleo", "test.leo");
        }

        let trap_output = converter.finish();

        // Verify TRAP contains expected structures
        assert!(
            trap_output.contains("leo_programs("),
            "Should contain leo_programs tuple"
        );
        assert!(
            trap_output.contains("leo_functions("),
            "Should contain leo_functions tuple"
        );
        assert!(
            trap_output.contains("leo_parameters("),
            "Should contain leo_parameters tuple"
        );
        assert!(
            trap_output.contains("leo_binary_ops("),
            "Should contain leo_binary_ops tuple (for a + b)"
        );
        assert!(
            trap_output.contains("leo_return_types("),
            "Should contain leo_return_types tuple"
        );
        assert!(
            trap_output.contains("\"main\""),
            "Should contain function name 'main'"
        );
        assert!(
            trap_output.contains("\"u32\""),
            "Should contain type name 'u32'"
        );
    });
}

#[test]
fn test_optional_type_extraction() {
    let source = r###"program test.aleo {
    transition check(x: u64?) -> bool {
        return x.is_some();
    }
}"###;

    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        for (_sym, scope) in &ast.ast.program_scopes {
            converter.convert_program(scope, "test.aleo", "test.leo");
        }

        let trap_output = converter.finish();

        // Verify optional type and inner type are emitted
        assert!(
            trap_output.contains("leo_types(") && trap_output.contains("23"),
            "Should contain optional type with kind=23"
        );
        assert!(
            trap_output.contains("leo_optional_inner_type("),
            "Should contain leo_optional_inner_type tuple"
        );
    });
}

#[test]
fn test_storage_variable_kind() {
    let source = r###"program test.aleo {
    mapping balances: address => u64;

    storage account: address;
}"###;

    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        for (_sym, scope) in &ast.ast.program_scopes {
            converter.convert_program(scope, "test.aleo", "test.leo");
        }

        let trap_output = converter.finish();

        // Verify storage variable uses kind=9
        assert!(
            trap_output.contains("leo_stmts(") && trap_output.contains(", 9)"),
            "Should contain storage statement with kind=9"
        );
        assert!(
            trap_output.contains("leo_variable_decls(") && trap_output.contains("\"account\""),
            "Should contain storage variable declaration for 'account'"
        );
    });
}

#[test]
fn test_field_type_extraction() {
    let source = r###"program test.aleo {
    transition compute(x: field) -> field {
        return x + 1field;
    }
}"###;

    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        for (_sym, scope) in &ast.ast.program_scopes {
            converter.convert_program(scope, "test.aleo", "test.leo");
        }

        let trap_output = converter.finish();

        // Verify field type with kind=11
        assert!(
            trap_output.contains("leo_types(") && trap_output.contains("11, \"field\""),
            "Should contain field type with kind=11"
        );
    });
}

#[test]
fn test_struct_init_extraction() {
    let source = r###"program test.aleo {
    struct Point {
        x: u32,
        y: u32,
    }

    transition make_point(a: u32, b: u32) -> Point {
        return Point { x: a, y: b };
    }
}"###;

    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        for (_sym, scope) in &ast.ast.program_scopes {
            converter.convert_program(scope, "test.aleo", "test.leo");
        }

        let trap_output = converter.finish();

        // Verify struct declaration and initialization tuples
        assert!(
            trap_output.contains("leo_struct_declarations("),
            "Should contain struct declaration"
        );
        assert!(
            trap_output.contains("leo_struct_fields("),
            "Should contain struct fields"
        );
        assert!(
            trap_output.contains("leo_struct_init_name("),
            "Should contain struct init name"
        );
        assert!(
            trap_output.contains("leo_struct_init_fields("),
            "Should contain struct init fields"
        );
    });
}

#[test]
fn test_cast_expression_extraction() {
    let source = r###"program test.aleo {
    transition convert(x: u32) -> u64 {
        return x as u64;
    }
}"###;

    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        for (_sym, scope) in &ast.ast.program_scopes {
            converter.convert_program(scope, "test.aleo", "test.leo");
        }

        let trap_output = converter.finish();

        // Verify cast type tuple
        assert!(
            trap_output.contains("leo_cast_type("),
            "Should contain cast type tuple"
        );
    });
}

#[test]
fn test_control_flow_extraction() {
    let source = r###"program test.aleo {
    transition sum(n: u32) -> u32 {
        let total: u32 = 0u32;
        for i: u32 in 0u32..n {
            total = total + i;
        }
        if (total > 100u32) {
            return total;
        } else {
            return 0u32;
        }
    }
}"###;

    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        for (_sym, scope) in &ast.ast.program_scopes {
            converter.convert_program(scope, "test.aleo", "test.leo");
        }

        let trap_output = converter.finish();

        // Verify control flow tuples
        assert!(
            trap_output.contains("leo_for_variable("),
            "Should contain for loop variable"
        );
        assert!(
            trap_output.contains("leo_for_range("),
            "Should contain for loop range"
        );
        assert!(
            trap_output.contains("leo_for_body("),
            "Should contain for loop body"
        );
        assert!(
            trap_output.contains("leo_if_condition("),
            "Should contain if condition"
        );
        assert!(
            trap_output.contains("leo_if_then("),
            "Should contain if then branch"
        );
        assert!(
            trap_output.contains("leo_if_else("),
            "Should contain if else branch"
        );
    });
}

#[test]
fn test_assert_extraction() {
    let source = r###"program test.aleo {
    transition check(a: u32, b: u32) {
        assert(a > 0u32);
        assert_eq(a, b);
        assert_neq(a, 0u32);
    }
}"###;

    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        for (_sym, scope) in &ast.ast.program_scopes {
            converter.convert_program(scope, "test.aleo", "test.leo");
        }

        let trap_output = converter.finish();

        // Verify assert variants (0=assert, 1=assert_eq, 2=assert_neq)
        assert!(
            trap_output.contains("leo_assert_variants("),
            "Should contain assert variants"
        );
        assert!(
            trap_output.contains(", 0)") || trap_output.contains("0,"),
            "Should contain assert variant 0"
        );
        assert!(
            trap_output.contains(", 1)") || trap_output.contains("1,"),
            "Should contain assert_eq variant 1"
        );
        assert!(
            trap_output.contains(", 2)") || trap_output.contains("2,"),
            "Should contain assert_neq variant 2"
        );
    });
}

#[test]
fn test_ternary_expression_extraction() {
    let source = r###"program test.aleo {
    transition pick(cond: bool, a: u32, b: u32) -> u32 {
        return cond ? a : b;
    }
}"###;

    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        for (_sym, scope) in &ast.ast.program_scopes {
            converter.convert_program(scope, "test.aleo", "test.leo");
        }

        let trap_output = converter.finish();

        // Verify ternary expression tuples
        assert!(
            trap_output.contains("leo_ternary_condition("),
            "Should contain ternary condition"
        );
        assert!(
            trap_output.contains("leo_ternary_then("),
            "Should contain ternary then branch"
        );
        assert!(
            trap_output.contains("leo_ternary_else("),
            "Should contain ternary else branch"
        );
    });
}

#[test]
fn test_import_extraction() {
    let source = r###"import credits.aleo;
program test.aleo {
    transition main() -> u32 {
        return 1u32;
    }
}"###;

    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        let mut first_prog_label = None;

        for (_sym, scope) in &ast.ast.program_scopes {
            let prog_label = converter.convert_program(scope, "test.aleo", "test.leo");
            if first_prog_label.is_none() {
                first_prog_label = Some(prog_label);
            }
        }

        // Convert imports
        if let Some(label) = first_prog_label {
            converter.convert_imports(&ast.ast.imports, label);
        }

        let trap_output = converter.finish();

        // Verify imports tuple
        assert!(
            trap_output.contains("leo_imports("),
            "Should contain import declaration"
        );
    });
}

#[test]
fn test_mapping_extraction() {
    let source = r###"program test.aleo {
    mapping balances: address => u64;

    transition deposit(addr: address, amount: u64) {
        assert(amount > 0u64);
    }
}"###;

    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        for (_sym, scope) in &ast.ast.program_scopes {
            converter.convert_program(scope, "test.aleo", "test.leo");
        }

        let trap_output = converter.finish();

        // Verify mappings tuple
        assert!(
            trap_output.contains("leo_mappings("),
            "Should contain mapping declaration"
        );
    });
}

#[test]
fn test_record_extraction() {
    let source = r###"program test.aleo {
    record token {
        owner: address,
        amount: u64,
    }

    transition mint(owner: address, amount: u64) -> token {
        return token { owner, amount };
    }
}"###;

    leo_span::create_session_if_not_set_then(|_| {
        let handler = Handler::default();
        let node_builder = NodeBuilder::default();
        let source_map = SourceMap::default();
        let file_name = leo_span::source_map::FileName::Custom("test.leo".to_string());
        let sf = source_map.new_source(source, file_name);

        let ast = leo_parser::parse_ast(
            handler,
            &node_builder,
            &sf,
            &[],
            leo_ast::NetworkName::MainnetV0,
        )
        .expect("Parse failed");

        let mut converter = AstToTrap::new(source);

        for (_sym, scope) in &ast.ast.program_scopes {
            converter.convert_program(scope, "test.aleo", "test.leo");
        }

        let trap_output = converter.finish();

        // Verify struct declaration with is_record=1
        assert!(
            trap_output.contains("leo_struct_declarations("),
            "Should contain struct/record declaration"
        );
        assert!(
            trap_output.contains(", 1)") && trap_output.contains("\"token\""),
            "Should contain record declaration with is_record=1"
        );
    });
}
