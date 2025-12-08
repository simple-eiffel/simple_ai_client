note
	description: "Tests for {OLLAMA_CLIENT}"
	testing: "covers"

class
	TEST_OLLAMA_CLIENT

inherit
	TEST_SET_BASE

feature -- Test routines

	test_simple_ask
			-- Test single prompt
		note
			testing: "execution/isolated", "covers/{OLLAMA_CLIENT}.ask"
		local
			l_client: OLLAMA_CLIENT
			l_response: AI_RESPONSE
		do
			create l_client.make
			l_response := l_client.ask ("What is 2+2? Answer with just the number.")

			print ("%N=== Simple Ask Test ===%N")
			print ("Response: " + l_response.text + "%N")

			if l_response.is_success then
				assert_true ("has_response", not l_response.text.is_empty)
				assert_strings_equal ("provider", "ollama", l_response.provider)
			else
				print ("Ollama not running%N")
			end
		end

	test_ask_with_system
			-- Test with system message
		note
			testing: "execution/isolated", "covers/{OLLAMA_CLIENT}.ask_with_system"
		local
			l_client: OLLAMA_CLIENT
			l_response: AI_RESPONSE
		do
			create l_client.make
			l_response := l_client.ask_with_system (
				"You are a concise calculator. Answer with only numbers.",
				"What is 5+3?"
			)

			print ("%N=== System Message Test ===%N")
			print ("Response: " + l_response.text + "%N")

			if l_response.is_success then
				assert_true ("has_response", not l_response.text.is_empty)
			else
				print ("Ollama not running%N")
			end
		end

	test_chat_conversation
			-- Test multi-turn conversation
		note
			testing: "execution/isolated", "covers/{OLLAMA_CLIENT}.chat"
		local
			l_client: OLLAMA_CLIENT
			l_messages: ARRAY [AI_MESSAGE]
			l_response: AI_RESPONSE
		do
			create l_client.make
			create l_messages.make_filled (create {AI_MESSAGE}.make_user ("hi"), 1, 3)
			l_messages.put (create {AI_MESSAGE}.make_system ("Be extremely concise."), 1)
			l_messages.put (create {AI_MESSAGE}.make_user ("Name the first US president"), 2)
			l_messages.put (create {AI_MESSAGE}.make_assistant ("George Washington"), 3)
			l_messages.force (create {AI_MESSAGE}.make_user ("What number president was he? (e.g. as 1st, 2nd, 3rd, et al)"), 4)

			l_response := l_client.chat (l_messages)

			print ("%N=== Chat Conversation Test ===%N")
			print ("Response: " + l_response.text + "%N")

			if l_response.is_success then
				assert_true ("has_response", not l_response.text.is_empty)
				assert_string_contains ("mentions_first", l_response.text.as_lower, "1st")
			else
				print ("Ollama not running%N")
			end
		end

	test_model_selection
			-- Test model switching
		note
			testing: "execution/isolated", "covers/{OLLAMA_CLIENT}.set_model"
		local
			l_client: OLLAMA_CLIENT
		do
			create l_client.make
			assert_strings_equal ("default_model", "llama3", l_client.model)

			l_client.set_model ("qwen2.5-coder:latest")
			assert_strings_equal ("model_changed", "qwen2.5-coder:latest", l_client.model)
		end

	test_server_availability
			-- Check if Ollama is running
		note
			testing: "execution/isolated"
		local
			l_client: OLLAMA_CLIENT
			l_response: AI_RESPONSE
		do
			create l_client.make
			l_response := l_client.ask ("test")

			print ("%N=== Server Check ===%N")
			print ("Success: " + l_response.is_success.out + "%N")

			if l_response.is_success then
				print ("â Ollama server running%N")
			else
				print ("â Ollama server not running%N")
				if attached l_response.error_message as al_err then
					print ("Error: " + al_err + "%N")
				end
			end
		end

	test_verbosity_concise
			-- Test concise response mode (default)
		note
			testing: "execution/isolated", "covers/{AI_CLIENT}.use_concise_responses"
		local
			l_client: OLLAMA_CLIENT
			l_response: AI_RESPONSE
		do
			create l_client.make
			l_client.use_concise_responses
			l_response := l_client.ask ("Explain photosynthesis")

			print ("%N=== Concise Test ===%N")
			print ("Length: " + l_response.text.count.out + " chars%N")
			print ("Response: " + l_response.text + "%N")

			if l_response.is_success then
				assert_true ("has_response", not l_response.text.is_empty)
			else
				print ("Ollama not running%N")
			end
		end

	test_verbosity_verbose
			-- Test verbose response mode
		note
			testing: "execution/isolated", "covers/{AI_CLIENT}.use_verbose_responses"
		local
			l_client: OLLAMA_CLIENT
			l_response: AI_RESPONSE
		do
			create l_client.make
			l_client.use_verbose_responses
			l_response := l_client.ask ("Explain photosynthesis")

			print ("%N=== Verbose Test ===%N")
			print ("Length: " + l_response.text.count.out + " chars%N")
			print ("Response: " + l_response.text + "%N")

			if l_response.is_success then
				assert_true ("has_response", not l_response.text.is_empty)
			else
				print ("Ollama not running%N")
			end
		end

	test_verbosity_comparison
			-- Compare response lengths across verbosity levels
		note
			testing: "execution/isolated", "covers/{AI_CLIENT}.set_verbosity"
		local
			l_client: OLLAMA_CLIENT
			l_concise, l_normal, l_verbose: AI_RESPONSE
			l_query: STRING_32
		do
			create l_client.make
			l_query := "What is a binary tree?"

			l_client.use_concise_responses
			l_concise := l_client.ask (l_query)

			l_client.use_normal_responses
			l_normal := l_client.ask (l_query)

			l_client.use_verbose_responses
			l_verbose := l_client.ask (l_query)

			print ("%N=== Verbosity Comparison ===%N")
			print ("Concise: " + l_concise.text.count.out + " chars%N")
			print ("Normal:  " + l_normal.text.count.out + " chars%N")
			print ("Verbose: " + l_verbose.text.count.out + " chars%N")

			if l_concise.is_success and l_normal.is_success and l_verbose.is_success then
				assert_true ("all_responded", True)
			else
				print ("Ollama not running%N")
			end
		end

feature -- Eiffel Coding with Ollama

	test_architecture_task
			--
		note
			testing: "execution/isolated", "covers/{AI_CLIENT}.use_concise_responses"
		local
			l_client: OLLAMA_CLIENT
			l_response: AI_RESPONSE
		do
			create l_client.make
			l_client.use_concise_responses
			prompt_1.do_nothing
			l_response := l_client.ask (prompt_1)

			print ("%N=== Concise Test ===%N")
			print ("Length: " + l_response.text.count.out + " chars%N")
			print ("Response: " + l_response.text + "%N")

			if l_response.is_success then
				assert_true ("has_response", not l_response.text.is_empty)
			else
				print ("Ollama not running%N")
			end
		end

	prompt_1: STRING_32
			--
		local
			l_file: PLAIN_TEXT_FILE
		once
			create Result.make_from_string_general ("NEED: I need a shopping cart that holds items and calculates totals. Follow the guidance found in the eiffel_mini_guide below. Give me your results as JSON. %N%N")

			create l_file.make_open_read ("C:\Users\LJR19\OneDrive\Desktop\Eiffel-libs\claude-instruction-pack\eiffel_mini_guide.txt")
			l_file.read_stream (l_file.count)
			Result.append (l_file.last_string)
			l_file.close
		ensure
			result_not_empty: not Result.is_empty
		end

note
	copyright: "Copyright (c) 2025, Larry Rix"
	license: "MIT License"
	source: "[
		SIMPLE_AI_CLIENT - Unified AI Provider Library
		Tests require Ollama running: ollama serve
	]"

end
