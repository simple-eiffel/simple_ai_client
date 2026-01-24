# 7S-05: SECURITY

**Library**: simple_ai_client
**Date**: 2026-01-23
**Status**: BACKWASH (reverse-engineered from implementation)

## Security Considerations

### API Key Management

1. **Environment Variables**: Primary key storage
   - ANTHROPIC_API_KEY for Claude
   - OPENAI_API_KEY for OpenAI
   - GOOGLE_AI_KEY for Google
   - Keys never hardcoded

2. **Runtime Key Setting**: `set_api_key` feature
   - Allows programmatic key setting
   - Caller responsible for secure key retrieval

3. **No Key Logging**: API keys excluded from all logs
   - Usage logging shows model/tokens, not keys
   - Error messages never include keys

### Data Transmission

1. **HTTPS Only**: All cloud API calls use HTTPS
   - TLS 1.2+ enforced by curl
   - Certificate validation enabled

2. **Local Ollama**: HTTP allowed for localhost only
   - Default: http://localhost:11434
   - No sensitive data over unencrypted network

### Prompt/Response Security

1. **No Local Storage**: Prompts/responses not persisted by library
   - Application responsible for any caching
   - Embeddings stored separately via AI_EMBEDDING_STORE

2. **Content Limits**: Max 100KB per message
   - Prevents accidental large payload transmission
   - Enforced by AI_MESSAGE invariant

### Threat Mitigation

| Threat | Mitigation |
|--------|------------|
| API key exposure | Environment variables, no logging |
| Man-in-middle | HTTPS for cloud APIs |
| Prompt injection | Application responsibility |
| Token exhaustion | Usage tracking, cost estimation |
| Denial of service | Timeout on curl (not yet implemented) |

### Audit Capabilities

1. **Usage Logging**: Optional logging to file/stderr/SIMPLE_LOGGER
2. **Request Tracking**: request_count, total_tokens tracked
3. **Cost Estimation**: estimated_cost for budget monitoring

### Recommendations

1. Rotate API keys regularly
2. Use separate keys for dev/prod
3. Monitor usage via provider dashboards
4. Set spending limits in provider accounts
