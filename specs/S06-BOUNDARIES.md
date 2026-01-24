# S06: BOUNDARIES

**Library**: simple_ai_client
**Date**: 2026-01-23
**Status**: BACKWASH (reverse-engineered from implementation)

## System Boundaries

### External Systems

```
┌─────────────────────────────────────────────────────────────┐
│                     Eiffel Application                       │
├─────────────────────────────────────────────────────────────┤
│                    simple_ai_client                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │  AI_CLIENT  │ │ AI_MESSAGE  │ │    AI_EMBEDDING     │   │
│  │  (deferred) │ │             │ │                     │   │
│  └──────┬──────┘ └─────────────┘ └─────────────────────┘   │
│         │                                                    │
│  ┌──────┴───────────────────────────────────────────────┐  │
│  │                    Providers                          │  │
│  │  CLAUDE_CLIENT | OLLAMA_CLIENT | OPENAI_CLIENT | ... │  │
│  └──────────────────────────┬───────────────────────────┘  │
└─────────────────────────────┼───────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Anthropic API   │  │  Ollama Server  │  │   OpenAI API    │
│ (HTTPS)         │  │  (HTTP local)   │  │   (HTTPS)       │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Internal Dependencies

```
simple_ai_client
       │
       ├── simple_json (JSON handling)
       │      └── SIMPLE_JSON, SIMPLE_JSON_OBJECT, SIMPLE_JSON_ARRAY
       │
       ├── simple_process (HTTP via curl)
       │      └── SIMPLE_PROCESS_HELPER
       │
       ├── simple_logger (optional logging)
       │      └── SIMPLE_LOGGER
       │
       └── simple_sql (embedding storage)
              └── SIMPLE_SQL
```

## Interface Boundaries

### Public API Surface
- AI_CLIENT (deferred): Core interface
- AI_MESSAGE: Message construction
- AI_RESPONSE: Response handling
- AI_EMBEDDING: Vector operations
- CLAUDE_CLIENT, OLLAMA_CLIENT, etc.: Provider clients

### Internal (Not Public)
- execute_chat: Provider implementation detail
- build_curl_command: HTTP construction
- parse_response: JSON parsing
- callback_registry: Internal storage

## Data Flow Boundaries

### Input Boundary
- Prompts/messages from application
- API keys from environment
- Configuration (model, verbosity)

### Output Boundary
- AI_RESPONSE objects to application
- AI_EMBEDDING objects for storage
- Error messages on failure

### Storage Boundary
- AI_EMBEDDING_STORE: SQLite database
- No direct file I/O in core classes
- Logging via SIMPLE_LOGGER or file

## Security Boundaries

### Trusted Zone
- Application code
- simple_ai_client library
- Local Ollama server

### Untrusted Zone
- Cloud API responses (validated)
- User input (prompts)
- Network transport (use HTTPS)
