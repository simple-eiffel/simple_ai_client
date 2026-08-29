note
	description: "[
		Claude AI client using curl via SIMPLE_PROCESS_HELPER.
		
		Implements the Anthropic Messages API for Claude models.
		API key is read from ANTHROPIC_API_KEY environment variable.
		
		Supported Models:
		- claude-opus-5 (default, most capable general model)
		- claude-sonnet-5 (balanced speed and capability)
		- claude-haiku-4-5 (fastest)
		- claude-fable-5 (most capable; highest price)
		- claude-opus-4-8 / 4-7 / 4-6, claude-sonnet-4-6
		
		Model identifiers are complete as written: current models carry no
		date suffix. Appending one produces a 404.
		
		The API key is never placed on the curl command line, and the request
		body travels by temporary file rather than as a shell argument. See
		`build_curl_command' for why. Requires curl 8.3.0 or later.
		
		API Documentation:
		https://platform.claude.com/docs/en/api/messages/create
		
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
			max_tokens := Max_tokens_default
			create process_helper
			create json
		ensure
			model_set: model ~ Default_model
			max_tokens_set: max_tokens = Max_tokens_default
		end

	make_with_api_key (a_api_key: STRING_32)
			-- Create with explicit API key
		require
			key_not_empty: not a_api_key.is_empty
		do
			api_key := a_api_key
			model := Default_model
			max_tokens := Max_tokens_default
			create process_helper
			create json
		ensure
			api_key_set: api_key = a_api_key
			model_set: model ~ Default_model
			max_tokens_set: max_tokens = Max_tokens_default
		end

feature -- Access

	model: STRING_32
			-- Current model (e.g., "claude-opus-5")

	provider_name: STRING_8 = "claude"
			-- Provider identifier

	api_key: STRING_32
			-- Anthropic API key

	max_tokens: INTEGER
			-- Maximum tokens in a response. See `set_max_tokens'.

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
			-- Estimated cost in USD for this session.
			-- Each request is costed when recorded, at the price of the model
			-- that served it, so mid-session model changes total correctly.
			-- A local estimate from published rates, never an invoice.
		do
			Result := accumulated_cost
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
			Result.append ("Fable:  " + fable_input_tokens.out + " in / " + fable_output_tokens.out + " out = $" + formatted_cost (fable_cost) + "%N")
		end

	reset_usage
			-- Reset all usage counters to zero
		do
			total_input_tokens := 0
			total_output_tokens := 0
			request_count := 0
			accumulated_cost := 0.0
			fable_input_tokens := 0
			fable_output_tokens := 0
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

feature {NONE} -- Usage tracking: Per-family counters

	fable_input_tokens: INTEGER_64
	fable_output_tokens: INTEGER_64
	haiku_input_tokens: INTEGER_64
	haiku_output_tokens: INTEGER_64
	sonnet_input_tokens: INTEGER_64
	sonnet_output_tokens: INTEGER_64
	opus_input_tokens: INTEGER_64
	opus_output_tokens: INTEGER_64

	accumulated_cost: REAL_64
			-- Running cost, summed per request at the price of the model that
			-- served that request.

feature -- Usage tracking: Pricing lookup

	model_family (a_model: STRING_32): INTEGER
			-- Pricing family of `a_model'.
			-- Matched on substring, so dated or later identifiers within a
			-- family still price correctly. An unrecognised model is priced as
			-- Opus: over-estimating a cost is safer than under-estimating it.
		require
			model_not_empty: not a_model.is_empty
		local
			l_lower: STRING_32
		do
			l_lower := a_model.as_lower
			if l_lower.has_substring ({STRING_32} "fable") or l_lower.has_substring ({STRING_32} "mythos") then
				Result := Family_fable
			elseif l_lower.has_substring ({STRING_32} "opus") then
				Result := Family_opus
			elseif l_lower.has_substring ({STRING_32} "sonnet-4-6") or l_lower.has_substring ({STRING_32} "sonnet-4.6") then
				Result := Family_sonnet_46
			elseif l_lower.has_substring ({STRING_32} "sonnet") then
				Result := Family_sonnet
			elseif l_lower.has_substring ({STRING_32} "haiku") then
				Result := Family_haiku
			else
				Result := Family_opus
			end
		ensure
			known_family: Result >= Family_fable and Result <= Family_haiku
		end

	input_price (a_model: STRING_32): REAL_64
			-- Input price per million tokens for `a_model'.
		require
			model_not_empty: not a_model.is_empty
		do
			inspect model_family (a_model)
			when Family_fable then Result := Price_fable_input
			when Family_sonnet then Result := Price_sonnet_input
			when Family_sonnet_46 then Result := Price_sonnet_46_input
			when Family_haiku then Result := Price_haiku_input
			else Result := Price_opus_input
			end
		ensure
			positive: Result > 0.0
		end

	output_price (a_model: STRING_32): REAL_64
			-- Output price per million tokens for `a_model'.
		require
			model_not_empty: not a_model.is_empty
		do
			inspect model_family (a_model)
			when Family_fable then Result := Price_fable_output
			when Family_sonnet then Result := Price_sonnet_output
			when Family_sonnet_46 then Result := Price_sonnet_46_output
			when Family_haiku then Result := Price_haiku_output
			else Result := Price_opus_output
			end
		ensure
			positive: Result > 0.0
		end

feature {NONE} -- Usage tracking: Cost calculation

	fable_cost: REAL_64
			-- Cost for Fable usage
		do
			Result := (fable_input_tokens * Price_fable_input + fable_output_tokens * Price_fable_output) / 1_000_000.0
		end

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
			-- Record token usage, costed at the current model's rate.
		do
			total_input_tokens := total_input_tokens + a_input_tokens
			total_output_tokens := total_output_tokens + a_output_tokens
			request_count := request_count + 1

			-- Cost this request at the price of the model that served it, so
			-- that switching models mid-session still totals correctly.
			accumulated_cost := accumulated_cost +
				(a_input_tokens * input_price (model) + a_output_tokens * output_price (model)) / 1_000_000.0

			inspect model_family (model)
			when Family_fable then
				fable_input_tokens := fable_input_tokens + a_input_tokens
				fable_output_tokens := fable_output_tokens + a_output_tokens
			when Family_haiku then
				haiku_input_tokens := haiku_input_tokens + a_input_tokens
				haiku_output_tokens := haiku_output_tokens + a_output_tokens
			when Family_sonnet, Family_sonnet_46 then
				sonnet_input_tokens := sonnet_input_tokens + a_input_tokens
				sonnet_output_tokens := sonnet_output_tokens + a_output_tokens
			else
				opus_input_tokens := opus_input_tokens + a_input_tokens
				opus_output_tokens := opus_output_tokens + a_output_tokens
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

	set_max_tokens (a_max: INTEGER)
			-- Set the maximum number of tokens in a response.
		require
			positive: a_max > 0
		do
			max_tokens := a_max
		ensure
			max_tokens_set: max_tokens = a_max
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

feature -- Model validation

	is_valid_model (a_model: STRING_32): BOOLEAN
			-- Is `a_model' a valid Claude model?
			-- Checks against known Claude model identifiers.
		do
			Result := across supported_models as m some m.same_string (a_model) end
		end

	supported_models: ARRAYED_LIST [STRING_32]
			-- List of supported Claude model identifiers.
			-- Includes both versioned and alias names.
		do
			create Result.make (10)
			-- Claude 5 generation
			Result.extend (Model_fable_5)
			Result.extend (Model_opus_5)
			Result.extend (Model_sonnet_5)
			Result.extend (Model_haiku_45)
			-- Claude 4.x still in service
			Result.extend (Model_opus_48)
			Result.extend (Model_opus_47)
			Result.extend (Model_opus_46)
			Result.extend (Model_sonnet_46)
		ensure then
			has_models: Result.count >= 6
		end

feature -- Model selection helpers

	use_sonnet
			-- Use Claude Sonnet 5 (balanced speed and capability)
		do
			set_model (Model_sonnet_5)
		ensure
			model_set: model ~ Model_sonnet_5
		end

	use_opus
			-- Use Claude Opus 5 (most capable general model)
		do
			set_model (Model_opus_5)
		ensure
			model_set: model ~ Model_opus_5
		end

	use_haiku
			-- Use Claude Haiku 4.5 (fastest)
		do
			set_model (Model_haiku_45)
		ensure
			model_set: model ~ Model_haiku_45
		end

	use_fable
			-- Use Claude Fable 5 (most capable; highest price).
		do
			set_model (Model_fable_5)
		ensure
			model_set: model ~ Model_fable_5
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
				l_request.put_integer (max_tokens, Key_max_tokens).do_nothing

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

				-- The key goes to the environment and the body to a file;
				-- neither ever appears on the command line. See `build_curl_command'.
				publish_api_key
				if attached write_request_body (l_request.to_json_string) as al_body_path then
					l_curl_cmd := build_curl_command (al_body_path)
					l_output := process_helper.shell_output (l_curl_cmd, Void)
					delete_request_body (al_body_path)

					-- Parse curl output as JSON and convert to AI_RESPONSE
					l_response_value := json.parse_response (l_output)
					if attached l_response_value as al_value and then al_value.is_object then
						l_response_obj := al_value.as_object
						Result := parse_response (l_response_obj, l_output)
					elseif l_output.is_empty then
						Result := create_error_response ("No output from curl.exe. Check that curl 8.3.0 or later is on PATH.")
					else
						-- JSON parsing failed - return error with truncated raw output for debugging
						Result := create_error_response ({STRING_32} "Failed to parse Claude response: " + l_output.head (200))
					end
				else
					Result := create_error_response ("Could not write the request body to a temporary file.")
				end
			end
		end

feature -- Diagnostics

	curl_command_preview (a_body_path: STRING_32): STRING_32
			-- The exact curl command this client would run for a request body
			-- held at `a_body_path'.
			--
			-- Public because a library that shells out should let its caller see
			-- what it is about to execute. It is safe to log: the postcondition
			-- guarantees the API key is not in it.
		require
			body_path_not_empty: not a_body_path.is_empty
		do
			Result := build_curl_command (a_body_path)
		ensure
			safe_to_log: not api_key.is_empty implies not Result.has_substring (api_key)
		end

feature {NONE} -- Implementation: request construction

	build_curl_command (a_body_path: STRING_32): STRING_32
			-- Build the curl command, reading its request body from `a_body_path'.
			--
			-- The API key is deliberately NOT placed on the command line. On
			-- Windows any process running as the same user can read another
			-- process's full command line (Win32_Process.CommandLine), so a key
			-- passed as `-H "x-api-key: ..."' is exposed for the life of the
			-- call. Instead the key is published to the `Env_curl_key_name'
			-- environment variable, which curl reads for itself via `--variable'
			-- and substitutes via `--expand-header'. Reading another process's
			-- environment requires ReadProcessMemory: a materially higher bar.
			-- Requires curl 8.3.0 or later for `--variable'.
			--
			-- The body travels by file for that reason and two others: a Windows
			-- command line is capped near 32 KB, and escaping JSON through the
			-- shell mangled quotes, backslashes and non-ASCII text.
		require
			body_path_not_empty: not a_body_path.is_empty
		do
			create Result.make (400)
			Result.append ("curl.exe -sS -X POST ")
			Result.append (Api_url)
			Result.append (" -H %"Content-Type: application/json%"")
			Result.append (" -H %"anthropic-version: ")
			Result.append (Api_version)
			Result.append ("%"")
			Result.append (" --variable %%")
			Result.append (Env_curl_key_name)
			Result.append (" --expand-header %"x-api-key: {{")
			Result.append (Env_curl_key_name)
			Result.append ("}}%"")
			Result.append (" --data-binary %"@")
			Result.append (a_body_path)
			Result.append ("%"")
		ensure
			key_never_on_command_line: not api_key.is_empty implies not Result.has_substring (api_key)
		end

	publish_api_key
			-- Make `api_key' reachable by the curl child process through the
			-- environment, under a name private to this library so that a
			-- caller's own ANTHROPIC_API_KEY is never overwritten.
		require
			has_key: has_api_key
		local
			l_env: EXECUTION_ENVIRONMENT
		do
			create l_env
			l_env.put (api_key, Env_curl_key_name)
		end

	write_request_body (a_json: STRING_32): detachable STRING_32
			-- Write `a_json' as UTF-8 to a uniquely named temporary file and
			-- return its path, or Void if it could not be written.
			-- The caller must pass the result to `delete_request_body'.
		require
			json_not_empty: not a_json.is_empty
		local
			l_file: RAW_FILE
			l_env: EXECUTION_ENVIRONMENT
			l_uuid: SIMPLE_UUID
			l_path, l_dir: STRING_32
			l_failed: BOOLEAN
		do
			if not l_failed then
				create l_env
				create l_uuid.make
				if attached l_env.item ({STRING_32} "TEMP") as al_temp and then not al_temp.is_empty then
					l_dir := al_temp.to_string_32
				else
					l_dir := {STRING_32} "."
				end
					-- A v4 name keeps concurrent clients from colliding.
				l_path := l_dir + {STRING_32} "\simple_ai_claude_" + l_uuid.new_v4_compact.to_string_32 + {STRING_32} ".json"
				create l_file.make_with_name (l_path)
				l_file.create_read_write
					-- Write UTF-8 bytes, so Hebrew, Greek and any other
					-- non-ASCII content survives the round trip intact.
				l_file.put_string ({UTF_CONVERTER}.string_32_to_utf_8_string_8 (a_json))
				l_file.close
				Result := l_path
			end
		rescue
			l_failed := True
			retry
		end

	delete_request_body (a_path: STRING_32)
			-- Delete the temporary body file at `a_path'. Failure is ignored:
			-- a leftover temp file must never mask the API result.
		require
			path_not_empty: not a_path.is_empty
		local
			l_file: RAW_FILE
			l_failed: BOOLEAN
		do
			if not l_failed then
				create l_file.make_with_name (a_path)
				if l_file.exists then
					l_file.delete
				end
			end
		rescue
			l_failed := True
			retry
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

				-- A refusal arrives as HTTP 200 with stop_reason "refusal" and
				-- usually no text at all, so it must be distinguished from a
				-- genuinely empty reply before reporting a fault.
				if attached a_obj.string_item (Key_stop_reason) as al_stop and then al_stop ~ {STRING_32} "refusal" then
					Result := create_error_response ("Claude declined this request (stop_reason: refusal).")
				elseif l_text.is_empty then
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

					-- Truncation still yields usable text, so it is reported
					-- rather than raised: the caller may want to raise max_tokens.
					if is_logging_enabled and then
						attached a_obj.string_item (Key_stop_reason) as al_stop and then
						al_stop ~ {STRING_32} "max_tokens"
					then
						log_message ("Claude API: response truncated at max_tokens=" + max_tokens.out +
							"; call set_max_tokens for a longer answer.")
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
			-- Environment variable read by `make' to find the API key

	Env_curl_key_name: STRING_32 = "SIMPLE_AI_CLAUDE_KEY"
			-- Environment variable this library publishes the key to for curl
			-- to read. Distinct from `Env_api_key_name' so that `make_with_api_key'
			-- never overwrites a caller's own ANTHROPIC_API_KEY.

	Max_tokens_default: INTEGER = 16000
			-- Default maximum response tokens. Large enough that ordinary
			-- answers are not truncated mid-sentence, small enough to stay
			-- inside curl's default response handling without streaming.

feature -- Constants: Models

	Default_model: STRING_32 = "claude-opus-5"
			-- Default model. Opus 5 is the most capable general model;
			-- call `use_sonnet' or `use_haiku' for cheaper/faster work.

	-- Claude 5 generation (current)
	Model_fable_5: STRING_32 = "claude-fable-5"
			-- Claude Fable 5 - most capable. Thinking is always on and the
			-- `thinking' parameter must be omitted entirely.

	Model_opus_5: STRING_32 = "claude-opus-5"
			-- Claude Opus 5 - most capable general model

	Model_sonnet_5: STRING_32 = "claude-sonnet-5"
			-- Claude Sonnet 5 - balanced speed and capability

	Model_haiku_45: STRING_32 = "claude-haiku-4-5"
			-- Claude Haiku 4.5 - fastest. Note: no date suffix; current
			-- model identifiers are complete as written.

	-- Claude 4.x models still in service
	Model_opus_48: STRING_32 = "claude-opus-4-8"
			-- Claude Opus 4.8

	Model_opus_47: STRING_32 = "claude-opus-4-7"
			-- Claude Opus 4.7

	Model_opus_46: STRING_32 = "claude-opus-4-6"
			-- Claude Opus 4.6

	Model_sonnet_46: STRING_32 = "claude-sonnet-4-6"
			-- Claude Sonnet 4.6 - priced above Sonnet 5

feature -- Constants: Pricing (USD per million tokens)

	-- Rates as published 2026-06-24. Anthropic changes pricing from time to
	-- time; `estimated_cost' is a local estimate, never an invoice.

	Price_fable_input: REAL_64 = 10.0
			-- Fable 5 input: $10.00 per million tokens

	Price_fable_output: REAL_64 = 50.0
			-- Fable 5 output: $50.00 per million tokens

	Price_opus_input: REAL_64 = 5.0
			-- Opus 5 / 4.8 / 4.7 / 4.6 input: $5.00 per million tokens

	Price_opus_output: REAL_64 = 25.0
			-- Opus 5 / 4.8 / 4.7 / 4.6 output: $25.00 per million tokens

	Price_sonnet_input: REAL_64 = 2.0
			-- Sonnet 5 input: $2.00 per million tokens

	Price_sonnet_output: REAL_64 = 10.0
			-- Sonnet 5 output: $10.00 per million tokens

	Price_sonnet_46_input: REAL_64 = 3.0
			-- Sonnet 4.6 input: $3.00 per million tokens

	Price_sonnet_46_output: REAL_64 = 15.0
			-- Sonnet 4.6 output: $15.00 per million tokens

	Price_haiku_input: REAL_64 = 1.0
			-- Haiku 4.5 input: $1.00 per million tokens

	Price_haiku_output: REAL_64 = 5.0
			-- Haiku 4.5 output: $5.00 per million tokens

feature -- Constants: Pricing families

	Family_fable: INTEGER = 1
	Family_opus: INTEGER = 2
	Family_sonnet: INTEGER = 3
	Family_sonnet_46: INTEGER = 4
	Family_haiku: INTEGER = 5

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
	Key_stop_reason: STRING_32 = "stop_reason"

invariant
	max_tokens_positive: max_tokens > 0
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
