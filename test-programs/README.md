# Leo Test Programs

Test programs for validating Leo CodeQL extractor and security detectors.

## Test Programs

### Clean Examples

**basic-token.leo** - Comprehensive example exercising core Leo features
- Records, mappings, transitions with finalize, functions
- Proper u64 types for balances
- Access patterns for teaching/reference

**safe-contract.leo** - Best practices baseline
- Proper integer types (u64)
- Access control on init functions
- No privacy leaks
- Safe conditional logic (if-else not ternary)
- Should trigger NO security detectors

### Vulnerable Examples

**privacy-leak.leo** - PrivacyLeakToFinalize
- Passes private record field directly to finalize function
- Two patterns: direct leak and expression leak
- Private data exposed to public execution

**missing-init-guard.leo** - MissingInitAccessControl
- Initialization functions without access control
- Anyone can call initialize() and setup_config()
- No assert checking caller authorization

**ternary-underflow.leo** - TernaryPanicTrap
- Ternary expressions with subtraction operations
- Both branches evaluated in ZK circuits
- Can panic even when "safe" branch taken

**field-balance.leo** - FieldTypeForBalance
- Uses field type for monetary values
- No overflow protection
- Can represent negative values
- Should use u64 or u128 instead

## Running Tests

### Extract TRAP Files

Run extractor validation:
```bash
./scripts/run-extraction-test.sh
```

Manual extraction:
```bash
TRAP_FOLDER=/tmp/trap \
SOURCE_ARCHIVE=/tmp/src \
LGTM_SRC=test-programs \
./extractor/target/release/leo-extractor
```

### Run Detectors

After building CodeQL database:
```bash
# Build database
codeql database create leo-test-db --language=leo --source-root=test-programs

# Run specific query
codeql query run ql/src/security/PrivacyLeakToFinalize.ql \
  --database=leo-test-db

# Run all security queries
codeql database analyze leo-test-db \
  ql/src/security/ \
  --format=sarif-latest \
  --output=results.sarif
```

## Expected Results

| Test Program | Expected Findings |
|--------------|------------------|
| basic-token.leo | None (clean example) |
| safe-contract.leo | None (best practices) |
| privacy-leak.leo | PrivacyLeakToFinalize: 2 findings |
| missing-init-guard.leo | MissingInitAccessControl: 2 findings |
| ternary-underflow.leo | TernaryPanicTrap: 3 findings |
| field-balance.leo | FieldTypeForBalance: multiple findings |

## Test Coverage

### Language Features
- ✓ Program declarations
- ✓ Records (private on-chain data)
- ✓ Mappings (public key-value storage)
- ✓ Transitions (externally callable)
- ✓ Async transitions with finalize
- ✓ Functions (helper functions)
- ✓ Constants
- ✓ Type annotations (address, u64, u32, field)
- ✓ Expressions (binary ops, ternary, calls)
- ✓ Struct initialization
- ✓ Variable declarations and references
- ✓ Parameters (public and private)

### Security Patterns
- ✓ Privacy leaks (private → finalize)
- ✓ Missing access control (init functions)
- ✓ Arithmetic panics (ternary underflow)
- ✓ Type misuse (field for balances)

## Adding New Tests

1. Create new `.leo` file in `test-programs/`
2. Add descriptive comment header
3. Mark vulnerabilities with `// VULNERABILITY:` or `// BUG:`
4. Run `./scripts/run-extraction-test.sh` to verify extraction
5. Update this README with expected findings
6. Run detectors to validate
