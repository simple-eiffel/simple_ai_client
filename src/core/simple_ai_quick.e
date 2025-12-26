note
	description: "[
		Zero-configuration AI facade for beginners.

		One-liner AI operations using local Ollama or Claude.
		For full control, use AI_CLIENT implementations directly.

		Quick Start Examples:
			create ai.make

			-- Use local Ollama (default)
			ai.use_ollama

			-- Or use Claude API
			ai.use_claude ("your-api-key")

			-- Simple question
			answer := ai.ask ("What is the capital of France?")

			-- With system context
			answer := ai.ask_as ("You are a helpful cooking assistant", "How do I make pasta?")

			-- Quick utilities
			summary := ai.summarize (long_text)
			french := ai.translate ("Hello, world!", "French")
			code := ai.generate_code ("Calculate fibonacci numbers in Python")
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SIMPLE_AI_QUICK

create
	make

feature {NONE} -- Initialization

	make
			-- Create quick AI facade.
			-- Defaults to Ollama with llama3 model.
		do
			create logger.make
			use_ollama
		end

feature -- Provider Configuration

	use_ollama
			-- Use local Ollama with llama3 model.
			-- Requires Ollama running at http://localhost:11434
		do
			logger.info ("Configuring Ollama provider")
			create {OLLAMA_CLIENT} client.make
			provider := "ollama"
			current_model := "llama3"
		ensure
			is_configured: is_configured
			provider_ollama: provider ~ "ollama"
		end

	use_ollama_model (a_model: STRING)
			-- Use local Ollama with specific model.
			-- Common models: llama3, mistral, codellama, llama2
		require
			model_not_empty: not a_model.is_empty
		do
			logger.info ("Configuring Ollama with model: " + a_model)
			create {OLLAMA_CLIENT} client.make
			if attached {OLLAMA_CLIENT} client as oc then
				oc.set_model (a_model)
			end
			provider := "ollama"
			current_model := a_model
		ensure
			is_configured: is_configured
			model_set: current_model ~ a_model
		end

	use_claude (a_api_key: STRING)
			-- Use Anthropic Claude API.
		require
			api_key_not_empty: not a_api_key.is_empty
		do
			logger.info ("Configuring Claude provider")
			create {CLAUDE_CLIENT} client.make_with_api_key (a_api_key)
			provider := "claude"
			current_model := "claude-sonnet-4-20250514"
		ensure
			is_configured: is_configured
			provider_claude: provider ~ "claude"
		end

feature -- Status

	is_configured: BOOLEAN
			-- Is an AI provider configured?
		do
			Result := attached client
		end

	provider: STRING
			-- Current provider name.
		attribute
			Result := ""
		end

	current_model: STRING
			-- Current model name.
		attribute
			Result := ""
		end

	has_error: BOOLEAN
			-- Did last request fail?
		do
			Result := not last_error.is_empty
		end

	last_error: STRING
			-- Error from last failed request.
		attribute
			Result := ""
		end

feature -- Basic Queries

	ask (a_question: STRING): STRING
			-- Ask a question and get answer.
		require
			is_configured: is_configured
			question_not_empty: not a_question.is_empty
		do
			logger.debug_log ("Asking: " + a_question.head (50) + "...")
			last_error := ""
			if attached client as c then
				if attached c.ask (a_question.to_string_32) as resp then
					Result := resp.text.to_string_8
					logger.debug_log ("Response: " + Result.head (50) + "...")
				else
					Result := ""
					last_error := "No response from AI"
					logger.error (last_error)
				end
			else
				Result := ""
				last_error := "AI client not configured"
			end
		ensure
			result_exists: Result /= Void
		end

	ask_as (a_role: STRING; a_question: STRING): STRING
			-- Ask question with system role/context.
			-- Example: ai.ask_as ("You are a Python expert", "How do I read a file?")
		require
			is_configured: is_configured
			role_not_empty: not a_role.is_empty
			question_not_empty: not a_question.is_empty
		do
			logger.debug_log ("Asking as '" + a_role.head (30) + "': " + a_question.head (50) + "...")
			last_error := ""
			if attached client as c then
				if attached c.ask_with_system (a_role.to_string_32, a_question.to_string_32) as resp then
					Result := resp.text.to_string_8
				else
					Result := ""
					last_error := "No response from AI"
				end
			else
				Result := ""
				last_error := "AI client not configured"
			end
		ensure
			result_exists: Result /= Void
		end

feature -- Utility Functions

	summarize (a_text: STRING): STRING
			-- Summarize text in a few sentences.
		require
			is_configured: is_configured
			text_not_empty: not a_text.is_empty
		do
			logger.info ("Summarizing text (" + a_text.count.out + " chars)")
			Result := ask_as (
				"You are a concise summarizer. Provide a brief summary in 2-3 sentences.",
				"Summarize the following text:%N%N" + a_text
			)
		ensure
			result_exists: Result /= Void
		end

	translate (a_text: STRING; a_language: STRING): STRING
			-- Translate text to specified language.
		require
			is_configured: is_configured
			text_not_empty: not a_text.is_empty
			language_not_empty: not a_language.is_empty
		do
			logger.info ("Translating to " + a_language)
			Result := ask_as (
				"You are a translator. Translate the following text to " + a_language + ". Only output the translation, nothing else.",
				a_text
			)
		ensure
			result_exists: Result /= Void
		end

	generate_code (a_task: STRING): STRING
			-- Generate code for a task.
		require
			is_configured: is_configured
			task_not_empty: not a_task.is_empty
		do
			logger.info ("Generating code for: " + a_task.head (50))
			Result := ask_as (
				"You are an expert programmer. Generate clean, well-commented code. Only output the code, no explanations.",
				a_task
			)
		ensure
			result_exists: Result /= Void
		end

	explain_code (a_code: STRING): STRING
			-- Explain what code does.
		require
			is_configured: is_configured
			code_not_empty: not a_code.is_empty
		do
			logger.info ("Explaining code (" + a_code.count.out + " chars)")
			Result := ask_as (
				"You are a helpful programming instructor. Explain the following code clearly and concisely.",
				a_code
			)
		ensure
			result_exists: Result /= Void
		end

	fix_grammar (a_text: STRING): STRING
			-- Fix grammar and spelling in text.
		require
			is_configured: is_configured
			text_not_empty: not a_text.is_empty
		do
			logger.info ("Fixing grammar")
			Result := ask_as (
				"You are an editor. Fix any grammar, spelling, or punctuation errors. Only output the corrected text.",
				a_text
			)
		ensure
			result_exists: Result /= Void
		end

	extract_keywords (a_text: STRING): STRING
			-- Extract key topics/keywords from text.
		require
			is_configured: is_configured
			text_not_empty: not a_text.is_empty
		do
			logger.info ("Extracting keywords")
			Result := ask_as (
				"Extract the main keywords and topics from the following text. Output as a comma-separated list.",
				a_text
			)
		ensure
			result_exists: Result /= Void
		end

feature -- Advanced Access

	client: detachable AI_CLIENT
			-- Access underlying AI client for advanced operations.

feature {NONE} -- Implementation

	logger: SIMPLE_LOGGER
			-- Logger for debugging.

invariant
	logger_exists: logger /= Void
	provider_set_when_configured: is_configured implies not provider.is_empty

end
