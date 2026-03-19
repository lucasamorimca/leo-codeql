/// Main expression dispatcher that delegates to specific expression converters.
use leo_ast::{Expression, Node};

use crate::ast_to_trap::AstToTrap;
use crate::kind_constants::expr;
use crate::trap;
use crate::trap_writer::Label;

impl AstToTrap {
    // ── Main Expression Dispatcher ──────────────────────────────

    pub(crate) fn convert_expression(
        &mut self,
        expr: &Expression,
        parent: Label,
        index: usize,
    ) -> Label {
        let span = expr.span();
        let label = match expr {
            Expression::Literal(lit) => self.convert_literal(lit, parent, index),
            Expression::Path(path) => self.convert_path_expr(path, parent, index),
            Expression::Binary(bin) => self.convert_binary(bin, parent, index),
            Expression::Unary(unary) => self.convert_unary(unary, parent, index),
            Expression::Ternary(ternary) => self.convert_ternary(ternary, parent, index),
            Expression::Call(call) => self.convert_call(call, parent, index),
            Expression::MemberAccess(access) => self.convert_member_access(access, parent, index),
            Expression::ArrayAccess(access) => self.convert_array_access(access, parent, index),
            Expression::TupleAccess(access) => self.convert_tuple_access(access, parent, index),
            Expression::Cast(cast) => self.convert_cast(cast, parent, index),
            Expression::Composite(comp) => self.convert_composite_expr(comp, parent, index),
            Expression::Tuple(tuple) => self.convert_tuple_expr(tuple, parent, index),
            Expression::Unit(_) => self.convert_unit_expr(parent, index),
            Expression::Array(arr) => self.convert_array_expr(arr, parent, index),
            Expression::Repeat(rep) => self.convert_repeat_expr(rep, parent, index),
            Expression::Async(async_expr) => self.convert_async_expr(async_expr, parent, index),
            Expression::Intrinsic(intrinsic) => {
                self.convert_intrinsic_expr(intrinsic, parent, index)
            }
            Expression::Err(_) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_exprs", label, expr::BLOCK_EXPR);
                self.emit_parent(label, parent, index);
                label
            }
        };
        self.emit_location(label, span);
        label
    }
}
