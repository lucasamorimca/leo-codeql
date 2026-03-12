#!/usr/bin/env bash
set -euo pipefail

# Index all Leo source files
# Finds .leo files in the source directory

if [ -z "${LGTM_SRC:-}" ]; then
  echo "Error: LGTM_SRC environment variable not set" >&2
  exit 1
fi

echo "Indexing Leo files in: $LGTM_SRC"

# Find all .leo files and print them
find "$LGTM_SRC" -name "*.leo" -type f
