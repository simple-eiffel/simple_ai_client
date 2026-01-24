# EiffelMate Pro - Ecosystem Integration

**Date**: 2026-01-24
**Version**: 1.0.0

## simple_* Dependencies

### Required Libraries

| Library | Purpose | Integration Point |
|---------|---------|-------------------|
| simple_ai_client | Core AI functionality, embeddings, multi-provider support | ERROR_ANALYZER, CONTRACT_GENERATOR, CODE_GENERATOR, KNOWLEDGE_BASE |
| simple_sql | SQLite database for embedding storage and error patterns | KNOWLEDGE_BASE class for persist/retrieve operations |
| simple_json | Configuration file parsing, API response handling | EIFFELMATE_CONFIG, AI response parsing |
| simple_cli | Command-line argument parsing and command routing | EIFFELMATE_CLI main entry point |
| simple_logger | Debug logging, audit trails, usage analytics | All components for telemetry and debugging |
| simple_file | Code file reading/writing operations | CODE_GENERATOR, CONTRACT_GENERATOR for file I/O |

### Optional Libraries

| Library | Purpose | When Needed |
|---------|---------|-------------|
| simple_process | EiffelStudio compiler integration, error log parsing | When using `--log` flag to read compiler output |
| simple_regex | Advanced error pattern matching | For complex error parsing beyond string operations |
| simple_markdown | Markdown report generation | When using `--format markdown` for review reports |
| simple_template | Code template management | For advanced code generation with custom templates |
| simple_http | REST API for team knowledge base sync | Enterprise tier with shared knowledge base |
| simple_encryption | Encrypt API keys and knowledge base | Enterprise tier with enhanced security requirements |

## Integration Patterns

### simple_ai_client Integration

**Purpose**: Core AI functionality for error analysis, contract generation, and code generation

**Usage**:
```eiffel
feature {NONE} -- Implementation

    ai_orchestrator: AI_ORCHESTRATOR
            -- Manages multi-provider AI access

    fix_error (error_text: STRING): RESOLUTION
            -- Analyze error and generate resolution
        local
            ai_client: AI_CLIENT
            prompt: STRING
            response: AI_RESPONSE
            embedding: AI_EMBEDDING
        do
            -- Select best provider (fallback logic)
            ai_client := ai_orchestrator.select_provider

            -- Build context-aware prompt
            prompt := build_fix_prompt (error_text)

            -- Get AI response
            response := ai_client.ask_with_system (system_context, prompt)

            if response.is_success then
                -- Parse response into resolution
                create Result.make_from_response (response)

                -- Generate embedding for knowledge base
                if attached ai_orchestrator.embedding_client as emb_client then
                    embedding := emb_client.embed (error_text)
                    knowledge_base.store_error_resolution (error_text, Result, embedding)
                end
            else
                -- Handle error (fallback to next provider)
                Result := try_fallback_provider (error_text)
            end
        end
```

**Data flow**:
1. User provides error text
2. AI_ORCHESTRATOR selects best provider (cost, availability, quality)
3. Build prompt with Eiffel context (OOSC2 principles, simple_* patterns)
4. AI_CLIENT sends request to provider (Claude/OpenAI/Ollama)
5. Parse response into structured RESOLUTION object
6. Generate embedding via OLLAMA_EMBEDDING_CLIENT
7. Store in KNOWLEDGE_BASE via simple_sql

### simple_sql Integration

**Purpose**: Persistent storage for error patterns, resolutions, and embeddings

**Usage**:
```eiffel
class
    KNOWLEDGE_BASE

feature {NONE} -- Initialization

    make (db_path: STRING)
            -- Initialize knowledge base at `db_path'
        do
            create database.make (db_path)
            initialize_schema
        end

    initialize_schema
            -- Create tables if they don't exist
        do
            database.execute_sql ("[
                CREATE TABLE IF NOT EXISTS error_patterns (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    error_code TEXT NOT NULL,
                    error_message TEXT NOT NULL,
                    file_path TEXT,
                    line_number INTEGER,
                    severity TEXT,
                    embedding_id INTEGER,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (embedding_id) REFERENCES embeddings(id)
                );

                CREATE TABLE IF NOT EXISTS resolutions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    error_pattern_id INTEGER NOT NULL,
                    explanation TEXT NOT NULL,
                    fix_steps TEXT NOT NULL,
                    code_snippet TEXT,
                    confidence REAL,
                    provider TEXT,
                    model TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (error_pattern_id) REFERENCES error_patterns(id)
                );

                CREATE TABLE IF NOT EXISTS embeddings (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    vector TEXT NOT NULL,  -- JSON array of floats
                    dimension INTEGER NOT NULL,
                    model TEXT NOT NULL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                );

                CREATE INDEX IF NOT EXISTS idx_error_code ON error_patterns(error_code);
                CREATE INDEX IF NOT EXISTS idx_created_at ON error_patterns(created_at);
            ]")
        end

feature -- Storage

    store_error_resolution (error: ERROR_PATTERN; resolution: RESOLUTION; embedding: AI_EMBEDDING)
            -- Store error and resolution in knowledge base
        local
            emb_id, error_id: INTEGER
        do
            -- Store embedding
            emb_id := store_embedding (embedding)

            -- Store error pattern
            database.execute_sql ("[
                INSERT INTO error_patterns (error_code, error_message, file_path, line_number, severity, embedding_id)
                VALUES (?, ?, ?, ?, ?, ?)
            ]")
            database.bind_string (1, error.code)
            database.bind_string (2, error.message)
            database.bind_string (3, error.file_path)
            database.bind_integer (4, error.line_number)
            database.bind_string (5, error.severity)
            database.bind_integer (6, emb_id)

            error_id := database.last_insert_id

            -- Store resolution
            database.execute_sql ("[
                INSERT INTO resolutions (error_pattern_id, explanation, fix_steps, code_snippet, confidence, provider, model)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ]")
            database.bind_integer (1, error_id)
            database.bind_string (2, resolution.explanation)
            database.bind_string (3, resolution.fix_steps)
            database.bind_string (4, resolution.code_snippet)
            database.bind_real (5, resolution.confidence)
            database.bind_string (6, resolution.provider)
            database.bind_string (7, resolution.model)
        end

feature -- Search

    find_similar_errors (query_embedding: AI_EMBEDDING; threshold: REAL; limit: INTEGER): LIST [TUPLE [error: ERROR_PATTERN; resolution: RESOLUTION; similarity: REAL]]
            -- Find similar errors using cosine similarity
        local
            all_embeddings: LIST [TUPLE [id: INTEGER; vector: AI_EMBEDDING]]
            similarities: SORTED_SET [TUPLE [id: INTEGER; similarity: REAL]]
        do
            -- Load all embeddings from database
            all_embeddings := load_all_embeddings

            -- Compute similarities (local, no AI call!)
            create {ARRAYED_LIST [TUPLE [id: INTEGER; similarity: REAL]]} similarities.make (all_embeddings.count)
            across all_embeddings as emb loop
                similarity := query_embedding.cosine_similarity (emb.item.vector)
                if similarity >= threshold then
                    similarities.extend ([emb.item.id, similarity])
                end
            end

            -- Sort by similarity descending
            similarities.sort_descending

            -- Load top N error patterns and resolutions
            create {ARRAYED_LIST [TUPLE [error: ERROR_PATTERN; resolution: RESOLUTION; similarity: REAL]]} Result.make (limit)
            across similarities.take (limit) as sim loop
                Result.extend (load_error_and_resolution (sim.item.id, sim.item.similarity))
            end
        end
```

**Data flow**:
1. Initialize database schema (tables, indexes)
2. Store error patterns with embeddings
3. Similarity search: load embeddings, compute cosine similarity locally
4. Return top N matches with confidence scores

### simple_json Integration

**Purpose**: Configuration file parsing and API response handling

**Usage**:
```eiffel
class
    EIFFELMATE_CONFIG

feature -- Access

    load (file_path: STRING)
            -- Load configuration from JSON file
        local
            json_parser: SIMPLE_JSON_PARSER
            json_object: JSON_OBJECT
        do
            create json_parser.make
            json_parser.parse_file (file_path)

            if json_parser.is_valid then
                json_object := json_parser.object

                -- Load provider config
                if attached json_object.object ("providers") as providers then
                    load_provider_config (providers)
                end

                -- Load knowledge base config
                if attached json_object.object ("knowledge_base") as kb then
                    knowledge_base_path := kb.string ("path")
                    auto_learn := kb.boolean ("auto_learn")
                    similarity_threshold := kb.real ("similarity_threshold")
                end

                -- Load code generation config
                if attached json_object.object ("code_generation") as codegen then
                    default_style := codegen.string ("default_style")
                    include_tests := codegen.boolean ("include_tests")
                    contract_level := codegen.string ("contract_level")
                end
            else
                -- Handle parse error
                io.error.put_string ("Config parse error: " + json_parser.error_message)
            end
        end

feature {NONE} -- Implementation

    load_provider_config (providers: JSON_OBJECT)
            -- Load AI provider configuration
        do
            default_provider := providers.string ("default")

            -- Claude config
            if attached providers.object ("claude") as claude then
                claude_api_key := claude.string ("api_key")
                claude_model := claude.string ("model")
                claude_max_tokens := claude.integer ("max_tokens")
                claude_temperature := claude.real ("temperature")
            end

            -- OpenAI config
            if attached providers.object ("openai") as openai then
                openai_api_key := openai.string ("api_key")
                openai_model := openai.string ("model")
                openai_max_tokens := openai.integer ("max_tokens")
                openai_temperature := openai.real ("temperature")
            end

            -- Ollama config
            if attached providers.object ("ollama") as ollama then
                ollama_base_url := ollama.string ("base_url")
                ollama_model := ollama.string ("model")
                ollama_timeout := ollama.integer ("timeout")
            end
        end
```

**Data flow**:
1. Read JSON config file from disk
2. Parse with simple_json
3. Extract configuration values (providers, models, API keys)
4. Validate and set defaults for missing values
5. Pass to AI_ORCHESTRATOR for provider initialization

### simple_cli Integration

**Purpose**: Command-line argument parsing and routing

**Usage**:
```eiffel
class
    EIFFELMATE_CLI

feature -- Execution

    execute (args: ARRAY [STRING])
            -- Parse arguments and execute command
        local
            cli_parser: SIMPLE_CLI_PARSER
            command: STRING
        do
            create cli_parser.make ("eiffelmate", "AI-powered Eiffel development assistant")

            -- Define global options
            cli_parser.add_flag ("verbose", "v", "Verbose output")
            cli_parser.add_flag ("quiet", "q", "Minimal output")
            cli_parser.add_option ("config", "c", "Configuration file", "FILE")
            cli_parser.add_option ("provider", "p", "AI provider (claude|openai|ollama|auto)", "PROVIDER")
            cli_parser.add_option ("output", "o", "Output format (text|json|markdown)", "FORMAT")

            -- Define commands
            cli_parser.add_command ("fix", "Analyze error and suggest fixes")
            cli_parser.add_command ("contract", "Generate contracts for feature or class")
            cli_parser.add_command ("generate", "Generate Eiffel code from specification")
            cli_parser.add_command ("learn", "Store error resolution in knowledge base")
            cli_parser.add_command ("search", "Search knowledge base for similar errors")
            cli_parser.add_command ("review", "Review code for contract completeness")
            cli_parser.add_command ("config", "Manage configuration")
            cli_parser.add_command ("stats", "Show usage statistics")

            -- Parse arguments
            cli_parser.parse (args)

            if cli_parser.is_valid then
                command := cli_parser.command

                -- Route to command handler
                if command.is_equal ("fix") then
                    execute_fix (cli_parser)
                elseif command.is_equal ("contract") then
                    execute_contract (cli_parser)
                elseif command.is_equal ("generate") then
                    execute_generate (cli_parser)
                -- ... other commands
                end
            else
                io.error.put_string (cli_parser.error_message)
                cli_parser.print_usage
            end
        end
```

**Data flow**:
1. Define CLI structure (commands, options, flags)
2. Parse argv array
3. Validate arguments
4. Route to appropriate command handler
5. Pass parsed options to business logic

### simple_logger Integration

**Purpose**: Debug logging, audit trails, usage analytics

**Usage**:
```eiffel
feature {NONE} -- Logging

    logger: SIMPLE_LOGGER

    log_ai_request (provider: STRING; model: STRING; prompt_length: INTEGER)
            -- Log AI request for analytics
        do
            logger.info ("[AI] Provider: " + provider + ", Model: " + model + ", Prompt: " + prompt_length.out + " chars")
        end

    log_error_resolution (error_code: STRING; confidence: REAL; provider: STRING)
            -- Log successful error resolution
        do
            logger.info ("[RESOLVE] Error: " + error_code + ", Confidence: " + confidence.out + ", Provider: " + provider)
        end

    log_knowledge_base_hit (similarity: REAL)
            -- Log knowledge base similarity match
        do
            logger.debug ("[KB] Similarity match: " + similarity.out)
        end
```

**Data flow**:
1. Initialize logger (file/stderr/SIMPLE_LOGGER integration)
2. Log events at appropriate levels (DEBUG, INFO, WARN, ERROR)
3. Aggregate for usage analytics
4. Export for billing/audit purposes (enterprise tier)

### simple_file Integration

**Purpose**: Code file reading and writing

**Usage**:
```eiffel
feature -- Code Generation

    generate_class_file (class_name: STRING; content: STRING; output_path: STRING)
            -- Generate Eiffel class file
        local
            file_writer: SIMPLE_FILE_WRITER
        do
            create file_writer.make (output_path)
            file_writer.write (content)
            file_writer.close

            logger.info ("[CODEGEN] Generated class: " + class_name + " at " + output_path)
        ensure
            file_exists: (create {SIMPLE_FILE}).exists (output_path)
        end

    read_eiffel_class (file_path: STRING): STRING
            -- Read Eiffel class source code
        local
            file_reader: SIMPLE_FILE_READER
        do
            create file_reader.make (file_path)
            Result := file_reader.read_all
            file_reader.close
        end
```

---

## Dependency Graph

```
eiffelmate_pro
    ├── simple_ai_client (REQUIRED) ─── Core AI functionality
    │   ├── AI_CLIENT (deferred)
    │   ├── CLAUDE_CLIENT
    │   ├── OPENAI_CLIENT
    │   ├── OLLAMA_CLIENT
    │   ├── OLLAMA_EMBEDDING_CLIENT
    │   ├── AI_MESSAGE
    │   ├── AI_RESPONSE
    │   ├── AI_EMBEDDING
    │   └── AI_EMBEDDING_RESPONSE
    ├── simple_sql (REQUIRED) ─────── SQLite storage
    │   ├── SIMPLE_SQL_DATABASE
    │   ├── SIMPLE_SQL_QUERY
    │   └── SIMPLE_SQL_RESULT
    ├── simple_json (REQUIRED) ────── Config & API parsing
    │   ├── SIMPLE_JSON_PARSER
    │   ├── JSON_OBJECT
    │   ├── JSON_ARRAY
    │   └── JSON_VALUE
    ├── simple_cli (REQUIRED) ─────── CLI argument parsing
    │   ├── SIMPLE_CLI_PARSER
    │   ├── CLI_COMMAND
    │   └── CLI_OPTION
    ├── simple_logger (REQUIRED) ──── Logging & analytics
    │   ├── SIMPLE_LOGGER
    │   └── LOG_LEVEL
    ├── simple_file (REQUIRED) ────── File I/O
    │   ├── SIMPLE_FILE_READER
    │   └── SIMPLE_FILE_WRITER
    ├── simple_process (OPTIONAL) ─── Compiler integration
    │   └── SIMPLE_PROCESS
    ├── simple_regex (OPTIONAL) ───── Error pattern matching
    │   └── SIMPLE_REGEX
    ├── simple_markdown (OPTIONAL) ── Report generation
    │   └── SIMPLE_MARKDOWN
    ├── simple_template (OPTIONAL) ── Code templates
    │   └── SIMPLE_TEMPLATE
    ├── simple_http (OPTIONAL) ────── Team sync
    │   └── SIMPLE_HTTP_CLIENT
    └── simple_encryption (OPTIONAL) Enterprise security
        └── SIMPLE_ENCRYPTION
```

---

## ECF Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<system name="eiffelmate_pro" uuid="12345678-1234-1234-1234-123456789abc">
    <target name="eiffelmate_pro">
        <root class="EIFFELMATE_CLI" feature="make"/>

        <!-- Compiler settings -->
        <option warning="true" void_safety="all" is_attached_by_default="true">
            <assertions precondition="true" postcondition="true" check="true" invariant="true"/>
        </option>

        <!-- simple_* dependencies -->
        <library name="simple_ai_client" location="$SIMPLE_EIFFEL/simple_ai_client/simple_ai_client.ecf"/>
        <library name="simple_sql" location="$SIMPLE_EIFFEL/simple_sql/simple_sql.ecf"/>
        <library name="simple_json" location="$SIMPLE_EIFFEL/simple_json/simple_json.ecf"/>
        <library name="simple_cli" location="$SIMPLE_EIFFEL/simple_cli/simple_cli.ecf"/>
        <library name="simple_logger" location="$SIMPLE_EIFFEL/simple_logger/simple_logger.ecf"/>
        <library name="simple_file" location="$SIMPLE_EIFFEL/simple_file/simple_file.ecf"/>

        <!-- Optional dependencies (conditionally included) -->
        <library name="simple_process" location="$SIMPLE_EIFFEL/simple_process/simple_process.ecf"/>
        <library name="simple_regex" location="$SIMPLE_EIFFEL/simple_regex/simple_regex.ecf"/>
        <library name="simple_markdown" location="$SIMPLE_EIFFEL/simple_markdown/simple_markdown.ecf"/>

        <!-- ISE dependencies (only when no simple_* alternative) -->
        <library name="base" location="$ISE_LIBRARY/library/base/base-safe.ecf"/>
        <library name="time" location="$ISE_LIBRARY/library/time/time-safe.ecf"/>

        <!-- Clusters -->
        <cluster name="src" location="./src/" recursive="true"/>
    </target>

    <!-- Test target -->
    <target name="eiffelmate_pro_tests" extends="eiffelmate_pro">
        <root class="TEST_APP" feature="make"/>
        <library name="simple_testing" location="$SIMPLE_EIFFEL/simple_testing/simple_testing.ecf"/>
        <cluster name="testing" location="./testing/" recursive="true"/>
    </target>
</system>
```

---

## Ecosystem Benefits

1. **Multi-provider AI**: simple_ai_client already supports Claude, OpenAI, Ollama - EiffelMate Pro gets vendor independence for free

2. **Local embeddings**: simple_sql + AI_EMBEDDING enable offline similarity search without external vector databases (Pinecone, Qdrant)

3. **Zero external dependencies**: Everything runs locally except AI API calls - no cloud services required

4. **SCOOP-safe**: All simple_* libraries are SCOOP-compatible, enabling future concurrent processing

5. **Contract-verified**: All simple_* libraries use Design by Contract, giving EiffelMate Pro production-grade reliability

6. **Consistent patterns**: Following simple_* conventions (facade pattern, builder pattern) makes integration seamless

7. **Ecosystem growth**: As more simple_* libraries are added, EiffelMate Pro automatically benefits (e.g., simple_tui for TUI version)

8. **Cost optimization**: Ollama support via simple_ai_client enables free, local AI processing for cost-sensitive users
