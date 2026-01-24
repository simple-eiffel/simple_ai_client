# S04: FEATURE SPECIFICATIONS

**Library**: simple_ai_client
**Date**: 2026-01-23
**Status**: BACKWASH (reverse-engineered from implementation)

## AI_CLIENT Features

### ask (a_prompt: STRING_32): AI_RESPONSE
**Purpose**: Send single prompt to AI, get response
**Behavior**: Internally calls chat_with_system with Void system message
**Returns**: AI_RESPONSE with text or error

### ask_with_system (a_system, a_prompt: STRING_32): AI_RESPONSE
**Purpose**: Send prompt with system instructions
**Behavior**: Combines system message with user prompt
**Returns**: AI_RESPONSE with text or error

### chat (a_messages: ARRAY [AI_MESSAGE]): AI_RESPONSE
**Purpose**: Full multi-turn conversation
**Behavior**: Sends message array to provider
**Returns**: AI_RESPONSE with assistant reply

### set_verbosity (a_level: INTEGER)
**Purpose**: Control response detail level
**Valid Values**: Verbosity_concise (1), Verbosity_normal (2), Verbosity_verbose (3)
**Effect**: Prepends verbosity instruction to system messages

## CLAUDE_CLIENT Features

### use_sonnet, use_opus, use_haiku
**Purpose**: Quick model selection
**Effect**: Sets model to corresponding Claude 4.5 version

### estimated_cost: REAL_64
**Purpose**: Calculate session cost in USD
**Behavior**: Sums per-model costs (haiku_cost + sonnet_cost + opus_cost)
**Formula**: (input_tokens * input_price + output_tokens * output_price) / 1_000_000

### enable_file_logging (a_path: STRING_32)
**Purpose**: Log API usage to file
**Creates**: File if doesn't exist, appends otherwise
**Logs**: Model, tokens, session totals, estimated cost

### usage_summary: STRING_32
**Purpose**: Human-readable usage report
**Includes**: Request count, token totals, per-model breakdown, costs

## AI_EMBEDDING Features

### cosine_similarity (other: AI_EMBEDDING): REAL_64
**Purpose**: Measure semantic similarity
**Formula**: dot_product / (magnitude_self * magnitude_other)
**Range**: -1.0 to 1.0 (clamped)

### euclidean_distance (other: AI_EMBEDDING): REAL_64
**Purpose**: Measure vector distance
**Formula**: sqrt(sum((v1[i] - v2[i])^2))
**Use Case**: When direction matters less than magnitude

### to_blob: MANAGED_POINTER
**Purpose**: Serialize for storage
**Format**: Raw REAL_64 bytes (8 bytes per dimension)
**Use**: SQLite BLOB storage

### make_from_blob (a_blob: MANAGED_POINTER)
**Purpose**: Deserialize from storage
**Requirement**: Blob size must be multiple of 8

## AI_EMBEDDING_STORE Features

### save_embedding (embedding, doc_id, text)
**Purpose**: Store embedding with metadata
**Creates**: SQLite table if needed
**Stores**: Vector blob, document ID, source text, timestamp

### find_similar (query: AI_EMBEDDING; limit: INTEGER): ARRAYED_LIST
**Purpose**: Find most similar stored embeddings
**Algorithm**: Cosine similarity ranking
**Returns**: List of (doc_id, similarity) tuples
