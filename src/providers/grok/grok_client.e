note
	description: "Grok AI client using xAI API (OpenAI-compatible)"
	date: "$Date$"
	revision: "$Revision$"

class
	GROK_CLIENT

inherit
	AI_CLIENT

create
	make_with_api_key

feature {NONE} -- Initialization

	make_with_api_key (a_key: STRING_32)
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
	provider_name: STRING_8 = "grok"
	api_key: STRING_32

feature -- Element change

	set_model (a_model: STRING_32)
		do
			model := a_model
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
			l_temp_file.put_string (l_json_body.to_string_8)
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
			
			create l_temp_file.make_with_name (l_temp_path.to_string_8)
			if l_temp_file.exists then
				l_temp_file.delete
			end
			
			l_response_value := json.parse_response (l_output)
			if attached l_response_value as al_value and then al_value.is_object then
				l_response_obj := al_value.as_object
				Result := parse_response (l_response_obj)
			else
				Result := create_error_response ("Failed to parse Grok response: " + l_output.head (100))
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

feature {NONE} -- Constants

	Api_endpoint: STRING_32 = "https://api.x.ai/v1/chat/completions"
	Default_model: STRING_32 = "grok-3"

invariant
	api_key_attached: api_key /= Void
	model_attached: model /= Void

end