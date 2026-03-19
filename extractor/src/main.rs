/// `CodeQL` extractor for the Leo programming language.
///
/// Parses `.leo` files using the official `leo-parser` crate and emits
/// `TRAP` files matching the `leo.dbscheme` schema for `CodeQL` analysis.
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::{env, fs, process};

use leo_extractor::ast_to_trap::AstToTrap;
use leo_span::source_map::SourceMap;

fn main() {
    // Initialize tracing subscriber
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .with_writer(std::io::stderr)
        .init();

    // Initialize leo_span session globals (symbol interner)
    leo_span::create_session_if_not_set_then(|_| run());
}

fn run() {
    let trap_folder = required_env("TRAP_FOLDER");
    let source_archive = required_env("SOURCE_ARCHIVE");
    let source_root = required_env("LGTM_SRC");

    let leo_files = discover_leo_files(Path::new(&source_root));
    if leo_files.is_empty() {
        tracing::error!(root = %source_root, "no .leo files found");
        // Exit with error code when no Leo files found - extractor cannot proceed
        #[allow(clippy::exit)]
        process::exit(1);
    }

    tracing::info!(count = leo_files.len(), "found .leo files");

    for path in &leo_files {
        let relative = path
            .strip_prefix(&source_root)
            .unwrap_or(path)
            .to_string_lossy()
            .to_string();

        tracing::info!(%relative, "extracting file");

        // Copy source to archive (skip if same path to avoid truncation)
        let archive_dest = Path::new(&source_archive).join(&relative);
        if archive_dest != *path {
            if let Some(parent) = archive_dest.parent() {
                if let Err(e) = fs::create_dir_all(parent) {
                    tracing::warn!(dir = %parent.display(), error = %e, "cannot create archive dir");
                }
            }
            if let Err(e) = fs::copy(path, &archive_dest) {
                tracing::warn!(error = %e, "cannot copy source to archive");
            }
        }

        match extract_file(path, &relative) {
            Ok(trap_content) => {
                let trap_path = Path::new(&trap_folder).join(format!("{relative}.trap"));
                if let Some(parent) = trap_path.parent() {
                    if let Err(e) = fs::create_dir_all(parent) {
                        tracing::warn!(dir = %parent.display(), error = %e, "cannot create TRAP dir");
                    }
                }
                if let Err(e) = fs::write(&trap_path, trap_content) {
                    tracing::error!(error = %e, "error writing TRAP file");
                } else {
                    tracing::debug!(path = %trap_path.display(), "wrote TRAP file");
                }
            }
            Err(e) => {
                tracing::error!(error = %e, "parse error");
            }
        }
    }
}

/// Parse a single .leo file and return TRAP content.
fn extract_file(path: &Path, relative_path: &str) -> Result<String, String> {
    let source =
        fs::read_to_string(path).map_err(|e| format!("Cannot read {}: {e}", path.display()))?;

    let handler = leo_errors::Handler::default();
    let node_builder = leo_ast::NodeBuilder::default();

    // Build SourceFile via SourceMap (SourceFile::new is private)
    let source_map = SourceMap::default();
    let file_name = leo_span::source_map::FileName::Custom(path.to_string_lossy().to_string());
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

    let mut converter = AstToTrap::new(&source);

    // Walk all program scopes (usually one per file)
    // Attach imports to the first scope since they're file-level
    let mut first_prog_label = None;
    for (_sym, scope) in &ast.ast.program_scopes {
        let label = converter.convert_program(scope, &program_name, relative_path);
        if first_prog_label.is_none() {
            first_prog_label = Some(label);
        }
    }

    // Extract imports (lives on Program, not ProgramScope)
    if let Some(label) = first_prog_label {
        converter.convert_imports(&ast.ast.imports, label);
    }

    Ok(converter.finish())
}

/// Recursively find all `.leo` files under a directory.
fn discover_leo_files(root: &Path) -> Vec<PathBuf> {
    let mut results = Vec::new();
    let mut visited = HashSet::new();
    collect_leo_files(root, &mut results, &mut visited);
    results.sort();
    results
}

fn collect_leo_files(dir: &Path, out: &mut Vec<PathBuf>, visited: &mut HashSet<PathBuf>) {
    // Resolve symlinks to canonical path for cycle detection
    let canonical = match fs::canonicalize(dir) {
        Ok(p) => p,
        Err(e) => {
            tracing::warn!(dir = %dir.display(), error = %e, "cannot resolve path");
            return;
        }
    };
    if !visited.insert(canonical) {
        return; // Already visited — symlink cycle
    }

    let entries = match fs::read_dir(dir) {
        Ok(e) => e,
        Err(e) => {
            tracing::warn!(dir = %dir.display(), error = %e, "cannot read directory");
            return;
        }
    };
    for entry in entries.filter_map(|e| match e {
        Ok(entry) => Some(entry),
        Err(err) => {
            tracing::warn!(error = %err, "cannot read directory entry");
            None
        }
    }) {
        let path = entry.path();
        if path.is_dir() {
            collect_leo_files(&path, out, visited);
        } else if path.extension().is_some_and(|ext| ext == "leo") {
            out.push(path);
        }
    }
}

fn required_env(name: &str) -> String {
    env::var(name).unwrap_or_else(|_| {
        tracing::error!(var = name, "environment variable not set");
        // Exit with error code when required env var missing - extractor cannot proceed
        #[allow(clippy::exit)]
        process::exit(1);
    })
}
