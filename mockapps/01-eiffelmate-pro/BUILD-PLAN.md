# EiffelMate Pro - Build Plan

**Date**: 2026-01-24
**Version**: 1.0.0
**Status**: Design Complete, Ready for Implementation

## Phase Overview

| Phase | Deliverable | Effort | Dependencies |
|-------|-------------|--------|--------------|
| Phase 1 | MVP CLI (fix + contract commands) | 2-3 weeks | simple_ai_client, simple_sql, simple_json, simple_cli |
| Phase 2 | Full CLI (all commands) | 2-3 weeks | Phase 1 complete |
| Phase 3 | Production Polish | 1-2 weeks | Phase 2 complete |
| Phase 4 | Enterprise Features (optional) | 3-4 weeks | Phase 3 complete, customer demand validated |

---

## Phase 1: MVP (Minimum Viable Product)

### Objective

Deliver core value proposition: error resolution and contract generation. Prove that AI-powered Eiffel assistance is valuable enough that developers will pay for it.

### Deliverables

1. **EIFFELMATE_CLI** - Basic CLI with argument parsing
2. **ERROR_ANALYZER** - Parse errors, find similar errors, suggest fixes
3. **KNOWLEDGE_BASE** - SQLite storage for error patterns and embeddings
4. **AI_ORCHESTRATOR** - Multi-provider AI access with fallback
5. **EIFFELMATE_CONFIG** - JSON configuration file support
6. **Two working commands**: `eiffelmate fix` and `eiffelmate contract`

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T1.1 | Set up ECF project with dependencies | Compiles without errors, all simple_* libraries linked |
| T1.2 | Implement EIFFELMATE_CONFIG | Loads ~/.eiffelmate.json, validates provider config, sets defaults |
| T1.3 | Implement AI_ORCHESTRATOR | Selects provider, handles fallback, tracks costs/tokens |
| T1.4 | Implement KNOWLEDGE_BASE schema | SQLite tables created, indexes added, basic CRUD operations |
| T1.5 | Implement ERROR_ANALYZER.parse_error | Parses VEVI, VD89, SCOOP errors into ERROR_PATTERN object |
| T1.6 | Implement ERROR_ANALYZER.find_similar | Searches knowledge base using cosine similarity |
| T1.7 | Implement ERROR_ANALYZER.generate_fix | Calls AI to explain error and suggest fix |
| T1.8 | Implement EIFFELMATE_CLI.fix | End-to-end `eiffelmate fix` command works |
| T1.9 | Implement CONTRACT_GENERATOR | Analyzes Eiffel feature, suggests contracts via AI |
| T1.10 | Implement EIFFELMATE_CLI.contract | End-to-end `eiffelmate contract` command works |
| T1.11 | Write unit tests | 80%+ code coverage for core classes |
| T1.12 | Create sample error database | Seed with 20+ common Eiffel errors for demo |
| T1.13 | Write user documentation | README with installation, usage examples, config guide |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| TC1.1 | `eiffelmate fix "VEVI: make not found"` | Explains VEVI, suggests adding `make` to creation clause, confidence 90%+ |
| TC1.2 | `eiffelmate fix --clipboard` (SCOOP error) | Detects SCOOP violation, explains separate keyword, suggests fix |
| TC1.3 | `eiffelmate fix` (same error as TC1.1) | Finds similar error from TC1.1 in knowledge base, shows past resolution |
| TC1.4 | `eiffelmate contract src/stack.e:push` | Generates `not_full` precondition, `count_increased` postcondition |
| TC1.5 | Invalid config file | Shows clear error message, falls back to defaults |
| TC1.6 | Ollama unavailable, Claude configured | Automatically falls back to Claude |
| TC1.7 | No API keys configured | Shows helpful setup message, points to config docs |

### Success Criteria

| Criterion | Measure | Target |
|-----------|---------|--------|
| Compiles | Zero errors | 100% |
| Tests pass | All unit tests | 100% |
| Demo works | Fix 5 different error types | All succeed |
| Config loads | Valid and invalid JSON | Handles both |
| Fallback works | Primary provider down | Succeeds with secondary |
| Documentation | README complete | Yes |

---

## Phase 2: Full Implementation

### Objective

Add remaining commands to create a complete CLI tool ready for public beta. Enable users to generate code, search knowledge base, review contracts, and manage configuration.

### Deliverables

1. **CODE_GENERATOR** - Generate Eiffel classes from natural language
2. **CONTRACT_REVIEWER** - Analyze codebase for contract completeness
3. **Commands**: `generate`, `learn`, `search`, `review`, `config`, `stats`
4. **Output formats**: Text, JSON, Markdown
5. **Advanced error parsing**: Support all Eiffel compiler error codes
6. **Template system**: Code generation templates for simple_* patterns

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T2.1 | Implement CODE_GENERATOR.generate_class | Takes natural language spec, generates Eiffel class with contracts |
| T2.2 | Create code templates | Templates for common patterns (builder, facade, SCOOP-safe) |
| T2.3 | Implement `eiffelmate generate` | End-to-end code generation command |
| T2.4 | Implement `eiffelmate learn` | Store user-provided error resolutions |
| T2.5 | Implement `eiffelmate search` | Natural language search of knowledge base |
| T2.6 | Implement CONTRACT_REVIEWER | Scan files for missing/weak contracts |
| T2.7 | Implement `eiffelmate review` | Generate contract review reports |
| T2.8 | Implement `eiffelmate config` | Show/edit configuration interactively |
| T2.9 | Implement `eiffelmate stats` | Show usage analytics (tokens, costs, errors fixed) |
| T2.10 | Add output formatters | Support --output text|json|markdown |
| T2.11 | Expand error parser | Handle all common Eiffel error codes |
| T2.12 | Add telemetry (opt-in) | Track usage for product improvements |
| T2.13 | Write integration tests | Test multi-command workflows |
| T2.14 | Update documentation | Complete command reference, examples |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| TC2.1 | `eiffelmate generate "sorted array with binary search"` | Generates complete SORTED_ARRAY class with contracts and tests |
| TC2.2 | `eiffelmate learn "VEVI: foo" "Added foo to creation"` | Stores in knowledge base, confirms storage |
| TC2.3 | `eiffelmate search "void safety"` | Returns relevant past errors and resolutions |
| TC2.4 | `eiffelmate review src/` | Generates markdown report with missing contracts |
| TC2.5 | `eiffelmate config show` | Displays current configuration |
| TC2.6 | `eiffelmate stats` | Shows total errors fixed, tokens used, cost |
| TC2.7 | `eiffelmate fix --output json` | Returns JSON response |
| TC2.8 | `eiffelmate generate --tests` | Includes test suite in generated code |

### Success Criteria

| Criterion | Measure | Target |
|-----------|---------|--------|
| All commands work | Manual testing of each | 100% |
| Output formats | JSON, markdown, text all valid | 100% |
| Code generation quality | Generated code compiles | 90%+ |
| Review accuracy | Correctly identifies missing contracts | 85%+ |
| Documentation | All commands documented with examples | Yes |

---

## Phase 3: Production Polish

### Objective

Harden the application for production use: error handling, performance optimization, security hardening, comprehensive testing, professional documentation.

### Deliverables

1. **Robust error handling** - Graceful failures, helpful error messages
2. **Performance optimization** - Fast embedding search, cached AI responses
3. **Security hardening** - Encrypt API keys, validate inputs, sanitize outputs
4. **Comprehensive tests** - Unit, integration, end-to-end, stress tests
5. **Professional docs** - User guide, API reference, troubleshooting
6. **Packaging** - Easy installation (binary releases, package managers)

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T3.1 | Add comprehensive error handling | All error paths tested, user-friendly messages |
| T3.2 | Optimize embedding search | <100ms for 1000 stored errors |
| T3.3 | Add response caching | Identical prompts don't re-query AI |
| T3.4 | Encrypt API keys | Keys stored encrypted, decrypted at runtime |
| T3.5 | Input validation | Sanitize all user inputs, prevent injection |
| T3.6 | Output sanitization | Prevent code injection in generated code |
| T3.7 | Add stress tests | Test with 10,000+ errors in knowledge base |
| T3.8 | Add end-to-end tests | Realistic workflows from start to finish |
| T3.9 | Write troubleshooting guide | Common issues and solutions |
| T3.10 | Create video tutorials | 5-minute quickstart, 20-minute deep dive |
| T3.11 | Build binary releases | Windows, Linux, macOS executables |
| T3.12 | Package for distribution | Homebrew, Chocolatey, apt/yum repos |
| T3.13 | Set up CI/CD | Automated tests, builds, releases |
| T3.14 | Security audit | External review or automated scanning |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| TC3.1 | Malformed JSON config | Clear error, suggests fix |
| TC3.2 | 10,000 errors in KB, similarity search | <100ms response time |
| TC3.3 | Same prompt twice | Second call instant (cached) |
| TC3.4 | API key visible in config | Encrypted in file, decrypted at load |
| TC3.5 | Malicious input (`rm -rf /` in prompt) | Sanitized, safe |
| TC3.6 | Network failure during AI call | Graceful retry with backoff |
| TC3.7 | Concurrent commands | No database corruption |
| TC3.8 | Large codebase review (1000+ files) | Completes without crash |

### Success Criteria

| Criterion | Measure | Target |
|-----------|---------|--------|
| Error handling | No uncaught exceptions | 100% |
| Performance | Embedding search <100ms | Yes |
| Security | Pass security audit | Yes |
| Test coverage | Line coverage | 85%+ |
| Documentation | User guide + API ref complete | Yes |
| Packaging | Binary releases for 3 platforms | Yes |

---

## Phase 4: Enterprise Features (Optional)

### Objective

Add features required for enterprise customers: team collaboration, SSO, audit logs, custom AI fine-tuning, on-premise deployment.

### Deliverables

1. **Team knowledge base sync** - Shared embedding store across team
2. **SSO integration** - SAML, OAuth for enterprise auth
3. **Audit logs** - Compliance-grade activity logging
4. **Custom AI fine-tuning** - Train on company codebase
5. **On-premise deployment** - Docker, Kubernetes support
6. **Admin dashboard** - Web UI for team management

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T4.1 | Implement team sync server | REST API for knowledge base sync |
| T4.2 | Add conflict resolution | Handle concurrent knowledge base updates |
| T4.3 | Implement SSO (SAML) | Integrate with Okta, Azure AD |
| T4.4 | Add audit logging | Log all commands, AI calls, config changes |
| T4.5 | Create fine-tuning pipeline | Train custom model on customer code |
| T4.6 | Build Docker images | One-command deployment |
| T4.7 | Add Kubernetes manifests | Scalable deployment |
| T4.8 | Build admin dashboard | Web UI for user/team management |
| T4.9 | Add analytics | Usage trends, error hotspots, cost attribution |
| T4.10 | Enterprise documentation | Deployment guide, admin manual |

### Success Criteria

| Criterion | Measure | Target |
|-----------|---------|--------|
| Team sync works | 10 users concurrently updating | No conflicts |
| SSO integrated | Works with major IdPs | Yes |
| Audit logs complete | All actions logged | 100% |
| Custom fine-tuning | Improves accuracy for customer | 10%+ |
| Deployment | <30min from zero to running | Yes |

---

## ECF Target Structure

```xml
<!-- Library target (reusable core) -->
<target name="eiffelmate_pro">
    <!-- Core classes without CLI entry point -->
</target>

<!-- CLI executable target -->
<target name="eiffelmate_pro_cli" extends="eiffelmate_pro">
    <root class="EIFFELMATE_CLI" feature="make"/>
    <setting name="executable_name" value="eiffelmate"/>
</target>

<!-- Test target -->
<target name="eiffelmate_pro_tests" extends="eiffelmate_pro">
    <root class="TEST_APP" feature="make"/>
    <library name="simple_testing" location="$SIMPLE_EIFFEL/simple_testing/simple_testing.ecf"/>
    <cluster name="testing" location="./testing/" recursive="true"/>
</target>
```

---

## Build Commands

### Compile CLI (Development)

```bash
# Workbench build (fast, for development)
/d/prod/ec.sh -batch -config eiffelmate_pro.ecf -target eiffelmate_pro_cli -c_compile

# Run
./EIFGENs/eiffelmate_pro_cli/W_code/eiffelmate.exe
```

### Compile CLI (Production)

```bash
# Finalized build (optimized, for release)
/d/prod/ec.sh -batch -config eiffelmate_pro.ecf -target eiffelmate_pro_cli -finalize -c_compile

# Run
./EIFGENs/eiffelmate_pro_cli/F_code/eiffelmate.exe
```

### Run Tests

```bash
# Compile tests
/d/prod/ec.sh -batch -config eiffelmate_pro.ecf -target eiffelmate_pro_tests -c_compile

# Run tests
./EIFGENs/eiffelmate_pro_tests/W_code/eiffelmate.exe

# Expected output:
# EiffelMate Pro Test Suite
# =========================
# ERROR_ANALYZER tests: 15/15 PASS
# CONTRACT_GENERATOR tests: 12/12 PASS
# CODE_GENERATOR tests: 10/10 PASS
# KNOWLEDGE_BASE tests: 18/18 PASS
# AI_ORCHESTRATOR tests: 8/8 PASS
# CLI tests: 14/14 PASS
# =========================
# TOTAL: 77/77 PASS (100%)
```

---

## Release Checklist

### Pre-Release

- [ ] All Phase 1 tasks complete
- [ ] All Phase 2 tasks complete
- [ ] All Phase 3 tasks complete
- [ ] Test suite passes (100%)
- [ ] Documentation complete (README, user guide, API reference)
- [ ] Binary builds for Windows, Linux, macOS
- [ ] Security audit passed
- [ ] Beta testers validated (10+ users)

### Release (v1.0.0)

- [ ] Tag release in git (`git tag v1.0.0`)
- [ ] Build binaries (finalized builds)
- [ ] Upload to GitHub Releases
- [ ] Publish to package managers (Homebrew, Chocolatey)
- [ ] Update website (simple-eiffel.github.io/eiffelmate-pro)
- [ ] Announce on Eiffel forums, mailing lists
- [ ] Tweet/blog post about launch
- [ ] Email beta testers with launch link

### Post-Release

- [ ] Monitor error reports (GitHub issues)
- [ ] Track usage analytics (opt-in telemetry)
- [ ] Gather user feedback (surveys, interviews)
- [ ] Plan Phase 4 (enterprise features) based on demand
- [ ] Iterate on bug fixes and feature requests

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| AI accuracy insufficient | Combine AI with rule-based patterns, gather user feedback, fine-tune prompts |
| API costs too high | Default to Ollama (free), charge enough to cover paid APIs, offer local-only tier |
| Eiffel market too small | Validate with surveys before Phase 2, pivot to Ada/Spark if needed |
| Integration complexity | Start simple (text I/O), defer EiffelStudio integration to Phase 2+ |
| Security vulnerabilities | Encrypt API keys, sanitize inputs/outputs, external security audit |
| Performance issues | Optimize embedding search, cache AI responses, profile hot paths |

---

## Success Metrics (6 Months Post-Launch)

| Metric | Target |
|--------|--------|
| Active users | 100+ |
| Paying customers | 30+ |
| MRR (Monthly Recurring Revenue) | $2,000+ |
| Customer retention | 85%+ |
| NPS (Net Promoter Score) | 40+ |
| Errors fixed via EiffelMate | 1,000+ |
| Knowledge base size | 500+ error patterns |
| Average resolution time | <5 minutes (down from 30+ minutes) |
