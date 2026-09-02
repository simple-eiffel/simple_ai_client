note
	description: "[
		AI client that drives the locally installed Claude Code CLI in headless
		mode (`claude -p'), rather than calling the Anthropic HTTP API.

		WHY THIS EXISTS

		{CLAUDE_CLIENT} calls api.anthropic.com and is billed per token against
		an API key. This class instead runs the `claude' binary the user has
		already installed and logged in to, so the work is drawn against that
		login (for example a Claude Max subscription) and not against API
		credit. No API key is required or used.

		THE KEY MUST BE ABSENT

		Claude Code prefers ANTHROPIC_API_KEY over a claude.ai login when both
		are present: with the key set it will use the API and can fail with
		"Credit balance is too low" even though the subscription is healthy.
		This class therefore clears ANTHROPIC_API_KEY and ANTHROPIC_AUTH_TOKEN
		in the child process only. The calling process's own environment is
		left untouched.

		DISTRIBUTION

		Software using this class does not ship or offer anyone's login: each
		user supplies their own installed, already-authenticated `claude'. That
		is the same arrangement as a program that shells out to `git'. Note that
		Anthropic does not permit third-party developers to offer claude.ai
		login or rate limits as part of their product without prior approval,
		so do not build a product whose selling point is that it runs on the
		user's subscription.

		WHAT THIS COSTS

		`total_cost_usd' from the CLI is a list-price equivalent, not an
		invoice. On a subscription no such amount is charged. It is exposed as
		`last_cost_estimate' for proportion only.

		CONTEXT LOADING

		`claude -p' loads whatever CLAUDE.md, skills, hooks and MCP servers the
		working directory and ~/.claude provide. Requests therefore run in
		`working_directory', which defaults to the system temp directory to keep
		a caller's project configuration out of a library call. `--bare' would
		suppress all of it but also forces API-key authentication, which would
		defeat the purpose of this class.
	]"
	author: "Larry Rix"
	EIS: "name=Claude Code headless mode", "src=https://code.claude.com/docs/en/headless", "tag=cli"

class
	CLAUDE_CODE_CLIENT

inherit
	AI_CLIENT

create
	make,
	make_in_directory

feature {NONE} -- Initialization

	make
			-- Create a client running in the system temp directory.
		local
			l_env: EXECUTION_ENVIRONMENT
		do
			create l_env
			if attached l_env.item (Env_temp) as al_temp and then not al_temp.is_empty then
				working_directory := al_temp.to_string_32
			else
				working_directory := {STRING_32} "."
			end
			model := Default_model
			timeout_seconds := Default_timeout_seconds
			create process_helper
			create json
		ensure
			model_set: model ~ Default_model
			directory_attached: not working_directory.is_empty
		end

	make_in_directory (a_directory: STRING_32)
			-- Create a client running in `a_directory', so that its CLAUDE.md,
			-- skills and MCP servers are loaded.
		require
			directory_not_empty: not a_directory.is_empty
		do
			make
			working_directory := a_directory
		ensure
			directory_set: working_directory ~ a_directory
		end

feature -- Access

	model: STRING_32
			-- Model passed to `--model'. An alias such as "opus" or a full
			-- identifier such as "claude-opus-5".

	provider_name: STRING_8 = "claude_code"
			-- Provider identifier

	working_directory: STRING_32
			-- Directory the CLI runs in. Determines which project configuration
			-- it loads.

	timeout_seconds: INTEGER
			-- Advisory ceiling reported in errors. The CLI is not killed.

	last_session_id: detachable STRING_32
			-- `session_id' of the most recent call, for `--resume'.

	last_cost_estimate: REAL_64
			-- `total_cost_usd' from the most recent call. A list-price
			-- equivalent, not an amount charged against a subscription.

	last_raw_output: detachable STRING_32
			-- Unparsed CLI output of the most recent call, for diagnosis.

feature -- Status report

	is_available: BOOLEAN
			-- Is the `claude' binary on PATH?
		local
			l_process: SIMPLE_PROCESS
		do
			create l_process.make
			Result := l_process.has_command ("claude.exe") or else l_process.has_command ("claude")
		end

feature -- Model validation

	is_valid_model (a_model: STRING_32): BOOLEAN
			-- Is `a_model' one this client will pass to `--model'?
			-- Permissive: the CLI is the authority and rejects what it cannot
			-- serve, so aliases and models newer than this library are allowed.
		do
			Result := not a_model.is_empty
		end

	supported_models: ARRAYED_LIST [STRING_32]
			-- Aliases and identifiers known to work with `--model'.
		do
			create Result.make (7)
			Result.extend ({STRING_32} "opus")
			Result.extend ({STRING_32} "sonnet")
			Result.extend ({STRING_32} "haiku")
			Result.extend ({STRING_32} "claude-opus-5")
			Result.extend ({STRING_32} "claude-sonnet-5")
			Result.extend ({STRING_32} "claude-haiku-4-5")
			Result.extend ({STRING_32} "claude-fable-5")
		ensure then
			has_models: Result.count >= 3
		end

feature -- Element change

	set_model (a_model: STRING_32)
			-- Set the model passed to `--model'.
		do
			model := a_model
		end

	set_working_directory (a_directory: STRING_32)
			-- Run subsequent calls in `a_directory'.
		require
			directory_not_empty: not a_directory.is_empty
		do
			working_directory := a_directory
		ensure
			directory_set: working_directory ~ a_directory
		end

	set_timeout_seconds (a_seconds: INTEGER)
			-- Set the advisory timeout.
		require
			positive: a_seconds > 0
		do
			timeout_seconds := a_seconds
		ensure
			timeout_set: timeout_seconds = a_seconds
		end

feature -- Diagnostics

	batch_script_preview (a_prompt_path: STRING_32; a_system_path: detachable STRING_32): STRING_32
			-- The batch file this client would run for the given input files.
			-- Public so a caller can see exactly what will execute. Contains no
			-- secret: the whole point is that no key is passed.
		require
			prompt_path_not_empty: not a_prompt_path.is_empty
		do
			Result := build_batch_script (a_prompt_path, a_system_path)
		end

feature {NONE} -- Implementation

	execute_chat (a_messages: ARRAY [AI_MESSAGE]; a_options: detachable ANY): AI_RESPONSE
			-- Run the CLI once for `a_messages' and parse its JSON result.
		local
			l_prompt, l_system: STRING_32
			l_output: STRING_32
			l_value: SIMPLE_JSON_VALUE
		do
			if not is_available then
				Result := create_error_response ("The 'claude' CLI was not found on PATH. Install Claude Code, or use CLAUDE_CLIENT for API access.")
			else
					-- The CLI takes one system prompt and one user prompt, so a
					-- multi-turn array is flattened: system parts are joined and
					-- passed via --append-system-prompt-file, the rest becomes
					-- the prompt on stdin. For real multi-turn work use
					-- `last_session_id' with --resume.
				create l_prompt.make_empty
				create l_system.make_empty
				across a_messages as ic loop
					if ic.is_system then
						if not l_system.is_empty then
							l_system.append ("%N%N")
						end
						l_system.append (ic.content)
					else
						if not l_prompt.is_empty then
							l_prompt.append ("%N%N")
						end
						l_prompt.append (ic.content)
					end
				end

				if l_prompt.is_empty then
					Result := create_error_response ("No user message to send.")
				else
					l_output := run_cli (l_prompt, l_system)
					last_raw_output := l_output

					if l_output.is_empty then
						Result := create_error_response ({STRING_32} "No output from the claude CLI. It may have failed to start, or exceeded " + timeout_seconds.out + "s.")
					else
						l_value := json.parse_response (l_output)
						if attached l_value as al_value and then al_value.is_object then
							Result := parse_cli_response (al_value.as_object)
						else
							Result := create_error_response ({STRING_32} "Could not parse claude CLI output: " + l_output.head (300))
						end
					end
				end
			end
		end

	run_cli (a_prompt, a_system: STRING_32): STRING_32
			-- Run the CLI with `a_prompt' on stdin and return its raw output.
			--
			-- Everything travels by file. The prompt is redirected into stdin
			-- rather than passed as an argument, which keeps it clear of the
			-- ~32 KB Windows command-line limit and of shell quoting, and the
			-- invocation is written to a batch file so that the two auth
			-- variables can be cleared for the child alone.
		local
			l_prompt_path, l_system_path, l_script_path: detachable STRING_32
		do
			create Result.make_empty
			l_prompt_path := write_temp_file (a_prompt, {STRING_32} "prompt.txt")
			if not a_system.is_empty then
				l_system_path := write_temp_file (a_system, {STRING_32} "system.txt")
			end

			if attached l_prompt_path as al_prompt then
				l_script_path := write_temp_file (build_batch_script (al_prompt, l_system_path), {STRING_32} "run.bat")
				if attached l_script_path as al_script then
					Result := process_helper.shell_output ({STRING_32} "cmd.exe /c %"" + al_script + {STRING_32} "%"", working_directory)
					delete_temp_file (al_script)
				end
				delete_temp_file (al_prompt)
			end
			if attached l_system_path as al_system then
				delete_temp_file (al_system)
			end
		end

	build_batch_script (a_prompt_path: STRING_32; a_system_path: detachable STRING_32): STRING_32
			-- The batch file contents for one CLI call.
			--
			-- `set VAR=' with nothing after the equals sign deletes the variable
			-- in this cmd session, so the child `claude' sees no API key and
			-- falls back to the user's login. An empty value would not do:
			-- an empty ANTHROPIC_API_KEY still outranks a login.
		require
			prompt_path_not_empty: not a_prompt_path.is_empty
		do
			create Result.make (400)
			Result.append ("@echo off%R%N")
			Result.append ("set ANTHROPIC_API_KEY=%R%N")
			Result.append ("set ANTHROPIC_AUTH_TOKEN=%R%N")
			Result.append ("claude -p --output-format json")
			Result.append (" --model %"")
			Result.append (model)
			Result.append ("%"")
			if attached a_system_path as al_system then
				Result.append (" --append-system-prompt-file %"")
				Result.append (al_system)
				Result.append ("%"")
			end
			Result.append (" < %"")
			Result.append (a_prompt_path)
			Result.append ("%"%R%N")
		ensure
			clears_api_key: Result.has_substring ({STRING_32} "set ANTHROPIC_API_KEY=")
			reads_prompt_from_stdin: Result.has_substring ({STRING_32} "< %"")
		end

	parse_cli_response (a_obj: SIMPLE_JSON_OBJECT): AI_RESPONSE
			-- Convert one CLI JSON result object into an AI_RESPONSE.
		local
			l_text, l_model_name: STRING_32
			l_in, l_out: INTEGER
		do
				-- The CLI reports failure in-band: exit status alone is not
				-- enough, so `is_error' is checked before reading `result'.
			if a_obj.boolean_item (Key_is_error) then
				if attached a_obj.string_item (Key_result) as al_msg then
					Result := create_error_response ({STRING_32} "claude CLI: " + al_msg)
				else
					Result := create_error_response ("claude CLI reported an error with no message.")
				end
			elseif attached a_obj.string_item (Key_result) as al_result and then not al_result.is_empty then
				l_text := al_result
				l_model_name := model
				create Result.make (l_text, l_model_name, provider_name)

				if attached a_obj.string_item (Key_session_id) as al_session then
					last_session_id := al_session
				end
				last_cost_estimate := a_obj.real_item (Key_total_cost_usd)

				if attached a_obj.object_item (Key_usage) as al_usage then
					l_in := al_usage.integer_item (Key_input_tokens).to_integer_32
					l_out := al_usage.integer_item (Key_output_tokens).to_integer_32
					Result.set_tokens (l_in, l_out)
				end
			else
				Result := create_error_response ("Empty result from the claude CLI.")
			end
		end

	create_error_response (a_message: STRING_32): AI_RESPONSE
			-- Build an error response carrying `a_message'.
		do
			create Result.make_error (a_message, provider_name)
		end

feature {NONE} -- Implementation: temporary files

	write_temp_file (a_content, a_suffix: STRING_32): detachable STRING_32
			-- Write `a_content' as UTF-8 to a uniquely named temp file whose
			-- name ends in `a_suffix'; return its path, or Void on failure.
		require
			suffix_not_empty: not a_suffix.is_empty
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
				if attached l_env.item (Env_temp) as al_temp and then not al_temp.is_empty then
					l_dir := al_temp.to_string_32
				else
					l_dir := {STRING_32} "."
				end
				l_path := l_dir + {STRING_32} "\simple_ai_cc_" + l_uuid.new_v4_compact.to_string_32 + {STRING_32} "_" + a_suffix
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
			-- Delete `a_path', ignoring failure: a stranded temp file must not
			-- mask the result of the call.
		require
			path_not_empty: not a_path.is_empty
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

feature {NONE} -- Implementation: Attributes

	process_helper: SIMPLE_PROCESS_HELPER
			-- Helper used to run the batch file

	json: SIMPLE_JSON
			-- JSON parser

feature -- Constants

	Default_model: STRING_32 = "claude-opus-5"
			-- Model used unless `set_model' says otherwise

	Default_timeout_seconds: INTEGER = 300
			-- Advisory ceiling reported in errors

feature {NONE} -- Constants: environment and JSON keys

	Env_temp: STRING_32 = "TEMP"

	Key_result: STRING_32 = "result"
	Key_is_error: STRING_32 = "is_error"
	Key_session_id: STRING_32 = "session_id"
	Key_total_cost_usd: STRING_32 = "total_cost_usd"
	Key_usage: STRING_32 = "usage"
	Key_input_tokens: STRING_32 = "input_tokens"
	Key_output_tokens: STRING_32 = "output_tokens"

invariant
	model_attached: model /= Void
	model_not_empty: not model.is_empty
	working_directory_attached: working_directory /= Void
	timeout_positive: timeout_seconds > 0
	process_helper_attached: process_helper /= Void
	json_attached: json /= Void

note
	copyright: "Copyright (c) 2026, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
