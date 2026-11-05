note
	description: "[
		Offline tests for the llama.cpp provider: LLAMA_REPLY_DECODER,
		LLAMA_SERVER_SETTINGS and the request side of LLAMA_CPP_CLIENT.
		No server, no network.

		The stream fixtures follow llama-server's OpenAI-compatible
		output (build 12069): "data: {...}" events whose delta carries
		"reasoning_content" (thinking) or "content" (answer), a final
		event with "usage" and "timings", then "data: [DONE]".
	]"
	testing: "covers"

class
	TEST_LLAMA_CPP_OFFLINE

inherit
	TEST_SET_BASE

feature -- Test routines: decoder, streamed

	test_stream_split_anywhere
			-- Events split at arbitrary points still decode to the same text.
		note
			testing: "covers/{LLAMA_REPLY_DECODER}.feed"
		local
			l_decoder: LLAMA_REPLY_DECODER
			l_stream: STRING_32
			l_cut: INTEGER
		do
			l_stream := sample_stream
			across 1 |..| 40 as ic loop
				create l_decoder.make
				l_cut := 1 + (ic * 37) \\ l_stream.count
				l_decoder.feed (l_stream.substring (1, l_cut))
				l_decoder.feed (l_stream.substring (l_cut + 1, l_stream.count))
				l_decoder.finish
				assert_strings_equal ("reasoning_" + ic.out, {STRING_32} "Let me think. Done.", l_decoder.reasoning)
				assert_strings_equal ("content_" + ic.out, {STRING_32} "Hello, world.", l_decoder.content)
				assert_true ("done_" + ic.out, l_decoder.is_done)
			end
		end

	test_stream_fresh_text
			-- Fresh text is what arrived since the last `clear_fresh'.
		note
			testing: "covers/{LLAMA_REPLY_DECODER}.clear_fresh"
		local
			l_decoder: LLAMA_REPLY_DECODER
		do
			create l_decoder.make
			l_decoder.feed (event ({STRING_32} "reasoning_content", {STRING_32} "Hmm."))
			assert_strings_equal ("first_thought", {STRING_32} "Hmm.", l_decoder.fresh_reasoning)
			assert_true ("no_answer_yet", l_decoder.fresh_content.is_empty)
			l_decoder.clear_fresh
			assert_false ("taken", l_decoder.has_fresh_text)
			l_decoder.feed (event ({STRING_32} "content", {STRING_32} "Yes"))
			assert_strings_equal ("answer", {STRING_32} "Yes", l_decoder.fresh_content)
			assert_true ("old_thought_not_fresh", l_decoder.fresh_reasoning.is_empty)
			assert_strings_equal ("total_kept", {STRING_32} "Hmm.", l_decoder.reasoning)
		end

	test_stream_figures
			-- Token counts and speed come from the closing event.
		note
			testing: "covers/{LLAMA_REPLY_DECODER}.feed"
		local
			l_decoder: LLAMA_REPLY_DECODER
		do
			create l_decoder.make
			l_decoder.feed (sample_stream)
			assert_integers_equal ("prompt_tokens", 12, l_decoder.prompt_tokens)
			assert_integers_equal ("output_tokens", 7, l_decoder.output_tokens)
			assert_true ("speed", l_decoder.tokens_per_second > 47.0 and l_decoder.tokens_per_second < 48.0)
			assert_true ("finish_stop", attached l_decoder.finish_reason as al_r and then al_r.same_string ({STRING_32} "stop"))
		end

	test_stream_unicode
			-- Hebrew and Greek survive the decoder.
		note
			testing: "covers/{LLAMA_REPLY_DECODER}.feed"
		local
			l_decoder: LLAMA_REPLY_DECODER
			l_text: STRING_32
		do
				-- chesed (Hebrew), an em-dash, agape (Greek)
			l_text := {STRING_32} "%/0x05D7/%/0x05E1/%/0x05D3/ %/0x2014/ %/0x1F00/%/0x03B3/%/0x03AC/%/0x03C0/%/0x03B7/"
			create l_decoder.make
			l_decoder.feed (event ({STRING_32} "content", l_text))
			l_decoder.feed ({STRING_32} "data: [DONE]%N")
			assert_strings_equal ("unicode_kept", l_text, l_decoder.content)
		end

	test_stream_error_event
			-- An error object becomes `error_message'.
		note
			testing: "covers/{LLAMA_REPLY_DECODER}.feed"
		local
			l_decoder: LLAMA_REPLY_DECODER
		do
			create l_decoder.make
			l_decoder.feed ({STRING_32} "{%"error%":{%"code%":400,%"message%":%"the request exceeds the available context size%",%"type%":%"exceed_context_size_error%"}}%N")
			assert_true ("has_error", l_decoder.has_error)
			assert_true ("message", attached l_decoder.error_message as al_m and then al_m.has_substring ({STRING_32} "context size"))
		end

	test_stream_curl_noise
			-- A curl error line is kept as stray text, not taken as content.
		note
			testing: "covers/{LLAMA_REPLY_DECODER}.feed"
		local
			l_decoder: LLAMA_REPLY_DECODER
		do
			create l_decoder.make
			l_decoder.feed ({STRING_32} "curl: (7) Failed to connect to 127.0.0.1 port 8737%N")
			l_decoder.finish
			assert_true ("no_content", l_decoder.content.is_empty)
			assert_true ("stray_kept", l_decoder.stray_text.has_substring ({STRING_32} "Failed to connect"))
			assert_false ("not_server_error", l_decoder.has_error)
		end

	test_stream_crlf_and_comments
			-- CRLF line ends and ":" comment lines are tolerated.
		note
			testing: "covers/{LLAMA_REPLY_DECODER}.feed"
		local
			l_decoder: LLAMA_REPLY_DECODER
		do
			create l_decoder.make
			l_decoder.feed ({STRING_32} ": keep-alive%R%N")
			l_decoder.feed ({STRING_32} "data: {%"choices%":[{%"index%":0,%"delta%":{%"content%":%"ok%"}}]}%R%N%R%N")
			l_decoder.feed ({STRING_32} "data: [DONE]%R%N")
			assert_strings_equal ("content", {STRING_32} "ok", l_decoder.content)
			assert_true ("no_stray", l_decoder.stray_text.is_empty)
			assert_true ("done", l_decoder.is_done)
		end

	test_real_stream_capture
			-- A stream captured from llama-server b12069 running Swift 1.5
			-- (2026-11-03, effort "low") decodes as Python's json reads it:
			-- 463 characters of thinking, 1,253 of answer, 59 / 343 tokens.
		note
			testing: "covers/{LLAMA_REPLY_DECODER}.feed"
		local
			l_decoder: LLAMA_REPLY_DECODER
			l_text: STRING_32
			l_at: INTEGER
		do
			l_text := fixture_text ("testing/fixtures/llama_stream_b12069.txt")
			assert_true ("fixture_present", l_text.count > 1000)
			create l_decoder.make
			from l_at := 1 until l_at > l_text.count loop
				l_decoder.feed (l_text.substring (l_at, (l_at + 96).min (l_text.count)))
				l_at := l_at + 97
			end
			l_decoder.finish
			assert_integers_equal ("thinking_chars", 463, l_decoder.reasoning.count)
			assert_integers_equal ("answer_chars", 1253, l_decoder.content.count)
			assert_true ("answer_start", l_decoder.content.starts_with ({STRING_32} "In the ancient Near East"))
			assert_true ("answer_end", l_decoder.content.ends_with ({STRING_32} "consequences for breach."))
			assert_integers_equal ("prompt_tokens", 59, l_decoder.prompt_tokens)
			assert_integers_equal ("output_tokens", 343, l_decoder.output_tokens)
			assert_true ("speed_read", l_decoder.tokens_per_second > 77.0)
			assert_true ("done", l_decoder.is_done)
			assert_true ("no_stray", l_decoder.stray_text.is_empty)
		end

feature -- Test routines: decoder, whole

	test_whole_reply
			-- A non-streamed reply keeps thinking and answer apart.
		note
			testing: "covers/{LLAMA_REPLY_DECODER}.decode_whole"
		local
			l_decoder: LLAMA_REPLY_DECODER
		do
			create l_decoder.make
			l_decoder.decode_whole ({STRING_32} "{%"choices%":[{%"finish_reason%":%"stop%",%"index%":0,%"message%":{%"role%":%"assistant%",%"content%":%"Four.%",%"reasoning_content%":%"2+2=4%"}}],%"usage%":{%"completion_tokens%":30,%"prompt_tokens%":15,%"total_tokens%":45},%"timings%":{%"prompt_n%":15,%"predicted_n%":30,%"predicted_per_second%":52.5}}")
			assert_strings_equal ("answer", {STRING_32} "Four.", l_decoder.content)
			assert_strings_equal ("thinking", {STRING_32} "2+2=4", l_decoder.reasoning)
			assert_integers_equal ("prompt", 15, l_decoder.prompt_tokens)
			assert_integers_equal ("output", 30, l_decoder.output_tokens)
			assert_true ("done", l_decoder.is_done)
		end

	test_whole_not_json
			-- Text that is not JSON is an error, not a crash.
		note
			testing: "covers/{LLAMA_REPLY_DECODER}.decode_whole"
		local
			l_decoder: LLAMA_REPLY_DECODER
		do
			create l_decoder.make
			l_decoder.decode_whole ({STRING_32} "curl: (28) Operation timed out")
			assert_true ("error", l_decoder.has_error)
			create l_decoder.make
			l_decoder.decode_whole ({STRING_32} "   ")
			assert_true ("empty_is_error", l_decoder.has_error)
		end

feature -- Test routines: settings

	test_default_command_matches_rixqwen
			-- Defaults reproduce RixQwen 1.0's server line exactly.
		note
			testing: "covers/{LLAMA_SERVER_SETTINGS}.command_line"
		local
			l_settings: LLAMA_SERVER_SETTINGS
		do
			create l_settings.make ("llama\llama-server.exe", "model\rixqwen-Q4_K_M.gguf")
			assert_strings_equal ("rixqwen_line",
				{STRING_32} "%"llama\llama-server.exe%" -m %"model\rixqwen-Q4_K_M.gguf%" --host 127.0.0.1 --port 8737 -ngl 99 -c 4096 -np 1",
				l_settings.command_line)
		end

	test_swift_command
			-- A tuned profile adds cache, flash attention and MTP flags.
		note
			testing: "covers/{LLAMA_SERVER_SETTINGS}.command_line"
		local
			l_settings: LLAMA_SERVER_SETTINGS
			l_line: STRING_32
		do
			create l_settings.make ("D:\llama\llama-server.exe", "D:\models\swift.gguf")
			l_settings.set_port (8790)
			l_settings.set_context_size (110000)
			l_settings.set_kv_cache_type ("q8_0")
			l_settings.set_flash_attention ("on")
			l_settings.enable_mtp (3)
			l_line := l_settings.command_line
			assert_true ("port", l_line.has_substring ({STRING_32} "--port 8790 "))
			assert_true ("context", l_line.has_substring ({STRING_32} " -c 110000 "))
			assert_true ("cache_k", l_line.has_substring ({STRING_32} " -ctk q8_0"))
			assert_true ("cache_v", l_line.has_substring ({STRING_32} " -ctv q8_0"))
			assert_true ("flash", l_line.has_substring ({STRING_32} " -fa on"))
			assert_true ("mtp", l_line.has_substring ({STRING_32} "--spec-type draft-mtp --spec-draft-n-max 3"))
			assert_strings_equal ("url", {STRING_32} "http://127.0.0.1:8790", l_settings.base_url)
			l_settings.disable_mtp
			assert_false ("mtp_off", l_settings.command_line.has_substring ({STRING_32} "draft-mtp"))
		end

	test_fit_command
			-- Context 0 leaves -c and -ngl unset so llama.cpp's fit can work.
		note
			testing: "covers/{LLAMA_SERVER_SETTINGS}.fits_to_memory"
		local
			l_settings: LLAMA_SERVER_SETTINGS
			l_line: STRING_32
		do
			create l_settings.make ("s.exe", "m.gguf")
			l_settings.set_context_size (0)
			l_line := l_settings.command_line
			assert_true ("fits", l_settings.fits_to_memory)
			assert_false ("no_context", l_line.has_substring ({STRING_32} " -c "))
			assert_false ("no_layers", l_line.has_substring ({STRING_32} " -ngl "))
			assert_true ("still_loopback", l_line.has_substring ({STRING_32} "--host 127.0.0.1 "))
		end

	test_cache_type_validation
			-- Only llama-server's cache types are accepted.
		note
			testing: "covers/{LLAMA_SERVER_SETTINGS}.is_valid_cache_type"
		local
			l_settings: LLAMA_SERVER_SETTINGS
		do
			create l_settings.make ("s.exe", "m.gguf")
			assert_true ("q8_0", l_settings.is_valid_cache_type ("q8_0"))
			assert_true ("q4_0", l_settings.is_valid_cache_type ("q4_0"))
			assert_false ("bogus", l_settings.is_valid_cache_type ("q3_k"))
			assert_false ("injection", l_settings.is_valid_cache_type ("q8_0 --host 0.0.0.0"))
		end

	test_locked_command
			-- A key and the local-origins lock add their flags at the end;
			-- removing them gives back the plain line.
		note
			testing: "covers/{LLAMA_SERVER_SETTINGS}.set_api_key",
				"covers/{LLAMA_SERVER_SETTINGS}.allow_local_origins_only"
		local
			l_settings: LLAMA_SERVER_SETTINGS
			l_plain: STRING_32
		do
			create l_settings.make ("s.exe", "m.gguf")
			l_plain := l_settings.command_line
			assert_false ("starts_unlocked", l_settings.is_locked)
			assert_false ("no_key_flag", l_plain.has_substring ({STRING_32} "--api-key"))
			assert_false ("no_origins_flag", l_plain.has_substring ({STRING_32} "--cors-origins"))
			l_settings.set_api_key ("Ab3_xY-9kLmN0pQr")
			l_settings.allow_local_origins_only
			assert_true ("locked", l_settings.is_locked)
			assert_true ("ends_locked", l_settings.command_line.ends_with ({STRING_32} " --cors-origins localhost --api-key Ab3_xY-9kLmN0pQr"))
			l_settings.remove_api_key
			l_settings.allow_any_origin
			assert_strings_equal ("plain_again", l_plain, l_settings.command_line)
		end

	test_api_key_validation
			-- A key must be long enough and hold nothing that could end an argument.
		note
			testing: "covers/{LLAMA_KEY_RULES}.is_valid_api_key"
		local
			l_settings: LLAMA_SERVER_SETTINGS
		do
			create l_settings.make ("s.exe", "m.gguf")
			assert_true ("good", l_settings.is_valid_api_key ("Ab3_xY-9kLmN0pQr"))
			assert_false ("short", l_settings.is_valid_api_key ("abc123"))
			assert_false ("space", l_settings.is_valid_api_key ("Ab3_xY-9kL mN0pQr"))
			assert_false ("quote", l_settings.is_valid_api_key ("Ab3_xY-9kLmN0pQr%" --host 0.0.0.0"))
			assert_false ("non_ascii", l_settings.is_valid_api_key ({STRING_32} "Ab3_xY-9kLmN0pQ%/1488/"))
		end

feature -- Test routines: client requests

	test_curl_sends_key
			-- A set key travels as a Bearer header on chat and nowhere when unset.
		note
			testing: "covers/{LLAMA_CPP_CLIENT}.set_api_key",
				"covers/{LLAMA_CPP_CLIENT}.curl_command"
		local
			l_client: LLAMA_CPP_CLIENT
		do
			create l_client.make_with_base_url ("http://127.0.0.1:8790")
			assert_false ("no_header", l_client.curl_command ("C:\temp\b.json", True).has_substring ({STRING_32} "Authorization"))
			l_client.set_api_key ("Ab3_xY-9kLmN0pQr")
			assert_true ("header", l_client.curl_command ("C:\temp\b.json", True).has_substring ({STRING_32} " -H %"Authorization: Bearer Ab3_xY-9kLmN0pQr%" "))
			l_client.remove_api_key
			assert_false ("removed", l_client.curl_command ("C:\temp\b.json", False).has_substring ({STRING_32} "Authorization"))
		end

	test_request_without_effort
			-- With no effort set, no template arguments are sent.
		note
			testing: "covers/{LLAMA_CPP_CLIENT}.request_json"
		local
			l_client: LLAMA_CPP_CLIENT
			l_json: STRING_32
		do
			create l_client.make_with_base_url ("http://127.0.0.1:8790")
			l_json := l_client.request_json (one_message, True)
			assert_false ("no_kwargs", l_json.has_substring ({STRING_32} "chat_template_kwargs"))
			assert_true ("streams", l_json.has_substring ({STRING_32} "%"stream%":true"))
			assert_true ("usage_asked", l_json.has_substring ({STRING_32} "include_usage"))
			assert_false ("no_cap", l_json.has_substring ({STRING_32} "max_tokens"))
		end

	test_request_with_effort
			-- A set effort travels as chat_template_kwargs.reasoning_effort.
		note
			testing: "covers/{LLAMA_CPP_CLIENT}.set_reasoning_effort"
		local
			l_client: LLAMA_CPP_CLIENT
			l_json: STRING_32
		do
			create l_client.make_with_base_url ("http://127.0.0.1:8790")
			l_client.set_reasoning_effort ("low")
			l_client.set_max_tokens (2000)
			l_json := l_client.request_json (one_message, False)
			assert_true ("effort", l_json.has_substring ({STRING_32} "%"chat_template_kwargs%":{%"reasoning_effort%":%"low%"}"))
			assert_true ("cap", l_json.has_substring ({STRING_32} "%"max_tokens%":2000"))
			assert_true ("not_streamed", l_json.has_substring ({STRING_32} "%"stream%":false"))
			l_client.use_template_default_effort
			assert_false ("cleared", l_client.request_json (one_message, False).has_substring ({STRING_32} "reasoning_effort"))
		end

	test_thinking_off
			-- Thinking off travels as enable_thinking false, beside any effort.
		note
			testing: "covers/{LLAMA_CPP_CLIENT}.turn_thinking_off"
		local
			l_client: LLAMA_CPP_CLIENT
			l_json: STRING_32
		do
			create l_client.make
			l_client.turn_thinking_off
			l_json := l_client.request_json (one_message, False)
			assert_true ("off_sent", l_json.has_substring ({STRING_32} "%"enable_thinking%":false"))
			assert_false ("no_effort", l_json.has_substring ({STRING_32} "reasoning_effort"))
			l_client.set_reasoning_effort ("low")
			l_json := l_client.request_json (one_message, False)
			assert_true ("both", l_json.has_substring ({STRING_32} "reasoning_effort") and l_json.has_substring ({STRING_32} "enable_thinking"))
			l_client.turn_thinking_on
			l_client.use_template_default_effort
			assert_false ("none", l_client.request_json (one_message, False).has_substring ({STRING_32} "chat_template_kwargs"))
		end

	test_effort_validation
			-- An effort word can carry nothing but letters, digits and "_".
		note
			testing: "covers/{LLAMA_CPP_CLIENT}.is_valid_effort"
		local
			l_client: LLAMA_CPP_CLIENT
		do
			create l_client.make
			assert_true ("xhigh", l_client.is_valid_effort ("xhigh"))
			assert_true ("low", l_client.is_valid_effort ("low"))
			assert_false ("empty", l_client.is_valid_effort (""))
			assert_false ("quote", l_client.is_valid_effort ("low%",%"x"))
			assert_false ("space", l_client.is_valid_effort ("x high"))
		end

	test_curl_command
			-- Streaming adds -N; the body goes by file.
		note
			testing: "covers/{LLAMA_CPP_CLIENT}.curl_command"
		local
			l_client: LLAMA_CPP_CLIENT
			l_line: STRING_32
		do
			create l_client.make_with_base_url ("http://127.0.0.1:8790")
			l_line := l_client.curl_command ("C:\temp\b.json", True)
			assert_true ("unbuffered", l_line.has_substring ({STRING_32} " -N "))
			assert_true ("by_file", l_line.has_substring ({STRING_32} "--data-binary %"@C:\temp\b.json%""))
			assert_true ("endpoint", l_line.has_substring ({STRING_32} "%"http://127.0.0.1:8790/v1/chat/completions%""))
			assert_false ("whole_buffered", l_client.curl_command ("C:\temp\b.json", False).has_substring ({STRING_32} " -N "))
		end

	test_dead_server_is_an_error
			-- Nothing listening gives an error response, not an exception.
		note
			testing: "covers/{LLAMA_CPP_CLIENT}.chat_streaming"
		local
			l_client: LLAMA_CPP_CLIENT
			l_response: AI_RESPONSE
		do
				-- Port 9 (discard) has no HTTP server on a normal machine.
			create l_client.make_with_base_url ("http://127.0.0.1:9")
			l_client.set_timeout_seconds (5)
			l_response := l_client.chat_streaming (one_message, Void, Void)
			assert_true ("stream_error", l_response.is_error)
			l_response := l_client.chat (one_message)
			assert_true ("whole_error", l_response.is_error)
		end

feature {NONE} -- Fixtures

	fixture_text (a_path: STRING): STRING_32
			-- The UTF-8 file at `a_path' as text ("" if absent).
		local
			l_file: RAW_FILE
		do
			create Result.make_empty
			create l_file.make_with_name (a_path)
			if l_file.exists and then l_file.count > 0 then
				l_file.open_read
				l_file.read_stream (l_file.count)
				Result := {UTF_CONVERTER}.utf_8_string_8_to_string_32 (l_file.last_string)
				l_file.close
			end
		end

	one_message: ARRAY [AI_MESSAGE]
			-- A one-message conversation.
		do
			Result := <<create {AI_MESSAGE}.make_user ({STRING_32} "Hi")>>
		end

	event (a_field, a_text: STRING_32): STRING_32
			-- One stream event putting `a_text' in delta field `a_field'.
		local
			l_obj, l_delta, l_choice: SIMPLE_JSON_OBJECT
			l_choices: SIMPLE_JSON_ARRAY
		do
			create l_delta.make
			l_delta.put_string (a_text, a_field).do_nothing
			create l_choice.make
			l_choice.put_integer (0, {STRING_32} "index").do_nothing
			l_choice.put_object (l_delta, {STRING_32} "delta").do_nothing
			create l_choices.make
			l_choices.add_object (l_choice).do_nothing
			create l_obj.make
			l_obj.put_array (l_choices, {STRING_32} "choices").do_nothing
			Result := {STRING_32} "data: " + l_obj.to_json_string + {STRING_32} "%N%N"
		end

	sample_stream: STRING_32
			-- Thinking in two pieces, answer in two, figures, [DONE].
		do
			Result := event ({STRING_32} "reasoning_content", {STRING_32} "Let me think.")
				+ event ({STRING_32} "reasoning_content", {STRING_32} " Done.")
				+ event ({STRING_32} "content", {STRING_32} "Hello,")
				+ event ({STRING_32} "content", {STRING_32} " world.")
				+ {STRING_32} "data: {%"choices%":[{%"finish_reason%":%"stop%",%"index%":0,%"delta%":{}}]}%N%N"
				+ {STRING_32} "data: {%"choices%":[],%"usage%":{%"completion_tokens%":7,%"prompt_tokens%":12,%"total_tokens%":19},%"timings%":{%"prompt_n%":12,%"predicted_n%":7,%"predicted_per_second%":47.3}}%N%N"
				+ {STRING_32} "data: [DONE]%N%N"
		end

end
