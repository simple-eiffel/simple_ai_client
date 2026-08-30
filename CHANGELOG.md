# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `CLAUDE_CODE_CLIENT`: chat completions through the local `claude -p --output-format json` CLI on a Claude subscription (no API key); clears `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` for the child only; prompt by stdin; parses `is_error`, `result`, `session_id`, `total_cost_usd`, `usage`

### Changed
- `CLAUDE_CLIENT`: current models (`claude-opus-5`, `claude-sonnet-5`, `claude-haiku-4-5`, `claude-fable-5`) with per-model costing; refusal and truncation surfaced; `curl_command_preview` for tests

### Security
- `CLAUDE_CLIENT`: the API key is never on the command line (curl `--variable`/`--expand-header`; it was visible to every process before); the request body goes by temporary file

### Changed
- Testing config updates, AutoTest fixes, .gitignore cleanup
- Add SCOOP concurrency capability
- Migrate to simple_testing library
- Add Claude API client and update embedding store tests
- Replace framework with simple_process, use environment variables
- removed log
- Add vector embedding support for semantic similarity search
- Test clean-up on test_architecture_task
- init add and commit
- first commit

## [1.0.0] - 2025-12-08

### Added
- Initial release
- Core functionality implemented
- Test suite with comprehensive coverage
- Documentation and examples

[Unreleased]: https://github.com/simple-eiffel/simple_ai_client/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/simple-eiffel/simple_ai_client/releases/tag/v1.0.0
