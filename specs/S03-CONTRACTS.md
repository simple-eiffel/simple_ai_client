# S03: CONTRACTS

**Library**: simple_ai_client
**Date**: 2026-01-23
**Status**: BACKWASH (reverse-engineered from implementation)

## AI_CLIENT Contracts

### Feature: ask
```eiffel
ask (a_prompt: STRING_32): AI_RESPONSE
    require
        prompt_attached: a_prompt /= Void
        prompt_not_empty: not a_prompt.is_empty
    ensure
        result_attached: Result /= Void
        provider_matches: Result.provider ~ provider_name
```

### Feature: chat
```eiffel
chat (a_messages: ARRAY [AI_MESSAGE]): AI_RESPONSE
    require
        messages_attached: a_messages /= Void
        messages_not_empty: a_messages.count > 0
        all_messages_attached: across a_messages as ic all ic /= Void end
    ensure
        result_attached: Result /= Void
        provider_matches: Result.provider ~ provider_name
```

### Feature: set_model
```eiffel
set_model (a_model: STRING_32)
    require
        model_attached: a_model /= Void
        model_not_empty: not a_model.is_empty
    ensure
        model_set: model ~ a_model
```

## AI_MESSAGE Contracts

### Feature: make
```eiffel
make (a_role: STRING_8; a_content: STRING_32)
    require
        role_valid: valid_role (a_role)
        role_not_empty: not a_role.is_empty
        content_attached: a_content /= Void
        content_not_empty: not a_content.is_empty
        content_reasonable_length: a_content.count <= Max_reasonable_content_length
    ensure
        role_set: role = a_role
        content_set: content = a_content
        role_still_valid: valid_role (role)
```

### Invariants
```eiffel
invariant
    role_attached: role /= Void
    content_attached: content /= Void
    role_not_empty: not role.is_empty
    role_is_valid: valid_role (role)
    content_not_empty: not content.is_empty
    content_reasonable: content.count <= Max_reasonable_content_length
    exactly_one_role:
        (is_system and not is_user and not is_assistant) or
        (not is_system and is_user and not is_assistant) or
        (not is_system and not is_user and is_assistant)
```

## AI_RESPONSE Contracts

### Feature: make
```eiffel
make (a_text: STRING_32; a_model: STRING_32; a_provider: STRING_8)
    require
        text_attached: a_text /= Void
        model_attached: a_model /= Void
        model_not_empty: not a_model.is_empty
        provider_attached: a_provider /= Void
        provider_not_empty: not a_provider.is_empty
    ensure
        text_set: text = a_text
        model_set: model = a_model
        provider_set: provider = a_provider
        is_success: is_success
        not_error: not is_error
```

### Invariants
```eiffel
invariant
    provider_not_empty: not provider.is_empty
    input_tokens_non_negative: input_tokens.item >= 0
    output_tokens_non_negative: output_tokens.item >= 0
    success_xor_error: is_success = not is_error
    error_implies_message: not is_success implies attached error_message
    success_implies_model: is_success implies not model.is_empty
```

## AI_EMBEDDING Contracts

### Feature: cosine_similarity
```eiffel
cosine_similarity (other: AI_EMBEDDING): REAL_64
    require
        same_dimension: other.dimension = dimension
```

### Invariants
```eiffel
invariant
    vector_attached: vector /= Void
    source_text_attached: source_text /= Void
```
