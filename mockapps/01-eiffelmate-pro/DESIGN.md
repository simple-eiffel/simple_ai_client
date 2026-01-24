# EiffelMate Pro - Technical Design

**Version**: 1.0.0
**Last Updated**: 2026-01-24
**Status**: Design Phase

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    EIFFELMATE PRO CLI                        │
├─────────────────────────────────────────────────────────────┤
│  CLI Interface Layer                                         │
│    - Argument parsing (simple_cli)                           │
│    - Command routing                                         │
│    - Output formatting (text, JSON, markdown)                │
│    - Interactive prompts (TUI-lite)                          │
├─────────────────────────────────────────────────────────────┤
│  Business Logic Layer                                        │
│    - Error analyzer (parse EiffelStudio errors)              │
│    - Contract generator (design contracts from code)         │
│    - Code generator (create Eiffel classes with contracts)   │
│    - Knowledge base manager (embeddings, similarity search)  │
│    - AI orchestrator (multi-provider, fallback logic)        │
├─────────────────────────────────────────────────────────────┤
│  Integration Layer                                           │
│    - simple_ai_client (Claude, OpenAI, Ollama)               │
│    - simple_sql (SQLite embedding store)                     │
│    - simple_json (config, API responses)                     │
│    - simple_logger (debug logging, audit trails)             │
│    - simple_file (code file I/O)                             │
│    - simple_process (EiffelStudio integration)               │
└─────────────────────────────────────────────────────────────┘
```

### Class Design

| Class | Responsibility | Key Features |
|-------|----------------|--------------|
| `EIFFELMATE_CLI` | Main entry point, command dispatcher | `parse_args`, `execute_command`, `format_output` |
| `ERROR_ANALYZER` | Parse and analyze EiffelStudio errors | `parse_error`, `classify_error`, `find_similar_errors` |
| `CONTRACT_GENERATOR` | Generate DbC contracts from code | `analyze_feature`, `suggest_preconditions`, `suggest_postconditions` |
| `CODE_GENERATOR` | Generate Eiffel code with contracts | `generate_class`, `generate_feature`, `apply_template` |
| `KNOWLEDGE_BASE` | Manage embedding store | `store_resolution`, `find_similar`, `export_knowledge`, `import_knowledge` |
| `AI_ORCHESTRATOR` | Coordinate multi-provider AI calls | `ask_with_fallback`, `select_best_provider`, `track_costs` |
| `EIFFELMATE_CONFIG` | Configuration management | `load`, `save`, `validate`, `get_provider_config` |
| `ERROR_PATTERN` | Error representation | `code`, `message`, `file`, `line`, `severity`, `embedding` |
| `RESOLUTION` | Error resolution representation | `explanation`, `fix_steps`, `code_snippet`, `confidence` |
| `CONTRACT_SUGGESTION` | Contract suggestion representation | `preconditions`, `postconditions`, `invariants`, `rationale` |

### Command Structure

```bash
eiffelmate <command> [options] [arguments]

Commands:
  fix <error>            Analyze error and suggest fixes
  contract <file>        Generate contracts for a feature or class
  generate <spec>        Generate Eiffel code from specification
  learn <error> <fix>    Store error resolution in knowledge base
  search <query>         Search knowledge base for similar errors
  review <file>          Review code for contract completeness
  config                 Manage configuration (providers, API keys)
  export                 Export knowledge base
  import <file>          Import knowledge base from file
  stats                  Show usage statistics and costs

Global Options:
  --config FILE          Configuration file (default: ~/.eiffelmate.json)
  --provider PROVIDER    AI provider (claude|openai|ollama|auto)
  --model MODEL          Specific model to use
  --output FORMAT        Output format (text|json|markdown)
  --verbose              Verbose output with reasoning steps
  --quiet                Minimal output (just results)
  --help                 Show help for command
```

### Command Details

#### `eiffelmate fix`

Analyze an EiffelStudio error and suggest fixes.

**Usage**:
```bash
# Paste error directly
eiffelmate fix "VEVI: Feature `make' not found in class FOO"

# Read from clipboard
eiffelmate fix --clipboard

# Read from EiffelStudio error log
eiffelmate fix --log EIFGENs/app/COMP/errors.txt

# Interactive mode (paste multi-line error)
eiffelmate fix --interactive
```

**Output** (text format):
```
Error Analysis
--------------
Type: VEVI (Validity: Entity and Variable Initialization)
Message: Feature `make' not found in class FOO
File: src/foo.e:42
Severity: ERROR

Similar Past Errors (2 found)
------------------------------
1. VEVI on `default_create' in BAR (95% similar)
   Resolution: Added creation procedure to class
   Date: 2026-01-15

2. VEVI on `make' in BAZ (87% similar)
   Resolution: Declared `make' in creation clause
   Date: 2026-01-10

AI Explanation
--------------
The VEVI error indicates that the feature `make' is being called as a
creation procedure, but it's not declared in the class's creation clause.
Eiffel requires that all creation procedures be explicitly listed.

Suggested Fix
-------------
1. Add `make' to the creation clause in FOO:

   class
       FOO

   create
       make  -- Add this line

   feature {NONE} -- Initialization

       make
           -- Initialize FOO
           do
               -- implementation
           end

   end

2. Or, if `make' shouldn't be a creation procedure, use an existing
   creation procedure instead.

Confidence: 95%
```

**Output** (JSON format):
```json
{
  "error": {
    "type": "VEVI",
    "message": "Feature `make' not found in class FOO",
    "file": "src/foo.e",
    "line": 42,
    "severity": "ERROR"
  },
  "similar_errors": [
    {
      "id": 123,
      "error": "VEVI on `default_create' in BAR",
      "resolution": "Added creation procedure to class",
      "similarity": 0.95,
      "date": "2026-01-15"
    }
  ],
  "explanation": "The VEVI error indicates...",
  "fix": {
    "steps": ["Add `make' to creation clause"],
    "code_snippet": "create\n    make",
    "confidence": 0.95
  },
  "provider": "claude",
  "model": "claude-sonnet-4-5",
  "tokens": {"input": 450, "output": 320},
  "cost": 0.0032
}
```

#### `eiffelmate contract`

Generate contracts for a feature or class.

**Usage**:
```bash
# Generate contracts for a specific feature
eiffelmate contract src/stack.e:push

# Generate contracts for entire class
eiffelmate contract src/stack.e

# Apply contracts directly to file (edit in place)
eiffelmate contract src/stack.e --apply

# Review mode (show what would be generated)
eiffelmate contract src/stack.e --dry-run
```

**Output**:
```eiffel
feature -- Element change

    push (item: G)
            -- Add `item' to top of stack
        require
            item_not_void: item /= Void  -- (if G is detachable)
            not_full: count < capacity
        do
            -- (existing implementation)
        ensure
            count_increased: count = old count + 1
            item_on_top: top = item
        end
```

#### `eiffelmate generate`

Generate Eiffel code from natural language specification.

**Usage**:
```bash
# Generate a class
eiffelmate generate "Create a sorted array class with binary search"

# Generate with specific contracts
eiffelmate generate "Create a queue with FIFO semantics" --contracts

# Generate with tests
eiffelmate generate "Create a ring buffer" --tests

# Save to file
eiffelmate generate "Create a hash table" --output src/hash_table.e
```

**Output**:
```eiffel
note
    description: "Sorted array with binary search"
    date: "$Date$"
    revision: "$Revision$"

class
    SORTED_ARRAY [G -> COMPARABLE]

inherit
    ANY
        redefine
            default_create
        end

create
    default_create,
    make

feature {NONE} -- Initialization

    default_create
            -- Initialize empty sorted array
        do
            create items.make (10)
        ensure then
            empty: count = 0
        end

    make (a_capacity: INTEGER)
            -- Initialize with capacity `a_capacity'
        require
            valid_capacity: a_capacity > 0
        do
            create items.make (a_capacity)
        ensure
            capacity_set: capacity = a_capacity
            empty: count = 0
        end

feature -- Access

    item (index: INTEGER): G
            -- Item at `index'
        require
            valid_index: valid_index (index)
        do
            Result := items [index]
        end

    has (value: G): BOOLEAN
            -- Does array contain `value'?
        do
            Result := index_of (value) > 0
        end

feature -- Search

    index_of (value: G): INTEGER
            -- Index of `value', or 0 if not found (binary search)
        local
            low, high, mid: INTEGER
        do
            from
                low := 1
                high := count
            until
                low > high or Result > 0
            loop
                mid := (low + high) // 2
                if items [mid] < value then
                    low := mid + 1
                elseif items [mid] > value then
                    high := mid - 1
                else
                    Result := mid
                end
            end
        ensure
            found_implies_equal: Result > 0 implies item (Result) ~ value
            not_found: Result = 0 implies not has (value)
        end

-- (rest of implementation)
end
```

#### `eiffelmate learn`

Store an error resolution in the knowledge base.

**Usage**:
```bash
# Store resolution interactively
eiffelmate learn

# Store from command line
eiffelmate learn "VEVI: make not found" "Added make to creation clause"

# Import from git commit
eiffelmate learn --from-commit abc123
```

#### `eiffelmate search`

Search knowledge base for similar errors.

**Usage**:
```bash
# Natural language search
eiffelmate search "how do I fix void safety errors?"

# Search by error code
eiffelmate search --code VEVI

# Show top 10 results
eiffelmate search "SCOOP violations" --limit 10
```

#### `eiffelmate review`

Review code for contract completeness.

**Usage**:
```bash
# Review single file
eiffelmate review src/stack.e

# Review entire project
eiffelmate review .

# Output as report
eiffelmate review . --output report.md --format markdown
```

**Output**:
```markdown
# Contract Review Report

**Project**: my_app
**Date**: 2026-01-24
**Files Reviewed**: 42
**Features Analyzed**: 387

## Summary

| Metric | Value |
|--------|-------|
| Features with preconditions | 312 (81%) |
| Features with postconditions | 245 (63%) |
| Classes with invariants | 35 (83%) |
| Contract coverage score | 75% |

## Missing Contracts

### HIGH PRIORITY (Public commands without contracts)

1. `STACK.push` (src/stack.e:42)
   - Missing precondition: `not_full`
   - Missing postcondition: `count_increased`

2. `QUEUE.dequeue` (src/queue.e:67)
   - Missing precondition: `not_empty`
   - Missing postcondition: `count_decreased`

### MEDIUM PRIORITY (Weak contracts)

1. `HASH_TABLE.put` (src/hash_table.e:89)
   - Weak precondition: always true
   - Suggestion: Add `valid_key: key /= Void`
```

### Data Flow

```
┌──────────────┐
│ User Input   │ (error text, file path, natural language spec)
└──────┬───────┘
       │
       v
┌──────────────────────────────────────────────────┐
│ EIFFELMATE_CLI: Parse arguments, validate input  │
└──────┬───────────────────────────────────────────┘
       │
       v
┌──────────────────────────────────────────────────┐
│ Command Dispatcher: Route to appropriate handler │
└──────┬───────────────────────────────────────────┘
       │
       ├─> fix ──────> ERROR_ANALYZER
       ├─> contract ─> CONTRACT_GENERATOR
       ├─> generate ─> CODE_GENERATOR
       ├─> learn ────> KNOWLEDGE_BASE
       ├─> search ───> KNOWLEDGE_BASE
       └─> review ───> CONTRACT_GENERATOR + ERROR_ANALYZER
                              │
                              v
                    ┌─────────────────────┐
                    │ AI_ORCHESTRATOR     │
                    │ - Select provider   │
                    │ - Fallback logic    │
                    │ - Cost tracking     │
                    └──────┬──────────────┘
                           │
                ┌──────────┼──────────┐
                v          v          v
         ┌─────────┐ ┌────────┐ ┌────────┐
         │ CLAUDE  │ │ OPENAI │ │ OLLAMA │
         │ CLIENT  │ │ CLIENT │ │ CLIENT │
         └────┬────┘ └───┬────┘ └───┬────┘
              │          │          │
              └──────────┴──────────┘
                      │
                      v
              ┌───────────────┐
              │ AI Response   │
              └───────┬───────┘
                      │
                      v
       ┌──────────────────────────────┐
       │ Response Processing          │
       │ - Parse AI output            │
       │ - Extract code snippets      │
       │ - Generate embeddings        │
       │ - Store in knowledge base    │
       └──────┬───────────────────────┘
              │
              v
       ┌──────────────────────────┐
       │ KNOWLEDGE_BASE (SQLite)  │
       │ - error_patterns table   │
       │ - resolutions table      │
       │ - embeddings table       │
       └──────┬───────────────────┘
              │
              v
       ┌──────────────────┐
       │ Output Formatter │ (text, JSON, markdown)
       └──────┬───────────┘
              │
              v
       ┌──────────────┐
       │ User Output  │
       └──────────────┘
```

### Configuration Schema

**File**: `~/.eiffelmate.json`

```json
{
  "version": "1.0.0",
  "providers": {
    "default": "auto",
    "fallback_order": ["ollama", "claude", "openai"],
    "claude": {
      "api_key": "sk-ant-...",
      "model": "claude-sonnet-4-5",
      "max_tokens": 4096,
      "temperature": 0.3
    },
    "openai": {
      "api_key": "sk-...",
      "model": "gpt-4",
      "max_tokens": 4096,
      "temperature": 0.3
    },
    "ollama": {
      "base_url": "http://localhost:11434",
      "model": "codellama",
      "timeout": 60
    }
  },
  "knowledge_base": {
    "path": "~/.eiffelmate/knowledge.db",
    "auto_learn": true,
    "similarity_threshold": 0.75
  },
  "code_generation": {
    "default_style": "simple_star",
    "include_tests": true,
    "contract_level": "full"
  },
  "output": {
    "format": "text",
    "color": true,
    "verbose": false
  },
  "logging": {
    "enabled": true,
    "level": "info",
    "file": "~/.eiffelmate/eiffelmate.log"
  },
  "telemetry": {
    "enabled": false,
    "anonymous": true
  }
}
```

### Error Handling

| Error Type | Handling | User Message |
|------------|----------|--------------|
| Invalid API key | Prompt for key, fallback to other provider | "Claude API key invalid. Falling back to Ollama..." |
| Provider unavailable | Try next provider in fallback order | "OpenAI unavailable. Trying Claude..." |
| Rate limit exceeded | Wait and retry (exponential backoff) | "Rate limit hit. Retrying in 30s..." |
| Invalid input | Show usage help | "Invalid error format. Use: eiffelmate fix '<error>'" |
| File not found | Check path, suggest alternatives | "File not found: src/foo.e. Did you mean src/bar.e?" |
| Knowledge base corrupted | Recreate database | "Knowledge base corrupted. Reinitializing..." |
| Parse error | Show parse context | "Failed to parse at line 42: unexpected token 'end'" |
| AI response invalid | Retry with clarified prompt | "AI response malformed. Retrying with simplified prompt..." |

## GUI/TUI Future Path

### CLI Foundation Enables:

1. **TUI (Terminal UI) Version**:
   - Interactive error browser with vim-style navigation
   - Live contract suggestions as you type (LSP integration)
   - Visual diff for generated code
   - Knowledge base explorer with similarity heatmap
   - Real-time cost/token tracking dashboard

2. **GUI (Desktop App) Version**:
   - Visual dependency graph explorer
   - Contract violation debugger with step-through
   - Drag-and-drop code generation
   - Team knowledge base dashboard
   - Analytics: error trends, developer productivity metrics

3. **IDE Plugin Version**:
   - EiffelStudio plugin for inline suggestions
   - VS Code extension (if Eiffel support added)
   - Sublime/Vim/Emacs plugins via LSP

### Shared Components Between CLI/TUI/GUI:

- **Core logic**: ERROR_ANALYZER, CONTRACT_GENERATOR, CODE_GENERATOR (100% reusable)
- **Knowledge base**: Same SQLite database across all interfaces
- **AI orchestration**: Same multi-provider logic and fallback
- **Configuration**: Same JSON config file
- **Telemetry**: Unified analytics across all versions

### What Would Change for TUI:

- Add `simple_tui` library for rich terminal UI
- Event loop for keyboard/mouse interaction
- Screen buffering for smooth updates
- Component library: panels, menus, dialogs

### What Would Change for GUI:

- Add `simple_gui` library (or native framework like Electron/Tauri)
- WebSocket server for real-time updates
- REST API for external integrations
- Authentication/authorization for team features
