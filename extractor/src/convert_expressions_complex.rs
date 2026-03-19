/// Converts complex Leo expressions (binary, calls, casts, composites) to TRAP tuples.
use leo_ast::{
    BinaryExpression, CallExpression, CastExpression, CompositeExpression, MemberAccess,
    TernaryExpression, UnaryExpression,
};

use crate::ast_to_trap::AstToTrap;
use crate::kind_constants::expr;
use crate::op_codes::{binary_op_code, unary_op_code};
use crate::trap;
use crate::trap_writer::Label;

impl AstToTrap {
    // ── Binary, Unary, Ternary ──────────────────────────────────

    pub(crate) fn convert_binary(
        &mut self,
        bin: &BinaryExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::BINARY);
        self.emit_parent(label, parent, index);

        let op_code = binary_op_code(bin.op);
        trap!(self.writer, "leo_binary_ops", label, op_code);

        let lhs = self.convert_expression(&bin.left, label, 0);
        trap!(self.writer, "leo_binary_lhs", label, lhs);

        let rhs = self.convert_expression(&bin.right, label, 1);
        trap!(self.writer, "leo_binary_rhs", label, rhs);

        label
    }

    pub(crate) fn convert_unary(
        &mut self,
        unary: &UnaryExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::UNARY);
        self.emit_parent(label, parent, index);

        let op_code = unary_op_code(unary.op);
        trap!(self.writer, "leo_unary_ops", label, op_code);

        let operand = self.convert_expression(&unary.receiver, label, 0);
        trap!(self.writer, "leo_unary_operand", label, operand);

        label
    }

    pub(crate) fn convert_ternary(
        &mut self,
        ternary: &TernaryExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::TERNARY);
        self.emit_parent(label, parent, index);

        let cond = self.convert_expression(&ternary.condition, label, 0);
        trap!(self.writer, "leo_ternary_condition", label, cond);

        let then = self.convert_expression(&ternary.if_true, label, 1);
        trap!(self.writer, "leo_ternary_then", label, then);

        let else_ = self.convert_expression(&ternary.if_false, label, 2);
        trap!(self.writer, "leo_ternary_else", label, else_);

        label
    }

    // ── Calls ───────────────────────────────────────────────────

    pub(crate) fn convert_call(
        &mut self,
        call: &CallExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();

        // Determine if this is a regular call or associated function call
        let segments: Vec<String> = call
            .function
            .segments_iter()
            .map(|s| s.to_string())
            .collect();

        if segments.len() >= 2 {
            // Associated function call: Type::method(args)
            trap!(self.writer, "leo_exprs", label, expr::ASSOCIATED_FN_CALL);
            let func_name = segments.last().map_or("unknown", String::as_str);
            trap!(self.writer, "leo_call_targets", label, func_name);
        } else {
            // Regular function call
            trap!(self.writer, "leo_exprs", label, expr::CALL);
            let func_name = segments.first().map_or("unknown", String::as_str);
            trap!(self.writer, "leo_call_targets", label, func_name);
        }

        self.emit_parent(label, parent, index);

        for (i, arg) in call.arguments.iter().enumerate() {
            let arg_label = self.convert_expression(arg, label, i);
            trap!(self.writer, "leo_call_args", label, arg_label, i);
        }

        label
    }

    // ── Member Access ───────────────────────────────────────────

    pub(crate) fn convert_member_access(
        &mut self,
        access: &MemberAccess,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::FIELD_ACCESS);
        self.emit_parent(label, parent, index);

        let field_name = access.name.to_string();
        trap!(
            self.writer,
            "leo_field_access_name",
            label,
            field_name.as_str()
        );

        let base = self.convert_expression(&access.inner, label, 0);
        trap!(self.writer, "leo_field_access_base", label, base);

        label
    }

    // ── Cast ────────────────────────────────────────────────────

    pub(crate) fn convert_cast(
        &mut self,
        cast: &CastExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::CAST);
        self.emit_parent(label, parent, index);

        let type_label = self.convert_type(&cast.type_);
        trap!(self.writer, "leo_cast_type", label, type_label);

        self.convert_expression(&cast.expression, label, 0);

        label
    }

    // ── Composite Expressions ───────────────────────────────────

    pub(crate) fn convert_composite_expr(
        &mut self,
        comp: &CompositeExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::STRUCT_INIT);
        self.emit_parent(label, parent, index);

        let struct_name = comp.path.to_string();
        trap!(
            self.writer,
            "leo_struct_init_name",
            label,
            struct_name.as_str()
        );

        for (i, field) in comp.members.iter().enumerate() {
            let field_name = field.identifier.to_string();
            // If expression is None, use the identifier as a variable ref
            let value = if let Some(ref expr) = field.expression {
                self.convert_expression(expr, label, i)
            } else {
                // Shorthand: `Foo { bar }` means `Foo { bar: bar }`
                let var_label = self.writer.fresh_id();
                trap!(self.writer, "leo_exprs", var_label, expr::VARIABLE);
                trap!(
                    self.writer,
                    "leo_variable_refs",
                    var_label,
                    field_name.as_str()
                );
                self.emit_parent(var_label, label, i);
                self.emit_location(var_label, field.span);
                var_label
            };
            trap!(
                self.writer,
                "leo_struct_init_fields",
                label,
                field_name.as_str(),
                value,
                i
            );
        }

        label
    }
}
