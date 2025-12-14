note
	description: "[
		Claude AI client using curl via SIMPLE_PROCESS_HELPER.
		
		Implements the Anthropic Messages API for Claude models.
		API key is read from ANTHROPIC_API_KEY environment variable.
		
		Supported Models:
		- claude-sonnet-4-5-20250929 (default, fast and capable)
		- claude-opus-4-5-20251101 (most capable)
		- claude-haiku-4-5-20251001 (fastest)
		
		API Documentation:
		https://docs.anthropic.com/en/api/messages
		
		Design by Contract:
		- API key must be set (via environment or explicit)
		- All operations require valid API key
		- Responses always attached (error or success)
	]"
	date: "$Date$"
	revision: "$Revision$"
	EIS: "name=Anthropic Messages API", "src=https://docs.anthropic.com/en/api/messages", "tag=api"

class
	CLAUDE_CLIENT

inherit
	AI_CLIENT

create
	make,
	make_with_api_key

feature {NONE} -- Initialization

	make
			-- Create with API key from environment variable ANTHROPIC_API_KEY
		local
			l_env: EXECUTION_ENVIRONMENT
		do
			create l_env
			if attached l_env.item (Env_api_key_name) as al_key then
				api_key := al_key.to_string_32
			else
				create api_key.make_empty
			end
			model := Default_model
			create process_helper
			create json
		ensure
			model_set: model ~ Default_model
		end

	make_with_api_key (a_api_key: STRING_32)
			-- Create with explicit API key
		require
			key_not_empty: not a_api_key.is_empty
		do
			api_key := a_api_key
			model := Default_model
			create process_helper
			create json
		ensure
			api_key_set: api_key = a_api_key
			model_set: model ~ Default_model
		end

feature -- Access

	model: STRING_32
			-- Current model (e.g., "claude-sonnet-4-5-20250929")

	provider_name: STRING_8 = "claude"
			-- Provider identifier

	api_key: STRING_32
			-- Anthropic API key

feature -- Status report

	has_api_key: BOOLEAN
			-- Is API key configured?
		do
			Result := not api_key.is_empty
		ensure
			definition: Result = not api_key.is_empty
		end

	is_available: BOOLEAN
			-- Is Claude API available (has key and can connect)?
		do
			Result := has_api_key
		end

feature -- Usage tracking

	total_input_tokens: INTEGER_64
			-- Cumulative input tokens across all requests in this session

	total_output_tokens: INTEGER_64
			-- Cumulative output tokens across all requests in this session

	total_tokens: INTEGER_64
			-- Total tokens used this session
		do
			Result := total_input_tokens + total_output_tokens
		ensure
			definition: Result = total_input_tokens + total_output_tokens
		end

	request_count: INTEGER
			-- Number of API requests made this session

	estimated_cost: REAL_64
			-- Estimated cost in USD for this session based on tokens used
			-- Note: Tracks per-model usage for accurate cost calculation
		do
			Result := haiku_cost + sonnet_cost + opus_cost
		end

	usage_summary: STRING_32
			-- Human-readable usage summary
		do
			create Result.make (200)
			Result.append ("=== Claude API Usage Summary ===%N")
			Result.append ("Requests: " + request_count.out + "%N")
			Result.append ("Input tokens: " + total_input_tokens.out + "%N")
			Result.append ("Output tokens: " + total_output_tokens.out + "%N")
			Result.append ("Total tokens: " + total_tokens.out + "%N")
			Result.append ("Estimated cost: $" + formatted_cost (estimated_cost) + "%N")
			Result.append ("--------------------------------%N")
			Result.append ("Haiku:  " + haiku_input_tokens.out + " in / " + haiku_output_tokens.out + " out = $" + formatted_cost (haiku_cost) + "%N")
			Result.append ("Sonnet: " + sonnet_input_tokens.out + " in / " + sonnet_output_tokens.out + " out = $" + formatted_cost (sonnet_cost) + "%N")
			Result.append ("Opus:   " + opus_input_tokens.out + " in / " + opus_output_tokens.out + " out = $" + formatted_cost (opus_cost) + "%N")
		end

	reset_usage
			-- Reset all usage counters to zero
		do
			total_input_tokens := 0
			total_output_tokens := 0
			request_count := 0
			haiku_input_tokens := 0
			haiku_output_tokens := 0
			sonnet_input_tokens := 0
			sonnet_output_tokens := 0
			opus_input_tokens := 0
			opus_output_tokens := 0
		ensure
			tokens_reset: total_tokens = 0
			requests_reset: request_count = 0
			cost_reset: estimated_cost = 0.0
		end

feature -- Logging

	enable_file_logging (a_path: STRING_32)
			-- Enable usage logging to file at `a_path`
		require
			path_not_empty: not a_path.is_empty
		local
			l_file: PLAIN_TEXT_FILE
		do
			create l_file.make_with_name (a_path)
			if not l_file.exists then
				l_file.create_read_write
			else
				l_file.open_append
			end
			log_file := l_file
			is_file_logging_enabled := True
		ensure
			file_logging_enabled: is_file_logging_enabled
		end

	enable_stderr_logging
			-- Enable usage logging to stderr (visible in console)
		do
			is_stderr_logging_enabled := True
		ensure
			stderr_logging_enabled: is_stderr_logging_enabled
		end

	enable_logging (a_logger: SIMPLE_LOGGER)
			-- Enable usage logging to provided SIMPLE_LOGGER
		require
			logger_attached: a_logger /= Void
		do
			logger := a_logger
			is_facility_logging_enabled := True
		ensure
			facility_logging_enabled: is_facility_logging_enabled
			logger_set: logger = a_logger
		end

	disable_all_logging
			-- Disable all logging
		do
			is_file_logging_enabled := False
			is_stderr_logging_enabled := False
			is_facility_logging_enabled := False
			if attached log_file as al_file and then not al_file.is_closed then
				al_file.close
			end
		ensure
			file_logging_disabled: not is_file_logging_enabled
			stderr_logging_disabled: not is_stderr_logging_enabled
			facility_logging_disabled: not is_facility_logging_enabled
		end

	is_logging_enabled: BOOLEAN
			-- Is any logging currently enabled?
		do
			Result := is_file_logging_enabled or is_stderr_logging_enabled or is_facility_logging_enabled
		end

	is_file_logging_enabled: BOOLEAN
			-- Is file logging enabled?

	is_stderr_logging_enabled: BOOLEAN
			-- Is stderr logging enabled?

	is_facility_logging_enabled: BOOLEAN
			-- Is SIMPLE_LOGGER logging enabled?

feature {NONE} -- Logging: Implementation

	log_file: detachable PLAIN_TEXT_FILE
			-- Log file for file-based logging

	logger: detachable SIMPLE_LOGGER
			-- Optional SIMPLE_LOGGER logger

	log_message (a_message: STRING)
			-- Write message to all enabled log destinations
		require
			message_not_empty: not a_message.is_empty
		do
			if is_stderr_logging_enabled then
				io.error.put_string (a_message)
				io.error.put_new_line
			end
			if is_file_logging_enabled and attached log_file as al_file then
				al_file.put_string (a_message)
				al_file.put_new_line
				al_file.flush
			end
			if is_facility_logging_enabled and attached logger as al_logger then
				al_logger.log_info (a_message)
			end
		end

feature {NONE} -- Usage tracking: Per-model counters

	haiku_input_tokens: INTEGER_64
	haiku_output_tokens: INTEGER_64
	sonnet_input_tokens: INTEGER_64
	sonnet_output_tokens: INTEGER_64
	opus_input_tokens: INTEGER_64
	opus_output_tokens: INTEGER_64

feature {NONE} -- Usage tracking: Cost calculation

	haiku_cost: REAL_64
			-- Cost for Haiku usage
		do
			Result := (haiku_input_tokens * Price_haiku_input + haiku_output_tokens * Price_haiku_output) / 1_000_000.0
		end

	sonnet_cost: REAL_64
			-- Cost for Sonnet usage
		do
			Result := (sonnet_input_tokens * Price_sonnet_input + sonnet_output_tokens * Price_sonnet_output) / 1_000_000.0
		end

	opus_cost: REAL_64
			-- Cost for Opus usage
		do
			Result := (opus_input_tokens * Price_opus_input + opus_output_tokens * Price_opus_output) / 1_000_000.0
		end

	record_usage (a_input_tokens, a_output_tokens: INTEGER)
			-- Record token usage for current model
		do
			total_input_tokens := total_input_tokens + a_input_tokens
			total_output_tokens := total_output_tokens + a_output_tokens
			request_count := request_count + 1

			-- Track per-model usage for accurate costing
			if model ~ Model_haiku then
				haiku_input_tokens := haiku_input_tokens + a_input_tokens
				haiku_output_tokens := haiku_output_tokens + a_output_tokens
			elseif model ~ Model_opus then
				opus_input_tokens := opus_input_tokens + a_input_tokens
				opus_output_tokens := opus_output_tokens + a_output_tokens
			else
				-- Default to Sonnet (includes any custom model strings)
				sonnet_input_tokens := sonnet_input_tokens + a_input_tokens
				sonnet_output_tokens := sonnet_output_tokens + a_output_tokens
			end

			-- Log if any logging enabled
			if is_logging_enabled then
				log_message ("Claude API: " + model.to_string_8 +
					" | in:" + a_input_tokens.out +
					" out:" + a_output_tokens.out +
					" | session_total:" + total_tokens.out +
					" | est_cost:$" + formatted_cost (estimated_cost))
			end
		end

	formatted_cost (a_cost: REAL_64): STRING
			-- Format cost with 4 decimal places
		do
			create Result.make (10)
			Result.append ((a_cost * 10000).truncated_to_integer.out)
			if Result.count < 5 then
				Result.prepend (create {STRING}.make_filled ('0', 5 - Result.count))
			end
			Result.insert_character ('.', Result.count - 3)
		end

feature -- Element change

	set_model (a_model: STRING_32)
			-- Set model to use
		do
			model := a_model
		end

	set_api_key (a_key: STRING_32)
			-- Set API key explicitly
		require
			key_not_empty: not a_key.is_empty
		do
			api_key := a_key
		ensure
			key_set: api_key = a_key
		end

feature -- Model selection helpers

	use_sonnet
			-- Use Claude Sonnet 4.5 (balanced speed/capability)
		do
			set_model (Model_sonnet)
		ensure
			model_set: model ~ Model_sonnet
		end

	use_opus
			-- Use Claude Opus 4.5 (most capable)
		do
			set_model (Model_opus)
		ensure
			model_set: model ~ Model_opus
		end

	use_haiku
			-- Use Claude Haiku 4.5 (fastest)
		do
			set_model (Model_haiku)
		ensure
			model_set: model ~ Model_haiku
		end

feature {NONE} -- Implementation

	execute_chat (a_messages: ARRAY [AI_MESSAGE]; a_options: detachable ANY): AI_RESPONSE
			-- Execute chat via Anthropic Messages API.
			-- Converts AI_MESSAGE array to Anthropic's JSON format, sends via curl,
			-- and parses the response into an AI_RESPONSE object.
		local
			l_request: SIMPLE_JSON_OBJECT
			l_messages_array: SIMPLE_JSON_ARRAY
			l_msg_obj: SIMPLE_JSON_OBJECT
			l_curl_cmd: STRING_32
			l_output: STRING_32
			l_response_value: SIMPLE_JSON_VALUE
			l_response_obj: SIMPLE_JSON_OBJECT
			l_system_content: STRING_32
		do
			-- Guard: ensure API key is configured before making request
			if not has_api_key then
				Result := create_error_response ("API key not configured. Set ANTHROPIC_API_KEY environment variable.")
			else
				-- Initialize JSON request object with model and token limit
				create l_request.make
				l_request.put_string (model, Key_model).do_nothing
				l_request.put_integer (Max_tokens_default, Key_max_tokens).do_nothing

				-- Claude API requires system messages separate from conversation messages.
				-- Accumulate all system messages into a single string, and build
				-- a JSON array of user/assistant messages for the conversation.
				create l_system_content.make_empty
				create l_messages_array.make

				across a_messages as ic loop
					if ic.is_system then
						-- Concatenate multiple system messages with newlines
						if not l_system_content.is_empty then
							l_system_content.append ("%N")
						end
						l_system_content.append (ic.content)
					else
						-- Build JSON object for each user/assistant message
						create l_msg_obj.make
						l_msg_obj.put_string (ic.role, Key_role).do_nothing
						l_msg_obj.put_string (ic.content, Key_content).do_nothing
						l_messages_array.add_object (l_msg_obj).do_nothing
					end
				end

				-- Add accumulated system content to request if any was provided
				if not l_system_content.is_empty then
					l_request.put_string (l_system_content, Key_system).do_nothing
				end

				-- Attach the messages array to complete the request body
				l_request.put_array (l_messages_array, Key_messages).do_nothing

				-- Build curl command with headers and JSON body, then execute
				l_curl_cmd := build_curl_command (l_request.to_json_string)
				l_output := process_helper.shell_output (l_curl_cmd, Void)

				-- Parse curl output as JSON and convert to AI_RESPONSE
				l_response_value := json.parse_response (l_output)
				if attached l_response_value as al_value and then al_value.is_object then
					l_response_obj := al_value.as_object
					Result := parse_response (l_response_obj, l_output)
				else
					-- JSON parsing failed - return error with truncated raw output for debugging
					Result := create_error_response ({STRING_32} "Failed to parse Claude response: " + l_output.head (200))
				end
			end
		end

	build_curl_command (a_json_body: STRING_32): STRING_32
			-- Build curl command string for Anthropic Messages API.
			-- Constructs a complete curl command with required headers
			-- (Content-Type, API key, API version) and the JSON request body.
		local
			l_escaped_body: STRING_32
		do
			-- Escape special characters in JSON for Windows command line processing
			l_escaped_body := escape_for_windows (a_json_body)

			-- Build curl command with silent mode (-s) and POST method
			create Result.make (1000)
			Result.append ("curl.exe -s -X POST ")
			Result.append (Api_url)

			-- Add required HTTP headers for Anthropic API
			Result.append (" -H %"Content-Type: application/json%"")
			Result.append (" -H %"x-api-key: ")
			Result.append (api_key)
			Result.append ("%"")
			Result.append (" -H %"anthropic-version: ")
			Result.append (Api_version)
			Result.append ("%"")

			-- Append the escaped JSON request body
			Result.append (" -d %"")
			Result.append (l_escaped_body)
			Result.append ("%"")
		end

	escape_for_windows (a_json: STRING_32): STRING_32
			-- Escape JSON for Windows command line
		do
			create Result.make_from_string (a_json)
			Result.replace_substring_all ({STRING_32} "\", {STRING_32} "\\")
			Result.replace_substring_all ({STRING_32} "%"", {STRING_32} "\%"")
		end

	parse_response (a_obj: SIMPLE_JSON_OBJECT; a_raw: STRING_32): AI_RESPONSE
			-- Parse Claude API JSON response into AI_RESPONSE object.
			-- Handles both successful responses and error responses from the API.
			-- Extracts text content, model info, and token usage statistics.
		local
			l_text: STRING_32
			l_model_name: STRING_32
			l_input_tokens, l_output_tokens: INTEGER
			i: INTEGER
		do
			-- Check for API error response (contains "error" key with nested message)
			if a_obj.has_key (Key_error) then
				if attached a_obj.object_item (Key_error) as al_error then
					if attached al_error.string_item (Key_message) as al_msg then
						Result := create_error_response (al_msg)
					else
						Result := create_error_response ("Unknown API error")
					end
				else
					Result := create_error_response ("Unknown API error")
				end
			else
				-- Parse successful response - extract text content
				create l_text.make_empty

				-- Claude responses contain a "content" array with typed blocks.
				-- Iterate through blocks, extracting text from "text" type blocks.
				-- Multiple text blocks are joined with newlines.
				if attached a_obj.array_item (Key_content) as al_content then
					from i := 1 until i > al_content.count loop
						if attached al_content.object_item (i) as al_block then
							-- Only process blocks with type="text"
							if attached al_block.string_item (Key_type) as al_type and then al_type ~ "text" then
								if attached al_block.string_item (Key_text) as al_text then
									if not l_text.is_empty then
										l_text.append ("%N")
									end
									l_text.append (al_text)
								end
							end
						end
						i := i + 1
					end
				end

				-- Extract model name from response, fall back to request model if not present
				if attached a_obj.string_item (Key_model) as al_model then
					l_model_name := al_model
				else
					l_model_name := model
				end

				-- Build final AI_RESPONSE object
				if l_text.is_empty then
					Result := create_error_response ("Empty response from Claude")
				else
					create Result.make (l_text, l_model_name, provider_name)

					-- Extract and record token usage from "usage" object for cost tracking
					if attached a_obj.object_item (Key_usage) as al_usage then
						l_input_tokens := al_usage.integer_item (Key_input_tokens).to_integer_32
						l_output_tokens := al_usage.integer_item (Key_output_tokens).to_integer_32
						Result.set_tokens (l_input_tokens, l_output_tokens)

						-- Update session-level usage counters and log if enabled
						record_usage (l_input_tokens, l_output_tokens)
					end
				end
			end
		end

	create_error_response (a_message: STRING_32): AI_RESPONSE
			-- Create error response
		do
			create Result.make_error (a_message, provider_name)
		end

feature {NONE} -- Implementation: Attributes

	process_helper: SIMPLE_PROCESS_HELPER
			-- Process helper for curl execution

	json: SIMPLE_JSON
			-- JSON parser

feature {NONE} -- Constants: API

	Api_url: STRING_32 = "https://api.anthropic.com/v1/messages"
			-- Anthropic Messages API endpoint

	Api_version: STRING_32 = "2023-06-01"
			-- Anthropic API version

	Env_api_key_name: STRING_32 = "ANTHROPIC_API_KEY"
			-- Environment variable name for API key

	Max_tokens_default: INTEGER = 4096
			-- Default maximum tokens for response

feature -- Constants: Models

	Default_model: STRING_32 = "claude-sonnet-4-5-20250929"
			-- Default model (Sonnet - balanced)

	Model_sonnet: STRING_32 = "claude-sonnet-4-5-20250929"
			-- Claude Sonnet 4.5 - fast and capable

	Model_opus: STRING_32 = "claude-opus-4-5-20251101"
			-- Claude Opus 4.5 - most capable

	Model_haiku: STRING_32 = "claude-haiku-4-5-20251001"
			-- Claude Haiku 4.5 - fastest

feature -- Constants: Pricing (USD per million tokens)

	Price_haiku_input: REAL_64 = 0.80
			-- Haiku input price: $0.80 per million tokens

	Price_haiku_output: REAL_64 = 4.0
			-- Haiku output price: $4.00 per million tokens

	Price_sonnet_input: REAL_64 = 3.0
			-- Sonnet input price: $3.00 per million tokens

	Price_sonnet_output: REAL_64 = 15.0
			-- Sonnet output price: $15.00 per million tokens

	Price_opus_input: REAL_64 = 15.0
			-- Opus input price: $15.00 per million tokens

	Price_opus_output: REAL_64 = 75.0
			-- Opus output price: $75.00 per million tokens

feature {NONE} -- Constants: JSON Keys

	Key_model: STRING_32 = "model"
	Key_max_tokens: STRING_32 = "max_tokens"
	Key_messages: STRING_32 = "messages"
	Key_system: STRING_32 = "system"
	Key_role: STRING_32 = "role"
	Key_content: STRING_32 = "content"
	Key_type: STRING_32 = "type"
	Key_text: STRING_32 = "text"
	Key_error: STRING_32 = "error"
	Key_message: STRING_32 = "message"
	Key_usage: STRING_32 = "usage"
	Key_input_tokens: STRING_32 = "input_tokens"
	Key_output_tokens: STRING_32 = "output_tokens"

invariant
	model_attached: model /= Void
	model_not_empty: not model.is_empty
	api_key_attached: api_key /= Void
	process_helper_attached: process_helper /= Void
	json_attached: json /= Void

note
	copyright: "Copyright (c) 2025, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
