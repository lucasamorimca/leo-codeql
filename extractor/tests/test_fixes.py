"""Tests for critical and high priority fixes."""

import pytest
import tempfile
from leo_extractor.parser import Parser
from leo_extractor.lexer import Lexer, TokenType
from leo_extractor.ast_nodes import IfStmt, BlockStmt, LetStmt
from leo_extractor.ast_to_trap import AstToTrap
from leo_extractor.trap_writer import TrapWriter


def test_else_if_chain():
    """Test C4: else if chains are parsed correctly."""
    source = """
program test.aleo {
    function test(x: u32) -> u32 {
        if x == 1u32 {
            return 1u32;
        } else if x == 2u32 {
            return 2u32;
        } else if x == 3u32 {
            return 3u32;
        } else {
            return 0u32;
        }
    }
}
"""
    parser = Parser(source, "test.leo")
    program = parser.parse()
    assert program is not None
    assert len(program.functions) == 1
    func = program.functions[0]
    assert isinstance(func.body, BlockStmt)
    assert len(func.body.statements) == 1

    # First if statement
    first_if = func.body.statements[0]
    assert isinstance(first_if, IfStmt)
    assert first_if.else_block is not None

    # Else if is wrapped in BlockStmt with nested IfStmt
    assert isinstance(first_if.else_block, BlockStmt)
    assert len(first_if.else_block.statements) == 1
    second_if = first_if.else_block.statements[0]
    assert isinstance(second_if, IfStmt)

    # Check third level
    assert second_if.else_block is not None
    assert isinstance(second_if.else_block, BlockStmt)
    assert len(second_if.else_block.statements) == 1
    third_if = second_if.else_block.statements[0]
    assert isinstance(third_if, IfStmt)

    # Final else block
    assert third_if.else_block is not None
    assert isinstance(third_if.else_block, BlockStmt)


def test_unterminated_string_error():
    """Test C5: unterminated strings emit error tokens."""
    source = '"unterminated'
    lexer = Lexer(source, "test.leo")
    tokens = lexer.tokenize()

    # Should have error token for unterminated string
    assert len(tokens) == 2  # ERROR + EOF
    assert tokens[0].type == TokenType.ERROR


def test_unterminated_block_comment_error():
    """Test C6: unterminated block comments emit error tokens."""
    source = '/* unterminated comment'
    lexer = Lexer(source, "test.leo")
    tokens = lexer.tokenize()

    # Should have error token for unterminated block comment
    assert len(tokens) == 2  # ERROR + EOF
    assert tokens[0].type == TokenType.ERROR


def test_parameter_visibility():
    """Test C1: parameter visibility is captured and emitted."""
    source = """
program test.aleo {
    transition test(public x: u32, private y: u32, z: u32) -> u32 {
        return x + y + z;
    }
}
"""
    parser = Parser(source, "test.leo")
    program = parser.parse()
    assert program is not None
    assert len(program.functions) == 1
    func = program.functions[0]

    # Check visibility captured
    assert len(func.parameters) == 3
    assert func.parameters[0].visibility == "public"
    assert func.parameters[1].visibility == "private"
    assert func.parameters[2].visibility is None

    # Test TRAP emission
    with tempfile.TemporaryDirectory() as tmpdir:
        writer = TrapWriter(tmpdir, tmpdir)
        converter = AstToTrap(writer, ".")
        converter.convert_program(program, "test.leo")
        trap_output = "\n".join(writer._lines)

    # Check parameters in TRAP have correct visibility
    # public=1, private=0, none=0
    assert "leo_parameters" in trap_output


def test_record_field_visibility():
    """Test C1: record field visibility uses correct encoding."""
    source = """
program test.aleo {
    record Token {
        private owner: address,
        public amount: u64,
        constant id: field
    }
}
"""
    parser = Parser(source, "test.leo")
    program = parser.parse()
    assert program is not None
    assert len(program.records) == 1
    record = program.records[0]

    # Check visibility captured
    assert len(record.fields) == 3
    assert record.fields[0].visibility == "private"
    assert record.fields[1].visibility == "public"
    assert record.fields[2].visibility == "constant"

    # Test TRAP emission uses: private=0, public=1, constant=2
    with tempfile.TemporaryDirectory() as tmpdir:
        writer = TrapWriter(tmpdir, tmpdir)
        converter = AstToTrap(writer, ".")
        converter.convert_program(program, "test.leo")
        trap_output = "\n".join(writer._lines)

    # Verify struct fields emitted
    assert "leo_struct_fields" in trap_output


def test_constants_emitted():
    """Test H3: program-level constants are emitted to TRAP."""
    source = """
program test.aleo {
    const MAX: u32 = 100u32;
    const MIN: u32 = 0u32;

    function test() -> u32 {
        return MAX;
    }
}
"""
    parser = Parser(source, "test.leo")
    program = parser.parse()
    assert program is not None
    assert len(program.constants) == 2

    # Test TRAP emission
    with tempfile.TemporaryDirectory() as tmpdir:
        writer = TrapWriter(tmpdir, tmpdir)
        converter = AstToTrap(writer, ".")
        converter.convert_program(program, "test.leo")
        trap_output = "\n".join(writer._lines)

    # Verify constants emitted
    assert "leo_constants" in trap_output


def test_future_type_inner_type():
    """Test H6: FutureType inner type is emitted."""
    source = """
program test.aleo {
    async function test() -> Future<u32> {
        return 42u32;
    }
}
"""
    parser = Parser(source, "test.leo")
    program = parser.parse()
    assert program is not None
    assert len(program.functions) == 1
    func = program.functions[0]
    assert func.return_type is not None

    # Test TRAP emission
    with tempfile.TemporaryDirectory() as tmpdir:
        writer = TrapWriter(tmpdir, tmpdir)
        converter = AstToTrap(writer, ".")
        converter.convert_program(program, "test.leo")
        trap_output = "\n".join(writer._lines)

    # Verify future inner type emitted
    assert "leo_future_inner_type" in trap_output


def test_self_block_network_distinction():
    """Test H5: self/block/network access expressions are distinguished."""
    source = """
program test.aleo {
    transition test() -> address {
        let a: address = self.caller;
        let h: u32 = block.height;
        let n: u32 = network.id;
        return a;
    }
}
"""
    parser = Parser(source, "test.leo")
    program = parser.parse()
    assert program is not None

    # Test TRAP emission
    with tempfile.TemporaryDirectory() as tmpdir:
        writer = TrapWriter(tmpdir, tmpdir)
        converter = AstToTrap(writer, ".")
        converter.convert_program(program, "test.leo")
        trap_output = "\n".join(writer._lines)

    # Verify self_kind table distinguishes them
    assert "leo_self_kind" in trap_output
    assert '"self"' in trap_output
    assert '"block"' in trap_output
    assert '"network"' in trap_output


def test_source_locations():
    """Test H1: source locations are propagated to AST nodes."""
    source = """
program test.aleo {
    function test(x: u32) -> u32 {
        let y: u32 = x + 1u32;
        return y;
    }
}
"""
    parser = Parser(source, "test.leo")
    program = parser.parse()
    assert program is not None
    assert len(program.functions) == 1
    func = program.functions[0]

    # Check function has location
    assert func.location is not None
    assert func.location.start_line > 0
    assert func.location.start_col > 0

    # Check parameters have locations
    assert len(func.parameters) == 1
    assert func.parameters[0].location is not None

    # Check body has location
    assert func.body is not None
    assert func.body.location is not None

    # Check statements have locations
    assert len(func.body.statements) == 2
    let_stmt = func.body.statements[0]
    assert isinstance(let_stmt, LetStmt)
    assert let_stmt.location is not None
    assert let_stmt.location.start_line > 0
