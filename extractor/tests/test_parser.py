"""Tests for Leo parser."""

import pytest
from leo_extractor.parser import Parser
from leo_extractor.ast_nodes import ProgramDecl, FunctionDecl, FunctionKind


def test_simple_program():
    """Test parsing a simple Leo program."""
    source = """
    program hello.aleo {
        transition main(a: u32, b: u32) -> u32 {
            let c: u32 = a + b;
            return c;
        }
    }
    """

    parser = Parser(source, "test.leo")
    ast = parser.parse()

    assert ast is not None
    assert isinstance(ast, ProgramDecl)
    assert ast.program_id == "hello.aleo"
    assert len(ast.functions) == 1

    func = ast.functions[0]
    assert func.name == "main"
    assert func.kind == FunctionKind.TRANSITION
    assert len(func.parameters) == 2


def test_struct_declaration():
    """Test parsing struct declaration."""
    source = """
    program test.aleo {
        struct Point {
            x: u32,
            y: u32
        }

        transition make_point() -> Point {
            return Point { x: 10u32, y: 20u32 };
        }
    }
    """

    parser = Parser(source, "test.leo")
    ast = parser.parse()

    assert ast is not None
    assert len(ast.structs) == 1
    assert ast.structs[0].name == "Point"
    assert len(ast.structs[0].fields) == 2


def test_literals():
    """Test parsing various literals."""
    source = """
    program test.aleo {
        transition test_literals() {
            let a: u32 = 42u32;
            let b: field = 100field;
            let c: bool = true;
            let d: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
        }
    }
    """

    parser = Parser(source, "test.leo")
    ast = parser.parse()

    assert ast is not None
    assert len(ast.functions) == 1


def test_control_flow():
    """Test parsing if and for statements."""
    source = """
    program test.aleo {
        function control_test(x: u32) -> u32 {
            if x > 10u32 {
                return x;
            } else {
                return 0u32;
            }
        }

        function loop_test() -> u32 {
            let sum: u32 = 0u32;
            for i in 0u32..10u32 {
                sum += i;
            }
            return sum;
        }
    }
    """

    parser = Parser(source, "test.leo")
    ast = parser.parse()

    assert ast is not None
    assert len(ast.functions) == 2


def test_expressions():
    """Test parsing complex expressions."""
    source = """
    program test.aleo {
        function expr_test(a: u32, b: u32) -> u32 {
            let c: u32 = (a + b) * 2u32;
            let d: u32 = a > b ? a : b;
            return c + d;
        }
    }
    """

    parser = Parser(source, "test.leo")
    ast = parser.parse()

    assert ast is not None
    assert len(ast.functions) == 1


def test_record_declaration():
    """Test parsing record with visibility modifiers."""
    source = """
    program test.aleo {
        record Token {
            owner: address,
            public amount: u64
        }
    }
    """

    parser = Parser(source, "test.leo")
    ast = parser.parse()

    assert ast is not None
    assert len(ast.records) == 1
    assert ast.records[0].name == "Token"
    assert len(ast.records[0].fields) == 2


def test_mapping_declaration():
    """Test parsing mapping declaration."""
    source = """
    program test.aleo {
        mapping balances: address => u64;
    }
    """

    parser = Parser(source, "test.leo")
    ast = parser.parse()

    assert ast is not None
    assert len(ast.mappings) == 1
    assert ast.mappings[0].name == "balances"


def test_imports():
    """Test parsing import declarations."""
    source = """
    import token.aleo;
    import credits.aleo;

    program test.aleo {
        transition main() {
            return;
        }
    }
    """

    parser = Parser(source, "test.leo")
    ast = parser.parse()

    assert ast is not None
    assert len(ast.imports) == 2
    assert ast.imports[0].program_id == "token.aleo"
    assert ast.imports[1].program_id == "credits.aleo"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
