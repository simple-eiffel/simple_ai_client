note
	description: "[
		Google AI (Gemini) client using curl via SIMPLE_PROCESS_HELPER.

		Implements the Google Generative Language API for Gemini models.
		API key is read from GOOGLE_AI_KEY environment variable.

		Supported Models:
		- gemini-1.5-flash (default, fast and efficient)
		- gemini-1.5-pro (more capable)
		- gemini-2.0-flash-exp (experimental)

		API Documentation:
		https://ai.google.dev/gemini-api/docs

		Design by Contract:
		- API key must be set (via environment or explicit)
		- All operations require valid API key
		- Responses always attached (error or success)
	]"
	date: "$Date$"
	revision: "$Revision$"

class
	GOOGLE_AI_CLIENT

inherit
	AI_CLIENT

create
	make,
	make_with_api_key

feature {NONE} -- Initialization

	make
			-- Create with API key from environment variable GOOGLE_AI_KEY
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
			-- Current model (e.g., "gemini-1.5-flash")

	provider_name: STRING_8 = "google"
			-- Provider identifier

	api_key: STRING_32
			-- Google AI API key

feature -- Status report

	has_api_key: BOOLEAN
			-- Is API key configured?
		do
			Result := not api_key.is_empty
		ensure
			definition: Result = not api_key.is_empty
		end

	is_available: BOOLEAN
			-- Is Google AI API available (has key)?
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

feature -- Model selection helpers

	use_flash
			-- Use Gemini 1.5 Flash (fast and efficient)
		do
			set_model (Model_flash)
		ensure
			model_set: model ~ Model_flash
		end

	use_pro
			-- Use Gemini 1.5 Pro (more capable)
		do
			set_model (Model_pro)
		ensure
			model_set: model ~ Model_pro
		end

feature {NONE} -- Implementation

	execute_chat (a_messages: ARRAY [AI_MESSAGE]; a_options: detachable ANY): AI_RESPONSE
			-- Execute chat via Google Generative Language API.
			-- Converts AI_MESSAGE array to Google's contents format, sends via curl,
			-- and parses the response into an AI_RESPONSE object.
		local
			l_request: SIMPLE_JSON_OBJECT
			l_contents_array: SIMPLE_JSON_ARRAY
			l_content_obj: SIMPLE_JSON_OBJECT
			l_parts_array: SIMPLE_JSON_ARRAY
			l_part_obj: SIMPLE_JSON_OBJECT
			l_curl_cmd: STRING_32
			l_output: STRING_32
			l_response_value: SIMPLE_JSON_VALUE
			l_response_obj: SIMPLE_JSON_OBJECT
			l_json_body: STRING_32
			l_temp_file: RAW_FILE
			l_temp_path: STRING_32
			l_system_instruction: detachable SIMPLE_JSON_OBJECT
		do
			-- Guard: ensure API key is configured before making request
			if not has_api_key then
				Result := create_error_response ("API key not configured. Set GOOGLE_AI_KEY environment variable.")
			else
				create l_request.make
				create l_contents_array.make

				-- Google API uses "contents" array with role and parts
				-- System messages become systemInstruction
				across a_messages as ic loop
					if ic.is_system then
						-- Google uses systemInstruction for system prompts
						create l_system_instruction.make
						create l_parts_array.make
						create l_part_obj.make
						l_part_obj.put_string (ic.content, Key_text).do_nothing
						l_parts_array.add_object (l_part_obj).do_nothing
						l_system_instruction.put_array (l_parts_array, Key_parts).do_nothing
					else
						create l_content_obj.make
						-- Google uses "user" and "model" roles (not "assistant")
						if ic.is_assistant then
							l_content_obj.put_string ("model", Key_role).do_nothing
						else
							l_content_obj.put_string (ic.role, Key_role).do_nothing
						end
						create l_parts_array.make
						create l_part_obj.make
						l_part_obj.put_string (ic.content, Key_text).do_nothing
						l_parts_array.add_object (l_part_obj).do_nothing
						l_content_obj.put_array (l_parts_array, Key_parts).do_nothing
						l_contents_array.add_object (l_content_obj).do_nothing
					end
				end

				l_request.put_array (l_contents_array, Key_contents).do_nothing

				-- Add system instruction if we had system messages
				if attached l_system_instruction as al_sys then
					l_request.put_object (al_sys, Key_system_instruction).do_nothing
				end

				l_json_body := l_request.to_json_string

				-- Write JSON to temp file to avoid escaping issues
				l_temp_path := {STRING_32} "google_ai_request.json"
				create l_temp_file.make_create_read_write (l_temp_path.to_string_8)
				l_temp_file.put_string (l_json_body.to_string_8)
				l_temp_file.close

				-- Build curl command with API key in URL
				create l_curl_cmd.make (500)
				l_curl_cmd.append ("curl.exe -s -X POST %"")
				l_curl_cmd.append (Api_base_url)
				l_curl_cmd.append (model)
				l_curl_cmd.append (":generateContent?key=")
				l_curl_cmd.append (api_key)
				l_curl_cmd.append ("%" -H %"Content-Type: application/json%" -d @")
				l_curl_cmd.append (l_temp_path)

				l_output := process_helper.shell_output (l_curl_cmd, Void)

				-- Clean up temp file
				create l_temp_file.make_with_name (l_temp_path.to_string_8)
				if l_temp_file.exists then
					l_temp_file.delete
				end

				-- Parse response
				l_response_value := json.parse_response (l_output)
				if attached l_response_value as al_value and then al_value.is_object then
					l_response_obj := al_value.as_object
					Result := parse_response (l_response_obj, l_output)
				else
					Result := create_error_response ({STRING_32} "Failed to parse Google AI response: " + l_output.head (200))
				end
			end
		end

	parse_response (a_obj: SIMPLE_JSON_OBJECT; a_raw: STRING_32): AI_RESPONSE
			-- Parse Google AI JSON response into AI_RESPONSE object.
		local
			l_text: STRING_32
			i, j: INTEGER
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
				-- Parse successful response - extract text from candidates
				create l_text.make_empty

				-- Response format: candidates[0].content.parts[0].text
				if attached a_obj.array_item (Key_candidates) as al_candidates then
					from i := 1 until i > al_candidates.count loop
						if attached al_candidates.object_item (i) as al_candidate then
							if attached al_candidate.object_item (Key_content) as al_content then
								if attached al_content.array_item (Key_parts) as al_parts then
									from j := 1 until j > al_parts.count loop
										if attached al_parts.object_item (j) as al_part then
											if attached al_part.string_item (Key_text) as al_text then
												if not l_text.is_empty then
													l_text.append ("%N")
												end
												l_text.append (al_text)
											end
										end
										j := j + 1
									end
								end
							end
						end
						i := i + 1
					end
				end

				-- Build final AI_RESPONSE object
				if l_text.is_empty then
					Result := create_error_response ("Empty response from Google AI")
				else
					create Result.make (l_text, model, provider_name)
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

	Api_base_url: STRING_32 = "https://generativelanguage.googleapis.com/v1beta/models/"
			-- Google Generative Language API base URL

	Env_api_key_name: STRING_32 = "GOOGLE_AI_KEY"
			-- Environment variable name for API key

feature -- Constants: Models

	Default_model: STRING_32 = "gemini-1.5-flash"
			-- Default model (fast and efficient)

	Model_flash: STRING_32 = "gemini-1.5-flash"
			-- Gemini 1.5 Flash - fast and efficient

	Model_pro: STRING_32 = "gemini-1.5-pro"
			-- Gemini 1.5 Pro - more capable

feature {NONE} -- Constants: JSON Keys

	Key_contents: STRING_32 = "contents"
	Key_content: STRING_32 = "content"
	Key_candidates: STRING_32 = "candidates"
	Key_parts: STRING_32 = "parts"
	Key_text: STRING_32 = "text"
	Key_role: STRING_32 = "role"
	Key_system_instruction: STRING_32 = "systemInstruction"
	Key_error: STRING_32 = "error"
	Key_message: STRING_32 = "message"

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
