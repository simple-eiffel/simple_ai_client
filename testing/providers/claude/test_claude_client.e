note
	description: "[
		Tests for {CLAUDE_CLIENT}
		
		Requires ANTHROPIC_API_KEY environment variable to be set.
		Tests are marked as manual since they require network access and API key.
	]"
	testing: "type/manual"

class
	TEST_CLAUDE_CLIENT

inherit
	TEST_SET_BASE

feature -- Test routines

	test_api_key_from_environment
			-- Test that API key is loaded from environment
		note
			testing: "execution/isolated", "covers/{CLAUDE_CLIENT}.make"
		local
			l_client: CLAUDE_CLIENT
		do
			create l_client.make
			
			print ("%N=== API Key Test ===%N")
			print ("Has API key: " + l_client.has_api_key.out + "%N")
			
			if l_client.has_api_key then
				print ("✓ API key loaded from ANTHROPIC_API_KEY%N")
				assert_true ("has_key", l_client.has_api_key)
			else
				print ("✗ ANTHROPIC_API_KEY not set%N")
				print ("  Set it via: System Properties → Environment Variables%N")
			end
		end

	test_simple_ask
			-- Test single prompt to Claude
		note
			testing: "execution/isolated", "covers/{CLAUDE_CLIENT}.ask"
		local
			l_client: CLAUDE_CLIENT
			l_response: AI_RESPONSE
		do
			create l_client.make
			
			if not l_client.has_api_key then
				print ("%N=== Skipping test_simple_ask (no API key) ===%N")
			else
				l_response := l_client.ask ("What is 2+2? Answer with just the number.")
				
				print ("%N=== Simple Ask Test ===%N")
				print ("Success: " + l_response.is_success.out + "%N")
				print ("Response: " + l_response.text + "%N")
				print ("Model: " + l_response.model + "%N")
				print ("Tokens: " + l_response.total_tokens.out + "%N")
				
				if l_response.is_success then
					assert_true ("has_response", not l_response.text.is_empty)
					assert_strings_equal ("provider", "claude", l_response.provider)
					assert_true ("has_tokens", l_response.total_tokens > 0)
				else
					if attached l_response.error_message as al_err then
						print ("Error: " + al_err + "%N")
					end
				end
			end
		end

	test_ask_with_system
			-- Test with system message
		note
			testing: "execution/isolated", "covers/{CLAUDE_CLIENT}.ask_with_system"
		local
			l_client: CLAUDE_CLIENT
			l_response: AI_RESPONSE
		do
			create l_client.make
			
			if not l_client.has_api_key then
				print ("%N=== Skipping test_ask_with_system (no API key) ===%N")
			else
				l_response := l_client.ask_with_system (
					"You are a concise calculator. Answer with only the number, nothing else.",
					"What is 15 multiplied by 7?"
				)
				
				print ("%N=== System Message Test ===%N")
				print ("Success: " + l_response.is_success.out + "%N")
				print ("Response: " + l_response.text + "%N")
				
				if l_response.is_success then
					assert_true ("has_response", not l_response.text.is_empty)
					-- Should contain "105"
					assert_string_contains ("correct_answer", l_response.text, "105")
				else
					if attached l_response.error_message as al_err then
						print ("Error: " + al_err + "%N")
					end
				end
			end
		end

	test_chat_conversation
			-- Test multi-turn conversation
		note
			testing: "execution/isolated", "covers/{CLAUDE_CLIENT}.chat"
		local
			l_client: CLAUDE_CLIENT
			l_messages: ARRAY [AI_MESSAGE]
			l_response: AI_RESPONSE
			l_lower_text: STRING_32
		do
			create l_client.make
			
			if not l_client.has_api_key then
				print ("%N=== Skipping test_chat_conversation (no API key) ===%N")
			else
				create l_messages.make_filled (create {AI_MESSAGE}.make_user ("hi"), 1, 4)
				l_messages.put (create {AI_MESSAGE}.make_system ("Be extremely concise. Answer in one word or number when possible."), 1)
				l_messages.put (create {AI_MESSAGE}.make_user ("What is the capital of France?"), 2)
				l_messages.put (create {AI_MESSAGE}.make_assistant ("Paris"), 3)
				l_messages.put (create {AI_MESSAGE}.make_user ("What country is it in?"), 4)
				
				l_response := l_client.chat (l_messages)
				
				print ("%N=== Chat Conversation Test ===%N")
				print ("Success: " + l_response.is_success.out + "%N")
				print ("Response: " + l_response.text + "%N")
				
				if l_response.is_success then
					assert_true ("has_response", not l_response.text.is_empty)
					-- Case-insensitive check
					create l_lower_text.make_from_string (l_response.text)
					l_lower_text.to_lower
					assert_true ("mentions_france", l_lower_text.has_substring ("france"))
				else
					if attached l_response.error_message as al_err then
						print ("Error: " + al_err + "%N")
					end
				end
			end
		end

	test_model_selection
			-- Test model switching
		note
			testing: "execution/isolated", "covers/{CLAUDE_CLIENT}.set_model"
		local
			l_client: CLAUDE_CLIENT
		do
			create l_client.make
			
			print ("%N=== Model Selection Test ===%N")
			
			-- Default is Sonnet
			print ("Default model: " + l_client.model + "%N")
			assert_strings_equal ("default_model", "claude-sonnet-4-5-20250929", l_client.model)
			
			-- Switch to Opus
			l_client.use_opus
			print ("After use_opus: " + l_client.model + "%N")
			assert_strings_equal ("opus_model", "claude-opus-4-5-20251101", l_client.model)
			
			-- Switch to Haiku
			l_client.use_haiku
			print ("After use_haiku: " + l_client.model + "%N")
			assert_strings_equal ("haiku_model", "claude-haiku-4-5-20251001", l_client.model)
			
			-- Switch back to Sonnet
			l_client.use_sonnet
			print ("After use_sonnet: " + l_client.model + "%N")
			assert_strings_equal ("sonnet_model", "claude-sonnet-4-5-20250929", l_client.model)
		end

	test_token_tracking
			-- Test that token counts are reported
		note
			testing: "execution/isolated", "covers/{AI_RESPONSE}.set_tokens"
		local
			l_client: CLAUDE_CLIENT
			l_response: AI_RESPONSE
		do
			create l_client.make
			
			if not l_client.has_api_key then
				print ("%N=== Skipping test_token_tracking (no API key) ===%N")
			else
				l_response := l_client.ask ("Say hello")
				
				print ("%N=== Token Tracking Test ===%N")
				print ("Success: " + l_response.is_success.out + "%N")
				print ("Input tokens: " + l_response.input_tokens.item.out + "%N")
				print ("Output tokens: " + l_response.output_tokens.item.out + "%N")
				print ("Total tokens: " + l_response.total_tokens.out + "%N")
				
				if l_response.is_success then
					assert_true ("has_input_tokens", l_response.input_tokens.item > 0)
					assert_true ("has_output_tokens", l_response.output_tokens.item > 0)
					assert_true ("total_calculated", l_response.total_tokens = l_response.input_tokens.item + l_response.output_tokens.item)
				else
					if attached l_response.error_message as al_err then
						print ("Error: " + al_err + "%N")
					end
				end
			end
		end

	test_verbosity_concise
			-- Test concise response mode
		note
			testing: "execution/isolated", "covers/{AI_CLIENT}.use_concise_responses"
		local
			l_client: CLAUDE_CLIENT
			l_response: AI_RESPONSE
		do
			create l_client.make
			
			if not l_client.has_api_key then
				print ("%N=== Skipping test_verbosity_concise (no API key) ===%N")
			else
				l_client.use_concise_responses
				l_response := l_client.ask ("Explain what an API is")
				
				print ("%N=== Concise Verbosity Test ===%N")
				print ("Success: " + l_response.is_success.out + "%N")
				print ("Length: " + l_response.text.count.out + " chars%N")
				print ("Response: " + l_response.text + "%N")
				
				if l_response.is_success then
					assert_true ("has_response", not l_response.text.is_empty)
					-- Concise should typically be under 500 chars
					assert_true ("reasonably_concise", l_response.text.count < 1000)
				end
			end
		end

	test_error_without_api_key
			-- Test error handling when no API key
		note
			testing: "execution/isolated", "covers/{CLAUDE_CLIENT}.execute_chat"
		local
			l_client: CLAUDE_CLIENT
			l_response: AI_RESPONSE
			l_lower_err: STRING_32
		do
			print ("%N=== Error Without Key Test ===%N")
			
			-- Create normally and check state
			create l_client.make
			if not l_client.has_api_key then
				l_response := l_client.ask ("test")
				assert_true ("is_error", l_response.is_error)
				if attached l_response.error_message as al_err then
					print ("Error message: " + al_err + "%N")
					-- Case-insensitive check
					create l_lower_err.make_from_string (al_err)
					l_lower_err.to_lower
					assert_true ("mentions_key", l_lower_err.has_substring ("api key"))
				end
			else
				print ("API key is set, skipping no-key error test%N")
			end
		end

	test_provider_name
			-- Test provider name is correct
		note
			testing: "execution/isolated", "covers/{CLAUDE_CLIENT}.provider_name"
		local
			l_client: CLAUDE_CLIENT
		do
			create l_client.make
			
			print ("%N=== Provider Name Test ===%N")
			print ("Provider: " + l_client.provider_name + "%N")
			
			assert_strings_equal ("provider_name", "claude", l_client.provider_name)
		end

	test_eiffel_code_generation
			-- Test Claude generating Eiffel code
		note
			testing: "execution/isolated", "covers/{CLAUDE_CLIENT}.ask_with_system"
		local
			l_client: CLAUDE_CLIENT
			l_response: AI_RESPONSE
			l_system: STRING_32
			l_lower_text: STRING_32
		do
			create l_client.make
			
			if not l_client.has_api_key then
				print ("%N=== Skipping test_eiffel_code_generation (no API key) ===%N")
			else
				l_system := "[
					You are an Eiffel programming expert. Generate clean, idiomatic Eiffel code 
					following Design by Contract principles. Include preconditions, postconditions, 
					and class invariants where appropriate.
				]"
				
				l_response := l_client.ask_with_system (l_system, 
					"Write a simple Eiffel class COUNTER with increment and decrement features")
				
				print ("%N=== Eiffel Code Generation Test ===%N")
				print ("Success: " + l_response.is_success.out + "%N")
				print ("Response length: " + l_response.text.count.out + " chars%N")
				print ("Response:%N" + l_response.text + "%N")
				
				if l_response.is_success then
					assert_true ("has_response", not l_response.text.is_empty)
					-- Case-insensitive check
					create l_lower_text.make_from_string (l_response.text)
					l_lower_text.to_lower
					assert_true ("has_class", l_lower_text.has_substring ("class"))
					assert_true ("has_feature", l_lower_text.has_substring ("feature"))
				else
					if attached l_response.error_message as al_err then
						print ("Error: " + al_err + "%N")
					end
				end
			end
		end

	test_usage_tracking
			-- Test cumulative usage tracking and cost estimation
		note
			testing: "execution/isolated", "covers/{CLAUDE_CLIENT}.total_tokens"
		local
			l_client: CLAUDE_CLIENT
			l_response: AI_RESPONSE
			l_log_path: STRING_32
		do
			create l_client.make
			
			-- Enable file logging so we can see output
			l_log_path := "claude_usage.log"
			l_client.enable_file_logging (l_log_path)
			
			print ("%N=== Usage Tracking Test ===%N")
			
			-- Initial state
			assert_integers_equal ("initial_tokens", 0, l_client.total_tokens.to_integer_32)
			assert_integers_equal ("initial_requests", 0, l_client.request_count)
			assert ("initial_cost", l_client.estimated_cost = 0.0)
			
			if not l_client.has_api_key then
				print ("Skipping API test - ANTHROPIC_API_KEY not set%N")
			else
				-- Use Haiku for cheapest test
				l_client.use_haiku
				l_response := l_client.ask ("What is 1+1? Reply with just the number.")
				
				if l_response.is_success then
					print ("After first request:%N")
					print ("  Input tokens: " + l_client.total_input_tokens.out + "%N")
					print ("  Output tokens: " + l_client.total_output_tokens.out + "%N")
					print ("  Total tokens: " + l_client.total_tokens.out + "%N")
					print ("  Request count: " + l_client.request_count.out + "%N")
					print ("  Estimated cost: $" + l_client.estimated_cost.out + "%N")
					
					assert_true ("tokens_recorded", l_client.total_tokens > 0)
					assert_integers_equal ("one_request", 1, l_client.request_count)
					assert_true ("cost_calculated", l_client.estimated_cost > 0.0)
					
					-- Second request to test accumulation
					l_response := l_client.ask ("What is 2+2? Reply with just the number.")
					
					if l_response.is_success then
						print ("%NAfter second request:%N")
						print ("  Total tokens: " + l_client.total_tokens.out + "%N")
						print ("  Request count: " + l_client.request_count.out + "%N")
						print ("  Estimated cost: $" + l_client.estimated_cost.out + "%N")
						
						assert_integers_equal ("two_requests", 2, l_client.request_count)
					end
					
					-- Print usage summary
					print ("%N" + l_client.usage_summary + "%N")
					
					-- Test reset
					l_client.reset_usage
					assert_integers_equal ("reset_tokens", 0, l_client.total_tokens.to_integer_32)
					assert_integers_equal ("reset_requests", 0, l_client.request_count)
					print ("Usage reset successfully%N")
				end
			end
			
			-- Cleanup
			l_client.disable_all_logging
			print ("Log written to: " + l_log_path + "%N")
		end

note
	copyright: "Copyright (c) 2025, Larry Rix"
	license: "MIT License"
	source: "[
		SIMPLE_AI_CLIENT - Unified AI Provider Library
		Tests require ANTHROPIC_API_KEY environment variable
	]"

end
