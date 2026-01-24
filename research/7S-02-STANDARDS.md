# 7S-02: STANDARDS

**Library**: simple_ai_client
**Date**: 2026-01-23
**Status**: BACKWASH (reverse-engineered from implementation)

## Applicable Standards

### API Specifications

1. **Anthropic Messages API**
   - Version: 2023-06-01
   - Documentation: https://docs.anthropic.com/en/api/messages
   - Authentication: x-api-key header
   - Rate limits: Per-model tiered limits

2. **OpenAI Chat Completions API**
   - Version: v1
   - Documentation: https://platform.openai.com/docs/api-reference/chat
   - Authentication: Bearer token
   - Streaming: SSE (not yet implemented)

3. **Google AI (Gemini) API**
   - Documentation: https://ai.google.dev/docs
   - Authentication: API key
   - Models: gemini-pro, gemini-pro-vision

4. **Ollama API**
   - Endpoints: /api/chat, /api/tags, /api/embeddings
   - Documentation: https://github.com/ollama/ollama/blob/main/docs/api.md
   - Local server: http://localhost:11434
   - No authentication required

5. **xAI Grok API**
   - API structure similar to OpenAI
   - Authentication: Bearer token

### Data Formats

1. **JSON**: All API communication uses JSON (RFC 8259)
2. **UTF-8**: All text content encoded as UTF-8
3. **Base64**: Used for binary data where needed

### Security Standards

1. **HTTPS**: All cloud API calls over TLS 1.2+
2. **API Keys**: Environment variable storage (ANTHROPIC_API_KEY, etc.)
3. **No key logging**: API keys never written to logs

## Compliance Notes

- Token counting uses provider-specific tokenizers
- Cost estimation based on public pricing as of implementation date
- Rate limiting handled by retry logic (not yet implemented)
