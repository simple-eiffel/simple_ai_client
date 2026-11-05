note
	description: "[
		Runs a local llama.cpp `llama-server' for the life of a program.

		`start' reuses a server already answering on the port (and then
		leaves it running at `stop'); otherwise it launches one, hidden,
		tied to this program so Windows ends it even if the program
		crashes. `wait_ready' polls /health until the model has loaded.
		`start' reuses a live server only if it accepts `settings''s key, or
		no key when the settings carry none; otherwise it reports why in
		`last_error' (a server locked by another program's key would
		refuse every request).

		    create l_server.make (l_settings)
		    l_server.start
		    if l_server.wait_ready (300) then
		        create l_client.make_with_base_url (l_server.base_url)
		        ...
		    end
		    l_server.stop

		Waiting uses EXECUTION_ENVIRONMENT.sleep and SIMPLE_ASYNC_PROCESS,
		whose waiting externals are all `C blocking', so a model load of
		a minute or more never stops another processor's allocator.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LLAMA_SERVER

create
	make

feature {NONE} -- Initialization

	make (a_settings: LLAMA_SERVER_SETTINGS)
			-- A server that will run with `a_settings'.
		do
			settings := a_settings
			create last_error.make_empty
			create log_tail.make_empty
		ensure
			settings_set: settings = a_settings
			not_started: not started_here
			no_error: last_error.is_empty
		end

feature -- Access

	settings: LLAMA_SERVER_SETTINGS
			-- How the server is launched.

	base_url: STRING_32
			-- Root URL, e.g. http://127.0.0.1:8737
		do
			Result := settings.base_url
		ensure
			definition: Result.same_string (settings.base_url)
		end

	last_error: STRING_32
			-- Why the last `start' or `wait_ready' failed ("" if it did not).

	log_tail: STRING_32
			-- The last `Log_tail_limit' characters the launched server printed.

	started_here: BOOLEAN
			-- Did `start' launch the server (rather than reuse one)?

feature -- Status report

	is_up: BOOLEAN
			-- Does a server answer /health on the port with HTTP 200?
		local
			l_process: SIMPLE_PROCESS
			l_output: STRING_32
		do
			create l_process.make
			l_output := l_process.command_output ({STRING_32} "curl.exe -s -o NUL --max-time 2 -w %"%%{http_code}%" %"" + base_url + {STRING_32} "/health%"")
			Result := l_process.was_successful and then l_output.has_substring ({STRING_32} "200")
		end

	accepts_settings_key: BOOLEAN
			-- Does the server on the port answer /props (which demands the
			-- key on a locked server) with HTTP 200, sending `settings''s key
			-- if it has one? False when nothing answers.
		local
			l_process: SIMPLE_PROCESS
			l_command, l_output: STRING_32
		do
			l_command := {STRING_32} "curl.exe -s -o NUL --max-time 2 -w %"%%{http_code}%""
			if attached settings.api_key as al_key then
				l_command.append ({STRING_32} " -H %"Authorization: Bearer " + al_key + {STRING_32} "%"")
			end
			l_command.append ({STRING_32} " %"" + base_url + {STRING_32} "/props%"")
			create l_process.make
			l_output := l_process.command_output (l_command)
			Result := l_process.was_successful and then l_output.has_substring ({STRING_32} "200")
		end

	server_supports (a_flag: READABLE_STRING_GENERAL): BOOLEAN
			-- Does `settings.server_exe --help' list `a_flag'? (Older builds
			-- refuse to start on a flag they do not know.)
		require
			is_flag: a_flag.to_string_32.starts_with ({STRING_32} "--")
			no_quote: not a_flag.has ('"')
		local
			l_process: SIMPLE_PROCESS
			l_output: STRING_32
		do
			create l_process.make
			l_output := l_process.command_output ({STRING_32} "%"" + settings.server_exe + {STRING_32} "%" --help")
			Result := l_output.has_substring (a_flag.to_string_32 + {STRING_32} " ")
		end

	is_running: BOOLEAN
			-- Is the server we launched still alive?
		do
			Result := attached process as al_process and then al_process.is_running
		ensure
			only_ours: Result implies started_here
		end

feature -- Operations

	start
			-- Make sure a server is listening: reuse a live one that takes
			-- `settings''s key (or none, if unlocked), else launch ours.
		require
			not_already_ours: not started_here
		local
			l_process: SIMPLE_ASYNC_PROCESS
		do
			last_error.wipe_out
			log_tail.wipe_out
			if is_up then
				if not accepts_settings_key then
					last_error := {STRING_32} "port " + settings.port.out
						+ {STRING_32} " already has a llama-server that this program did not start and that is locked with another key (another window?). Close it or choose another port."
				end
			else
				create l_process.make
				l_process.set_show_window (False)
				l_process.set_ends_with_owner (True)
				l_process.start (settings.command_line)
				if l_process.was_started_successfully then
					process := l_process
					started_here := True
				elseif attached l_process.last_error as al_reason then
					last_error := {STRING_32} "could not start llama-server: " + al_reason
				else
					last_error := {STRING_32} "could not start llama-server: " + settings.server_exe
				end
			end
		ensure
			reused_not_launched: (old is_up) implies not started_here
			failed_launch_explained: (not (old is_up) and not started_here) implies not last_error.is_empty
		end

	wait_ready (a_timeout_seconds: INTEGER): BOOLEAN
			-- Poll /health until the model has loaded; False after
			-- `a_timeout_seconds' or if our server exits first.
		require
			positive: a_timeout_seconds > 0
		local
			l_env: EXECUTION_ENVIRONMENT
			l_waited: INTEGER
			l_gave_up: BOOLEAN
		do
			create l_env
			from
			until
				Result or l_gave_up
			loop
				refresh_log
				if attached process as al_process and then al_process.has_finished then
					last_error := {STRING_32} "llama-server stopped while loading (exit " + al_process.exit_code.out + {STRING_32} ")"
					l_gave_up := True
				elseif is_up then
					Result := True
				elseif l_waited >= a_timeout_seconds then
					last_error := {STRING_32} "llama-server was not ready after " + a_timeout_seconds.out + {STRING_32} " seconds"
					l_gave_up := True
				else
					l_env.sleep (1_000_000_000)
					l_waited := l_waited + 1
				end
			end
			refresh_log
		ensure
			error_on_failure: not Result implies not last_error.is_empty
		end

	refresh_log
			-- Move what our server has printed into `log_tail'.
		do
			if attached process as al_process and then al_process.is_started then
				if attached al_process.read_available_output as al_text then
					log_tail.append (al_text)
					if log_tail.count > Log_tail_limit then
						log_tail.remove_head (log_tail.count - Log_tail_limit)
					end
				end
			end
		ensure
			bounded: log_tail.count <= Log_tail_limit
		end

	stop
			-- End the server if we launched it; leave a reused one alone.
		local
			l_killed: BOOLEAN
		do
			if attached process as al_process then
				refresh_log
				if al_process.is_running then
					l_killed := al_process.kill
				end
				al_process.close
			end
			process := Void
			started_here := False
		ensure
			released: not attached process
			not_ours: not started_here
		end

feature -- Constants

	Log_tail_limit: INTEGER = 8000
			-- Characters of server output kept for diagnosis.

feature {NONE} -- Implementation

	process: detachable SIMPLE_ASYNC_PROCESS
			-- The server we launched, if we did.

invariant
	ours_iff_process: started_here = attached process
	log_bounded: log_tail.count <= Log_tail_limit

note
	copyright: "Copyright (c) 2026, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
