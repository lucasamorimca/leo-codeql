/// `TRAP` file writer for `CodeQL` database import.
///
/// Emits tab-separated tuples with entity label definitions
/// matching the `leo.dbscheme` schema.
use std::fmt::Write as FmtWrite;

pub struct TrapWriter {
    buffer: String,
    next_id: u32,
}

impl Default for TrapWriter {
    fn default() -> Self {
        Self::new()
    }
}

impl TrapWriter {
    #[must_use]
    pub fn new() -> Self {
        Self {
            buffer: String::with_capacity(64 * 1024),
            next_id: 1,
        }
    }

    /// Allocate a fresh entity label like `#1`, `#2`, etc.
    ///
    /// # Panics
    ///
    /// Panics if label count exceeds `u32::MAX`.
    #[allow(clippy::expect_used)]
    pub fn fresh_id(&mut self) -> Label {
        let id = self.next_id;
        self.next_id = self
            .next_id
            .checked_add(1)
            .expect("TRAP label overflow: exceeded u32::MAX entities");
        let label = Label(id);
        // Emit label definition
        let _ = writeln!(self.buffer, "{label}=*");
        label
    }

    /// Emit a tuple with the given table name and columns.
    pub fn emit(&mut self, table: &str, columns: &[Value]) {
        self.buffer.push_str(table);
        self.buffer.push('(');
        for (i, col) in columns.iter().enumerate() {
            if i > 0 {
                self.buffer.push_str(", ");
            }
            match col {
                Value::Label(label) => {
                    let _ = write!(self.buffer, "{label}");
                }
                Value::Int(n) => {
                    let _ = write!(self.buffer, "{n}");
                }
                Value::Str(s) => {
                    self.buffer.push('"');
                    // Escape all characters that could corrupt TRAP format
                    for ch in s.chars() {
                        match ch {
                            '"' => self.buffer.push_str("\\\""),
                            '\\' => self.buffer.push_str("\\\\"),
                            '\n' => self.buffer.push_str("\\n"),
                            '\r' => self.buffer.push_str("\\r"),
                            '\t' => self.buffer.push_str("\\t"),
                            '\0' => self.buffer.push_str("\\0"),
                            '\x08' => self.buffer.push_str("\\b"),
                            '\x0C' => self.buffer.push_str("\\f"),
                            c if c.is_control() => {
                                let _ = write!(self.buffer, "\\u{:04x}", c as u32);
                            }
                            c => self.buffer.push(c),
                        }
                    }
                    self.buffer.push('"');
                }
            }
        }
        self.buffer.push_str(")\n");
    }

    /// Return the accumulated TRAP content.
    #[must_use]
    pub fn finish(self) -> String {
        self.buffer
    }
}

/// A TRAP entity label (`#N`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Label(pub u32);

impl std::fmt::Display for Label {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "#{}", self.0)
    }
}

/// A TRAP column value.
pub enum Value {
    Label(Label),
    Int(i64),
    Str(String),
}

// Convenience conversions
impl From<Label> for Value {
    fn from(l: Label) -> Self {
        Value::Label(l)
    }
}

impl From<i64> for Value {
    fn from(n: i64) -> Self {
        Value::Int(n)
    }
}

impl From<i32> for Value {
    fn from(n: i32) -> Self {
        Value::Int(i64::from(n))
    }
}

impl From<u32> for Value {
    fn from(n: u32) -> Self {
        Value::Int(i64::from(n))
    }
}

impl From<usize> for Value {
    fn from(n: usize) -> Self {
        #[allow(clippy::cast_possible_wrap)]
        let val = n as i64;
        Value::Int(val)
    }
}

impl From<&str> for Value {
    fn from(s: &str) -> Self {
        Value::Str(s.to_string())
    }
}

impl From<String> for Value {
    fn from(s: String) -> Self {
        Value::Str(s)
    }
}

/// Helper macro to emit a TRAP tuple concisely.
#[macro_export]
macro_rules! trap {
    ($writer:expr, $table:expr, $($col:expr),+ $(,)?) => {
        $writer.emit($table, &[$($crate::trap_writer::Value::from($col)),+])
    };
}
