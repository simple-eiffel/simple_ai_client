<p align="center">
  <img src="https://raw.githubusercontent.com/simple-eiffel/claude_eiffel_op_docs/main/artwork/LOGO.png" alt="simple_ library logo" width="400">
</p>

# simple_ai_client

**[Documentation](https://simple-eiffel.github.io/simple_ai_client/)** | **[GitHub](https://github.com/simple-eiffel/simple_ai_client)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Eiffel](https://img.shields.io/badge/Eiffel-25.02-blue.svg)](https://www.eiffel.org/)
[![Design by Contract](https://img.shields.io/badge/DbC-enforced-orange.svg)]()

Unified AI provider library for Eiffel applications.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

## Features

- **Multi-provider support**: Ollama (local), Claude, OpenAI
- **Vector embeddings**: Semantic similarity search with local computation
- **SQLite storage**: Persistent embedding store for error resolution patterns

## Installation

1. Set environment variable:
```bash
export SIMPLE_AI_CLIENT=/path/to/simple_ai_client
```

2. Add to ECF:
```xml
<library name="simple_ai_client" location="$SIMPLE_AI_CLIENT/simple_ai_client.ecf"/>
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

## Classes

| Class | Purpose |
|-------|---------|
| `SIMPLE_AI_QUICK` | Zero-configuration facade for beginners |
| `AI_EMBEDDING` | Vector with similarity operations (cosine, euclidean) |
| `AI_EMBEDDING_RESPONSE` | Response wrapper for embedding operations |
| `AI_EMBEDDING_STORE` | SQLite-backed semantic search storage |
| `OLLAMA_CLIENT` | Chat completions via Ollama |
| `OLLAMA_EMBEDDING_CLIENT` | Embeddings via Ollama `/api/embeddings` |
| `CLAUDE_CLIENT` | Chat completions via Anthropic Claude |
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
