note
	description: "[
		Offline tests for {CLAUDE_CLIENT}.

		These make no network calls and cost nothing to run, so unlike
		{TEST_CLAUDE_CLIENT} they are safe in the default suite.

		The most important test here is `test_curl_command_omits_api_key':
		it is a regression guard on the rule that the API key must never
		reach the curl command line, where any process running as the same
		user could read it out of Win32_Process.
	]"
	testing: "covers"

class
	TEST_CLAUDE_CLIENT_OFFLINE

inherit
	TEST_SET_BASE

feature -- Test routines: key handling

	test_curl_command_omits_api_key
			-- The API key must never appear on the command line.
		note
			testing: "covers/{CLAUDE_CLIENT}.curl_command_preview"
		local
			l_client: CLAUDE_CLIENT
			l_cmd: STRING_32
		do
			create l_client.make_with_api_key ({STRING_32} "sk-ant-SENTINEL-VALUE-DO-NOT-LEAK")
			l_cmd := l_client.curl_command_preview ({STRING_32} "C:\temp\body.json")

			assert_false ("key_absent_from_command_line",
				l_cmd.has_substring ({STRING_32} "sk-ant-SENTINEL-VALUE-DO-NOT-LEAK"))
			assert_true ("reads_key_from_environment",
				l_cmd.has_substring ({STRING_32} "--variable %%SIMPLE_AI_CLAUDE_KEY"))
			assert_true ("expands_key_into_header",
				l_cmd.has_substring ({STRING_32} "--expand-header"))
			assert_true ("body_sent_from_file",
				l_cmd.has_substring ({STRING_32} "--data-binary %"@C:\temp\body.json%""))
			assert_true ("sends_api_version",
				l_cmd.has_substring ({STRING_32} "anthropic-version"))
		end

feature -- Test routines: pricing

	test_model_family_classification
			-- Every model identifier lands in the right pricing family.
		note
			testing: "covers/{CLAUDE_CLIENT}.model_family"
		local
			l_c: CLAUDE_CLIENT
		do
			create l_c.make_with_api_key ({STRING_32} "k")
			assert_integers_equal ("fable", l_c.Family_fable, l_c.model_family ({STRING_32} "claude-fable-5"))
			assert_integers_equal ("mythos", l_c.Family_fable, l_c.model_family ({STRING_32} "claude-mythos-5"))
			assert_integers_equal ("opus5", l_c.Family_opus, l_c.model_family ({STRING_32} "claude-opus-5"))
			assert_integers_equal ("opus48", l_c.Family_opus, l_c.model_family ({STRING_32} "claude-opus-4-8"))
			assert_integers_equal ("sonnet5", l_c.Family_sonnet, l_c.model_family ({STRING_32} "claude-sonnet-5"))
			assert_integers_equal ("sonnet46", l_c.Family_sonnet_46, l_c.model_family ({STRING_32} "claude-sonnet-4-6"))
			assert_integers_equal ("haiku45", l_c.Family_haiku, l_c.model_family ({STRING_32} "claude-haiku-4-5"))
				-- A dated identifier must still price as its family. This is the
				-- case the previous exact-match bucketing got wrong: Haiku 4.5
				-- was billed at Sonnet rates.
			assert_integers_equal ("dated_haiku", l_c.Family_haiku,
				l_c.model_family ({STRING_32} "claude-haiku-4-5-20251001"))
				-- Unknown models price as Opus: over-estimating beats under-estimating.
			assert_integers_equal ("unknown", l_c.Family_opus, l_c.model_family ({STRING_32} "claude-something-new"))
		end

	test_pricing_lookup
			-- Published rates are returned for each family.
		note
			testing: "covers/{CLAUDE_CLIENT}.input_price", "covers/{CLAUDE_CLIENT}.output_price"
		local
			l_c: CLAUDE_CLIENT
		do
			create l_c.make_with_api_key ({STRING_32} "k")
			assert_reals_equal ("opus5_in", 5.0, l_c.input_price ({STRING_32} "claude-opus-5"), 0.001)
			assert_reals_equal ("opus5_out", 25.0, l_c.output_price ({STRING_32} "claude-opus-5"), 0.001)
			assert_reals_equal ("sonnet5_in", 2.0, l_c.input_price ({STRING_32} "claude-sonnet-5"), 0.001)
			assert_reals_equal ("sonnet5_out", 10.0, l_c.output_price ({STRING_32} "claude-sonnet-5"), 0.001)
			assert_reals_equal ("haiku_in", 1.0, l_c.input_price ({STRING_32} "claude-haiku-4-5"), 0.001)
			assert_reals_equal ("fable_out", 50.0, l_c.output_price ({STRING_32} "claude-fable-5"), 0.001)
		end

feature -- Test routines: defaults

	test_defaults
			-- Creation sets a current model and a usable token ceiling.
		note
			testing: "covers/{CLAUDE_CLIENT}.make_with_api_key"
		local
			l_c: CLAUDE_CLIENT
		do
			create l_c.make_with_api_key ({STRING_32} "k")
			assert_true ("default_is_current_model", l_c.is_valid_model (l_c.model))
			assert_greater_or_equal ("max_tokens_usable", l_c.max_tokens, 16000)
			assert_true ("has_key", l_c.has_api_key)
			assert_true ("no_dated_suffix_in_default", not l_c.model.has_substring ({STRING_32} "-2025"))
		end

	test_set_max_tokens
			-- `set_max_tokens' takes effect.
		note
			testing: "covers/{CLAUDE_CLIENT}.set_max_tokens"
		local
			l_c: CLAUDE_CLIENT
		do
			create l_c.make_with_api_key ({STRING_32} "k")
			l_c.set_max_tokens (2048)
			assert_integers_equal ("max_tokens", 2048, l_c.max_tokens)
		end

note
	copyright: "Copyright (c) 2026, Larry Rix"
	license: "MIT License"
end
