note
	description: "[
		OpenAI API client using curl via SIMPLE_PROCESS_HELPER.

		Implements the OpenAI Chat Completions API.
		API key is read from OPENAI_API_KEY environment variable.

		Supported Models:
		- gpt-4o-mini (default, fast and cheap)
		- gpt-4o (more capable)
		- gpt-4-turbo (previous generation)
		- o1-mini, o1-preview (reasoning models)

		API Documentation:
		https://platform.openai.com/docs/api-reference/chat

		Design by Contract:
		- API key must be set (via environment or explicit)
		- All operations require valid API key
		- Responses always attached (error or success)
	]"
	date: "$Date$"
	revision: "$Revision$"

class
	OPENAI_CLIENT

inherit
	AI_CLIENT

create
	make,
	make_with_api_key

feature {NONE} -- Initialization

	make
			-- Create with API key from environment variable OPENAI_API_KEY
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
			-- Current model (e.g., "gpt-4o-mini")

	provider_name: STRING_8 = "openai"
			-- Provider identifier

	api_key: STRING_32
			-- OpenAI API key

feature -- Status report

	has_api_key: BOOLEAN
			-- Is API key configured?
		do
			Result := not api_key.is_empty
		ensure
			definition: Result = not api_key.is_empty
		end

	is_available: BOOLEAN
			-- Is OpenAI API available (has key)?
		do
			Result := has_api_key
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

feature -- Model validation

	is_valid_model (a_model: STRING_32): BOOLEAN
			-- Is `a_model' a valid OpenAI model?
		do
			Result := across supported_models as m some m.same_string (a_model) end
		end

	supported_models: ARRAYED_LIST [STRING_32]
			-- List of supported OpenAI model identifiers.
		do
			create Result.make (20)
			-- GPT-4.1 family (latest)
			Result.extend (Model_gpt41)
			Result.extend (Model_gpt41_mini)
			Result.extend (Model_gpt41_nano)
			-- GPT-4o family
			Result.extend (Model_gpt4o)
			Result.extend (Model_gpt4o_mini)
			-- GPT-4 Turbo
			Result.extend (Model_gpt4_turbo)
			-- O-series reasoning models
			Result.extend (Model_o3)
			Result.extend (Model_o3_mini)
			Result.extend (Model_o3_pro)
			Result.extend (Model_o1)
			Result.extend (Model_o1_pro)
			-- GPT-5 family
			Result.extend (Model_gpt5)
			Result.extend (Model_gpt51)
			Result.extend (Model_gpt52)
		ensure then
			has_models: Result.count >= 10
		end

feature -- Model selection helpers

	use_gpt4o_mini
			-- Use GPT-4o mini (fast and cheap)
		do
			set_model (Model_gpt4o_mini)
		ensure
			model_set: model ~ Model_gpt4o_mini
		end

	use_gpt4o
			-- Use GPT-4o (more capable)
		do
			set_model (Model_gpt4o)
		ensure
			model_set: model ~ Model_gpt4o
		end

	use_gpt41
			-- Use GPT-4.1 (latest non-reasoning)
		do
			set_model (Model_gpt41)
		ensure
			model_set: model ~ Model_gpt41
		end

	use_o3
			-- Use o3 (powerful reasoning)
		do
			set_model (Model_o3)
		ensure
			model_set: model ~ Model_o3
		end

feature {NONE} -- Implementation

	execute_chat (a_messages: ARRAY [AI_MESSAGE]; a_options: detachable ANY): AI_RESPONSE
			-- Execute chat via OpenAI Chat Completions API.
		local
			l_request: SIMPLE_JSON_OBJECT
			l_messages_array: SIMPLE_JSON_ARRAY
			l_msg_obj: SIMPLE_JSON_OBJECT
			l_curl_cmd: STRING_32
			l_output: STRING_32
			l_response_value: SIMPLE_JSON_VALUE
			l_response_obj: SIMPLE_JSON_OBJECT
			l_json_body: STRING_32
			l_temp_file: RAW_FILE
			l_temp_path: STRING_32
		do
			-- Guard: ensure API key is configured before making request
			if not has_api_key then
				Result := create_error_response ("API key not configured. Set OPENAI_API_KEY environment variable.")
			else
				create l_request.make
				l_request.put_string (model, Key_model).do_nothing
				l_request.put_integer (Max_tokens_default, Key_max_tokens).do_nothing

				-- Build messages array
				create l_messages_array.make
				across a_messages as ic loop
					create l_msg_obj.make
					l_msg_obj.put_string (ic.role, Key_role).do_nothing
					l_msg_obj.put_string (ic.content, Key_content).do_nothing
					l_messages_array.add_object (l_msg_obj).do_nothing
				end
				l_request.put_array (l_messages_array, Key_messages).do_nothing

				l_json_body := l_request.to_json_string

				-- Write JSON to temp file to avoid escaping issues
				l_temp_path := {STRING_32} "openai_request.json"
				create l_temp_file.make_create_read_write (l_temp_path.to_string_8)
					-- Encode as real UTF-8: `l_json_body` may hold code points
					-- above 255, which `to_string_8` would truncate.
				l_temp_file.put_string ({UTF_CONVERTER}.string_32_to_utf_8_string_8 (l_json_body))
				l_temp_file.close

				-- Build curl command
				create l_curl_cmd.make (500)
				l_curl_cmd.append ("curl.exe -s -X POST ")
				l_curl_cmd.append (Api_url)
				l_curl_cmd.append (" -H %"Content-Type: application/json%"")
				l_curl_cmd.append (" -H %"Authorization: Bearer ")
				l_curl_cmd.append (api_key)
				l_curl_cmd.append ("%"")
				l_curl_cmd.append (" -d @")
				l_curl_cmd.append (l_temp_path)

				l_output := process_helper.shell_output (l_curl_cmd, Void)
					-- curl's stdout arrives byte-widened, not UTF-8 decoded;
					-- undo that before it reaches the JSON parser.
				l_output := decode_process_bytes (l_output)

				-- Clean up temp file
				create l_temp_file.make_with_name (l_temp_path.to_string_8)
				if l_temp_file.exists then
					l_temp_file.delete
				end

				-- Parse response
				l_response_value := json.parse_response (l_output)
				if attached l_response_value as al_value and then al_value.is_object then
					l_response_obj := al_value.as_object
					Result := parse_response (l_response_obj)
				else
					Result := create_error_response ({STRING_32} "Failed to parse OpenAI response: " + l_output.head (200))
				end
			end
		end

	parse_response (a_obj: SIMPLE_JSON_OBJECT): AI_RESPONSE
			-- Parse OpenAI API JSON response into AI_RESPONSE object.
		local
			l_text: STRING_32
			l_model_name: STRING_32
			l_input_tokens, l_output_tokens: INTEGER
		do
			-- Check for API error response
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
				-- Parse successful response
				create l_text.make_empty

				-- Response format: choices[0].message.content
				if attached a_obj.array_item (Key_choices) as al_choices then
					if al_choices.count > 0 then
						if attached al_choices.object_item (1) as al_choice then
							if attached al_choice.object_item (Key_message) as al_msg then
								if attached al_msg.string_item (Key_content) as al_content then
									l_text := al_content
								end
							end
						end
					end
				end

				-- Extract model name from response
				if attached a_obj.string_item (Key_model) as al_model then
					l_model_name := al_model
				else
					l_model_name := model
				end

				-- Build final AI_RESPONSE object
				if l_text.is_empty then
					Result := create_error_response ("Empty response from OpenAI")
				else
					create Result.make (l_text, l_model_name, provider_name)

					-- Extract token usage
					if attached a_obj.object_item (Key_usage) as al_usage then
						l_input_tokens := al_usage.integer_item (Key_prompt_tokens).to_integer_32
						l_output_tokens := al_usage.integer_item (Key_completion_tokens).to_integer_32
						Result.set_tokens (l_input_tokens, l_output_tokens)
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

	Api_url: STRING_32 = "https://api.openai.com/v1/chat/completions"
			-- OpenAI Chat Completions API endpoint

	Env_api_key_name: STRING_32 = "OPENAI_API_KEY"
			-- Environment variable name for API key

	Max_tokens_default: INTEGER = 4096
			-- Default maximum tokens for response

feature -- Constants: Models

	Default_model: STRING_32 = "gpt-4o-mini"
			-- Default model (fast and cheap)

	-- GPT-4.1 family (latest non-reasoning)
	Model_gpt41: STRING_32 = "gpt-4.1"
			-- GPT-4.1 - smartest non-reasoning model

	Model_gpt41_mini: STRING_32 = "gpt-4.1-mini"
			-- GPT-4.1 mini - smaller, faster

	Model_gpt41_nano: STRING_32 = "gpt-4.1-nano"
			-- GPT-4.1 nano - fastest, most cost-efficient

	-- GPT-4o family
	Model_gpt4o: STRING_32 = "gpt-4o"
			-- GPT-4o - multimodal flagship

	Model_gpt4o_mini: STRING_32 = "gpt-4o-mini"
			-- GPT-4o mini - fast and affordable

	-- GPT-4 Turbo
	Model_gpt4_turbo: STRING_32 = "gpt-4-turbo"
			-- GPT-4 Turbo - previous generation

	-- O-series reasoning models
	Model_o3: STRING_32 = "o3"
			-- o3 - powerful reasoning model

	Model_o3_mini: STRING_32 = "o3-mini"
			-- o3-mini - fast reasoning model

	Model_o3_pro: STRING_32 = "o3-pro"
			-- o3-pro - extended reasoning time

	Model_o1: STRING_32 = "o1"
			-- o1 - previous reasoning model

	Model_o1_pro: STRING_32 = "o1-pro"
			-- o1-pro - previous extended reasoning

	-- GPT-5 family
	Model_gpt5: STRING_32 = "gpt-5"
			-- GPT-5 - flagship reasoning model

	Model_gpt51: STRING_32 = "gpt-5.1"
			-- GPT-5.1 - improved speed and coding

	Model_gpt52: STRING_32 = "gpt-5.2"
			-- GPT-5.2 - latest flagship

feature {NONE} -- Constants: JSON Keys

	Key_model: STRING_32 = "model"
	Key_max_tokens: STRING_32 = "max_tokens"
	Key_messages: STRING_32 = "messages"
	Key_role: STRING_32 = "role"
	Key_content: STRING_32 = "content"
	Key_choices: STRING_32 = "choices"
	Key_message: STRING_32 = "message"
	Key_error: STRING_32 = "error"
	Key_usage: STRING_32 = "usage"
	Key_prompt_tokens: STRING_32 = "prompt_tokens"
	Key_completion_tokens: STRING_32 = "completion_tokens"

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
