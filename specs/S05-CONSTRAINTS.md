# S05: CONSTRAINTS

**Library**: simple_ai_client
**Date**: 2026-01-23
**Status**: BACKWASH (reverse-engineered from implementation)

## Technical Constraints

### Platform Requirements
- Windows (primary), Linux/macOS (via curl)
- curl executable must be in PATH
- Network access for cloud APIs

### Memory Constraints
- AI_MESSAGE content limit: 100,000 characters
- Embedding dimension limit: Practical limit ~4096 dimensions
- Response sizes: Provider-dependent (typically < 4KB text)

### Network Constraints
- HTTPS required for cloud providers
- HTTP allowed only for localhost (Ollama)
- Timeout: curl default (no explicit timeout yet)

### Concurrency Constraints
- Classes are NOT SCOOP-safe by default
- Each client instance should be used by single thread
- For concurrent access, create separate client instances

## API Constraints

### Claude (Anthropic)
- API Version: 2023-06-01
- Max tokens default: 4096
- Rate limits: Per-model, per-minute
- Supported models: Claude 4, Claude 4.5 family

### OpenAI
- API Version: v1
- Max tokens: Model-dependent (GPT-4: 8K/32K/128K)
- Rate limits: Tier-based

### Ollama
- Requires local server running
- Default port: 11434
- No authentication
- Model must be pulled first

## Data Constraints

### Messages
- Role must be: "system", "user", or "assistant"
- Content must be non-empty
- Content must be <= 100,000 characters

### Responses
- Provider name always required
- Model name required for success responses
- Token counts must be >= 0

### Embeddings
- Same dimension required for similarity operations
- Vector values: REAL_64 (double precision)
- Source text: Optional metadata

## Business Constraints

### Cost Tracking
- Claude pricing (per million tokens):
  - Haiku: $0.80 input, $4.00 output
  - Sonnet: $3.00 input, $15.00 output
  - Opus: $15.00 input, $75.00 output
- Prices as of implementation date, may change

### API Key Security
- Keys via environment variables only
- No key storage in code or logs
- Application responsible for secure key management
