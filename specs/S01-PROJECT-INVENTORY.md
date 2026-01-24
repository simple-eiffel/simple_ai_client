# S01: PROJECT INVENTORY

**Library**: simple_ai_client
**Date**: 2026-01-23
**Status**: BACKWASH (reverse-engineered from implementation)

## Project Structure

```
simple_ai_client/
├── simple_ai_client.ecf         # Library configuration
├── src/
│   ├── core/
│   │   ├── ai_client.e          # Deferred provider interface
│   │   ├── ai_message.e         # Conversation message
│   │   ├── ai_response.e        # API response wrapper
│   │   ├── ai_embedding.e       # Vector embedding
│   │   ├── ai_embedding_response.e  # Embedding API response
│   │   └── simple_ai_quick.e    # Quick-start facade
│   ├── providers/
│   │   ├── claude/
│   │   │   └── claude_client.e  # Anthropic Claude client
│   │   ├── openai/
│   │   │   └── openai_client.e  # OpenAI client
│   │   ├── google/
│   │   │   └── google_ai_client.e  # Google Gemini client
│   │   ├── grok/
│   │   │   └── grok_client.e    # xAI Grok client
│   │   └── ollama/
│   │       ├── ollama_client.e  # Ollama client
│   │       └── ollama_embedding_client.e  # Ollama embeddings
│   └── storage/
│       └── ai_embedding_store.e # SQLite embedding storage
├── testing/
│   ├── test_app.e               # Test application root
│   ├── lib_tests.e              # Test suite runner
│   ├── core/
│   │   └── test_ai_embedding.e  # Embedding tests
│   ├── providers/
│   │   ├── claude/
│   │   │   └── test_claude_client.e
│   │   └── ollama/
│   │       ├── test_ollama_client.e
│   │       └── test_ollama_embedding_client.e
│   └── storage/
│       └── test_ai_embedding_store.e
└── research/                    # This directory
└── specs/                       # Specification directory
```

## File Count Summary

| Category | Files |
|----------|-------|
| Core source | 6 |
| Provider source | 6 |
| Storage source | 1 |
| Test files | 7 |
| Configuration | 1 |
| **Total** | **21** |

## External Dependencies

- EiffelBase (standard library)
- simple_json (JSON handling)
- simple_process (curl execution)
- simple_logger (optional logging)
- simple_sql (embedding storage)
- simple_date_time (timestamps)
