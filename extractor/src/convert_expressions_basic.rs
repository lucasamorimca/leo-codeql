/// Converts basic Leo expressions (literals, paths, arrays, tuples) to TRAP tuples.
use leo_ast::{Literal, LiteralVariant};

use crate::ast_to_trap::AstToTrap;
use crate::kind_constants::expr;
use crate::trap;
use crate::trap_writer::Label;

impl AstToTrap {
    // ── Literals ────────────────────────────────────────────────

    pub(crate) fn convert_literal(&mut self, lit: &Literal, parent: Label, index: usize) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::LITERAL);
        self.emit_parent(label, parent, index);

        let (value, type_suffix) = match &lit.variant {
            LiteralVariant::Boolean(b) => (b.to_string(), "bool".to_string()),
            LiteralVariant::Field(v) => (v.clone(), "field".to_string()),
            LiteralVariant::Group(v) => (v.clone(), "group".to_string()),
            LiteralVariant::Scalar(v) => (v.clone(), "scalar".to_string()),
            LiteralVariant::Integer(int_type, v) => (v.clone(), int_type.to_string()),
            LiteralVariant::Address(v) => (v.clone(), "address".to_string()),
            LiteralVariant::String(v) => (v.clone(), "string".to_string()),
            LiteralVariant::Signature(v) => (v.clone(), "signature".to_string()),
            LiteralVariant::None => ("none".to_string(), "optional".to_string()),
            LiteralVariant::Unsuffixed(v) => (v.clone(), "unsuffixed".to_string()),
        };

        trap!(
            self.writer,
            "leo_literal_values",
            label,
            value.as_str(),
            type_suffix.as_str()
        );
        label
    }

    // ── Paths and Variables ─────────────────────────────────────

    pub(crate) fn convert_path_expr(
        &mut self,
        path: &leo_ast::Path,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        let segments: Vec<String> = path.segments_iter().map(|s| s.to_string()).collect();

        if segments.len() == 1 && segments[0] == "self" {
            trap!(self.writer, "leo_exprs", label, expr::SELF_EXPR);
        } else if segments.len() == 1 {
            trap!(self.writer, "leo_exprs", label, expr::VARIABLE);
            trap!(
                self.writer,
                "leo_variable_refs",
                label,
                segments[0].as_str()
            );
        } else {
            // 2+ segments: associated const (Type::CONST or longer path)
            trap!(self.writer, "leo_exprs", label, expr::ASSOCIATED_CONST);
            let full_name = segments.join("::");
            trap!(self.writer, "leo_variable_refs", label, full_name.as_str());
        }
        self.emit_parent(label, parent, index);
        label
    }

    // ── Array, Tuple, Unit ──────────────────────────────────────

    pub(crate) fn convert_array_access(
        &mut self,
        access: &leo_ast::ArrayAccess,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::INDEX_ACCESS);
        self.emit_parent(label, parent, index);
        self.convert_expression(&access.array, label, 0);
        self.convert_expression(&access.index, label, 1);
        label
    }

    pub(crate) fn convert_tuple_access(
        &mut self,
        access: &leo_ast::TupleAccess,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::TUPLE_ACCESS);
        self.emit_parent(label, parent, index);
        self.convert_expression(&access.tuple, label, 0);
        let index_str = access.index.to_string();
        let tuple_idx: i32 = index_str.parse().unwrap_or_else(|_| {
            tracing::warn!(index = %index_str, "failed to parse tuple index, using 0");
            0
        });
        trap!(self.writer, "leo_tuple_access_index", label, tuple_idx);
        label
    }

    pub(crate) fn convert_tuple_expr(
        &mut self,
        tuple: &leo_ast::TupleExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::TUPLE);
        self.emit_parent(label, parent, index);
        for (i, elem) in tuple.elements.iter().enumerate() {
            self.convert_expression(elem, label, i);
        }
        label
    }

    pub(crate) fn convert_unit_expr(&mut self, parent: Label, index: usize) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::LITERAL);
        trap!(self.writer, "leo_literal_values", label, "()", "unit");
        self.emit_parent(label, parent, index);
        label
    }

    pub(crate) fn convert_array_expr(
        &mut self,
        arr: &leo_ast::ArrayExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::ARRAY);
        self.emit_parent(label, parent, index);
        for (i, elem) in arr.elements.iter().enumerate() {
            self.convert_expression(elem, label, i);
        }
        label
    }

    pub(crate) fn convert_repeat_expr(
        &mut self,
        rep: &leo_ast::RepeatExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::REPEAT);
        self.emit_parent(label, parent, index);
        self.convert_expression(&rep.expr, label, 0);
        self.convert_expression(&rep.count, label, 1);
        label
    }

    // ── Async and Intrinsic ─────────────────────────────────────

    pub(crate) fn convert_async_expr(
        &mut self,
        async_expr: &leo_ast::AsyncExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::ASYNC);
        self.emit_parent(label, parent, index);
        for (i, stmt) in async_expr.block.statements.iter().enumerate() {
            self.convert_statement(stmt, label, i);
        }
        label
    }

    pub(crate) fn convert_intrinsic_expr(
        &mut self,
        intrinsic: &leo_ast::IntrinsicExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, expr::METHOD_CALL);
        self.emit_parent(label, parent, index);
        let method_name = intrinsic.name.to_string();
        trap!(self.writer, "leo_call_targets", label, method_name.as_str());
        for (i, arg) in intrinsic.arguments.iter().enumerate() {
            let arg_label = self.convert_expression(arg, label, i);
            trap!(self.writer, "leo_call_args", label, arg_label, i);
        }
        label
    }
}
