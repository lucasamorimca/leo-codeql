/// Converts Leo types to TRAP tuples.
use leo_ast::Type;

use crate::ast_to_trap::AstToTrap;
use crate::kind_constants::type_kind;
use crate::trap;
use crate::trap_writer::Label;

impl AstToTrap {
    // ── Type Conversion ─────────────────────────────────────────

    pub(crate) fn convert_type(&mut self, ty: &Type) -> Label {
        let (kind, name) = type_to_kind_name(ty);
        let cache_key = format!("{kind}:{name}");

        // Cache primitive types (kind < ARRAY)
        if kind < type_kind::ARRAY {
            if let Some(&cached) = self.type_cache.get(&cache_key) {
                return cached;
            }
        }

        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_types", label, kind, name.as_str());

        if kind < type_kind::ARRAY {
            self.type_cache.insert(cache_key, label);
        }

        // Array element type
        if let Type::Array(arr) = ty {
            let elem_label = self.convert_type(&arr.element_type);
            // length is an Expression; emit its string form as the size
            let size_str = arr.length.to_string();
            let size: i32 = size_str.parse().unwrap_or_else(|_| {
                tracing::warn!(size = %size_str, "non-literal array size, using -1");
                -1
            });
            trap!(self.writer, "leo_array_types", label, elem_label, size);
        }

        // Tuple element types
        if let Type::Tuple(tup) = ty {
            for (i, elem) in tup.elements.iter().enumerate() {
                let elem_label = self.convert_type(elem);
                trap!(self.writer, "leo_tuple_type_elements", label, elem_label, i);
            }
        }

        // Optional inner type
        if let Type::Optional(opt) = ty {
            let inner_label = self.convert_type(&opt.inner);
            trap!(self.writer, "leo_optional_inner_type", label, inner_label);
        }

        // Vector element type
        if let Type::Vector(vec) = ty {
            let elem_label = self.convert_type(&vec.element_type);
            trap!(self.writer, "leo_vector_element_type", label, elem_label);
        }

        // Future input types
        if let Type::Future(fut) = ty {
            for (i, input_ty) in fut.inputs.iter().enumerate() {
                let input_label = self.convert_type(input_ty);
                trap!(self.writer, "leo_future_input_types", label, input_label, i);
            }
        }

        // Mapping key and value types
        if let Type::Mapping(map) = ty {
            let key_label = self.convert_type(&map.key);
            let val_label = self.convert_type(&map.value);
            trap!(
                self.writer,
                "leo_mapping_key_value_types",
                label,
                key_label,
                val_label
            );
        }

        label
    }

    pub(crate) fn make_unknown_type(&mut self) -> Label {
        let cache_key = format!("{}:error", type_kind::ERROR);
        if let Some(&cached) = self.type_cache.get(&cache_key) {
            return cached;
        }
        let label = self.writer.fresh_id();
        trap!(self.writer, "leo_types", label, type_kind::ERROR, "error");
        self.type_cache.insert(cache_key, label);
        label
    }
}

/// Map a `Type` to (kind, name) for the dbscheme.
fn type_to_kind_name(ty: &Type) -> (i32, String) {
    match ty {
        Type::Boolean => (type_kind::BOOL, "bool".into()),
        Type::Integer(int_ty) => {
            let s = int_ty.to_string();
            let kind = match s.as_str() {
                "u8" => type_kind::U8,
                "u16" => type_kind::U16,
                "u32" => type_kind::U32,
                "u64" => type_kind::U64,
                "u128" => type_kind::U128,
                "i8" => type_kind::I8,
                "i16" => type_kind::I16,
                "i32" => type_kind::I32,
                "i64" => type_kind::I64,
                "i128" => type_kind::I128,
                other => {
                    tracing::warn!(int_type = ?other, "unknown integer type, emitting as error type");
                    type_kind::ERROR
                }
            };
            (kind, s)
        }
        Type::Field => (type_kind::FIELD, "field".into()),
        Type::Group => (type_kind::GROUP, "group".into()),
        Type::Scalar => (type_kind::SCALAR, "scalar".into()),
        Type::Address => (type_kind::ADDRESS, "address".into()),
        Type::Signature => (type_kind::SIGNATURE, "signature".into()),
        Type::String => (type_kind::STRING, "string".into()),
        Type::Array(_) => (type_kind::ARRAY, "array".into()),
        Type::Tuple(_) => (type_kind::TUPLE, "tuple".into()),
        Type::Composite(c) => (type_kind::COMPOSITE, c.path.to_string()),
        Type::Identifier(id) => (type_kind::COMPOSITE, id.to_string()),
        Type::Future(_) => (type_kind::FUTURE, "future".into()),
        Type::Unit => (type_kind::UNIT, "unit".into()),
        Type::Mapping(_) => (type_kind::MAPPING, "mapping".into()),
        Type::Optional(_) => (type_kind::OPTIONAL, "optional".into()),
        Type::Vector(_) => (type_kind::VECTOR, "vector".into()),
        Type::Numeric => (type_kind::NUMERIC, "numeric".into()),
        Type::Err => (type_kind::ERROR, "error".into()),
    }
}
