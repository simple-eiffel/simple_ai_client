note
	description: "Ollama AI client using curl via SIMPLE_PROCESS_HELPER"
	date: "$Date$"
	revision: "$Revision$"

class
	OLLAMA_CLIENT

inherit
	AI_CLIENT

create
	make,
	make_with_base_url

feature {NONE} -- Initialization

	make
			-- Create with default localhost URL
		do
			make_with_base_url (Default_base_url)
		ensure
			model_set: model ~ Default_model
		end

	make_with_base_url (a_base_url: STRING_32)
			-- Create with custom base URL
		require
			url_not_empty: not a_base_url.is_empty
		do
			base_url := a_base_url
			model := Default_model
			create process_helper
			create json
		ensure
			base_url_set: base_url = a_base_url
		end

feature -- Access

	model: STRING_32
			-- Current model

	provider_name: STRING_8 = "ollama"

	base_url: STRING_32
			-- Ollama server base URL

feature -- Element change

	set_model (a_model: STRING_32)
			-- Set model
		do
			model := a_model
		end

feature {NONE} -- Implementation

	execute_chat (a_messages: ARRAY [AI_MESSAGE]; a_options: detachable ANY): AI_RESPONSE
			-- Execute chat via curl
		local
			l_request: SIMPLE_JSON_OBJECT
			l_messages_array: SIMPLE_JSON_ARRAY
			l_msg_obj: SIMPLE_JSON_OBJECT
			l_curl_cmd: STRING_32
			l_output: STRING_32
			l_response_value: SIMPLE_JSON_VALUE
			l_response_obj: SIMPLE_JSON_OBJECT
		do
			create l_request.make
			l_request.put_string (model, Key_model).do_nothing
			
			create l_messages_array.make
			across a_messages as ic loop
				create l_msg_obj.make
				l_msg_obj.put_string (ic.role.as_string_32, Key_role).do_nothing
				l_msg_obj.put_string (ic.content, Key_content).do_nothing
				l_messages_array.add_object (l_msg_obj).do_nothing
			end
			l_request.put_array (l_messages_array, Key_messages).do_nothing
			l_request.put_boolean (False, Key_stream).do_nothing
			
			l_curl_cmd := build_curl_command (Endpoint_chat, l_request.to_json_string)
			l_output := process_helper.output_of_command (l_curl_cmd, Void)
			
			l_response_value := json.parse (l_output)
			if attached l_response_value as al_value and then al_value.is_object then
				l_response_obj := al_value.as_object
				Result := parse_chat_response (l_response_obj)
			else
				Result := create_error_response ("Failed to parse Ollama response")
			end
		end

	build_curl_command (a_endpoint: STRING_32; a_json_body: STRING_32): STRING_32
			-- Build curl command
		local
			l_url: STRING_32
		do
			l_url := base_url + a_endpoint
			create Result.make (500)
			Result.append ("curl.exe -s -X POST ")
			Result.append (l_url)
			Result.append (" -H %"Content-Type: application/json%" -d %"")
			Result.append (escape_for_windows (a_json_body))
			Result.append ("%"")
		end

	escape_for_windows (a_json: STRING_32): STRING_32
			-- Escape JSON for Windows cmd
		do
			create Result.make_from_string (a_json)
			Result.replace_substring_all ({STRING_32} "%"", {STRING_32} "\%"")
		end

	parse_chat_response (a_obj: SIMPLE_JSON_OBJECT): AI_RESPONSE
			-- Parse Ollama chat response
		local
			l_text: STRING_32
			l_model_name: STRING_32
		do
			if attached a_obj.object_item (Key_message) as al_msg then
				if attached al_msg.string_item (Key_content) as al_content then
					l_text := al_content
				else
					create l_text.make_empty
				end
			else
				create l_text.make_empty
			end
			
			if attached a_obj.string_item (Key_model) as al_model then
				l_model_name := al_model
			else
				l_model_name := model
			end
			
			create Result.make (l_text, l_model_name, provider_name)
			
			if l_text.is_empty then
				Result := create_error_response ("Empty response from Ollama")
			end
		end

	create_error_response (a_message: STRING_32): AI_RESPONSE
			-- Create error response
		do
			create Result.make_error (a_message, provider_name)
		end

feature {NONE} -- Implementation: Attributes

	process_helper: SIMPLE_PROCESS_HELPER
			-- Process helper for curl

	json: SIMPLE_JSON
			-- JSON parser

feature {NONE} -- Constants

	Default_base_url: STRING_32 = "http://localhost:11434"

	Default_model: STRING_32 = "llama3"

	Endpoint_chat: STRING_32 = "/api/chat"

	Key_model: STRING_32 = "model"
	Key_messages: STRING_32 = "messages"
	Key_role: STRING_32 = "role"
	Key_content: STRING_32 = "content"
	Key_stream: STRING_32 = "stream"
	Key_message: STRING_32 = "message"

invariant
	model_attached: model /= Void
	base_url_attached: base_url /= Void

note
	copyright: "Copyright (c) 2025, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
