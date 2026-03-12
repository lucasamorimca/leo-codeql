#!/usr/bin/env bash
set -euo pipefail

# CodeQL autobuild script for Leo language
# Invoked by CodeQL during database creation

# Environment variables provided by CodeQL:
# - TRAP_FOLDER: where to write .trap files
# - SOURCE_ARCHIVE: where to write source archive
# - LGTM_SRC: source root directory

echo "Leo extractor autobuild starting..."
echo "TRAP_FOLDER: ${TRAP_FOLDER:-not set}"
echo "SOURCE_ARCHIVE: ${SOURCE_ARCHIVE:-not set}"
echo "LGTM_SRC: ${LGTM_SRC:-not set}"

# Run the Python extractor
python3 -m leo_extractor.main

echo "Leo extractor autobuild completed."
