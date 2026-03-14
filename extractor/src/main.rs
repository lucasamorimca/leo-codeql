/// CodeQL extractor for the Leo programming language.
///
/// Parses `.leo` files using the official `leo-parser` crate and emits
/// TRAP files matching the `leo.dbscheme` schema for CodeQL analysis.
mod ast_to_trap;
mod op_codes;
mod trap_writer;

use std::path::{Path, PathBuf};
use std::{env, fs, process};

use ast_to_trap::AstToTrap;
use leo_span::source_map::SourceMap;

fn main() {
    // Initialize leo_span session globals (symbol interner)
    leo_span::create_session_if_not_set_then(|_| run());
}

fn run() {
    let trap_folder = required_env("TRAP_FOLDER");
    let source_archive = required_env("SOURCE_ARCHIVE");
    let source_root = required_env("LGTM_SRC");

    let leo_files = discover_leo_files(Path::new(&source_root));
    if leo_files.is_empty() {
        eprintln!("No .leo files found in {source_root}");
        process::exit(1);
    }

    eprintln!("Found {} .leo file(s)", leo_files.len());

    for path in &leo_files {
        let relative = path
            .strip_prefix(&source_root)
            .unwrap_or(path)
            .to_string_lossy()
            .to_string();

        eprintln!("Extracting: {relative}");

        // Copy source to archive (skip if same path to avoid truncation)
        let archive_dest = Path::new(&source_archive).join(&relative);
        if archive_dest != *path {
            if let Some(parent) = archive_dest.parent() {
                let _ = fs::create_dir_all(parent);
            }
            let _ = fs::copy(path, &archive_dest);
        }

        match extract_file(path, &relative) {
            Ok(trap_content) => {
                let trap_path =
                    Path::new(&trap_folder).join(format!("{relative}.trap"));
                if let Some(parent) = trap_path.parent() {
                    let _ = fs::create_dir_all(parent);
                }
                if let Err(e) = fs::write(&trap_path, trap_content) {
                    eprintln!("  Error writing TRAP: {e}");
                } else {
                    eprintln!("  Wrote {}", trap_path.display());
                }
            }
            Err(e) => {
                eprintln!("  Parse error: {e}");
            }
        }
    }
}

/// Parse a single .leo file and return TRAP content.
fn extract_file(
    path: &Path,
    relative_path: &str,
) -> Result<String, String> {
    let source = fs::read_to_string(path)
        .map_err(|e| format!("Cannot read {}: {e}", path.display()))?;

    let handler = leo_errors::Handler::default();
    let node_builder = leo_ast::NodeBuilder::default();

    // Build SourceFile via SourceMap (SourceFile::new is private)
    let source_map = SourceMap::default();
    let file_name = leo_span::source_map::FileName::Custom(
        path.to_string_lossy().to_string(),
    );
    let sf = source_map.new_source(&source, file_name);

    let ast = leo_parser::parse_ast(
        handler,
        &node_builder,
        &sf,
        &[],
        leo_ast::NetworkName::MainnetV0,
    )
    .map_err(|e| format!("Parse failed: {e}"))?;

    // Derive program name from filename (e.g. "hello.leo" → "hello.aleo")
    let stem = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("unknown");
    let program_name = format!("{stem}.aleo");

    let mut converter = AstToTrap::new();

    // Walk all program scopes (usually one per file)
    for (_sym, scope) in &ast.ast.program_scopes {
        converter.convert_program(scope, &program_name, relative_path);
    }

    Ok(converter.writer.finish())
}

/// Recursively find all `.leo` files under a directory.
fn discover_leo_files(root: &Path) -> Vec<PathBuf> {
    let mut results = Vec::new();
    collect_leo_files(root, &mut results);
    results.sort();
    results
}

fn collect_leo_files(dir: &Path, out: &mut Vec<PathBuf>) {
    let entries = match fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return,
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            collect_leo_files(&path, out);
        } else if path.extension().is_some_and(|ext| ext == "leo") {
            out.push(path);
        }
    }
}

fn required_env(name: &str) -> String {
    env::var(name).unwrap_or_else(|_| {
        eprintln!("Error: {name} environment variable not set");
        process::exit(1);
    })
}
