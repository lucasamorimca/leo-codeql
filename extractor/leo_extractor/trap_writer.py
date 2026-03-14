"""TRAP file writer for Leo CodeQL extractor.

Handles entity ID generation, string escaping, and TRAP file writing.
"""

import os
from typing import Any


class TrapWriter:
    """TRAP file writer with entity ID management."""

    def __init__(self, trap_dir: str, source_archive_dir: str):
        """Initialize TRAP writer.

        Args:
            trap_dir: Directory to write TRAP files
            source_archive_dir: Directory for source archive
        """
        self.trap_dir = trap_dir
        self.source_archive_dir = source_archive_dir
        self._id_counter = 0
        self._label_map = {}  # maps AST node_id to TRAP label
        self._lines = []      # accumulated TRAP tuples

    def fresh_id(self) -> str:
        """Generate unique TRAP entity label like #1, #2, etc.

        Emits label definition (#N=*) to TRAP file.

        Returns:
            TRAP entity label (e.g., "#42")
        """
        self._id_counter += 1
        label = f"#{self._id_counter}"
        # Define the label in TRAP file
        self._lines.append(f"{label}=*")
        return label

    def get_or_create_label(self, node_id: int) -> str:
        """Get TRAP label for an AST node, creating if needed.

        Args:
            node_id: AST node ID

        Returns:
            TRAP entity label for this node
        """
        if node_id not in self._label_map:
            self._label_map[node_id] = self.fresh_id()
        return self._label_map[node_id]

    def emit(self, table_name: str, *values: Any) -> None:
        """Emit a TRAP tuple: table_name(val1, val2, ...).

        Args:
            table_name: Name of TRAP table
            *values: Column values (strings will be escaped and quoted)
        """
        escaped = []
        for v in values:
            if isinstance(v, str) and not v.startswith("#"):
                # Escape and quote strings (but not entity IDs)
                escaped.append(f'"{self._escape(v)}"')
            else:
                # Numbers, booleans, entity IDs
                escaped.append(str(v))
        self._lines.append(f"{table_name}({', '.join(escaped)})")

    def _escape(self, s: str) -> str:
        """Escape string for TRAP format.

        Args:
            s: String to escape

        Returns:
            Escaped string
        """
        return (s.replace('\\', '\\\\')
                 .replace('"', '\\"')
                 .replace('\n', '\\n')
                 .replace('\r', '\\r')
                 .replace('\t', '\\t'))

    def write_trap_file(self, source_path: str) -> None:
        """Write accumulated tuples to .trap file.

        Args:
            source_path: Relative path of source file
        """
        # TRAP file path mirrors source path under trap_dir
        trap_path = os.path.join(self.trap_dir, source_path + ".trap")
        os.makedirs(os.path.dirname(trap_path), exist_ok=True)
        with open(trap_path, "w", encoding="utf-8") as f:
            for line in self._lines:
                f.write(line + "\n")

    def copy_source(self, source_path: str, content: str) -> None:
        """Copy source to source archive.

        Args:
            source_path: Relative path of source file
            content: Source file content
        """
        archive_path = os.path.join(self.source_archive_dir, source_path)
        os.makedirs(os.path.dirname(archive_path), exist_ok=True)
        with open(archive_path, "w", encoding="utf-8") as f:
            f.write(content)
