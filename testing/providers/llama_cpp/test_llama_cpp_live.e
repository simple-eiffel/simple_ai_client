note
	description: "[
		Live tests for the llama.cpp provider against a REAL llama-server.
		They need a server answering on 127.0.0.1:8790 (or LLAMA_TEST_URL),
		so they are not in the default suite; LLAMA_LIVE_TEST_APP runs them.
		With no server they FAIL - they never pass by skipping.
	]"
	testing: "covers"

class
	TEST_LLAMA_CPP_LIVE

inherit
	TEST_SET_BASE

feature -- Test routines

	test_stream_pieces_add_up
			-- The pieces handed to the agents are exactly the reply.
		note
			testing: "covers/{LLAMA_CPP_CLIENT}.chat_streaming"
		local
			l_client: LLAMA_CPP_CLIENT
			l_response: AI_RESPONSE
		do
			l_client := live_client
			assert_true ("server_up", l_client.is_available)
			l_client.set_reasoning_effort ("low")
			create streamed_reasoning.make_empty
			create streamed_content.make_empty
			l_response := l_client.chat_streaming (
				<<create {AI_MESSAGE}.make_user ({STRING_32} "In one sentence: what does the Hebrew word chesed mean?")>>,
				agent on_reasoning, agent on_content)
			assert_true ("success", l_response.is_success)
			assert_true ("thought", not l_client.last_reasoning.is_empty)
			assert_strings_equal ("thinking_adds_up", l_client.last_reasoning, streamed_reasoning)
			streamed_content.left_adjust
			streamed_content.right_adjust
			assert_strings_equal ("answer_adds_up", l_response.text, streamed_content)
			assert_true ("tokens_counted", l_response.output_tokens.item > 0)
			assert_true ("speed_measured", l_client.last_tokens_per_second > 0.0)
			io.put_string ("    live: " + l_response.output_tokens.item.out + " tokens at " +
				l_client.last_tokens_per_second.truncated_to_integer.out + " tok/s%N")
		end

	test_whole_reply_and_thinking_off
			-- A non-streamed reply works, and thinking off yields no thinking.
		note
			testing: "covers/{LLAMA_CPP_CLIENT}.turn_thinking_off"
		local
			l_client: LLAMA_CPP_CLIENT
			l_response: AI_RESPONSE
		do
			l_client := live_client
			l_client.turn_thinking_off
			l_response := l_client.ask ({STRING_32} "Reply with the single word: shalom")
			assert_true ("success", l_response.is_success)
			assert_true ("says_shalom", l_response.text.as_lower.has_substring ({STRING_32} "shalom"))
			assert_true ("no_thinking", l_client.last_reasoning.is_empty)
		end

	test_bad_effort_is_reported
			-- An effort the template rejects comes back as an error response.
		note
			testing: "covers/{LLAMA_CPP_CLIENT}.execute_chat"
		local
			l_client: LLAMA_CPP_CLIENT
			l_response: AI_RESPONSE
		do
			l_client := live_client
			l_client.set_reasoning_effort ("high")
			l_response := l_client.chat (<<create {AI_MESSAGE}.make_user ({STRING_32} "Hi")>>)
			assert_true ("error", l_response.is_error)
			if attached l_response.error_message as al_message then
				io.put_string ("    server said: " + {UTF_CONVERTER}.string_32_to_utf_8_string_8 (al_message.head (120)) + "%N")
			end
		end

feature {NONE} -- Implementation

	streamed_reasoning, streamed_content: STRING_32
			-- What the agents received.
		attribute
			create Result.make_empty
		end

	on_reasoning (a_piece: STRING_32)
			-- Collect a piece of thinking.
		do
			streamed_reasoning.append (a_piece)
		end

	on_content (a_piece: STRING_32)
			-- Collect a piece of the answer.
		do
			streamed_content.append (a_piece)
		end

	live_client: LLAMA_CPP_CLIENT
			-- A client for the test server.
		local
			l_env: EXECUTION_ENVIRONMENT
		do
			create l_env
			if attached l_env.item ({STRING_32} "LLAMA_TEST_URL") as al_url and then not al_url.is_empty
				and then not al_url.has ('"')
			then
				create Result.make_with_base_url (al_url)
			else
				create Result.make_with_base_url ({STRING_32} "http://127.0.0.1:8790")
			end
			Result.set_timeout_seconds (600)
		end

end
