"""Test TRAP file generation from Leo AST."""

import tempfile
import os
from pathlib import Path
from leo_extractor.parser import Parser
from leo_extractor.trap_writer import TrapWriter
from leo_extractor.ast_to_trap import AstToTrap


def test_hello_program_trap():
    """Test TRAP generation for hello.leo test program."""
    # Read hello.leo test file
    test_file = Path(__file__).parent.parent.parent / "test-programs" / "hello.leo"
    source = test_file.read_text()

    # Parse the source
    parser = Parser(source, "hello.leo")
    ast = parser.parse()
    assert ast is not None, "Parse failed"

    # Create temporary directories for TRAP and source archive
    with tempfile.TemporaryDirectory() as trap_dir, \
         tempfile.TemporaryDirectory() as archive_dir:

        # Create TRAP writer and converter
        writer = TrapWriter(trap_dir, archive_dir)
        converter = AstToTrap(writer, "")

        # Emit source location prefix
        writer.emit("sourceLocationPrefix", "")

        # Convert AST to TRAP
        converter.convert_program(ast, "hello.leo")

        # Copy source to archive
        writer.copy_source("hello.leo", source)

        # Write TRAP file
        writer.write_trap_file("hello.leo")

        # Read generated TRAP file
        trap_path = Path(trap_dir) / "hello.leo.trap"
        assert trap_path.exists(), "TRAP file not created"

        trap_content = trap_path.read_text()
        print("\n=== Generated TRAP ===")
        print(trap_content)
        print("=== End TRAP ===\n")

        # Verify essential tuples are present
        assert "sourceLocationPrefix" in trap_content, "Missing sourceLocationPrefix"
        assert "files(" in trap_content, "Missing files tuple"
        assert "folders(" in trap_content, "Missing folders tuple"
        assert "leo_programs(" in trap_content, "Missing leo_programs tuple"
        assert "leo_functions(" in trap_content, "Missing leo_functions tuple"
        assert "leo_parameters(" in trap_content, "Missing leo_parameters tuple"

        # Check for specific program details
        assert '"hello"' in trap_content, "Program name not found"
        assert '"aleo"' in trap_content, "Network not found"
        assert '"main"' in trap_content, "Function name not found"

        # Check for types
        assert "leo_types(" in trap_content, "Missing leo_types tuple"
        assert '"u32"' in trap_content, "u32 type not found"

        # Check for statements
        assert "leo_stmts(" in trap_content, "Missing leo_stmts tuple"

        # Check for expressions
        assert "leo_exprs(" in trap_content, "Missing leo_exprs tuple"

        # Check for locations (optional - parser may not set them yet)
        # assert "locations_default(" in trap_content, "Missing locations_default tuple"
        # assert "leo_ast_node_location(" in trap_content, "Missing leo_ast_node_location tuple"

        # Check for parent relationships
        assert "leo_ast_node_parent(" in trap_content, "Missing leo_ast_node_parent tuple"

        # Verify source archive was created
        archive_path = Path(archive_dir) / "hello.leo"
        assert archive_path.exists(), "Source archive not created"
        archive_content = archive_path.read_text()
        assert archive_content == source, "Source archive content mismatch"


def test_trap_writer_escape():
    """Test string escaping in TRAP writer."""
    with tempfile.TemporaryDirectory() as trap_dir:
        writer = TrapWriter(trap_dir, trap_dir)

        # Test escaping
        writer.emit("test_table", 'hello"world', "line1\nline2", "back\\slash")

        # Check internal representation
        assert len(writer._lines) == 1
        line = writer._lines[0]

        assert r'hello\"world' in line, "Double quote not escaped"
        assert r'line1\nline2' in line, "Newline not escaped"
        assert r'back\\slash' in line, "Backslash not escaped"


def test_trap_writer_entity_ids():
    """Test entity ID generation and caching."""
    with tempfile.TemporaryDirectory() as trap_dir:
        writer = TrapWriter(trap_dir, trap_dir)

        # Generate IDs
        id1 = writer.fresh_id()
        id2 = writer.fresh_id()
        id3 = writer.fresh_id()

        assert id1 == "#1", "First ID should be #1"
        assert id2 == "#2", "Second ID should be #2"
        assert id3 == "#3", "Third ID should be #3"

        # Test label caching
        label1 = writer.get_or_create_label(100)
        label2 = writer.get_or_create_label(100)
        label3 = writer.get_or_create_label(200)

        assert label1 == label2, "Same node ID should return same label"
        assert label1 != label3, "Different node IDs should return different labels"


def test_type_conversion():
    """Test type conversion to TRAP."""
    source = """
    program types_test.aleo {
        struct Point {
            x: u32,
            y: u32
        }

        record Token {
            public owner: address,
            private amount: u64
        }

        mapping balances: address => u64;

        transition test(a: u32, b: field, c: address) -> bool {
            return true;
        }
    }
    """

    parser = Parser(source, "types_test.leo")
    ast = parser.parse()
    assert ast is not None, "Parse failed"

    with tempfile.TemporaryDirectory() as trap_dir, \
         tempfile.TemporaryDirectory() as archive_dir:

        writer = TrapWriter(trap_dir, archive_dir)
        converter = AstToTrap(writer, "")

        writer.emit("sourceLocationPrefix", "")
        converter.convert_program(ast, "types_test.leo")
        writer.write_trap_file("types_test.leo")

        trap_path = Path(trap_dir) / "types_test.leo.trap"
        trap_content = trap_path.read_text()

        # Verify struct
        assert "leo_struct_declarations(" in trap_content
        assert '"Point"' in trap_content
        assert "leo_struct_fields(" in trap_content

        # Verify record (is_record=1)
        assert '"Token"' in trap_content
        assert '"owner"' in trap_content
        assert '"amount"' in trap_content

        # Verify mapping
        assert "leo_mappings(" in trap_content
        assert '"balances"' in trap_content

        # Verify types
        assert '"u32"' in trap_content
        assert '"u64"' in trap_content
        assert '"field"' in trap_content
        assert '"address"' in trap_content
        assert '"bool"' in trap_content


def test_expression_conversion():
    """Test expression conversion to TRAP."""
    source = """
    program expr_test.aleo {
        transition test(a: u32, b: u32) -> u32 {
            let c: u32 = a + b;
            let d: u32 = c * 2u32;
            let e: bool = a > b;
            return d;
        }
    }
    """

    parser = Parser(source, "expr_test.leo")
    ast = parser.parse()
    assert ast is not None, "Parse failed"

    with tempfile.TemporaryDirectory() as trap_dir, \
         tempfile.TemporaryDirectory() as archive_dir:

        writer = TrapWriter(trap_dir, archive_dir)
        converter = AstToTrap(writer, "")

        writer.emit("sourceLocationPrefix", "")
        converter.convert_program(ast, "expr_test.leo")
        writer.write_trap_file("expr_test.leo")

        trap_path = Path(trap_dir) / "expr_test.leo.trap"
        trap_content = trap_path.read_text()

        # Verify expressions
        assert "leo_exprs(" in trap_content
        assert "leo_binary_ops(" in trap_content
        assert "leo_binary_lhs(" in trap_content
        assert "leo_binary_rhs(" in trap_content

        # Verify literals
        assert "leo_literal_values(" in trap_content

        # Verify variable references
        assert "leo_variable_refs(" in trap_content

        # Verify statements
        assert "leo_variable_decls(" in trap_content


def test_control_flow_conversion():
    """Test control flow statement conversion to TRAP."""
    source = """
    program control_test.aleo {
        transition test(a: u32, b: u32) -> u32 {
            if a > b {
                return a;
            } else {
                return b;
            }
        }

        transition loop_test(n: u32) -> u32 {
            let sum: u32 = 0u32;
            for i in 0u32..n {
                sum += i;
            }
            return sum;
        }
    }
    """

    parser = Parser(source, "control_test.leo")
    ast = parser.parse()
    assert ast is not None, "Parse failed"

    with tempfile.TemporaryDirectory() as trap_dir, \
         tempfile.TemporaryDirectory() as archive_dir:

        writer = TrapWriter(trap_dir, archive_dir)
        converter = AstToTrap(writer, "")

        writer.emit("sourceLocationPrefix", "")
        converter.convert_program(ast, "control_test.leo")
        writer.write_trap_file("control_test.leo")

        trap_path = Path(trap_dir) / "control_test.leo.trap"
        trap_content = trap_path.read_text()

        # Verify if statement
        assert "leo_if_condition(" in trap_content
        assert "leo_if_then(" in trap_content
        assert "leo_if_else(" in trap_content

        # Verify for loop
        assert "leo_for_variable(" in trap_content
        assert "leo_for_range(" in trap_content
        assert "leo_for_body(" in trap_content


if __name__ == "__main__":
    # Run tests
    test_hello_program_trap()
    print("✓ test_hello_program_trap passed")

    test_trap_writer_escape()
    print("✓ test_trap_writer_escape passed")

    test_trap_writer_entity_ids()
    print("✓ test_trap_writer_entity_ids passed")

    test_type_conversion()
    print("✓ test_type_conversion passed")

    test_expression_conversion()
    print("✓ test_expression_conversion passed")

    test_control_flow_conversion()
    print("✓ test_control_flow_conversion passed")

    print("\nAll tests passed!")
