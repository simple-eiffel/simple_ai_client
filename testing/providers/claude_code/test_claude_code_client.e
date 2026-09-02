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

feature -- Test routines: sandbox flags

	test_sandbox_flags_off_by_default
			-- A fresh client adds no sandbox flag: existing callers see the
			-- exact command they always saw.
		note
			testing: "covers/{CLAUDE_CODE_CLIENT}.extra_arguments"
		local
			l_c: CLAUDE_CODE_CLIENT
			l_script: STRING_32
		do
			create l_c.make
			assert_true ("no_flags", l_c.extra_arguments.is_empty)
			assert_false ("tools_on", l_c.tools_disabled)
			assert_true ("sources_default", l_c.setting_sources = Void)
			assert_false ("mcp_default", l_c.strict_mcp_config)
			l_script := l_c.batch_script_preview ({STRING_32} "C:\temp\p.txt", Void)
			assert_false ("no_tools_flag", l_script.has_substring ({STRING_32} "--tools"))
			assert_false ("no_sources_flag", l_script.has_substring ({STRING_32} "--setting-sources"))
			assert_false ("no_strict_flag", l_script.has_substring ({STRING_32} "--strict-mcp-config"))
		end

	test_sandbox_flags_reach_the_command
			-- Each setter's flag appears, spelled as the installed CLI takes it,
			-- and the whole `extra_arguments' block is embedded verbatim.
		note
			testing: "covers/{CLAUDE_CODE_CLIENT}.set_tools_disabled"
		local
			l_c: CLAUDE_CODE_CLIENT
			l_script: STRING_32
		do
			create l_c.make
			l_c.set_tools_disabled
			l_c.set_setting_sources ("")
			l_c.set_strict_mcp_config
			assert_true ("tools_off", l_c.extra_arguments.has_substring ("--tools %"%""))
			assert_true ("sources_empty", l_c.extra_arguments.has_substring ("--setting-sources %"%""))
			assert_true ("strict", l_c.extra_arguments.has_substring ("--strict-mcp-config"))
			l_script := l_c.batch_script_preview ({STRING_32} "C:\temp\p.txt", Void)
			assert_true ("flags_verbatim", l_script.has_substring (l_c.extra_arguments))
			assert_true ("still_headless", l_script.has_substring ({STRING_32} "claude -p"))
			assert_true ("still_clears_key", l_script.has_substring ({STRING_32} "set ANTHROPIC_API_KEY=%R%N"))
			l_c.set_setting_sources ("user,project")
			assert_true ("named_sources", l_c.extra_arguments.has_substring ("--setting-sources %"user,project%""))
			assert_true ("valid_empty", l_c.is_valid_setting_sources (""))
			assert_true ("valid_list", l_c.is_valid_setting_sources ("user,project,local"))
			assert_false ("invalid_quote", l_c.is_valid_setting_sources ("user%""))
			assert_false ("invalid_space", l_c.is_valid_setting_sources ("user project"))
		end

feature -- Test routines: sessions

	test_resume_session_reaches_the_command
			-- A stored session id rides as `--resume "<uuid>"'; clearing it
			-- returns to a fresh conversation.
		note
			testing: "covers/{CLAUDE_CODE_CLIENT}.set_resume_session"
		local
			l_c: CLAUDE_CODE_CLIENT
			l_script: STRING_32
		do
			create l_c.make
			l_script := l_c.batch_script_preview ({STRING_32} "C:\temp\p.txt", Void)
			assert_false ("fresh_by_default", l_script.has_substring ({STRING_32} "--resume"))
			l_c.set_resume_session ("0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d")
			l_script := l_c.batch_script_preview ({STRING_32} "C:\temp\p.txt", Void)
			assert_true ("resume_embedded",
				l_script.has_substring ({STRING_32} "--resume %"0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d%""))
			assert_true ("still_headless", l_script.has_substring ({STRING_32} "claude -p"))
			l_c.clear_resume_session
			l_script := l_c.batch_script_preview ({STRING_32} "C:\temp\p.txt", Void)
			assert_false ("fresh_after_clear", l_script.has_substring ({STRING_32} "--resume"))
		end

	test_session_id_shape_is_a_uuid
			-- Only 8-4-4-4-12 hexadecimal survives: anything else - and in
			-- particular anything that could smuggle cmd metacharacters into
			-- the batch line - is refused before it can be stored.
		note
			testing: "covers/{CLAUDE_CODE_CLIENT}.is_valid_session_id"
		local
			l_c: CLAUDE_CODE_CLIENT
		do
			create l_c.make
			assert_true ("uuid", l_c.is_valid_session_id ("0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"))
			assert_true ("uppercase_hex", l_c.is_valid_session_id ("0A1B2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D"))
			assert_false ("empty", l_c.is_valid_session_id (""))
			assert_false ("short", l_c.is_valid_session_id ("abc"))
			assert_false ("no_dashes", l_c.is_valid_session_id ("0a1b2c3d4e5f4a6b8c7d9e0f1a2b3c4d0000"))
			assert_false ("bad_letter", l_c.is_valid_session_id ("0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3cZd"))
			assert_false ("injection", l_c.is_valid_session_id ("x%" & whoami & echo %"aaaaaaaaaaaaaa"))
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
