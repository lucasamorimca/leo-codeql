# leo-codeql

CodeQL analysis support for the [Leo programming language](https://leo-lang.org/) — the statically-typed language for writing zero-knowledge applications on [Aleo](https://aleo.org/).

## What This Does

This project provides a full CodeQL language pack for Leo: a Python-based extractor that parses `.leo` files into CodeQL databases, a typed QL library for querying Leo ASTs, and security detectors targeting vulnerabilities specific to zero-knowledge programs.

## Architecture

```
Leo source (.leo)
    │
    ▼
Python Extractor ──→ TRAP files ──→ CodeQL Database
    │                                      │
    ├─ Lexer                               ▼
    ├─ Parser (recursive descent)    QL Library (typed AST)
    └─ TRAP Generator                      │
                                           ▼
                                   Security Queries ──→ SARIF findings
```

## Security Detectors

| Query | Severity | What it finds |
|-------|----------|---------------|
| **PrivacyLeakToFinalize** | error | Private record fields passed to public `finalize` functions, exposing data on-chain |
| **MissingInitAccessControl** | error | Initialization functions without `assert` caller checks — anyone can re-initialize |
| **TernaryPanicTrap** | warning | Ternary expressions with subtraction — both branches evaluate in ZK circuits, causing panics even on the "safe" path |
| **FieldTypeForBalance** | warning | `field` type used for monetary values — wraps silently at the field prime with no overflow protection |

## Quick Start

### Prerequisites

- [CodeQL CLI](https://github.com/github/codeql-cli-binaries) (2.15+)
- Python 3.13+ with [uv](https://docs.astral.sh/uv/)

### Install

```bash
git clone https://github.com/lucasamorimca/leo-codeql.git
cd leo-codeql
cd extractor && uv sync && cd ..
```

### Extract a Leo project

```bash
cd extractor
TRAP_FOLDER=/tmp/trap \
SOURCE_ARCHIVE=/tmp/src \
LGTM_SRC=/path/to/your/leo/project \
uv run python3 -m leo_extractor.main
```

### Run security queries

```bash
# After building a CodeQL database
codeql database analyze your-db \
  ql/src/security/ \
  --search-path=ql/lib \
  --format=sarif-latest \
  --output=results.sarif
```

### Run tests

```bash
# Python extractor tests
cd extractor && uv run python -m pytest tests/ -v

# Extraction validation (all 7 test programs)
./scripts/run-extraction-test.sh

# QL compilation check
codeql query compile --search-path=ql/lib ql/src/security/*.ql
```

## Project Structure

```
├── extractor/              Python extractor
│   └── leo_extractor/
│       ├── lexer.py            Tokenizer (104 token types)
│       ├── parser.py           Recursive-descent parser
│       ├── expression_parser.py  Precedence-climbing expressions
│       ├── ast_nodes.py        AST node definitions (40+ types)
│       ├── ast_to_trap.py      AST → TRAP converter
│       ├── trap_writer.py      TRAP file writer
│       └── main.py             Entry point
├── ql/
│   ├── lib/
│   │   ├── leo.dbscheme        Database schema (30+ tables)
│   │   └── codeql/leo/
│   │       ├── ast/            Typed AST classes (Expression, Statement, etc.)
│   │       └── controlflow/    CFG and call graph analysis
│   └── src/security/           Security detector queries
├── test-programs/          Sample Leo programs (clean + vulnerable)
├── scripts/                Validation and packaging scripts
└── tools/                  CodeQL extractor integration scripts
```

## QL Library

The QL library provides typed wrappers over the database schema:

- **AST classes**: `Program`, `Function`, `Expr` (15 kinds), `Stmt` (8 kinds), `LeoType`, `StructDeclaration`, `RecordDeclaration`, `MappingDeclaration`
- **Control flow**: `CfgNode` with successor/predecessor edges, `EntryNode`, `ExitNode`, loop and conditional nodes
- **Call graph**: `callEdge`, `reachableFrom`, `resolveCall`, recursive call detection, on-chain/off-chain context tracking
- **Leo-specific**: visibility tracking (public/private), async transition → finalize flow, record vs struct differentiation

### Example query

```ql
import codeql.leo.Leo

from TransitionFunction t, Parameter p
where
  t.isAsync() and
  p = t.getAParameter() and
  p.isPrivate()
select t, "Async transition " + t.getName() + " accepts private parameter " + p.getName()
```

## Leo Language Features Covered

- Program declarations and imports
- Functions, transitions (external entry points), and inline functions
- Records (private UTXO state) and structs
- Mappings (public on-chain key-value storage)
- Async transitions with `finalize`
- All expression types (binary, unary, ternary, calls, field access, struct init, casts)
- All statement types (let, const, assign, if/else if/else, for, return, assert)
- Type system (primitives, address, field, group, scalar, arrays, tuples)

## Contributing

1. Add new `.leo` test programs in `test-programs/`
2. Write QL queries in `ql/src/security/`
3. Run `./scripts/run-extraction-test.sh` to validate extraction
4. Run `codeql query compile --search-path=ql/lib ql/src/security/*.ql` to verify queries

## License

MIT
