# 7S-04: SIMPLE-STAR INTEGRATION

**Library**: simple_ai_client
**Date**: 2026-01-23
**Status**: BACKWASH (reverse-engineered from implementation)

## Ecosystem Dependencies

### Required Libraries

1. **simple_json**
   - Purpose: JSON parsing/serialization for API requests/responses
   - Classes used: SIMPLE_JSON, SIMPLE_JSON_OBJECT, SIMPLE_JSON_ARRAY, SIMPLE_JSON_VALUE
   - Critical for: All provider communication

2. **simple_process**
   - Purpose: Execute curl commands for HTTP requests
   - Classes used: SIMPLE_PROCESS_HELPER
   - Critical for: All API calls

### Optional Libraries

3. **simple_logger**
   - Purpose: API usage logging
   - Classes used: SIMPLE_LOGGER
   - Used in: CLAUDE_CLIENT logging features

4. **simple_sql**
   - Purpose: Embedding storage
   - Classes used: SIMPLE_SQL for SQLite
   - Used in: AI_EMBEDDING_STORE

5. **simple_date_time**
   - Purpose: Timestamp operations
   - Used in: Logging timestamps

## Integration Patterns

### JSON Handling
```eiffel
create l_request.make
l_request.put_string (model, Key_model)
l_request.put_array (l_messages_array, Key_messages)
l_json_body := l_request.to_json_string
```

### Process Execution
```eiffel
l_output := process_helper.shell_output (l_curl_cmd, Void)
```

### Embedding Storage
```eiffel
store.save_embedding (embedding, "doc_id", "source_text")
similar := store.find_similar (query_embedding, 10)
```

## Libraries Using simple_ai_client

1. **simple_oracle**: AI-powered code assistance
2. **Application code**: Any Eiffel app needing AI features

## Namespace Conventions

- All classes prefixed with AI_ or provider name (CLAUDE_, OLLAMA_, etc.)
- No conflicts with other simple_* libraries
