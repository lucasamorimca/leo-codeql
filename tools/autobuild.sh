#!/usr/bin/env bash
set -euo pipefail

# CodeQL autobuild script for Leo language
# Invoked by CodeQL during database creation

# Environment variables provided by CodeQL:
# - TRAP_FOLDER: where to write .trap files
# - SOURCE_ARCHIVE: where to write source archive
# - LGTM_SRC: source root directory

echo "Leo extractor autobuild starting..."

# Get the extractor directory (parent of tools/)
EXTRACTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Check for environment variables with both naming conventions
TRAP_FOLDER="${TRAP_FOLDER:-${CODEQL_EXTRACTOR_LEO_TRAP_DIR:-}}"
SOURCE_ARCHIVE="${SOURCE_ARCHIVE:-${CODEQL_EXTRACTOR_LEO_SOURCE_ARCHIVE_DIR:-}}"

# LGTM_SRC should be the current working directory (where autobuild is run = source root)
LGTM_SRC="${LGTM_SRC:-$(pwd)}"

# Validate required environment variables
if [ -z "$TRAP_FOLDER" ]; then
    echo "Error: TRAP_FOLDER not set. Set TRAP_FOLDER or CODEQL_EXTRACTOR_LEO_TRAP_DIR."
    exit 1
fi
if [ -z "$SOURCE_ARCHIVE" ]; then
    echo "Error: SOURCE_ARCHIVE not set. Set SOURCE_ARCHIVE or CODEQL_EXTRACTOR_LEO_SOURCE_ARCHIVE_DIR."
    exit 1
fi

echo "TRAP_FOLDER: $TRAP_FOLDER"
echo "SOURCE_ARCHIVE: $SOURCE_ARCHIVE"
echo "LGTM_SRC: $LGTM_SRC"
echo "Current directory: $(pwd)"

# Run the Rust extractor binary
# Check for pre-built binary first, then fallback to cargo build location
BINARY="${EXTRACTOR_DIR}/tools/leo-extractor"
if [ ! -x "${BINARY}" ]; then
    BINARY="${EXTRACTOR_DIR}/extractor/target/release/leo-extractor"
fi

if [ ! -f "$BINARY" ]; then
    echo "Release binary not found, building..."
    (cd "$EXTRACTOR_DIR/extractor" && cargo build --release)
    BINARY="${EXTRACTOR_DIR}/extractor/target/release/leo-extractor"
fi

# Verify binary exists and is executable
if [ ! -x "$BINARY" ]; then
    echo "Error: Extractor binary not found or not executable at $BINARY"
    echo "Ensure Rust toolchain is installed: https://rustup.rs/"
    exit 1
fi

export TRAP_FOLDER
export SOURCE_ARCHIVE
export LGTM_SRC
"$BINARY"

echo "Leo extractor autobuild completed."
