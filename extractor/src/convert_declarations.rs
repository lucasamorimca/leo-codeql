/// Converts composite types (structs, records), mappings, and functions to TRAP tuples.
use leo_ast::{Composite, Function, Mapping, Variant};

use crate::ast_to_trap::AstToTrap;
use crate::kind_constants::func;
use crate::trap;
use crate::trap_writer::Label;

impl AstToTrap {
    // ── Composites (structs & records) ──────────────────────────

    pub(crate) fn convert_composite(
        &mut self,
        composite: &Composite,
        prog_label: Label,
        index: usize,
    ) {
        let label = self.writer.fresh_id();
        let name = composite.identifier.to_string();
        let is_record: i32 = i32::from(composite.is_record);
        trap!(
            self.writer,
            "leo_struct_declarations",
            label,
            name.as_str(),
            is_record,
            prog_label
        );
        self.emit_parent(label, prog_label, index);
        self.emit_location(label, composite.span);

        for (i, member) in composite.members.iter().enumerate() {
            let field_label = self.writer.fresh_id();
            let field_name = member.identifier.to_string();
            let type_label = self.convert_type(&member.type_);
            let visibility = mode_to_visibility(member.mode);
            trap!(
                self.writer,
                "leo_struct_fields",
                field_label,
                field_name.as_str(),
                type_label,
                visibility,
                label,
                i
            );
            self.emit_parent(field_label, label, i);
            self.emit_location(field_label, member.span);
        }
    }

    // ── Mappings ────────────────────────────────────────────────

    pub(crate) fn convert_mapping(&mut self, mapping: &Mapping, prog_label: Label, index: usize) {
        let label = self.writer.fresh_id();
        let name = mapping.identifier.to_string();
        let key_label = self.convert_type(&mapping.key_type);
        let val_label = self.convert_type(&mapping.value_type);
        trap!(
            self.writer,
            "leo_mappings",
            label,
            name.as_str(),
            key_label,
            val_label,
            prog_label
        );
        self.emit_parent(label, prog_label, index);
        self.emit_location(label, mapping.span);
    }

    // ── Functions ───────────────────────────────────────────────

    pub(crate) fn convert_function(&mut self, func: &Function, prog_label: Label, index: usize) {
        let label = self.writer.fresh_id();
        let name = func.identifier.to_string();

        let kind: i32 = match func.variant {
            Variant::Function => func::FUNCTION,
            Variant::Transition | Variant::AsyncTransition => func::TRANSITION,
            Variant::Inline | Variant::Script => func::INLINE,
            Variant::AsyncFunction => func::FINALIZE,
        };

        let is_async: i32 = i32::from(func.variant.is_async());

        trap!(
            self.writer,
            "leo_functions",
            label,
            name.as_str(),
            kind,
            is_async,
            prog_label
        );
        self.emit_parent(label, prog_label, index);
        self.emit_location(label, func.span);

        // Parameters
        for (i, input) in func.input.iter().enumerate() {
            let param_label = self.writer.fresh_id();
            let param_name = input.identifier.to_string();
            let type_label = self.convert_type(&input.type_);
            let visibility = mode_to_visibility(input.mode);
            trap!(
                self.writer,
                "leo_parameters",
                param_label,
                param_name.as_str(),
                type_label,
                visibility,
                label,
                i
            );
            self.emit_parent(param_label, label, i);
            self.emit_location(param_label, input.span);
        }

        // Return type
        let ret_label = self.convert_type(&func.output_type);
        trap!(self.writer, "leo_return_types", label, ret_label);

        // Body
        self.convert_block(&func.block, label, 0);
    }
}

/// Map Mode to visibility integer: private=0, public=1, constant=2.
fn mode_to_visibility(mode: leo_ast::Mode) -> i32 {
    match mode {
        leo_ast::Mode::None | leo_ast::Mode::Private => 0,
        leo_ast::Mode::Public => 1,
        leo_ast::Mode::Constant => 2,
    }
}
