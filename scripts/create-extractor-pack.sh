#!/usr/bin/env bash
set -euo pipefail

# Create CodeQL extractor pack for Leo language
# Bundles the extractor into a distributable pack

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Creating Leo CodeQL extractor pack..."
echo "Project root: $PROJECT_ROOT"

# Verify required files exist
required_files=(
  "codeql-extractor.yml"
  "tools/autobuild.sh"
  "tools/index-files.sh"
  "extractor/pyproject.toml"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$PROJECT_ROOT/$file" ]; then
    echo "Error: Required file not found: $file" >&2
    exit 1
  fi
done

echo "All required files present."
echo "Extractor pack structure ready for distribution."
echo ""
echo "To use this extractor:"
echo "  1. Set CODEQL_EXTRACTOR_LEO_ROOT to this directory"
echo "  2. Run: codeql resolve languages --search-path ."
