note
	description: "[
		Chat with a local llama.cpp `llama-server' through its
		OpenAI-compatible /v1/chat/completions endpoint.

		Made for thinking models (Qwen 3.8 and its Swift fine-tune):

		- REASONING EFFORT. `set_reasoning_effort ("low")' asks the chat
		  template for less thinking, per request. With no effort set,
		  nothing is sent and the template's own default applies - for
		  Qwen 3.8 that is "xhigh", the setting its benchmark scores
		  were measured at.
		- THINKING KEPT APART. `last_reasoning' holds the thinking;
		  the AI_RESPONSE text holds only the answer.
		- STREAMING. `chat_streaming' hands thinking and answer text to
		  two agents as it arrives, so a reply that thinks for minutes
		  is visible from its first word.

		The server is reached through curl.exe with the JSON body in a
		temp file (UTF-8 survives; no command-line length limit), as the
		other providers in this library do. LLAMA_SERVER starts the
		server; this class only talks to one.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LLAMA_CPP_CLIENT

inherit
	AI_CLIENT

create
	make,
	make_with_base_url

feature {NONE} -- Initialization

	make
			-- A client for a server on llama-server's own default port.
		do
			make_with_base_url (Default_base_url)
		ensure
			default_url: base_url.same_string (Default_base_url)
		end

	make_with_base_url (a_base_url: READABLE_STRING_GENERAL)
			-- A client for the server at `a_base_url' (e.g. http://127.0.0.1:8737).
		require
			url_not_empty: not a_base_url.is_empty
			http_url: a_base_url.to_string_32.starts_with ({STRING_32} "http://") or a_base_url.to_string_32.starts_with ({STRING_32} "https://")
			no_quote: not a_base_url.has ('"')
		do
			base_url := a_base_url.to_string_32
			model := Default_model
			create last_reasoning.make_empty
			temperature := Default_temperature
			top_p := Default_top_p
			top_k := Default_top_k
			min_p := Default_min_p
			presence_penalty := Default_presence_penalty
			timeout_seconds := Default_timeout_seconds
		ensure
			url_set: base_url.same_string_general (a_base_url)
			template_default_effort: reasoning_effort = Void
			unlimited_reply: max_tokens = 0
			nothing_yet: last_reasoning.is_empty
		end

feature -- Access

	model: STRING_32
			-- Name sent with each request. llama-server answers with
			-- whatever model it loaded, so this is only a label.

	provider_name: STRING_8 = "llama.cpp"
			-- Provider identifier.

	base_url: STRING_32
			-- Server root.

	reasoning_effort: detachable STRING_32
			-- Effort sent to the chat template ("low", "medium", "xhigh"
			-- for Qwen 3.8); Void sends none, leaving the template's default.

	is_thinking_off: BOOLEAN
			-- Is the template asked to skip thinking altogether?

	max_tokens: INTEGER
			-- Most tokens a reply may use, thinking included; 0 = no limit.

	temperature, top_p, min_p, presence_penalty: REAL_64
			-- Sampling settings (defaults: the Qwen 3.8 thinking-mode card).

	top_k: INTEGER
			-- Sampling: keep the `top_k' likeliest tokens.

	timeout_seconds: INTEGER
			-- Longest a request may run before curl gives up.

	last_reasoning: STRING_32
			-- The thinking behind the most recent reply.

	last_tokens_per_second: REAL_64
			-- Generation speed of the most recent reply, as the server measured it.

	last_finish_reason: detachable STRING_32
			-- Why the most recent reply ended ("stop"; "length" if cut off).

feature -- Status report

	is_available: BOOLEAN
			-- Does the server answer /health with HTTP 200?
		local
			l_process: SIMPLE_PROCESS
			l_output: STRING_32
		do
			create l_process.make
			l_output := l_process.command_output ({STRING_32} "curl.exe -s -o NUL --max-time 2 -w %"%%{http_code}%" %"" + base_url + {STRING_32} "/health%"")
			Result := l_process.was_successful and then l_output.has_substring ({STRING_32} "200")
		end

	is_valid_effort (a_effort: READABLE_STRING_GENERAL): BOOLEAN
			-- Could `a_effort' be a template's effort word? (Letters,
			-- digits and "_" only: it travels inside JSON and must not
			-- carry anything else.)
		do
			Result := not a_effort.is_empty and a_effort.count <= 20 and then
				across 1 |..| a_effort.count as i all is_effort_character (a_effort.item (i)) end
		end

	is_effort_character (a_character: CHARACTER_32): BOOLEAN
			-- Is `a_character' an ASCII letter, digit or "_"?
		do
			Result := a_character.is_character_8 and then
				(a_character.to_character_8.is_alpha_numeric or a_character.to_character_8 = '_')
		end

feature -- Model validation

	is_valid_model (a_model: STRING_32): BOOLEAN
			-- Any label will do: the server uses the model it loaded.
		do
			Result := True
		end

	supported_models: ARRAYED_LIST [STRING_32]
			-- The model the server reports at /v1/models (empty if unreachable).
		local
			l_process: SIMPLE_PROCESS
			l_output: STRING_32
			l_json: SIMPLE_JSON
		do
			create Result.make (1)
			create l_process.make
			l_output := l_process.command_output ({STRING_32} "curl.exe -s --max-time 5 %"" + base_url + {STRING_32} "/v1/models%"")
			if not l_output.is_empty then
				create l_json
				if attached l_json.parse (l_output) as al_value and then al_value.is_object and then
					attached al_value.as_object.array_item ({STRING_32} "data") as al_data
				then
					across 1 |..| al_data.count as i loop
						if attached al_data.object_item (i) as al_entry and then attached al_entry.string_item ({STRING_32} "id") as al_id then
							Result.extend (al_id)
						end
					end
				end
			end
		end

feature -- Element change

	set_model (a_model: STRING_32)
			-- Label requests with `a_model'.
		do
			model := a_model
		end

	set_reasoning_effort (a_effort: READABLE_STRING_GENERAL)
			-- Ask the template for effort `a_effort' on every request.
		require
			valid: is_valid_effort (a_effort)
		do
			reasoning_effort := a_effort.to_string_32
		ensure
			set: attached reasoning_effort as al_effort and then al_effort.same_string_general (a_effort)
		end

	use_template_default_effort
			-- Send no effort; the template's default applies.
		do
			reasoning_effort := Void
		ensure
			cleared: reasoning_effort = Void
			thinking_unchanged: is_thinking_off = old is_thinking_off
		end

	turn_thinking_off
			-- Ask the template to answer without thinking ("enable_thinking": false).
		do
			is_thinking_off := True
		ensure
			off: is_thinking_off
			effort_unchanged: reasoning_effort ~ old reasoning_effort
		end

	turn_thinking_on
			-- Let the model think (the template's default).
		do
			is_thinking_off := False
		ensure
			on: not is_thinking_off
			effort_unchanged: reasoning_effort ~ old reasoning_effort
		end

	set_max_tokens (a_tokens: INTEGER)
			-- Cap replies at `a_tokens' (0: no cap).
		require
			non_negative: a_tokens >= 0
		do
			max_tokens := a_tokens
		ensure
			set: max_tokens = a_tokens
		end

	set_sampling (a_temperature, a_top_p: REAL_64; a_top_k: INTEGER; a_min_p, a_presence_penalty: REAL_64)
			-- Use these sampling settings.
		require
			temperature_ok: a_temperature >= 0.0 and a_temperature <= 2.0
			top_p_ok: a_top_p > 0.0 and a_top_p <= 1.0
			top_k_ok: a_top_k >= 0
			min_p_ok: a_min_p >= 0.0 and a_min_p <= 1.0
			presence_ok: a_presence_penalty >= -2.0 and a_presence_penalty <= 2.0
		do
			temperature := a_temperature
			top_p := a_top_p
			top_k := a_top_k
			min_p := a_min_p
			presence_penalty := a_presence_penalty
		ensure
			set: temperature = a_temperature and top_p = a_top_p and top_k = a_top_k
				and min_p = a_min_p and presence_penalty = a_presence_penalty
		end

	set_timeout_seconds (a_seconds: INTEGER)
			-- Let a request run up to `a_seconds'.
		require
			positive: a_seconds > 0
		do
			timeout_seconds := a_seconds
		ensure
			set: timeout_seconds = a_seconds
		end

feature -- Basic operations

	chat_streaming (a_messages: ARRAY [AI_MESSAGE];
			a_on_reasoning, a_on_content: detachable PROCEDURE [STRING_32]): AI_RESPONSE
			-- Send `a_messages'; hand each piece of thinking to `a_on_reasoning'
			-- and each piece of the answer to `a_on_content' as it arrives.
		require
			messages_not_empty: a_messages.count > 0
			all_messages_attached: across a_messages as ic all ic /= Void end
		local
			l_body_path: detachable STRING_32
			l_process: SIMPLE_ASYNC_PROCESS
			l_decoder: LLAMA_REPLY_DECODER
			l_env: EXECUTION_ENVIRONMENT
			l_finished, l_done: BOOLEAN
			l_fed: INTEGER
		do
			reset_last
			create l_decoder.make
			l_body_path := write_temp_file (request_json (a_messages, True))
			if attached l_body_path as al_path then
				create l_env
				create l_process.make
				l_process.start (curl_command (al_path, True))
				if l_process.was_started_successfully then
					from
					until
						l_done
					loop
							-- Sample `has_finished' BEFORE reading, so the read
							-- that follows a finish sees everything curl wrote.
						l_finished := l_process.has_finished
						if attached l_process.read_available_output as al_piece then
							l_decoder.feed (al_piece)
							l_fed := l_fed + al_piece.count
							pass_fresh_text (l_decoder, a_on_reasoning, a_on_content)
						elseif l_finished then
							l_done := True
						else
							l_env.sleep (Poll_nanoseconds)
						end
					end
					l_process.close
						-- `close' collects whatever the pump threads still held.
					if l_process.accumulated_output.count > l_fed then
						l_decoder.feed (l_process.accumulated_output.substring (l_fed + 1, l_process.accumulated_output.count))
					end
					l_decoder.finish
					pass_fresh_text (l_decoder, a_on_reasoning, a_on_content)
					Result := response_from (l_decoder)
				elseif attached l_process.last_error as al_reason then
					Result := error_response ({STRING_32} "could not run curl.exe: " + al_reason)
				else
					Result := error_response ({STRING_32} "could not run curl.exe")
				end
				delete_temp_file (al_path)
			else
				Result := error_response ({STRING_32} "could not write the request to the temp folder")
			end
		ensure
			result_attached: Result /= Void
			provider_matches: Result.provider ~ provider_name
		end

feature -- Request building (public for tests)

	request_json (a_messages: ARRAY [AI_MESSAGE]; a_stream: BOOLEAN): STRING_32
			-- The JSON body for `a_messages'.
		require
			messages_not_empty: a_messages.count > 0
		local
			l_request, l_message, l_kwargs: SIMPLE_JSON_OBJECT
			l_array: SIMPLE_JSON_ARRAY
		do
			create l_request.make
			l_request.put_string (model, {STRING_32} "model").do_nothing
			create l_array.make
			across a_messages as ic loop
				create l_message.make
				l_message.put_string (ic.role.to_string_32, {STRING_32} "role").do_nothing
				l_message.put_string (ic.content, {STRING_32} "content").do_nothing
				l_array.add_object (l_message).do_nothing
			end
			l_request.put_array (l_array, {STRING_32} "messages").do_nothing
			l_request.put_boolean (a_stream, {STRING_32} "stream").do_nothing
			if a_stream then
					-- Ask for token counts on the last event.
				create l_kwargs.make
				l_kwargs.put_boolean (True, {STRING_32} "include_usage").do_nothing
				l_request.put_object (l_kwargs, {STRING_32} "stream_options").do_nothing
			end
			l_request.put_real (temperature, {STRING_32} "temperature").do_nothing
			l_request.put_real (top_p, {STRING_32} "top_p").do_nothing
			l_request.put_integer (top_k, {STRING_32} "top_k").do_nothing
			l_request.put_real (min_p, {STRING_32} "min_p").do_nothing
			l_request.put_real (presence_penalty, {STRING_32} "presence_penalty").do_nothing
			l_request.put_boolean (True, {STRING_32} "cache_prompt").do_nothing
			if max_tokens > 0 then
				l_request.put_integer (max_tokens, {STRING_32} "max_tokens").do_nothing
			end
			if attached reasoning_effort or is_thinking_off then
				create l_kwargs.make
				if attached reasoning_effort as al_effort then
					l_kwargs.put_string (al_effort, {STRING_32} "reasoning_effort").do_nothing
				end
				if is_thinking_off then
					l_kwargs.put_boolean (False, {STRING_32} "enable_thinking").do_nothing
				end
				l_request.put_object (l_kwargs, {STRING_32} "chat_template_kwargs").do_nothing
			end
			Result := l_request.to_json_string
		ensure
			thinking_off_sent: is_thinking_off implies Result.has_substring ({STRING_32} "%"enable_thinking%":false")
			effort_sent_when_set: attached reasoning_effort implies Result.has_substring ({STRING_32} "%"chat_template_kwargs%"")
			cap_sent_when_set: max_tokens > 0 implies Result.has_substring ({STRING_32} "%"max_tokens%"")
		end

	curl_command (a_body_path: READABLE_STRING_GENERAL; a_stream: BOOLEAN): STRING_32
			-- The curl.exe line that posts the body at `a_body_path'.
		require
			path_not_empty: not a_body_path.is_empty
			no_quote: not a_body_path.has ('"')
		do
			create Result.make (200)
			Result.append ({STRING_32} "curl.exe -sS")
			if a_stream then
					-- No output buffering: each event reaches us as it is sent.
				Result.append ({STRING_32} " -N")
			end
			Result.append ({STRING_32} " --max-time ")
			Result.append (timeout_seconds.out)
			Result.append ({STRING_32} " -X POST -H %"Content-Type: application/json%" --data-binary %"@")
			Result.append_string_general (a_body_path)
			Result.append ({STRING_32} "%" %"")
			Result.append (base_url)
			Result.append ({STRING_32} "/v1/chat/completions%"")
		ensure
			posts_body: Result.has_substring ({STRING_32} "@" + a_body_path.to_string_32)
			unbuffered_when_streaming: a_stream implies Result.has_substring ({STRING_32} " -N ")
		end

feature {NONE} -- Implementation

	execute_chat (a_messages: ARRAY [AI_MESSAGE]; a_options: detachable ANY): AI_RESPONSE
			-- Send `a_messages' and wait for the whole reply.
		local
			l_body_path: detachable STRING_32
			l_process: SIMPLE_PROCESS
			l_output: STRING_32
			l_decoder: LLAMA_REPLY_DECODER
		do
			reset_last
			l_body_path := write_temp_file (request_json (a_messages, False))
			if attached l_body_path as al_path then
				create l_process.make
				l_output := l_process.command_output (curl_command (al_path, False))
				delete_temp_file (al_path)
				create l_decoder.make
				if l_output.is_empty then
					Result := error_response ({STRING_32} "no reply from llama-server at " + base_url + {STRING_32} " (not running?)")
				else
					l_decoder.decode_whole (l_output)
					Result := response_from (l_decoder)
				end
			else
				Result := error_response ({STRING_32} "could not write the request to the temp folder")
			end
		end

	pass_fresh_text (a_decoder: LLAMA_REPLY_DECODER; a_on_reasoning, a_on_content: detachable PROCEDURE [STRING_32])
			-- Hand `a_decoder''s fresh text to the agents, then mark it taken.
		do
			if not a_decoder.fresh_reasoning.is_empty and attached a_on_reasoning as al_agent then
				al_agent.call ([a_decoder.fresh_reasoning.twin])
			end
			if not a_decoder.fresh_content.is_empty and attached a_on_content as al_agent then
				al_agent.call ([a_decoder.fresh_content.twin])
			end
			a_decoder.clear_fresh
		ensure
			taken: not a_decoder.has_fresh_text
		end

	reset_last
			-- Forget the previous reply's extras.
		do
			last_reasoning := create {STRING_32}.make_empty
			last_tokens_per_second := 0.0
			last_finish_reason := Void
		ensure
			cleared: last_reasoning.is_empty and last_tokens_per_second = 0.0 and last_finish_reason = Void
		end

	response_from (a_decoder: LLAMA_REPLY_DECODER): AI_RESPONSE
			-- The response `a_decoder' read; also fills the `last_*' extras.
		local
			l_text: STRING_32
		do
			last_reasoning := a_decoder.reasoning.twin
			last_tokens_per_second := a_decoder.tokens_per_second
			last_finish_reason := a_decoder.finish_reason
			if attached a_decoder.error_message as al_error and then not al_error.is_empty then
				Result := error_response ({STRING_32} "llama-server: " + al_error)
			else
				l_text := a_decoder.content.twin
				l_text.left_adjust
				l_text.right_adjust
				if not l_text.is_empty then
					create Result.make (l_text, model, provider_name)
					Result.set_tokens (a_decoder.prompt_tokens, a_decoder.output_tokens)
				elseif not a_decoder.reasoning.is_empty then
					Result := error_response ({STRING_32} "the model thought but gave no answer (finish: " + finish_label (a_decoder) + {STRING_32} ")")
				elseif not a_decoder.stray_text.is_empty then
					Result := error_response ({STRING_32} "no reply from llama-server at " + base_url + {STRING_32} ": " + a_decoder.stray_text.head (300))
				else
					Result := error_response ({STRING_32} "empty reply from llama-server at " + base_url)
				end
			end
		ensure
			provider_matches: Result.provider ~ provider_name
			reasoning_kept: last_reasoning ~ a_decoder.reasoning
		end

	finish_label (a_decoder: LLAMA_REPLY_DECODER): STRING_32
			-- `a_decoder''s finish reason, or "unknown".
		do
			if attached a_decoder.finish_reason as al_reason then
				Result := al_reason
			else
				Result := {STRING_32} "unknown"
			end
		end

	error_response (a_message: STRING_32): AI_RESPONSE
			-- An error response saying `a_message'.
		require
			not_empty: not a_message.is_empty
		do
			create Result.make_error (a_message, provider_name)
		ensure
			is_error: Result.is_error
		end

	write_temp_file (a_content: STRING_32): detachable STRING_32
			-- Write `a_content' as UTF-8 to a uniquely named temp file; its
			-- path, or Void on failure.
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
				l_path := l_dir + {STRING_32} "\simple_ai_llama_" + l_uuid.new_v4_compact.to_string_32 + {STRING_32} ".json"
				create l_file.make_with_name (l_path)
				l_file.create_read_write
				l_file.put_string ({UTF_CONVERTER}.string_32_to_utf_8_string_8 (a_content))
				l_file.close
				Result := l_path
			end
		rescue
			l_failed := True
			retry
		end

	delete_temp_file (a_path: STRING_32)
			-- Delete `a_path', ignoring failure.
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

feature -- Constants

	Default_base_url: STRING_32 = "http://127.0.0.1:8080"
			-- llama-server's own default address.

	Default_model: STRING_32 = "local"
			-- Request label.

	Default_temperature: REAL_64 = 1.0
	Default_top_p: REAL_64 = 0.95
	Default_top_k: INTEGER = 20
	Default_min_p: REAL_64 = 0.0
	Default_presence_penalty: REAL_64 = 0.0
			-- Qwen 3.8 thinking-mode sampling, from the model card.

	Default_timeout_seconds: INTEGER = 3600
			-- An hour: a hard question at "xhigh" can think for many minutes.

	Poll_nanoseconds: INTEGER_64 = 20_000_000
			-- 20 ms between looks at the stream when nothing has arrived.

invariant
	base_url_not_empty: not base_url.is_empty
	model_not_empty: not model.is_empty
	effort_valid: attached reasoning_effort as al_effort implies is_valid_effort (al_effort)
	max_tokens_non_negative: max_tokens >= 0
	timeout_positive: timeout_seconds > 0
	reasoning_attached: last_reasoning /= Void

note
	copyright: "Copyright (c) 2026, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
