note
	description: "[
		Abstract AI client interface for multiple providers.
		
		Provides unified interface for interacting with different AI providers
		(Ollama, Claude, Gemini, etc.) through a common API. All providers
		implement this deferred class to ensure consistent behavior.
		
		Core Operations:
		- ask: Single prompt query
		- ask_with_system: Query with system instructions
		- chat: Multi-turn conversation with message history
		
		Message Handling:
		All operations internally convert to the chat format (array of messages)
		which is the lowest-level operation. This ensures consistent behavior
		across all providers regardless of their native API structure.
		
		Design by Contract:
		- All prompts and messages must be non-empty
		- Message arrays must contain at least one message
		- Responses are always attached (never Void)
		- Model names must be non-empty strings
		
		Descendants must implement:
		- model: Current model name
		- provider_name: Provider identifier
		- set_model: Change active model
		- execute_chat: Provider-specific chat implementation
		- is_valid_model: Model validation
		- supported_models: List of supported model identifiers
	]"
	date: "$Date$"
	revision: "$Revision$"

deferred class
	AI_CLIENT

feature -- Access

	model: STRING_32
			-- Current model name (e.g., "llama3", "claude-sonnet-4.5")
		deferred
		ensure
			result_attached: Result /= Void
			result_not_empty: not Result.is_empty
		end

	provider_name: STRING_8
			-- Provider name (e.g., "ollama", "claude", "gemini")
		deferred
		ensure
			result_attached: Result /= Void
			result_not_empty: not Result.is_empty
		end

	verbosity_level: INTEGER
			-- Current verbosity level
		attribute
			Result := Verbosity_concise
		end

feature -- Model validation

	is_valid_model (a_model: STRING_32): BOOLEAN
			-- Is `a_model' a valid/supported model for this provider?
			-- Cloud providers check against known model list.
			-- Local providers (Ollama) may query the server dynamically.
		require
			model_attached: a_model /= Void
			model_not_empty: not a_model.is_empty
		deferred
		end

	supported_models: ARRAYED_LIST [STRING_32]
			-- List of supported model identifiers for this provider.
			-- For cloud providers, returns known/documented models.
			-- For local providers (Ollama), may query server for installed models.
		deferred
		ensure
			result_attached: Result /= Void
		end

feature -- Basic operations

	ask (a_prompt: STRING_32): AI_RESPONSE
			-- Send single prompt to AI and return response
			-- Simplest interface - no system message or conversation history
		require
			prompt_attached: a_prompt /= Void
			prompt_not_empty: not a_prompt.is_empty
		do
			Result := chat_with_system (Void, a_prompt)
		ensure
			result_attached: Result /= Void
			provider_matches: Result.provider ~ provider_name
		end

	ask_with_system (a_system, a_prompt: STRING_32): AI_RESPONSE
			-- Send prompt with system message to AI and return response
			-- System message sets context/instructions for the AI
		require
			system_attached: a_system /= Void
			system_not_empty: not a_system.is_empty
			prompt_attached: a_prompt /= Void
			prompt_not_empty: not a_prompt.is_empty
		do
			Result := chat_with_system (a_system, a_prompt)
		ensure
			result_attached: Result /= Void
			provider_matches: Result.provider ~ provider_name
		end

	chat (a_messages: ARRAY [AI_MESSAGE]): AI_RESPONSE
			-- Send conversation with message history to AI and return response
			-- Most flexible interface - full control over conversation structure
		require
			messages_attached: a_messages /= Void
			messages_not_empty: a_messages.count > 0
			all_messages_attached: across a_messages as ic all ic /= Void end
		do
			Result := execute_chat (a_messages, Void)
		ensure
			result_attached: Result /= Void
			provider_matches: Result.provider ~ provider_name
		end

feature -- Element change

	set_model (a_model: STRING_32)
			-- Set current model to `a_model'
		require
			model_attached: a_model /= Void
			model_not_empty: not a_model.is_empty
		deferred
		ensure
			model_set: model ~ a_model
		end

	set_verbosity (a_level: INTEGER)
			-- Set verbosity level for AI responses
		require
			valid_level: a_level = Verbosity_concise or a_level = Verbosity_normal or a_level = Verbosity_verbose
		do
			verbosity_level := a_level
		ensure
			level_set: verbosity_level = a_level
		end

	use_concise_responses
			-- Set AI to give brief, direct answers (default)
		do
			set_verbosity (Verbosity_concise)
		ensure
			concise_set: verbosity_level = Verbosity_concise
		end

	use_normal_responses
			-- Set AI to give standard detailed responses
		do
			set_verbosity (Verbosity_normal)
		ensure
			normal_set: verbosity_level = Verbosity_normal
		end

	use_verbose_responses
			-- Set AI to give comprehensive, detailed explanations
		do
			set_verbosity (Verbosity_verbose)
		ensure
			verbose_set: verbosity_level = Verbosity_verbose
		end

feature {NONE} -- Implementation

	verbosity_instruction: STRING_32
			-- System instruction based on current verbosity level
		do
			inspect verbosity_level
			when Verbosity_concise then
				Result := Instruction_concise
			when Verbosity_normal then
				Result := Instruction_normal
			when Verbosity_verbose then
				Result := Instruction_verbose
			else
				Result := Instruction_concise
			end
		ensure
			result_attached: Result /= Void
			result_not_empty: not Result.is_empty
		end

	chat_with_system (a_system: detachable STRING_32; a_prompt: STRING_32): AI_RESPONSE
			-- Execute chat with optional system message
			-- Internal helper that converts simple prompt to message array format
		require
			prompt_attached: a_prompt /= Void
			prompt_not_empty: not a_prompt.is_empty
			system_not_empty_if_attached: attached a_system as al_sys implies not al_sys.is_empty
		local
			l_messages: ARRAY [AI_MESSAGE]
			l_system_text: STRING_32
		do
			-- Build system message with verbosity instruction
			if attached a_system as al_system then
				l_system_text := verbosity_instruction + " " + al_system
			else
				l_system_text := verbosity_instruction
			end

			-- Create message array: system + user
			create l_messages.make_filled (create {AI_MESSAGE}.make_user (a_prompt), 1, 2)
			l_messages.put (create {AI_MESSAGE}.make_system (l_system_text), 1)
			l_messages.put (create {AI_MESSAGE}.make_user (a_prompt), 2)

			Result := execute_chat (l_messages, Void)
		ensure
			result_attached: Result /= Void
		end

	execute_chat (a_messages: ARRAY [AI_MESSAGE]; a_options: detachable ANY): AI_RESPONSE
			-- Execute chat request using provider-specific implementation
			-- This is the core operation that descendants must implement
		require
			messages_attached: a_messages /= Void
			messages_not_empty: a_messages.count > 0
			all_messages_attached: across a_messages as ic all ic /= Void end
		deferred
		ensure
			result_attached: Result /= Void
			provider_matches: Result.provider ~ provider_name
		end

feature -- Constants

	Verbosity_concise: INTEGER = 1
			-- Level for brief, direct answers

	Verbosity_normal: INTEGER = 2
			-- Level for standard detailed responses

	Verbosity_verbose: INTEGER = 3
			-- Level for comprehensive explanations

	Instruction_concise: STRING_32 = "Be extremely concise. Give brief, direct answers without unnecessary explanation."
			-- System instruction for concise responses

	Instruction_normal: STRING_32 = "Provide clear, well-explained answers with appropriate detail."
			-- System instruction for normal responses

	Instruction_verbose: STRING_32 = "Provide comprehensive, detailed explanations with examples and thorough analysis."
			-- System instruction for verbose responses

note
	copyright: "Copyright (c) 2025, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
