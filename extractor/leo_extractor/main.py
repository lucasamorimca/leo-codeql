"""Main entry point for Leo CodeQL extractor.

Reads environment variables from CodeQL and extracts Leo source files
into TRAP format for database creation.
"""

import os
import sys
from pathlib import Path
from .parser import Parser
from .trap_writer import TrapWriter
from .ast_to_trap import AstToTrap


def find_leo_files(source_root: Path) -> list[Path]:
    """Find all .leo files in the source directory."""
    return list(source_root.rglob("*.leo"))


def extract_file(leo_file: Path, source_root: Path, writer: TrapWriter, converter: AstToTrap) -> None:
    """Extract a single Leo file to TRAP format.

    Args:
        leo_file: Path to Leo source file
        source_root: Root directory of source files
        writer: TRAP writer instance
        converter: AST to TRAP converter
    """
    print(f"Extracting: {leo_file}")

    # Read source file
    try:
        source_content = leo_file.read_text(encoding="utf-8")
    except Exception as e:
        print(f"Error reading {leo_file}: {e}", file=sys.stderr)
        raise

    # Get relative path from source root
    try:
        relative_path = str(leo_file.relative_to(source_root))
    except ValueError:
        # File is not under source_root, use absolute path
        relative_path = str(leo_file)

    # Parse source file
    parser = Parser(source_content, str(leo_file))
    ast = parser.parse()

    if ast is None:
        print(f"Error: Failed to parse {leo_file}", file=sys.stderr)
        raise ValueError(f"Parse error in {leo_file}")

    # Convert AST to TRAP
    converter.convert_program(ast, relative_path)

    # Copy source to archive
    writer.copy_source(relative_path, source_content)

    # Write TRAP file
    writer.write_trap_file(relative_path)


def main() -> int:
    """Main extractor entry point."""
    # Read environment variables set by CodeQL
    # Support both standard and CODEQL_EXTRACTOR_LEO_* prefixed variables
    trap_folder = (os.environ.get("TRAP_FOLDER") or
                   os.environ.get("CODEQL_EXTRACTOR_LEO_TRAP_DIR"))
    source_archive = (os.environ.get("SOURCE_ARCHIVE") or
                     os.environ.get("CODEQL_EXTRACTOR_LEO_SOURCE_ARCHIVE_DIR"))
    lgtm_src = (os.environ.get("LGTM_SRC") or
                os.environ.get("CODEQL_EXTRACTOR_LEO_SOURCE_ROOT"))

    if not trap_folder:
        print("Error: TRAP_FOLDER or CODEQL_EXTRACTOR_LEO_TRAP_DIR not set", file=sys.stderr)
        return 1

    if not lgtm_src:
        print("Error: LGTM_SRC or CODEQL_EXTRACTOR_LEO_SOURCE_ROOT not set", file=sys.stderr)
        return 1

    # Use source_archive if set, otherwise create default location
    if not source_archive:
        source_archive = os.path.join(trap_folder, "..", "src")

    trap_path = Path(trap_folder)
    source_root = Path(lgtm_src)
    archive_path = Path(source_archive)

    # Ensure directories exist
    trap_path.mkdir(parents=True, exist_ok=True)
    archive_path.mkdir(parents=True, exist_ok=True)

    print(f"Leo extractor starting...")
    print(f"Source root: {source_root}")
    print(f"TRAP folder: {trap_path}")
    print(f"Source archive: {archive_path}")

    # Find all Leo files
    leo_files = find_leo_files(source_root)

    if not leo_files:
        print("No Leo files found")
        return 0

    print(f"Found {len(leo_files)} Leo file(s)")

    # Extract each file
    errors = 0
    for leo_file in leo_files:
        try:
            # Create fresh writer for each file
            writer = TrapWriter(str(trap_path), str(archive_path))
            converter = AstToTrap(writer, str(source_root))

            # Emit source location prefix (empty for relative paths)
            writer.emit("sourceLocationPrefix", "")

            extract_file(leo_file, source_root, writer, converter)
        except Exception as e:
            print(f"Error extracting {leo_file}: {e}", file=sys.stderr)
            errors += 1
            # Continue processing other files instead of failing immediately

    if errors > 0:
        print(f"Extraction completed with {errors} error(s)", file=sys.stderr)
        return 1

    print("Extraction complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
