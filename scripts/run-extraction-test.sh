#!/usr/bin/env bash
set -euo pipefail

# Leo CodeQL Extractor End-to-End Test Script
# Tests the Rust extractor on all test programs and verifies TRAP generation

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

# Build the extractor
echo -e "${YELLOW}Building extractor...${NC}"
(cd "${EXTRACTOR_DIR}" && cargo build --release) || { echo "Build failed"; exit 1; }

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
    [[ "${TEMP_DIR}" == */.test-extraction ]] || { echo "Error: unexpected TEMP_DIR: ${TEMP_DIR}"; exit 1; }
    rm -rf "${TEMP_DIR}"
fi

# Create temporary directories
mkdir -p "${TEMP_DIR}/trap"
mkdir -p "${TEMP_DIR}/src"
mkdir -p "${TEMP_DIR}/archive"
echo -e "${GREEN}Created temporary directories${NC}\n"

# Copy all test programs to the temp src directory
cp "${TEST_PROGRAMS_DIR}"/*.leo "${TEMP_DIR}/src/"

# IMPORTANT: SOURCE_ARCHIVE must differ from LGTM_SRC
# otherwise fs::copy overwrites source files with empty content
export TRAP_FOLDER="${TEMP_DIR}/trap"
export SOURCE_ARCHIVE="${TEMP_DIR}/archive"
export LGTM_SRC="${TEMP_DIR}/src"

# Run the Rust extractor via cargo
echo -e "${BLUE}Running extraction:${NC}\n"
if (cd "${EXTRACTOR_DIR}" && cargo run --release); then
    echo ""
else
    echo -e "\n${RED}Extractor failed!${NC}"
    exit 1
fi

# Count results
PASSED=0
FAILED=0
declare -a FAILED_TESTS=()

echo -e "${BLUE}Verifying TRAP files:${NC}\n"
for leo_file in "${TEMP_DIR}/src"/*.leo; do
    if [ ! -f "${leo_file}" ]; then
        continue
    fi

    filename=$(basename "${leo_file}")
    program_name="${filename%.leo}"
    trap_file="${TEMP_DIR}/trap/${filename}.trap"

    if [ -f "${trap_file}" ]; then
        trap_size=$(wc -l < "${trap_file}" | tr -d ' ')
        # Validate TRAP content: must contain label definitions and program tuples
        has_labels=$(grep -c '^#[0-9]*=\*' "${trap_file}" || echo "0")
        has_programs=$(grep -c '^leo_programs(' "${trap_file}" || echo "0")
        if [ "${has_labels}" -eq 0 ] || [ "${has_programs}" -eq 0 ]; then
            echo -e "  ${RED}✗${NC} ${program_name}: TRAP file has ${trap_size} lines but invalid content (labels=${has_labels}, programs=${has_programs})"
            FAILED=$((FAILED + 1))
            FAILED_TESTS+=("${program_name} (invalid TRAP content)")
        else
            echo -e "  ${GREEN}✓${NC} ${program_name}: ${trap_size} lines (${has_labels} labels, ${has_programs} programs)"
            PASSED=$((PASSED + 1))
        fi
    else
        echo -e "  ${RED}✗${NC} ${program_name}: TRAP file not found"
        FAILED=$((FAILED + 1))
        FAILED_TESTS+=("${program_name}")
    fi
done

# Print summary
echo -e "\n${BLUE}=== Test Summary ===${NC}\n"
echo -e "Total programs:  ${TEST_COUNT}"
echo -e "Passed:          ${GREEN}${PASSED}${NC}"
echo -e "Failed:          ${RED}${FAILED}${NC}"
echo ""

if [ "${FAILED}" -gt 0 ]; then
    echo -e "${RED}Failed tests:${NC}"
    for failure in "${FAILED_TESTS[@]}"; do
        echo -e "  - ${failure}"
    done
    echo ""
fi

# Analyze TRAP contents
echo -e "${BLUE}Analyzing extracted data:${NC}\n"
for trap_file in "${TEMP_DIR}/trap"/*.trap; do
    if [ ! -f "${trap_file}" ]; then
        continue
    fi

    filename=$(basename "${trap_file}" .trap)

    programs=$(grep -c "^leo_programs(" "${trap_file}" || echo "0")
    records=$(grep -c "^leo_struct_declarations(" "${trap_file}" || echo "0")
    functions=$(grep -c "^leo_functions(" "${trap_file}" || echo "0")
    mappings=$(grep -c "^leo_mappings(" "${trap_file}" || echo "0")
    stmts=$(grep -c "^leo_stmts(" "${trap_file}" || echo "0")
    exprs=$(grep -c "^leo_exprs(" "${trap_file}" || echo "0")

    echo -e "${YELLOW}${filename}:${NC}"
    echo "  Programs:    ${programs}"
    echo "  Records:     ${records}"
    echo "  Functions:   ${functions}"
    echo "  Mappings:    ${mappings}"
    echo "  Statements:  ${stmts}"
    echo "  Expressions: ${exprs}"
    echo ""
done

# Semantic validation checks (warnings only)
echo -e "${BLUE}Semantic validation:${NC}\n"
for trap_file in "${TEMP_DIR}/trap"/*.trap; do
    if [ ! -f "${trap_file}" ]; then
        continue
    fi

    filename=$(basename "${trap_file}" .trap)
    program_name="${filename%.leo}"

    # Targeted validation for specific test programs
    case "${program_name}" in
        ternary-underflow)
            if ! grep -q "leo_ternary_condition(" "${trap_file}"; then
                echo -e "  ${YELLOW}⚠${NC}  ${program_name}: Missing ternary condition tuples"
            else
                echo -e "  ${GREEN}✓${NC}  ${program_name}: Ternary conditions present"
            fi
            ;;
        privacy-leak)
            # Check for async finalize functions (kind=3)
            if ! grep -q "leo_functions.*3, 1," "${trap_file}"; then
                echo -e "  ${YELLOW}⚠${NC}  ${program_name}: Missing async finalize functions"
            else
                echo -e "  ${GREEN}✓${NC}  ${program_name}: Async finalize functions present"
            fi
            ;;
        basic-token)
            if ! grep -q "leo_struct_declarations(" "${trap_file}"; then
                echo -e "  ${YELLOW}⚠${NC}  ${program_name}: Missing struct/record tuples"
            else
                echo -e "  ${GREEN}✓${NC}  ${program_name}: Struct/record tuples present"
            fi
            ;;
    esac
done
echo ""

# Cleanup
echo -e "${YELLOW}Cleaning up temporary directories...${NC}"
[[ "${TEMP_DIR}" == */.test-extraction ]] || { echo "Error: unexpected TEMP_DIR: ${TEMP_DIR}"; exit 1; }
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
