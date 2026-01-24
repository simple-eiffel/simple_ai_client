# 7S-03: SOLUTIONS

**Library**: simple_ai_client
**Date**: 2026-01-23
**Status**: BACKWASH (reverse-engineered from implementation)

## Existing Solutions Comparison

### Direct API Clients

| Solution | Pros | Cons |
|----------|------|------|
| Provider SDKs (Python) | Official, well-maintained | Language-specific, no Eiffel |
| curl commands | Universal | Manual JSON handling, no abstraction |
| REST libraries | Flexible | No AI-specific features |

### Multi-Provider Libraries

| Solution | Pros | Cons |
|----------|------|------|
| LangChain | Feature-rich, many providers | Python only, heavy |
| LiteLLM | Unified API | Python only |
| Semantic Kernel | Microsoft-backed | .NET/Python only |

### Eiffel Ecosystem

No existing Eiffel libraries for AI provider access prior to simple_ai_client.

## Why Build simple_ai_client?

1. **No Eiffel Alternative**: First Eiffel library for unified AI access
2. **Design by Contract**: Proper preconditions/postconditions for AI operations
3. **Simple Ecosystem Integration**: Works with simple_json, simple_process
4. **Provider Agnostic**: Easy to switch between Claude/OpenAI/Ollama
5. **Cost Tracking**: Built-in token and cost estimation

## Design Decisions

1. **curl-based HTTP**: Uses SIMPLE_PROCESS_HELPER for HTTP calls
   - Avoids complex HTTP library dependencies
   - Works on all platforms with curl

2. **Deferred AI_CLIENT**: Abstract base class pattern
   - Providers implement execute_chat
   - Common logic in base class

3. **Verbosity System**: Three-level verbosity control
   - Concise: Brief, direct answers
   - Normal: Standard detail
   - Verbose: Comprehensive explanations

4. **CELL for Token Counts**: Mutable token tracking
   - Updated after API call completes
   - Allows response modification
