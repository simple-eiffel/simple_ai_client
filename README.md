<p align="center">
  <img src="docs/images/logo.svg" alt="simple_ai_client logo" width="400">
</p>

# simple_ai_client

**[Documentation](https://simple-eiffel.github.io/simple_ai_client/)** | **[GitHub](https://github.com/simple-eiffel/simple_ai_client)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Eiffel](https://img.shields.io/badge/Eiffel-25.02-blue.svg)](https://www.eiffel.org/)
[![Design by Contract](https://img.shields.io/badge/DbC-enforced-orange.svg)]()

Unified AI provider library for Eiffel applications.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

## Features

- **Multi-provider support**: Ollama (local), Claude API, **Claude Code CLI on a Claude subscription** (`CLAUDE_CODE_CLIENT`, no API key), OpenAI
- **Vector embeddings**: Semantic similarity search with local computation
- **SQLite storage**: Persistent embedding store for error resolution patterns

## Installation

1. Set environment variable (one-time setup for all simple_* libraries):
```bash
export SIMPLE_EIFFEL=/d/prod
```

2. Add to ECF:
```xml
<library name="simple_ai_client" location="$SIMPLE_EIFFEL/simple_ai_client/simple_ai_client.ecf"/>
```

## Quick Start (Zero-Configuration)

Use `SIMPLE_AI_QUICK` for the simplest possible AI operations:

```eiffel
local
    ai: SIMPLE_AI_QUICK
    answer: STRING
do
    create ai.make

    -- Use local Ollama (default, requires Ollama running)
    ai.use_ollama

    -- Or use specific Ollama model
    ai.use_ollama_model ("mistral")

    -- Or use Claude API
    ai.use_claude ("your-api-key")

    -- Simple question
    answer := ai.ask ("What is the capital of France?")

    -- With system context/role
    answer := ai.ask_as ("You are a helpful cooking assistant", "How do I make pasta?")

    -- Utility functions
    print (ai.summarize (long_text))
    print (ai.translate ("Hello, world!", "French"))
    print (ai.generate_code ("Calculate fibonacci in Python"))
    print (ai.explain_code (some_code))
    print (ai.fix_grammar ("their going to the store"))
    print (ai.extract_keywords (article_text))

    -- Error handling
    if ai.has_error then
        print ("Error: " + ai.last_error)
    end

    -- Check configuration
    print ("Provider: " + ai.provider)  -- "ollama" or "claude"
    print ("Model: " + ai.current_model)
end
```

## Standard API (Full Control)

### Chat Completion (Ollama)

```eiffel
local
    client: OLLAMA_CLIENT
    response: AI_RESPONSE
do
    create client.make
    response := client.chat ("Explain recursion in one sentence")
    if response.is_success then
        print (response.content)
    end
end
```

### Vector Embeddings

```eiffel
local
    client: OLLAMA_EMBEDDING_CLIENT
    response: AI_EMBEDDING_RESPONSE
    emb1, emb2: AI_EMBEDDING
    similarity: REAL_64
do
    create client.make

    -- Generate embeddings
    response := client.embed ("The cat sat on the mat")
    if response.is_success and then attached response.embedding as emb1 then
        response := client.embed ("A feline rested on the rug")
        if response.is_success and then attached response.embedding as emb2 then
            -- Compare (pure local math, no AI call)
            similarity := emb1.cosine_similarity (emb2)
            print ("Similarity: " + similarity.out)  -- ~0.85+
        end
    end
end
```

### Embedding Store (Error Resolution)

```eiffel
local
    db: SIMPLE_SQL_DATABASE
    client: OLLAMA_EMBEDDING_CLIENT
    store: AI_EMBEDDING_STORE
    matches: LIST [TUPLE [id: INTEGER; error_text: STRING_32; resolution_code: STRING_32; similarity: REAL_64]]
do
    create db.make ("eifmate.db")
    create client.make
    create store.make (db, client)

    -- Store a resolved error (one Ollama call)
    store.store_error_resolution (
        "VEVI: Feature `make' not found in class FOO",
        "Add creation procedure `make' to class FOO"
    )

    -- Later: find similar errors (one Ollama call + local search)
    matches := store.find_similar_errors (
        "VEVI: Feature `default_create' not found in class BAR",
        0.7,  -- threshold
        5     -- max results
    )

    across matches as m loop
        print ("Similar error (%.2f): " + m.similarity.out)
        print ("Resolution: " + m.resolution_code)
    end
end
```

### Claude Code CLI (subscription, no API key)

`CLAUDE_CODE_CLIENT` runs the locally installed `claude` CLI headless (`claude -p --output-format json`) so a Claude Pro/Max subscription pays for the call instead of a metered key. Three things it does that matter:

- It clears `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` **for the child process only** - a stale key in your environment would otherwise silently shadow the subscription login and the call would fail for lack of credit.
- The prompt travels on **stdin**, never on the command line (no 32 KB limit, no shell quoting, nothing readable through the process table); an optional system prompt goes by `--append-system-prompt-file`.
- It parses the CLI's JSON (`is_error`, `result`, `session_id`, `total_cost_usd`, `usage`) into the same `AI_RESPONSE` the other providers return.
- Sandbox flags for callers that hand untrusted text to the CLI: `set_tools_disabled` adds `--tools ""` (every built-in tool off), `set_setting_sources ("")` adds `--setting-sources ""` (no user, project or local settings file loads; managed policy settings still apply), `set_strict_mcp_config` adds `--strict-mcp-config` (only MCP servers from `--mcp-config`, so with none given, none). The pure query `extra_arguments` shows the flags exactly as they will run, and `batch_script_preview` shows the whole command. Note: CLAUDE.md files in the working directory's *ancestors* still load - placing the working directory is the caller's job.

- Sessions: `set_resume_session (a_session_id)` adds `--resume "<uuid>"` so the next call continues an earlier conversation (feed it a previous call's `last_session_id`); `clear_resume_session` returns to a fresh one. Only a UUID shape passes `is_valid_session_id`, so nothing else can ride into the generated batch line.

`timeout_seconds` is advisory until `simple_process` gains wait-with-timeout and kill. Usage: `testing/providers/claude_code/test_claude_code_client.e`.

### Claude API client hardening

`CLAUDE_CLIENT` never places the API key on the command line (curl `--variable %%ENV` + `--expand-header`), sends the body by temporary file, knows the current models (`claude-opus-5`, `claude-sonnet-5`, `claude-haiku-4-5`, `claude-fable-5`) with per-model costing, and surfaces refusals and truncation. `curl_command_preview` lets a test prove the key is absent from the command.

## Classes

| Class | Purpose |
|-------|---------|
| `SIMPLE_AI_QUICK` | Zero-configuration facade for beginners |
| `AI_EMBEDDING` | Vector with similarity operations (cosine, euclidean) |
| `AI_EMBEDDING_RESPONSE` | Response wrapper for embedding operations |
| `AI_EMBEDDING_STORE` | SQLite-backed semantic search storage |
| `OLLAMA_CLIENT` | Chat completions via Ollama |
| `OLLAMA_EMBEDDING_CLIENT` | Embeddings via Ollama `/api/embeddings` |
| `CLAUDE_CLIENT` | Chat completions via the Anthropic API (metered key) |
| `CLAUDE_CODE_CLIENT` | Chat completions through the local `claude -p` CLI, billed to the Claude.ai subscription - no API key |
| `AI_RESPONSE` | Response wrapper for chat operations |

## Embedding Models

Run `ollama pull <model>` to install:

| Model | Dimensions | Notes |
|-------|------------|-------|
| `nomic-embed-text` | 768 | Recommended, good balance |
| `mxbai-embed-large` | 1024 | Highest quality |
| `all-minilm` | 384 | Fastest, smallest |

## Dependencies

- `simple_json` - JSON parsing
- `simple_sql` - SQLite database access
- `simple_logger` - Logging for QUICK API
- `base` - EiffelBase library
- `time` - Time library (for tests)

## Performance

- **Embedding generation**: ~100-500ms per text (Ollama API call)
- **Similarity search**: ~1ms per 1000 stored items (pure Eiffel math)
- **Storage**: ~6KB per embedding (768 dims as JSON TEXT)

## License

MIT License - Copyright (c) 2025, Larry Rix
