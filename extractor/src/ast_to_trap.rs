/// Walks the `leo_ast` AST and emits TRAP tuples matching `leo.dbscheme`.
use std::collections::HashMap;

use leo_ast::ProgramScope;
use leo_span::Span;

use crate::kind_constants::{func, stmt};
use crate::trap;
use crate::trap_writer::{Label, TrapWriter};

/// Converts a parsed Leo program into TRAP tuples.
pub struct AstToTrap {
    pub(crate) writer: TrapWriter,
    pub(crate) file_label: Option<Label>,
    pub(crate) type_cache: HashMap<String, Label>,
    pub(crate) line_offsets: Vec<u32>,
}

impl AstToTrap {
    #[must_use]
    pub fn new(source: &str) -> Self {
        let mut line_offsets = vec![0u32];
        for (i, byte) in source.as_bytes().iter().enumerate() {
            if *byte == b'\n' {
                #[allow(clippy::cast_possible_truncation)]
                let offset = (i + 1) as u32;
                line_offsets.push(offset);
            }
        }
        Self {
            writer: TrapWriter::new(),
            file_label: None,
            type_cache: HashMap::new(),
            line_offsets,
        }
    }

    /// Convert a full program scope to TRAP. Returns the program label.
    pub fn convert_program(
        &mut self,
        scope: &ProgramScope,
        program_name: &str,
        source_path: &str,
    ) -> Label {
        // Only emit file structure once per file
        if self.file_label.is_none() {
            self.emit_file_structure(source_path);
            self.emit_source_location_prefix();
        }

        // Program entity
        let prog_label = self.writer.fresh_id();
        let (name, network) = if let Some(pos) = program_name.rfind('.') {
            (&program_name[..pos], &program_name[pos + 1..])
        } else {
            (program_name, "aleo")
        };
        trap!(self.writer, "leo_programs", prog_label, name, network);
        self.emit_location(prog_label, scope.span);

        // Composites (structs + records)
        let mut child_idx: usize = 0;
        for (_sym, composite) in &scope.composites {
            self.convert_composite(composite, prog_label, child_idx);
            child_idx += 1;
        }

        // Mappings
        for (_sym, mapping) in &scope.mappings {
            self.convert_mapping(mapping, prog_label, child_idx);
            child_idx += 1;
        }

        // Functions
        for (_sym, func) in &scope.functions {
            self.convert_function(func, prog_label, child_idx);
            child_idx += 1;
        }

        // Program-level const declarations
        for (_sym, const_decl) in &scope.consts {
            let label = self.writer.fresh_id();
            trap!(self.writer, "leo_stmts", label, stmt::CONST);
            self.emit_parent(label, prog_label, child_idx);
            let var_name = const_decl.place.to_string();
            let type_label = self.convert_type(&const_decl.type_);
            trap!(
                self.writer,
                "leo_variable_decls",
                label,
                var_name.as_str(),
                type_label
            );
            self.convert_expression(&const_decl.value, label, 0);
            self.emit_location(label, const_decl.span);
            child_idx += 1;
        }

        // Storage variables
        for (_sym, storage_var) in &scope.storage_variables {
            let label = self.writer.fresh_id();
            trap!(self.writer, "leo_stmts", label, stmt::STORAGE);
            self.emit_parent(label, prog_label, child_idx);
            let var_name = storage_var.identifier.to_string();
            let type_label = self.convert_type(&storage_var.type_);
            trap!(
                self.writer,
                "leo_variable_decls",
                label,
                var_name.as_str(),
                type_label
            );
            self.emit_location(label, storage_var.span);
            child_idx += 1;
        }

        // Constructor
        if let Some(ref ctor) = scope.constructor {
            let label = self.writer.fresh_id();
            trap!(
                self.writer,
                "leo_functions",
                label,
                "constructor",
                func::CONSTRUCTOR,
                0_i32,
                prog_label
            );
            self.emit_parent(label, prog_label, child_idx);
            self.convert_block(&ctor.block, label, 0);
            self.emit_location(label, ctor.span);
        }

        prog_label
    }

    /// Emit import declarations as `leo_imports` tuples.
    pub fn convert_imports(
        &mut self,
        imports: &indexmap::IndexMap<leo_span::Symbol, Span>,
        prog_label: Label,
    ) {
        for (idx, (sym, span)) in imports.iter().enumerate() {
            let label = self.writer.fresh_id();
            let program_id = sym.to_string();
            trap!(
                self.writer,
                "leo_imports",
                label,
                program_id.as_str(),
                prog_label
            );
            self.emit_parent(label, prog_label, idx);
            self.emit_location(label, *span);
        }
    }

    // ── File and Location Helpers ───────────────────────────────

    fn emit_file_structure(&mut self, source_path: &str) {
        let file_label = self.writer.fresh_id();
        trap!(self.writer, "files", file_label, source_path);

        let folder_label = self.writer.fresh_id();
        trap!(self.writer, "folders", folder_label, "");
        trap!(self.writer, "containerparent", folder_label, file_label);

        self.file_label = Some(file_label);
    }

    fn emit_source_location_prefix(&mut self) {
        trap!(self.writer, "sourceLocationPrefix", "");
    }

    fn byte_offset_to_line_col(&self, offset: u32) -> (i32, i32) {
        // Binary search to find which line this offset belongs to
        let line_index = match self.line_offsets.binary_search(&offset) {
            Ok(idx) => idx,
            Err(idx) => idx.saturating_sub(1),
        };
        let line_start = self.line_offsets[line_index];
        let col = offset - line_start;
        // Return 1-based line and column
        #[allow(clippy::cast_possible_truncation, clippy::cast_possible_wrap)]
        let line = (line_index + 1) as i32;
        #[allow(clippy::cast_possible_wrap)]
        let column = (col + 1).cast_signed();
        (line, column)
    }

    pub(crate) fn emit_location(&mut self, node_label: Label, span: leo_span::Span) {
        let Some(file_label) = self.file_label else {
            return;
        };
        let loc_label = self.writer.fresh_id();
        let (start_line, start_col) = self.byte_offset_to_line_col(span.lo);
        let end_offset = if span.hi > span.lo {
            span.hi - 1
        } else {
            span.lo
        };
        let (end_line, end_col) = self.byte_offset_to_line_col(end_offset);
        trap!(
            self.writer,
            "locations_default",
            loc_label,
            file_label,
            start_line,
            start_col,
            end_line,
            end_col
        );
        trap!(self.writer, "leo_ast_node_location", node_label, loc_label);
    }

    pub(crate) fn emit_parent(&mut self, child: Label, parent: Label, index: usize) {
        trap!(self.writer, "leo_ast_node_parent", child, parent, index);
    }

    /// Consume the converter and return the final TRAP output.
    #[must_use]
    pub fn finish(self) -> String {
        self.writer.finish()
    }
}
