note
	description: "[
		Vectors for the UTF-8 byte boundary every curl/CLI-based provider
		crosses twice: `SIMPLE_PROCESS' widens a child process's stdout
		bytes into STRING_32 one byte per character rather than decoding
		them, and the JSON request body a provider writes to a temp file
		must reach the child as real UTF-8 bytes rather than a STRING_32
		narrowed byte-for-byte.

		Observed live 2026-09-02: simple_chat's server ran `claude -p'
		through CLAUDE_CODE_CLIENT and the bot's reply reached the room as
		"... as @claude %/0xE2/%/0x80/%/0x94/ happy to help ..." - code
		points U+00E2 U+0080 U+0094 stored where the CLI wrote a single
		em-dash (UTF-8 bytes E2 80 94). `test_decode_process_bytes_combined'
		reproduces that exact line.

		Byte sequences are hand-computed from RFC 3629, not read back from
		the library under test: E2 80 94 (em-dash, U+2014), D7 A9 D7 9C D7
		95 D7 9D (Hebrew shalom, U+05E9 U+05DC U+05D5 U+05DD), F0 9F A4 96
		(robot emoji, U+1F916), CE A7 CF 81 (Greek Chi-rho, U+03A7 U+03C1).
	]"
	author: "Larry Rix"
	testing: "covers"

class
	TEST_UTF8_BOUNDARY

inherit
	TEST_SET_BASE

feature -- Test routines: response direction (decode_process_bytes)

	test_decode_process_bytes_em_dash
			-- Three widened bytes (E2 80 94) recover the one character
			-- U+2014, not the three-character mojibake `SIMPLE_PROCESS'
			-- currently hands back.
		note
			testing: "covers/{AI_CLIENT}.decode_process_bytes"
		local
			l_client: CLAUDE_CODE_CLIENT
			l_raw, l_expected: STRING_32
		do
			create l_client.make
			l_raw := {STRING_32} "%/0xE2/%/0x80/%/0x94/"
			l_expected := {STRING_32} "%/0x2014/"
			assert_false ("raw is three-character mojibake, not the em-dash",
				l_raw.same_string (l_expected))
			assert_strings_equal ("em-dash recovered", l_expected, l_client.decode_process_bytes (l_raw))
		end

	test_decode_process_bytes_hebrew
			-- D7 A9 D7 9C D7 95 D7 9D (8 widened bytes) recover the four
			-- characters of shalom.
		note
			testing: "covers/{AI_CLIENT}.decode_process_bytes"
		local
			l_client: CLAUDE_CODE_CLIENT
			l_raw, l_expected: STRING_32
		do
			create l_client.make
			l_raw := {STRING_32} "%/0xD7/%/0xA9/%/0xD7/%/0x9C/%/0xD7/%/0x95/%/0xD7/%/0x9D/"
			l_expected := {STRING_32} "%/0x5E9/%/0x5DC/%/0x5D5/%/0x5DD/"
			assert_false ("raw is eight-character mojibake, not shalom",
				l_raw.same_string (l_expected))
			assert_strings_equal ("shalom recovered", l_expected, l_client.decode_process_bytes (l_raw))
		end

	test_decode_process_bytes_emoji
			-- F0 9F A4 96 (four widened bytes, one astral-plane character)
			-- recover the single robot emoji U+1F916.
		note
			testing: "covers/{AI_CLIENT}.decode_process_bytes"
		local
			l_client: CLAUDE_CODE_CLIENT
			l_raw, l_expected: STRING_32
		do
			create l_client.make
			l_raw := {STRING_32} "%/0xF0/%/0x9F/%/0xA4/%/0x96/"
			l_expected := {STRING_32} "%/0x1F916/"
			assert_false ("raw is four-character mojibake, not the emoji",
				l_raw.same_string (l_expected))
			assert_strings_equal ("emoji recovered", l_expected, l_client.decode_process_bytes (l_raw))
		end

	test_decode_process_bytes_greek
			-- CE A7 CF 81 (four widened bytes) recover the two characters
			-- Chi-rho.
		note
			testing: "covers/{AI_CLIENT}.decode_process_bytes"
		local
			l_client: CLAUDE_CODE_CLIENT
			l_raw, l_expected: STRING_32
		do
			create l_client.make
			l_raw := {STRING_32} "%/0xCE/%/0xA7/%/0xCF/%/0x81/"
			l_expected := {STRING_32} "%/0x3A7/%/0x3C1/"
			assert_false ("raw is four-character mojibake, not Chi-rho",
				l_raw.same_string (l_expected))
			assert_strings_equal ("Chi-rho recovered", l_expected, l_client.decode_process_bytes (l_raw))
		end

	test_decode_process_bytes_combined
			-- The exact live failure, reproduced: "as @claude <mojibake>
			-- happy to help", plus shalom, the robot and Chi-rho mixed
			-- into one line, the shape of a real assistant reply.
		note
			testing: "covers/{AI_CLIENT}.decode_process_bytes"
		local
			l_client: CLAUDE_CODE_CLIENT
			l_raw, l_expected: STRING_32
		do
			create l_client.make
			l_raw := {STRING_32} "as @claude %/0xE2/%/0x80/%/0x94/ happy to help: %/0xD7/%/0xA9/%/0xD7/%/0x9C/%/0xD7/%/0x95/%/0xD7/%/0x9D/ %/0xF0/%/0x9F/%/0xA4/%/0x96/ %/0xCE/%/0xA7/%/0xCF/%/0x81/"
			l_expected := {STRING_32} "as @claude %/0x2014/ happy to help: %/0x5E9/%/0x5DC/%/0x5D5/%/0x5DD/ %/0x1F916/ %/0x3A7/%/0x3C1/"
			assert_false ("raw combined line is mojibake, not the reply", l_raw.same_string (l_expected))
			assert_strings_equal ("full line recovered", l_expected, l_client.decode_process_bytes (l_raw))
		end

	test_decode_process_bytes_ascii_passthrough
			-- Plain ASCII, the common case, is unchanged.
		note
			testing: "covers/{AI_CLIENT}.decode_process_bytes"
		local
			l_client: CLAUDE_CODE_CLIENT
		do
			create l_client.make
			assert_strings_equal ("ascii unchanged", {STRING_32} "hello world",
				l_client.decode_process_bytes ({STRING_32} "hello world"))
		end

	test_decode_process_bytes_empty
			-- No output from a failed or empty child stays empty.
		note
			testing: "covers/{AI_CLIENT}.decode_process_bytes"
		local
			l_client: CLAUDE_CODE_CLIENT
		do
			create l_client.make
			assert_true ("empty stays empty", l_client.decode_process_bytes ({STRING_32} "").is_empty)
		end

	test_decode_process_bytes_leaves_real_unicode_alone
			-- A STRING_32 that already holds real Unicode (a code point
			-- above 255, so it cannot be raw widened bytes) is returned
			-- unchanged rather than mis-decoded a second time.
		note
			testing: "covers/{AI_CLIENT}.decode_process_bytes"
		local
			l_client: CLAUDE_CODE_CLIENT
			l_already_decoded: STRING_32
		do
			create l_client.make
			l_already_decoded := {STRING_32} "%/0x2014/"
			assert_false ("not narrowable to STRING_8", l_already_decoded.is_valid_as_string_8)
			assert_strings_equal ("returned unchanged, not re-decoded",
				l_already_decoded, l_client.decode_process_bytes (l_already_decoded))
		end

feature -- Test routines: response direction, a real child process

	test_real_process_round_trip
			-- The defect reproduced live rather than simulated: `cmd /c
			-- type' of a file holding known UTF-8 bytes is a real child
			-- process read through {SIMPLE_PROCESS_HELPER}, the same path
			-- every provider's curl and claude CLI calls take.
		note
			testing: "covers/{AI_CLIENT}.decode_process_bytes"
		local
			l_helper: SIMPLE_PROCESS_HELPER
			l_client: CLAUDE_CODE_CLIENT
			l_env: EXECUTION_ENVIRONMENT
			l_uuid: SIMPLE_UUID
			l_file: RAW_FILE
			l_dir, l_path: STRING_32
			l_source, l_raw: STRING_32
		do
			l_source := {STRING_32} "reply %/0x2014/ %/0x5E9/%/0x5DC/%/0x5D5/%/0x5DD/ %/0x1F916/ %/0x3A7/%/0x3C1/"

			create l_env
			if attached l_env.item ({STRING_32} "TEMP") as al_temp and then not al_temp.is_empty then
				l_dir := al_temp.to_string_32
			else
				l_dir := {STRING_32} "."
			end
			create l_uuid.make
			l_path := l_dir + {STRING_32} "\simple_ai_utf8_test_" + l_uuid.new_v4_compact.to_string_32 + {STRING_32} ".txt"

			create l_file.make_with_name (l_path)
			l_file.create_read_write
			l_file.put_string ({UTF_CONVERTER}.string_32_to_utf_8_string_8 (l_source))
			l_file.close

			create l_helper
			l_raw := l_helper.shell_output ({STRING_32} "cmd.exe /c type %"" + l_path + {STRING_32} "%"", Void)

			create l_file.make_with_name (l_path)
			if l_file.exists then
				l_file.delete
			end

				-- RED: today's `SIMPLE_PROCESS' hands back byte-widened
				-- mojibake, not the text that was written - reproduced
				-- live rather than assumed.
			assert_false ("raw child output is mojibake, not the source text",
				l_raw.same_string (l_source))

				-- GREEN: `decode_process_bytes' recovers it exactly.
			create l_client.make
			assert_strings_equal ("decoded output matches the source text",
				l_source, l_client.decode_process_bytes (l_raw))
		end

feature -- Test routines: request direction

	test_json_body_not_narrowable_to_string_8
			-- Documents why `to_string_8' was the wrong tool for a request
			-- body: text shaped like what `SIMPLE_JSON_OBJECT.to_json_string'
			-- hands back for a prompt containing Hebrew, Greek or emoji is
			-- not `is_valid_as_string_8', so narrowing it - what every
			-- curl-based provider did before this fix - was not a silent
			-- truncation but a precondition violation waiting to happen.
		note
			testing: "covers/{OPENAI_CLIENT}.execute_chat"
		local
			l_source: STRING_32
		do
			l_source := {STRING_32} "%/0x5E9/%/0x5DC/%/0x5D5/%/0x5DD/ %/0x1F916/"
			assert_false ("non-ASCII json body is not narrowable to STRING_8",
				l_source.is_valid_as_string_8)
		end

	test_utf8_encode_decode_round_trip
			-- `{UTF_CONVERTER}.string_32_to_utf_8_string_8' - what every
			-- provider now calls instead of `to_string_8' to write a
			-- request body - produces valid UTF-8 bytes that decode back
			-- to the exact source text.
		note
			testing: "covers/{OPENAI_CLIENT}.execute_chat"
		local
			l_source: STRING_32
			l_bytes: STRING_8
		do
			l_source := {STRING_32} "%/0x2014/ %/0x5E9/%/0x5DC/%/0x5D5/%/0x5DD/ %/0x1F916/ %/0x3A7/%/0x3C1/"
			l_bytes := {UTF_CONVERTER}.string_32_to_utf_8_string_8 (l_source)
			assert_true ("bytes are valid utf-8", {UTF_CONVERTER}.is_valid_utf_8_string_8 (l_bytes))
			assert_strings_equal ("round trip matches the source text",
				l_source, {UTF_CONVERTER}.utf_8_string_8_to_string_32 (l_bytes))
		end

	test_request_body_round_trip_through_a_real_process
			-- A prompt with non-ASCII text, written to a file the way
			-- every provider now writes its request body, survives being
			-- read back by a real child process byte-for-byte as UTF-8 -
			-- the request-direction mirror of `test_real_process_round_trip'.
		note
			testing: "covers/{OPENAI_CLIENT}.execute_chat"
		local
			l_helper: SIMPLE_PROCESS_HELPER
			l_client: CLAUDE_CODE_CLIENT
			l_env: EXECUTION_ENVIRONMENT
			l_uuid: SIMPLE_UUID
			l_file: RAW_FILE
			l_dir, l_path: STRING_32
			l_source, l_raw: STRING_32
		do
			l_source := {STRING_32} "prompt: %/0x5E9/%/0x5DC/%/0x5D5/%/0x5DD/ %/0x1F916/ %/0x3A7/%/0x3C1/ %/0x2014/ done"

			create l_env
			if attached l_env.item ({STRING_32} "TEMP") as al_temp and then not al_temp.is_empty then
				l_dir := al_temp.to_string_32
			else
				l_dir := {STRING_32} "."
			end
			create l_uuid.make
			l_path := l_dir + {STRING_32} "\simple_ai_utf8_req_test_" + l_uuid.new_v4_compact.to_string_32 + {STRING_32} ".txt"

				-- Write the way every fixed provider now writes a request
				-- body: real UTF-8 bytes, not `l_source.to_string_8'
				-- (which `test_json_body_not_narrowable_to_string_8' shows
				-- would violate its own precondition on this text).
			create l_file.make_with_name (l_path)
			l_file.create_read_write
			l_file.put_string ({UTF_CONVERTER}.string_32_to_utf_8_string_8 (l_source))
			l_file.close

			create l_helper
			l_raw := l_helper.shell_output ({STRING_32} "cmd.exe /c type %"" + l_path + {STRING_32} "%"", Void)

			create l_file.make_with_name (l_path)
			if l_file.exists then
				l_file.delete
			end

			create l_client.make
			assert_strings_equal ("the child read back the exact prompt",
				l_source, l_client.decode_process_bytes (l_raw))
		end

note
	copyright: "Copyright (c) 2026, Larry Rix"
	license: "MIT License"
end
