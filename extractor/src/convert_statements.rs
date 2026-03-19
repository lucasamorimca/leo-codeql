/// Converts Leo statements to TRAP tuples.
use leo_ast::{
    AssertStatement, AssertVariant, Block, ConditionalStatement, IterationStatement, Statement,
};

use crate::ast_to_trap::AstToTrap;
use crate::kind_constants::{assert_variant, stmt};
use crate::trap;
use crate::trap_writer::Label;

impl AstToTrap {
    // ── Blocks ──────────────────────────────────────────────────

    pub(crate) fn convert_block(&mut self, block: &Block, parent: Label, index: usize) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_stmts", label, stmt::BLOCK);
        self.emit_parent(label, parent, index);
        self.emit_location(label, block.span);

        for (i, stmt) in block.statements.iter().enumerate() {
            self.convert_statement(stmt, label, i);
        }
        label
    }

    // ── Statements ──────────────────────────────────────────────

    pub(crate) fn convert_statement(&mut self, stmt: &Statement, parent: Label, index: usize) {
        match stmt {
            Statement::Expression(expr_stmt) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_stmts", label, stmt::EXPR);
                self.emit_parent(label, parent, index);
                self.emit_location(label, expr_stmt.span);
                self.convert_expression(&expr_stmt.expression, label, 0);
            }
            Statement::Return(ret) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_stmts", label, stmt::RETURN);
                self.emit_parent(label, parent, index);
                self.emit_location(label, ret.span);
                self.convert_expression(&ret.expression, label, 0);
            }
            Statement::Definition(def) => {
                // DefinitionStatement covers both let and const.
                // We emit kind=2 (let) since Leo 3.x unifies them.
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_stmts", label, stmt::LET);
                self.emit_parent(label, parent, index);
                self.emit_location(label, def.span);

                let var_name = def.place.to_string();
                let type_label = if let Some(ref ty) = def.type_ {
                    self.convert_type(ty)
                } else {
                    self.make_unknown_type()
                };
                trap!(
                    self.writer,
                    "leo_variable_decls",
                    label,
                    var_name.as_str(),
                    type_label
                );
                self.convert_expression(&def.value, label, 0);
            }
            Statement::Const(const_decl) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_stmts", label, stmt::CONST);
                self.emit_parent(label, parent, index);
                self.emit_location(label, const_decl.span);

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
            }
            Statement::Assign(assign) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_stmts", label, stmt::ASSIGN);
                self.emit_parent(label, parent, index);
                self.emit_location(label, assign.span);

                // Leo 3.x only has plain assignment (=), no compound ops
                trap!(self.writer, "leo_assign_ops", label, 0_i32);

                let lhs = self.convert_expression(&assign.place, label, 0);
                trap!(self.writer, "leo_assign_lhs", label, lhs);

                let rhs = self.convert_expression(&assign.value, label, 1);
                trap!(self.writer, "leo_assign_rhs", label, rhs);
            }
            Statement::Conditional(cond) => {
                self.convert_conditional(cond, parent, index);
            }
            Statement::Iteration(iter) => {
                self.convert_iteration(iter, parent, index);
            }
            Statement::Block(block) => {
                self.convert_block(block, parent, index);
            }
            Statement::Assert(assert_stmt) => {
                self.convert_assert(assert_stmt, parent, index);
            }
        }
    }

    // ── Conditional ─────────────────────────────────────────────

    pub(crate) fn convert_conditional(
        &mut self,
        cond: &ConditionalStatement,
        parent: Label,
        index: usize,
    ) {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_stmts", label, stmt::IF);
        self.emit_parent(label, parent, index);
        self.emit_location(label, cond.span);

        let cond_label = self.convert_expression(&cond.condition, label, 0);
        trap!(self.writer, "leo_if_condition", label, cond_label);

        // Then block
        let then_label = self.convert_block(&cond.then, label, 1);
        trap!(self.writer, "leo_if_then", label, then_label);

        // Else branch
        if let Some(ref otherwise) = cond.otherwise {
            match otherwise.as_ref() {
                Statement::Block(block) => {
                    let else_label = self.convert_block(block, label, 2);
                    trap!(self.writer, "leo_if_else", label, else_label);
                }
                Statement::Conditional(else_if) => {
                    // Wrap else-if in a block for the QL model
                    let wrapper = self.writer.fresh_id();
                    trap!(self.writer, "leo_stmts", wrapper, stmt::BLOCK);
                    self.emit_parent(wrapper, label, 2);
                    self.convert_conditional(else_if, wrapper, 0);
                    trap!(self.writer, "leo_if_else", label, wrapper);
                }
                other => {
                    // Fallback: wrap arbitrary statement in block
                    let wrapper = self.writer.fresh_id();
                    trap!(self.writer, "leo_stmts", wrapper, stmt::BLOCK);
                    self.emit_parent(wrapper, label, 2);
                    self.convert_statement(other, wrapper, 0);
                    trap!(self.writer, "leo_if_else", label, wrapper);
                }
            }
        }
    }

    // ── Iteration ───────────────────────────────────────────────

    pub(crate) fn convert_iteration(
        &mut self,
        iter: &IterationStatement,
        parent: Label,
        index: usize,
    ) {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_stmts", label, stmt::FOR);
        self.emit_parent(label, parent, index);
        self.emit_location(label, iter.span);

        let var_name = iter.variable.to_string();
        trap!(self.writer, "leo_for_variable", label, var_name.as_str());

        let lower = self.convert_expression(&iter.start, label, 0);
        let upper = self.convert_expression(&iter.stop, label, 1);
        trap!(self.writer, "leo_for_range", label, lower, upper);

        // Body block
        let body_label = self.convert_block(&iter.block, label, 2);
        trap!(self.writer, "leo_for_body", label, body_label);
    }

    // ── Assert ──────────────────────────────────────────────────

    pub(crate) fn convert_assert(
        &mut self,
        assert_stmt: &AssertStatement,
        parent: Label,
        index: usize,
    ) {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_stmts", label, stmt::ASSERT);
        self.emit_parent(label, parent, index);
        self.emit_location(label, assert_stmt.span);

        match &assert_stmt.variant {
            AssertVariant::Assert(expr) => {
                trap!(
                    self.writer,
                    "leo_assert_variants",
                    label,
                    assert_variant::ASSERT
                );
                self.convert_expression(expr, label, 0);
            }
            AssertVariant::AssertEq(left, right) => {
                trap!(
                    self.writer,
                    "leo_assert_variants",
                    label,
                    assert_variant::ASSERT_EQ
                );
                self.convert_expression(left, label, 0);
                self.convert_expression(right, label, 1);
            }
            AssertVariant::AssertNeq(left, right) => {
                trap!(
                    self.writer,
                    "leo_assert_variants",
                    label,
                    assert_variant::ASSERT_NEQ
                );
                self.convert_expression(left, label, 0);
                self.convert_expression(right, label, 1);
            }
        }
    }
}
