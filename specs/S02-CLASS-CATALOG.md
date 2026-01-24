# S02: CLASS CATALOG

**Library**: simple_ai_client
**Date**: 2026-01-23
**Status**: BACKWASH (reverse-engineered from implementation)

## Core Classes

### AI_CLIENT (deferred)
**Purpose**: Abstract interface for AI providers
**Inherits**: None
**Key Features**:
- `ask (prompt)`: Single prompt query
- `ask_with_system (system, prompt)`: Query with system message
- `chat (messages)`: Multi-turn conversation
- `model`: Current model name
- `provider_name`: Provider identifier
- `set_model`: Change active model
- `verbosity_level`: Response verbosity control

### AI_MESSAGE
**Purpose**: Message in AI conversation
**Inherits**: None
**Key Features**:
- `role`: system/user/assistant
- `content`: Message text
- `make_system`, `make_user`, `make_assistant`: Typed constructors
- Invariant: exactly one role is true

### AI_RESPONSE
**Purpose**: Response from AI provider
**Inherits**: None
**Key Features**:
- `text`: Response content
- `model`: Model that generated response
- `provider`: Provider identifier
- `is_success`, `is_error`: Status flags
- `input_tokens`, `output_tokens`: Token counts
- `error_message`: Error details if failed

### AI_EMBEDDING
**Purpose**: Vector embedding with similarity operations
**Inherits**: None
**Key Features**:
- `vector`: Float array of dimensions
- `cosine_similarity (other)`: Similarity measure
- `euclidean_distance (other)`: Distance measure
- `to_json_array`, `to_blob`: Serialization

### AI_EMBEDDING_RESPONSE
**Purpose**: Response from embedding API
**Inherits**: None
**Key Features**:
- `embedding`: The computed embedding
- `is_success`, `is_error`: Status flags

## Provider Classes

### CLAUDE_CLIENT
**Purpose**: Anthropic Claude API client
**Inherits**: AI_CLIENT
**Key Features**:
- Supports Claude 4/4.5 models
- Token usage tracking
- Cost estimation
- File/stderr/logger logging
- `use_sonnet`, `use_opus`, `use_haiku`: Model shortcuts

### OLLAMA_CLIENT
**Purpose**: Local Ollama server client
**Inherits**: AI_CLIENT
**Key Features**:
- `list_models`: Get available models
- `is_available`: Server connectivity check
- Custom base URL support

### OPENAI_CLIENT
**Purpose**: OpenAI API client
**Inherits**: AI_CLIENT
**Key Features**:
- GPT-4, GPT-3.5-turbo support
- Standard OpenAI Chat Completions API

### GOOGLE_AI_CLIENT
**Purpose**: Google Gemini API client
**Inherits**: AI_CLIENT
**Key Features**:
- Gemini Pro model support

### GROK_CLIENT
**Purpose**: xAI Grok API client
**Inherits**: AI_CLIENT
**Key Features**:
- OpenAI-compatible API structure

### OLLAMA_EMBEDDING_CLIENT
**Purpose**: Ollama embedding generation
**Inherits**: None
**Key Features**:
- `embed (text)`: Generate embedding
- Local model support

## Storage Classes

### AI_EMBEDDING_STORE
**Purpose**: SQLite-based embedding storage
**Inherits**: None
**Key Features**:
- `save_embedding`: Store embedding with metadata
- `find_similar`: Similarity search
- `delete_embedding`: Remove by ID
