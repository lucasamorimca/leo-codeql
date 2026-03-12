#!/usr/bin/env bash
set -euo pipefail

# Leo CodeQL Extractor End-to-End Test Script
# Tests the extractor on all test programs and verifies TRAP generation

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_PROGRAMS_DIR="${REPO_ROOT}/test-programs"
EXTRACTOR_DIR="${REPO_ROOT}/extractor"
TEMP_DIR="${REPO_ROOT}/.test-extraction"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Leo CodeQL Extractor Test ===${NC}\n"

# Check if test programs exist
if [ ! -d "${TEST_PROGRAMS_DIR}" ]; then
    echo -e "${RED}Error: test-programs directory not found at ${TEST_PROGRAMS_DIR}${NC}"
    exit 1
fi

# Check if extractor exists
if [ ! -d "${EXTRACTOR_DIR}" ]; then
    echo -e "${RED}Error: extractor directory not found at ${EXTRACTOR_DIR}${NC}"
    exit 1
fi

# Count test programs
TEST_COUNT=$(find "${TEST_PROGRAMS_DIR}" -name "*.leo" -type f | wc -l | tr -d ' ')
echo -e "Found ${GREEN}${TEST_COUNT}${NC} test programs\n"

if [ "${TEST_COUNT}" -eq 0 ]; then
    echo -e "${RED}Error: No .leo files found in ${TEST_PROGRAMS_DIR}${NC}"
    exit 1
fi

# Clean up any previous test runs
if [ -d "${TEMP_DIR}" ]; then
    echo -e "${YELLOW}Cleaning up previous test run...${NC}"
    rm -rf "${TEMP_DIR}"
fi

# Create temporary directories
mkdir -p "${TEMP_DIR}/trap"
mkdir -p "${TEMP_DIR}/src"
echo -e "${GREEN}Created temporary directories${NC}\n"

# Track results
PASSED=0
FAILED=0
declare -a FAILED_TESTS

# Test each Leo program
echo -e "${BLUE}Running extraction tests:${NC}\n"

for leo_file in "${TEST_PROGRAMS_DIR}"/*.leo; do
    if [ ! -f "${leo_file}" ]; then
        continue
    fi

    filename=$(basename "${leo_file}")
    program_name="${filename%.leo}"

    echo -e "${YELLOW}Testing: ${program_name}${NC}"

    # Copy source file to temp src directory
    cp "${leo_file}" "${TEMP_DIR}/src/"

    # Set up environment variables for extractor
    export TRAP_FOLDER="${TEMP_DIR}/trap"
    export SOURCE_ARCHIVE="${TEMP_DIR}/src"
    export LGTM_SRC="${TEMP_DIR}/src"
    export CODEQL_EXTRACTOR_LEO_ROOT="${EXTRACTOR_DIR}"

    # Run the extractor (using uv run for proper environment)
    if cd "${EXTRACTOR_DIR}" && uv run python3 -m leo_extractor.main "${leo_file}" 2>&1 | tee "${TEMP_DIR}/${program_name}.log"; then
        # Check if TRAP file was created
        trap_file="${TEMP_DIR}/trap/${filename}.trap"

        if [ -f "${trap_file}" ]; then
            trap_size=$(wc -l < "${trap_file}" | tr -d ' ')
            echo -e "  ${GREEN}✓ TRAP file created: ${trap_size} lines${NC}"

            # Show sample of TRAP contents
            echo -e "  ${BLUE}Sample TRAP output:${NC}"
            head -n 5 "${trap_file}" | sed 's/^/    /'
            echo "    ..."

            PASSED=$((PASSED + 1))
        else
            echo -e "  ${RED}✗ TRAP file not found at ${trap_file}${NC}"
            FAILED=$((FAILED + 1))
            FAILED_TESTS+=("${program_name}: TRAP file not created")
        fi
    else
        echo -e "  ${RED}✗ Extractor failed${NC}"
        FAILED=$((FAILED + 1))
        FAILED_TESTS+=("${program_name}: Extractor execution failed")
    fi

    echo ""
done

# Print summary
echo -e "${BLUE}=== Test Summary ===${NC}\n"
echo -e "Total programs:  ${TEST_COUNT}"
echo -e "Passed:          ${GREEN}${PASSED}${NC}"
echo -e "Failed:          ${RED}${FAILED}${NC}"
echo ""

# Print details of failures if any
if [ "${FAILED}" -gt 0 ]; then
    echo -e "${RED}Failed tests:${NC}"
    for failure in "${FAILED_TESTS[@]}"; do
        echo -e "  - ${failure}"
    done
    echo ""
fi

# Show TRAP directory contents
echo -e "${BLUE}TRAP files generated:${NC}"
ls -lh "${TEMP_DIR}/trap" | tail -n +2 | awk '{print "  " $9 " (" $5 ")"}'
echo ""

# Analyze TRAP contents
echo -e "${BLUE}Analyzing extracted data:${NC}\n"
for trap_file in "${TEMP_DIR}/trap"/*.trap; do
    if [ ! -f "${trap_file}" ]; then
        continue
    fi

    filename=$(basename "${trap_file}" .trap)

    # Count different entity types in TRAP file
    programs=$(grep -c "^leo_programs(" "${trap_file}" || echo "0")
    records=$(grep -c "^leo_struct_declarations(" "${trap_file}" || echo "0")
    transitions=$(grep -c "^leo_functions(.*1," "${trap_file}" || echo "0")
    functions=$(grep -c "^leo_functions(" "${trap_file}" || echo "0")
    mappings=$(grep -c "^leo_mappings(" "${trap_file}" || echo "0")

    echo -e "${YELLOW}${filename}:${NC}"
    echo "  Programs:    ${programs}"
    echo "  Records:     ${records}"
    echo "  Transitions: ${transitions}"
    echo "  Functions:   ${functions}"
    echo "  Mappings:    ${mappings}"
    echo ""
done

# Cleanup
echo -e "${YELLOW}Cleaning up temporary directories...${NC}"
rm -rf "${TEMP_DIR}"
echo -e "${GREEN}Cleanup complete${NC}\n"

# Exit with appropriate code
if [ "${FAILED}" -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
