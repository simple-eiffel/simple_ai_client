# 7S-01: SCOPE

**Library**: simple_ai_client
**Date**: 2026-01-23
**Status**: BACKWASH (reverse-engineered from implementation)

## Problem Domain

Unified AI provider client library enabling Eiffel applications to interact with multiple Large Language Model (LLM) APIs through a consistent interface. The library abstracts provider-specific API differences, allowing developers to switch between AI providers without code changes.

## Target Users

1. **Eiffel developers** building AI-powered applications
2. **Enterprise teams** requiring multi-provider AI strategy
3. **Researchers** comparing AI model outputs across providers
4. **Automation systems** using AI for text generation/analysis

## Primary Use Cases

1. Single-prompt text generation (ask)
2. System-instructed queries (ask_with_system)
3. Multi-turn conversations (chat)
4. Vector embeddings generation
5. Embedding similarity search
6. Token usage tracking and cost estimation

## Boundaries

### In Scope
- Text completion/chat APIs for Claude, OpenAI, Google, Grok, Ollama
- Vector embedding generation and storage
- Token counting and cost tracking
- Verbosity control (concise/normal/verbose)
- Local (Ollama) and cloud provider support

### Out of Scope
- Image generation APIs
- Audio transcription (use simple_speech)
- Fine-tuning APIs
- Streaming responses (planned for Phase 2)
- Function calling/tool use (planned for Phase 3)

## Dependencies

- simple_json: JSON parsing/generation
- simple_process: curl-based HTTP requests
- simple_logger: Optional logging
- simple_sql: Embedding storage (optional)
