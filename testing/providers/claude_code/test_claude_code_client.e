note
	description: "[
		Tests for {CLAUDE_CODE_CLIENT}.

		The offline tests make no calls and cost nothing, so they run in the
		default suite. `test_live_round_trip' does invoke the CLI and consumes
		the user's Claude subscription, so it skips itself unless the
		environment variable SIMPLE_AI_LIVE_CLI is set to 1.

		`test_batch_script_clears_api_key' is the important one. Claude Code
		prefers ANTHROPIC_API_KEY over a claude.ai login, so if that clearing
		line is ever dropped this class silently stops using the subscription
		and starts spending API credit instead.
	]"
	testing: "covers"

class
	TEST_CLAUDE_CODE_CLIENT

inherit
	TEST_SET_BASE

feature -- Test routines: invocation

	test_batch_script_clears_api_key
			-- The generated script must unset both auth variables, or the CLI
			-- will use API credit rather than the user's login.
		note
			testing: "covers/{CLAUDE_CODE_CLIENT}.batch_script_preview"
		local
			l_c: CLAUDE_CODE_CLIENT
			l_script: STRING_32
		do
			create l_c.make
			l_script := l_c.batch_script_preview ({STRING_32} "C:\temp\p.txt", Void)

				-- "set VAR=" with nothing after it deletes the variable.
				-- Assigning an empty value would not: an empty
				-- ANTHROPIC_API_KEY still outranks a claude.ai login.
			assert_true ("clears_api_key", l_script.has_substring ({STRING_32} "set ANTHROPIC_API_KEY=%R%N"))
			assert_true ("clears_auth_token", l_script.has_substring ({STRING_32} "set ANTHROPIC_AUTH_TOKEN=%R%N"))
			assert_false ("never_bare", l_script.has_substring ({STRING_32} "--bare"))
		end

	test_batch_script_reads_prompt_from_stdin
			-- The prompt is redirected, never passed as an argument, so that
			-- neither the command-line length limit nor shell quoting applies.
		note
			testing: "covers/{CLAUDE_CODE_CLIENT}.batch_script_preview"
		local
			l_c: CLAUDE_CODE_CLIENT
			l_script: STRING_32
		do
			create l_c.make
			l_script := l_c.batch_script_preview ({STRING_32} "C:\temp\p.txt", Void)
			assert_true ("redirects_stdin", l_script.has_substring ({STRING_32} "< %"C:\temp\p.txt%""))
			assert_true ("json_output", l_script.has_substring ({STRING_32} "--output-format json"))
			assert_true ("headless", l_script.has_substring ({STRING_32} "claude -p"))
		end

	test_batch_script_includes_system_prompt
			-- A system prompt is passed by file, not inline.
		note
			testing: "covers/{CLAUDE_CODE_CLIENT}.batch_script_preview"
		local
			l_c: CLAUDE_CODE_CLIENT
			l_script: STRING_32
		do
			create l_c.make
			l_script := l_c.batch_script_preview ({STRING_32} "C:\temp\p.txt", {STRING_32} "C:\temp\s.txt")
			assert_true ("system_by_file",
				l_script.has_substring ({STRING_32} "--append-system-prompt-file %"C:\temp\s.txt%""))
		end

feature -- Test routines: configuration

	test_defaults
			-- A new client is configured and needs no API key.
		note
			testing: "covers/{CLAUDE_CODE_CLIENT}.make"
		local
			l_c: CLAUDE_CODE_CLIENT
		do
			create l_c.make
			assert_true ("has_model", not l_c.model.is_empty)
			assert_true ("valid_model", l_c.is_valid_model (l_c.model))
			assert_true ("has_working_dir", not l_c.working_directory.is_empty)
			assert_true ("provider", l_c.provider_name.same_string ("claude_code"))
			assert_positive ("timeout", l_c.timeout_seconds)
		end

	test_set_working_directory
			-- The working directory decides which project config the CLI loads.
		note
			testing: "covers/{CLAUDE_CODE_CLIENT}.set_working_directory"
		local
			l_c: CLAUDE_CODE_CLIENT
		do
			create l_c.make
			l_c.set_working_directory ({STRING_32} "D:\prod")
			assert_true ("dir_set", l_c.working_directory.same_string ({STRING_32} "D:\prod"))
		end

feature -- Test routines: live

	test_live_round_trip
			-- Ask the real CLI a trivial question.
			-- Skipped unless SIMPLE_AI_LIVE_CLI=1, because it spends the user's
			-- subscription allowance.
		note
			testing: "covers/{CLAUDE_CODE_CLIENT}.ask"
		local
			l_c: CLAUDE_CODE_CLIENT
			l_env: EXECUTION_ENVIRONMENT
			l_response: AI_RESPONSE
			l_enabled: BOOLEAN
		do
			create l_env
			if attached l_env.item ({STRING_32} "SIMPLE_AI_LIVE_CLI") as al_flag then
				l_enabled := al_flag.same_string ({STRING_32} "1")
			end

			if not l_enabled then
				print ("%N  (skipped: set SIMPLE_AI_LIVE_CLI=1 to run the live CLI test)%N")
			else
				create l_c.make
				if not l_c.is_available then
					print ("%N  (skipped: 'claude' not found on PATH)%N")
				else
					l_response := l_c.ask ({STRING_32} "What is 2+2? Reply with just the digit, nothing else.")
					print ("%N=== Live claude -p round trip ===%N")
					print ("Success: " + l_response.is_success.out + "%N")
					print ("Text:    " + l_response.text.to_string_8 + "%N")
					if attached l_response.error_message as al_err then
						print ("Error:   " + al_err.to_string_8 + "%N")
					end
					if attached l_c.last_session_id as al_sid then
						print ("Session: " + al_sid.to_string_8 + "%N")
					end
					assert_true ("succeeded", l_response.is_success)
					assert_true ("answered", l_response.text.has_substring ({STRING_32} "4"))
					assert_true ("provider", l_response.provider.same_string ("claude_code"))
				end
			end
		end

note
	copyright: "Copyright (c) 2026, Larry Rix"
	license: "MIT License"
end
