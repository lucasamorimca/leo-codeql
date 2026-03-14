/// Walks the `leo_ast` AST and emits TRAP tuples matching `leo.dbscheme`.
use std::collections::HashMap;

use leo_ast::{
    AssertStatement, AssertVariant, Block, BinaryExpression, CallExpression,
    CastExpression, Composite, CompositeExpression, ConditionalStatement,
    Expression, Function, IterationStatement, Literal, LiteralVariant, Mapping,
    MemberAccess, Mode, ProgramScope, Statement, TernaryExpression, Type,
    UnaryExpression, Variant,
};

use crate::op_codes::{binary_op_code, unary_op_code};
use crate::trap;
use crate::trap_writer::{Label, TrapWriter};

/// Converts a parsed Leo program into TRAP tuples.
pub struct AstToTrap {
    pub writer: TrapWriter,
    file_label: Option<Label>,
    type_cache: HashMap<String, Label>,
}

impl AstToTrap {
    pub fn new() -> Self {
        Self {
            writer: TrapWriter::new(),
            file_label: None,
            type_cache: HashMap::new(),
        }
    }

    /// Convert a full program scope to TRAP.
    pub fn convert_program(
        &mut self,
        scope: &ProgramScope,
        program_name: &str,
        source_path: &str,
    ) {
        self.emit_file_structure(source_path);
        self.emit_source_location_prefix();

        // Program entity
        let prog_label = self.writer.fresh_id();
        let (name, network) = if let Some(pos) = program_name.rfind('.') {
            (&program_name[..pos], &program_name[pos + 1..])
        } else {
            (program_name, "aleo")
        };
        trap!(self.writer, "leo_programs", prog_label, name, network);

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
    }

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

    fn emit_location(&mut self, node_label: Label, span: &leo_span::Span) {
        let Some(file_label) = self.file_label else {
            return;
        };
        let loc_label = self.writer.fresh_id();
        // leo_ast::Span has lo/hi as byte offsets. We use 0-based line/col
        // placeholder since Span doesn't carry line/col directly.
        // CodeQL expects 1-based line/col. We'll emit (1,1,1,1) as fallback.
        trap!(
            self.writer,
            "locations_default",
            loc_label,
            file_label,
            1_i32,
            1_i32,
            1_i32,
            1_i32
        );
        trap!(self.writer, "leo_ast_node_location", node_label, loc_label);
    }

    fn emit_parent(&mut self, child: Label, parent: Label, index: usize) {
        trap!(self.writer, "leo_ast_node_parent", child, parent, index);
    }

    // ── Composites (structs & records) ──────────────────────────

    fn convert_composite(
        &mut self,
        composite: &Composite,
        prog_label: Label,
        index: usize,
    ) {
        let label = self.writer.fresh_id();
        let name = composite.identifier.to_string();
        let is_record: i32 = if composite.is_record { 1 } else { 0 };
        trap!(
            self.writer,
            "leo_struct_declarations",
            label,
            name.as_str(),
            is_record,
            prog_label
        );
        self.emit_parent(label, prog_label, index);

        for (i, member) in composite.members.iter().enumerate() {
            let field_label = self.writer.fresh_id();
            let field_name = member.identifier.to_string();
            let type_label = self.convert_type(&member.type_);
            let visibility = mode_to_visibility(&member.mode);
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
        }
    }

    // ── Mappings ────────────────────────────────────────────────

    fn convert_mapping(
        &mut self,
        mapping: &Mapping,
        prog_label: Label,
        index: usize,
    ) {
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
    }

    // ── Functions ───────────────────────────────────────────────

    fn convert_function(
        &mut self,
        func: &Function,
        prog_label: Label,
        index: usize,
    ) {
        let label = self.writer.fresh_id();
        let name = func.identifier.to_string();

        // Map variant to dbscheme kind:
        // function=0, transition=1, inline=2, finalize(async_function)=3
        let kind: i32 = match func.variant {
            Variant::Function => 0,
            Variant::Transition | Variant::AsyncTransition => 1,
            Variant::Inline | Variant::Script => 2,
            Variant::AsyncFunction => 3,
        };

        let is_async: i32 =
            if func.variant.is_async() { 1 } else { 0 };

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

        // Parameters
        for (i, input) in func.input.iter().enumerate() {
            let param_label = self.writer.fresh_id();
            let param_name = input.identifier.to_string();
            let type_label = self.convert_type(&input.type_);
            let visibility = mode_to_visibility(&input.mode);
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
        }

        // Return type
        let ret_label = self.convert_type(&func.output_type);
        trap!(self.writer, "leo_return_types", label, ret_label);

        // Body
        self.convert_block(&func.block, label, 0);
    }

    // ── Statements ──────────────────────────────────────────────

    fn convert_block(&mut self, block: &Block, parent: Label, index: usize) {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_stmts", label, 7_i32); // kind=7 block
        self.emit_parent(label, parent, index);

        for (i, stmt) in block.statements.iter().enumerate() {
            self.convert_statement(stmt, label, i);
        }
    }

    fn convert_statement(
        &mut self,
        stmt: &Statement,
        parent: Label,
        index: usize,
    ) {
        match stmt {
            Statement::Expression(expr_stmt) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_stmts", label, 0_i32);
                self.emit_parent(label, parent, index);
                self.convert_expression(&expr_stmt.expression, label, 0);
            }
            Statement::Return(ret) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_stmts", label, 1_i32);
                self.emit_parent(label, parent, index);
                self.convert_expression(&ret.expression, label, 0);
            }
            Statement::Definition(def) => {
                // DefinitionStatement covers both let and const.
                // We emit kind=2 (let) since Leo 3.x unifies them.
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_stmts", label, 2_i32);
                self.emit_parent(label, parent, index);

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
                trap!(self.writer, "leo_stmts", label, 3_i32);
                self.emit_parent(label, parent, index);

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
                trap!(self.writer, "leo_stmts", label, 4_i32);
                self.emit_parent(label, parent, index);

                // Leo 3.x only has plain assignment (=), no compound ops
                trap!(self.writer, "leo_assign_ops", label, 1_i32);

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

    fn convert_conditional(
        &mut self,
        cond: &ConditionalStatement,
        parent: Label,
        index: usize,
    ) {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_stmts", label, 5_i32); // kind=5 if
        self.emit_parent(label, parent, index);

        let cond_label = self.convert_expression(&cond.condition, label, 0);
        trap!(self.writer, "leo_if_condition", label, cond_label);

        // Then block
        let then_label = self.writer.fresh_id();
        trap!(self.writer, "leo_stmts", then_label, 7_i32);
        self.emit_parent(then_label, label, 1);
        for (i, stmt) in cond.then.statements.iter().enumerate() {
            self.convert_statement(stmt, then_label, i);
        }
        trap!(self.writer, "leo_if_then", label, then_label);

        // Else branch
        if let Some(ref otherwise) = cond.otherwise {
            match otherwise.as_ref() {
                Statement::Block(block) => {
                    let else_label = self.writer.fresh_id();
                    trap!(self.writer, "leo_stmts", else_label, 7_i32);
                    self.emit_parent(else_label, label, 2);
                    for (i, stmt) in block.statements.iter().enumerate() {
                        self.convert_statement(stmt, else_label, i);
                    }
                    trap!(self.writer, "leo_if_else", label, else_label);
                }
                Statement::Conditional(else_if) => {
                    // Wrap else-if in a block for the QL model
                    let wrapper = self.writer.fresh_id();
                    trap!(self.writer, "leo_stmts", wrapper, 7_i32);
                    self.emit_parent(wrapper, label, 2);
                    self.convert_conditional(else_if, wrapper, 0);
                    trap!(self.writer, "leo_if_else", label, wrapper);
                }
                other => {
                    // Fallback: wrap arbitrary statement in block
                    let wrapper = self.writer.fresh_id();
                    trap!(self.writer, "leo_stmts", wrapper, 7_i32);
                    self.emit_parent(wrapper, label, 2);
                    self.convert_statement(other, wrapper, 0);
                    trap!(self.writer, "leo_if_else", label, wrapper);
                }
            }
        }
    }

    fn convert_iteration(
        &mut self,
        iter: &IterationStatement,
        parent: Label,
        index: usize,
    ) {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_stmts", label, 6_i32); // kind=6 for
        self.emit_parent(label, parent, index);

        let var_name = iter.variable.to_string();
        trap!(self.writer, "leo_for_variable", label, var_name.as_str());

        let lower = self.convert_expression(&iter.start, label, 0);
        let upper = self.convert_expression(&iter.stop, label, 1);
        trap!(self.writer, "leo_for_range", label, lower, upper);

        // Body block
        let body_label = self.writer.fresh_id();
        trap!(self.writer, "leo_stmts", body_label, 7_i32);
        self.emit_parent(body_label, label, 2);
        for (i, stmt) in iter.block.statements.iter().enumerate() {
            self.convert_statement(stmt, body_label, i);
        }
        trap!(self.writer, "leo_for_body", label, body_label);
    }

    fn convert_assert(
        &mut self,
        assert_stmt: &AssertStatement,
        parent: Label,
        index: usize,
    ) {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_stmts", label, 8_i32); // kind=8 assert
        self.emit_parent(label, parent, index);

        match &assert_stmt.variant {
            AssertVariant::Assert(expr) => {
                self.convert_expression(expr, label, 0);
            }
            AssertVariant::AssertEq(left, right)
            | AssertVariant::AssertNeq(left, right) => {
                self.convert_expression(left, label, 0);
                self.convert_expression(right, label, 1);
            }
        }
    }

    // ── Expressions ─────────────────────────────────────────────

    fn convert_expression(
        &mut self,
        expr: &Expression,
        parent: Label,
        index: usize,
    ) -> Label {
        match expr {
            Expression::Literal(lit) => {
                self.convert_literal(lit, parent, index)
            }
            Expression::Path(path) => {
                // Simple variable reference or qualified path
                let label = self.writer.fresh_id();
                let segments: Vec<String> =
                    path.segments_iter().map(|s| s.to_string()).collect();

                if segments.len() == 1 {
                    // Simple variable reference
                    trap!(self.writer, "leo_exprs", label, 1_i32);
                    trap!(
                        self.writer,
                        "leo_variable_refs",
                        label,
                        segments[0].as_str()
                    );
                } else if segments.len() == 2 {
                    // Could be Type::method — associated function call
                    trap!(self.writer, "leo_exprs", label, 14_i32);
                    let full_name = segments.join("::");
                    trap!(
                        self.writer,
                        "leo_variable_refs",
                        label,
                        full_name.as_str()
                    );
                } else {
                    // Longer path
                    trap!(self.writer, "leo_exprs", label, 14_i32);
                    let full_name = segments.join("::");
                    trap!(
                        self.writer,
                        "leo_variable_refs",
                        label,
                        full_name.as_str()
                    );
                }
                self.emit_parent(label, parent, index);
                label
            }
            Expression::Binary(bin) => {
                self.convert_binary(bin, parent, index)
            }
            Expression::Unary(unary) => {
                self.convert_unary(unary, parent, index)
            }
            Expression::Ternary(ternary) => {
                self.convert_ternary(ternary, parent, index)
            }
            Expression::Call(call) => {
                self.convert_call(call, parent, index)
            }
            Expression::MemberAccess(access) => {
                self.convert_member_access(access, parent, index)
            }
            Expression::ArrayAccess(access) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_exprs", label, 8_i32);
                self.emit_parent(label, parent, index);
                self.convert_expression(&access.array, label, 0);
                self.convert_expression(&access.index, label, 1);
                label
            }
            Expression::TupleAccess(access) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_exprs", label, 9_i32);
                self.emit_parent(label, parent, index);
                self.convert_expression(&access.tuple, label, 0);
                label
            }
            Expression::Cast(cast) => {
                self.convert_cast(cast, parent, index)
            }
            Expression::Composite(comp) => {
                self.convert_composite_expr(comp, parent, index)
            }
            Expression::Tuple(tuple) => {
                // Emit as block expression containing children
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_exprs", label, 13_i32);
                self.emit_parent(label, parent, index);
                for (i, elem) in tuple.elements.iter().enumerate() {
                    self.convert_expression(elem, label, i);
                }
                label
            }
            Expression::Unit(_) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_exprs", label, 0_i32);
                trap!(
                    self.writer,
                    "leo_literal_values",
                    label,
                    "()",
                    "unit"
                );
                self.emit_parent(label, parent, index);
                label
            }
            Expression::Array(arr) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_exprs", label, 13_i32);
                self.emit_parent(label, parent, index);
                for (i, elem) in arr.elements.iter().enumerate() {
                    self.convert_expression(elem, label, i);
                }
                label
            }
            Expression::Repeat(rep) => {
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_exprs", label, 13_i32);
                self.emit_parent(label, parent, index);
                self.convert_expression(&rep.expr, label, 0);
                self.convert_expression(&rep.count, label, 1);
                label
            }
            Expression::Async(async_expr) => {
                // Async expression contains a block of async operations
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_exprs", label, 13_i32);
                self.emit_parent(label, parent, index);
                for (i, stmt) in
                    async_expr.block.statements.iter().enumerate()
                {
                    self.convert_statement(stmt, label, i);
                }
                label
            }
            Expression::Intrinsic(intrinsic) => {
                // Treat intrinsics as method calls
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_exprs", label, 6_i32);
                self.emit_parent(label, parent, index);
                let method_name = intrinsic.name.to_string();
                trap!(
                    self.writer,
                    "leo_call_targets",
                    label,
                    method_name.as_str()
                );
                for (i, arg) in intrinsic.arguments.iter().enumerate() {
                    let arg_label =
                        self.convert_expression(arg, label, i);
                    trap!(
                        self.writer,
                        "leo_call_args",
                        label,
                        arg_label,
                        i
                    );
                }
                label
            }
            Expression::Err(_) => {
                // Error recovery node — emit as unknown expr
                let label = self.writer.fresh_id();
                trap!(self.writer, "leo_exprs", label, 13_i32);
                self.emit_parent(label, parent, index);
                label
            }
        }
    }

    fn convert_literal(
        &mut self,
        lit: &Literal,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, 0_i32);
        self.emit_parent(label, parent, index);

        let (value, type_suffix) = match &lit.variant {
            LiteralVariant::Boolean(b) => {
                (b.to_string(), "bool".to_string())
            }
            LiteralVariant::Field(v) => (v.to_string(), "field".to_string()),
            LiteralVariant::Group(v) => (v.to_string(), "group".to_string()),
            LiteralVariant::Scalar(v) => {
                (v.to_string(), "scalar".to_string())
            }
            LiteralVariant::Integer(int_type, v) => {
                (v.to_string(), int_type.to_string())
            }
            LiteralVariant::Address(v) => {
                (v.to_string(), "address".to_string())
            }
            LiteralVariant::String(v) => {
                (v.to_string(), "string".to_string())
            }
            LiteralVariant::Signature(v) => {
                (v.to_string(), "signature".to_string())
            }
            _ => (lit.to_string(), String::new()),
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

    fn convert_binary(
        &mut self,
        bin: &BinaryExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, 2_i32);
        self.emit_parent(label, parent, index);

        let op_code = binary_op_code(bin.op);
        trap!(self.writer, "leo_binary_ops", label, op_code);

        let lhs = self.convert_expression(&bin.left, label, 0);
        trap!(self.writer, "leo_binary_lhs", label, lhs);

        let rhs = self.convert_expression(&bin.right, label, 1);
        trap!(self.writer, "leo_binary_rhs", label, rhs);

        label
    }

    fn convert_unary(
        &mut self,
        unary: &UnaryExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, 3_i32);
        self.emit_parent(label, parent, index);

        let op_code = unary_op_code(unary.op);
        trap!(self.writer, "leo_unary_ops", label, op_code);

        let operand = self.convert_expression(&unary.receiver, label, 0);
        trap!(self.writer, "leo_unary_operand", label, operand);

        label
    }

    fn convert_ternary(
        &mut self,
        ternary: &TernaryExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, 4_i32);
        self.emit_parent(label, parent, index);

        let cond =
            self.convert_expression(&ternary.condition, label, 0);
        trap!(self.writer, "leo_ternary_condition", label, cond);

        let then =
            self.convert_expression(&ternary.if_true, label, 1);
        trap!(self.writer, "leo_ternary_then", label, then);

        let else_ =
            self.convert_expression(&ternary.if_false, label, 2);
        trap!(self.writer, "leo_ternary_else", label, else_);

        label
    }

    fn convert_call(
        &mut self,
        call: &CallExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();

        // Determine if this is a regular call or associated function call
        let segments: Vec<String> =
            call.function.segments_iter().map(|s| s.to_string()).collect();

        if segments.len() >= 2 {
            // Associated function call: Type::method(args)
            trap!(self.writer, "leo_exprs", label, 15_i32);
            let func_name = segments.last().unwrap().as_str();
            trap!(
                self.writer,
                "leo_call_targets",
                label,
                func_name
            );
        } else {
            // Regular function call
            trap!(self.writer, "leo_exprs", label, 5_i32);
            let func_name = segments
                .first()
                .map(|s| s.as_str())
                .unwrap_or("unknown");
            trap!(
                self.writer,
                "leo_call_targets",
                label,
                func_name
            );
        }

        self.emit_parent(label, parent, index);

        for (i, arg) in call.arguments.iter().enumerate() {
            let arg_label = self.convert_expression(arg, label, i);
            trap!(self.writer, "leo_call_args", label, arg_label, i);
        }

        label
    }

    fn convert_member_access(
        &mut self,
        access: &MemberAccess,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, 7_i32);
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

    fn convert_cast(
        &mut self,
        cast: &CastExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, 10_i32);
        self.emit_parent(label, parent, index);

        let type_label = self.convert_type(&cast.type_);
        trap!(self.writer, "leo_cast_type", label, type_label);

        self.convert_expression(&cast.expression, label, 0);

        label
    }

    fn convert_composite_expr(
        &mut self,
        comp: &CompositeExpression,
        parent: Label,
        index: usize,
    ) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_exprs", label, 11_i32);
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
                trap!(self.writer, "leo_exprs", var_label, 1_i32);
                trap!(
                    self.writer,
                    "leo_variable_refs",
                    var_label,
                    field_name.as_str()
                );
                self.emit_parent(var_label, label, i);
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

    // ── Types ───────────────────────────────────────────────────

    fn convert_type(&mut self, ty: &Type) -> Label {
        let (kind, name) = type_to_kind_name(ty);
        let cache_key = format!("{kind}:{name}");

        // Cache primitive types (kind < 17)
        if kind < 17 {
            if let Some(&cached) = self.type_cache.get(&cache_key) {
                return cached;
            }
        }

        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_types", label, kind, name.as_str());

        if kind < 17 {
            self.type_cache.insert(cache_key, label);
        }

        // Array element type
        if let Type::Array(arr) = ty {
            let elem_label = self.convert_type(&arr.element_type);
            // length is an Expression; emit its string form as the size
            let size_str = arr.length.to_string();
            let size: i32 =
                size_str.parse().unwrap_or(0);
            trap!(
                self.writer,
                "leo_array_types",
                label,
                elem_label,
                size
            );
        }

        // Tuple element types
        if let Type::Tuple(tup) = ty {
            for (i, elem) in tup.elements.iter().enumerate() {
                let elem_label = self.convert_type(elem);
                trap!(
                    self.writer,
                    "leo_tuple_type_elements",
                    label,
                    elem_label,
                    i
                );
            }
        }

        label
    }

    fn make_unknown_type(&mut self) -> Label {
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_types", label, 19_i32, "unknown");
        label
    }
}

/// Map Mode to visibility integer: private=0, public=1, constant=2.
fn mode_to_visibility(mode: &Mode) -> i32 {
    match mode {
        Mode::None | Mode::Private => 0,
        Mode::Public => 1,
        Mode::Constant => 2,
    }
}

/// Map a `Type` to (kind, name) for the dbscheme.
fn type_to_kind_name(ty: &Type) -> (i32, String) {
    match ty {
        Type::Boolean => (0, "bool".into()),
        Type::Integer(int_ty) => {
            let s = int_ty.to_string();
            let kind = match s.as_str() {
                "u8" => 1,
                "u16" => 2,
                "u32" => 3,
                "u64" => 4,
                "u128" => 5,
                "i8" => 6,
                "i16" => 7,
                "i32" => 8,
                "i64" => 9,
                "i128" => 10,
                _ => 3, // fallback u32
            };
            (kind, s)
        }
        Type::Field => (11, "field".into()),
        Type::Group => (12, "group".into()),
        Type::Scalar => (13, "scalar".into()),
        Type::Address => (14, "address".into()),
        Type::Signature => (15, "signature".into()),
        Type::String => (16, "string".into()),
        Type::Array(_) => (17, "array".into()),
        Type::Tuple(_) => (18, "tuple".into()),
        Type::Composite(c) => (19, c.path.to_string()),
        Type::Identifier(id) => (19, id.to_string()),
        Type::Future(_) => (20, "future".into()),
        Type::Unit => (21, "unit".into()),
        Type::Mapping(_) => (19, "mapping".into()),
        _ => (19, "unknown".into()),
    }
}
