note
	description: "[
		Grok AI client using xAI API (OpenAI-compatible).

		API key is read from GROK_API_KEY environment variable.

		Supported Models:
		- grok-3 (default, most capable)
		- grok-3-fast (faster responses)

		Design by Contract:
		- API key must be set (via environment or explicit)
		- All operations require valid API key
		- Responses always attached (error or success)
	]"
	date: "$Date$"
	revision: "$Revision$"

class
	GROK_CLIENT

inherit
	AI_CLIENT

create
	make,
	make_with_api_key

feature {NONE} -- Initialization

	make
			-- Create with API key from environment variable GROK_API_KEY
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

	make_with_api_key (a_key: STRING_32)
			-- Create with explicit API key
		require
			key_not_empty: not a_key.is_empty
		do
			api_key := a_key
			model := Default_model
			create process_helper
			create json
		ensure
			key_set: api_key = a_key
			model_set: model ~ Default_model
		end

feature -- Access

	model: STRING_32
			-- Current model (e.g., "grok-3")

	provider_name: STRING_8 = "grok"
			-- Provider identifier

	api_key: STRING_32
			-- xAI API key

feature -- Status report

	has_api_key: BOOLEAN
			-- Is API key configured?
		do
			Result := not api_key.is_empty
		ensure
			definition: Result = not api_key.is_empty
		end

	is_available: BOOLEAN
			-- Is Grok API available (has key)?
		do
			Result := has_api_key
		end

feature -- Element change

	set_model (a_model: STRING_32)
		do
			model := a_model
		end

feature -- Model validation

	is_valid_model (a_model: STRING_32): BOOLEAN
			-- Is `a_model' a valid Grok model?
		do
			Result := across supported_models as m some m.same_string (a_model) end
		end

	supported_models: ARRAYED_LIST [STRING_32]
			-- List of supported Grok model identifiers.
		do
			create Result.make (15)
			-- Grok 4.1 family
			Result.extend (Model_grok41_fast_reasoning)
			Result.extend (Model_grok41_fast_non_reasoning)
			-- Grok 4 family
			Result.extend (Model_grok4)
			Result.extend (Model_grok4_fast_reasoning)
			Result.extend (Model_grok4_fast_non_reasoning)
			-- Grok 3 family
			Result.extend (Model_grok3)
			Result.extend (Model_grok3_mini)
			-- Grok 2 family
			Result.extend (Model_grok2)
			Result.extend (Model_grok2_vision)
			Result.extend (Model_grok2_image)
			-- Specialized
			Result.extend (Model_grok_code_fast)
		ensure then
			has_models: Result.count >= 8
		end

feature -- Model selection helpers

	use_grok4
			-- Use Grok 4 (most capable reasoning)
		do
			set_model (Model_grok4)
		ensure
			model_set: model ~ Model_grok4
		end

	use_grok3
			-- Use Grok 3 (balanced)
		do
			set_model (Model_grok3)
		ensure
			model_set: model ~ Model_grok3
		end

	use_grok3_mini
			-- Use Grok 3 Mini (fast, budget-friendly)
		do
			set_model (Model_grok3_mini)
		ensure
			model_set: model ~ Model_grok3_mini
		end

feature {NONE} -- Implementation

	execute_chat (a_messages: ARRAY [AI_MESSAGE]; a_options: detachable ANY): AI_RESPONSE
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
			create l_request.make
			l_request.put_string (model, "model").do_nothing
			
			create l_messages_array.make
			across a_messages as ic loop
				create l_msg_obj.make
				l_msg_obj.put_string (ic.role.as_string_32, "role").do_nothing
				l_msg_obj.put_string (ic.content, "content").do_nothing
				l_messages_array.add_object (l_msg_obj).do_nothing
			end
			l_request.put_array (l_messages_array, "messages").do_nothing
			l_request.put_integer (4096, "max_tokens").do_nothing
			
			l_json_body := l_request.to_json_string
			
			l_temp_path := {STRING_32} "grok_request.json"
			create l_temp_file.make_create_read_write (l_temp_path.to_string_8)
				-- Encode as real UTF-8: `l_json_body` may hold code points
				-- above 255, which `to_string_8` would truncate.
			l_temp_file.put_string ({UTF_CONVERTER}.string_32_to_utf_8_string_8 (l_json_body))
			l_temp_file.close
			
			create l_curl_cmd.make (500)
			l_curl_cmd.append ("curl.exe -s -X POST ")
			l_curl_cmd.append (Api_endpoint)
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
			
			create l_temp_file.make_with_name (l_temp_path.to_string_8)
			if l_temp_file.exists then
				l_temp_file.delete
			end
			
			l_response_value := json.parse_response (l_output)
			if attached l_response_value as al_value and then al_value.is_object then
				l_response_obj := al_value.as_object
				Result := parse_response (l_response_obj)
			else
				Result := create_error_response ({STRING_32} "Failed to parse Grok response: " + l_output.head (100))
			end
		end

	parse_response (a_obj: SIMPLE_JSON_OBJECT): AI_RESPONSE
		local
			l_text: STRING_32
			l_model_name: STRING_32
		do
			create l_text.make_empty
			
			if attached a_obj.array_item ("choices") as al_choices then
				if al_choices.count > 0 then
					if attached al_choices.item (1) as al_choice and then al_choice.is_object then
						if attached al_choice.as_object.object_item ("message") as al_msg then
							if attached al_msg.string_item ("content") as al_content then
								l_text := al_content
							end
						end
					end
				end
			end
			
			if attached a_obj.string_item ("model") as al_model then
				l_model_name := al_model
			else
				l_model_name := model
			end
			
			if l_text.is_empty then
				if attached a_obj.object_item ("error") as al_error then
					if attached al_error.string_item ("message") as al_msg then
						Result := create_error_response (al_msg)
					else
						Result := create_error_response ("Unknown Grok error")
					end
				else
					Result := create_error_response ("Empty response from Grok")
				end
			else
				create Result.make (l_text, l_model_name, provider_name)
			end
		end

	create_error_response (a_message: STRING_32): AI_RESPONSE
		do
			create Result.make_error (a_message, provider_name)
		end

feature {NONE} -- Implementation: Attributes

	process_helper: SIMPLE_PROCESS_HELPER
	json: SIMPLE_JSON

feature {NONE} -- Constants: API

	Api_endpoint: STRING_32 = "https://api.x.ai/v1/chat/completions"
			-- xAI API endpoint

	Env_api_key_name: STRING_32 = "GROK_API_KEY"
			-- Environment variable name for API key

feature -- Constants: Models

	Default_model: STRING_32 = "grok-3"
			-- Default model (balanced)

	-- Grok 4.1 family
	Model_grok41_fast_reasoning: STRING_32 = "grok-4-1-fast-reasoning"
			-- Grok 4.1 fast reasoning

	Model_grok41_fast_non_reasoning: STRING_32 = "grok-4-1-fast-non-reasoning"
			-- Grok 4.1 fast non-reasoning

	-- Grok 4 family
	Model_grok4: STRING_32 = "grok-4"
			-- Grok 4 - most capable reasoning

	Model_grok4_fast_reasoning: STRING_32 = "grok-4-fast-reasoning"
			-- Grok 4 fast reasoning

	Model_grok4_fast_non_reasoning: STRING_32 = "grok-4-fast-non-reasoning"
			-- Grok 4 fast non-reasoning

	-- Grok 3 family
	Model_grok3: STRING_32 = "grok-3"
			-- Grok 3 - balanced

	Model_grok3_mini: STRING_32 = "grok-3-mini"
			-- Grok 3 Mini - fast, budget-friendly

	-- Grok 2 family
	Model_grok2: STRING_32 = "grok-2-1212"
			-- Grok 2 (December 2024 version)

	Model_grok2_vision: STRING_32 = "grok-2-vision-1212"
			-- Grok 2 Vision

	Model_grok2_image: STRING_32 = "grok-2-image-1212"
			-- Grok 2 Image generation

	-- Specialized models
	Model_grok_code_fast: STRING_32 = "grok-code-fast-1"
			-- Grok Code Fast - optimized for coding

invariant
	api_key_attached: api_key /= Void
	model_attached: model /= Void

end