note
	description: "[
		Reads what llama-server sends back from /v1/chat/completions,
		in either shape:

		- one JSON object (a non-streamed reply): `decode_whole';
		- a server-sent-event stream, fed in pieces as curl prints it:
		  `feed', one call per piece, however the pieces fall.

		A thinking model's reply has two parts, kept apart here: the
		thinking (`reasoning', from "reasoning_content") and the answer
		(`content'). While streaming, `fresh_reasoning' and
		`fresh_content' hold what arrived since the last
		`clear_fresh', so a caller can print text as it comes.

		The closing figures - tokens read and written, and generation
		speed - come from the reply's "usage" and "timings" objects.

		Pure: no process, no network. TEST_LLAMA_REPLY_DECODER drives it
		with captured server text.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LLAMA_REPLY_DECODER

create
	make

feature {NONE} -- Initialization

	make
			-- A decoder that has read nothing.
		do
			create reasoning.make_empty
			create content.make_empty
			create fresh_reasoning.make_empty
			create fresh_content.make_empty
			create pending_line.make_empty
			create stray_text.make_empty
			create json
		ensure
			empty: reasoning.is_empty and content.is_empty
			nothing_fresh: not has_fresh_text
			not_done: not is_done
			no_error: error_message = Void
		end

feature -- Access

	reasoning: STRING_32
			-- All thinking read so far.

	content: STRING_32
			-- All answer text read so far.

	fresh_reasoning: STRING_32
			-- Thinking that arrived since the last `clear_fresh'.

	fresh_content: STRING_32
			-- Answer text that arrived since the last `clear_fresh'.

	error_message: detachable STRING_32
			-- The server's error, if it sent one.

	prompt_tokens: INTEGER
			-- Tokens the server read (0 until the closing figures arrive).

	output_tokens: INTEGER
			-- Tokens the server wrote, thinking included.

	tokens_per_second: REAL_64
			-- Generation speed the server measured.

	finish_reason: detachable STRING_32
			-- Why generation ended ("stop", "length"...), once known.

	stray_text: STRING_32
			-- Lines that were neither events nor JSON (curl's own errors).

feature -- Status report

	is_done: BOOLEAN
			-- Has the stream's closing "[DONE]" (or a whole reply) been read?

	has_fresh_text: BOOLEAN
			-- Is there text not yet taken?
		do
			Result := not fresh_reasoning.is_empty or not fresh_content.is_empty
		ensure
			definition: Result = (not fresh_reasoning.is_empty or not fresh_content.is_empty)
		end

	has_error: BOOLEAN
			-- Did the server report an error?
		do
			Result := attached error_message
		end

feature -- Basic operations

	feed (a_piece: READABLE_STRING_GENERAL)
			-- Read `a_piece' of an event stream. A line split across two
			-- pieces waits for the rest.
		local
			l_newline: INTEGER
			l_line: STRING_32
		do
			pending_line.append_string_general (a_piece)
			from
				l_newline := pending_line.index_of ('%N', 1)
			until
				l_newline = 0
			loop
				l_line := pending_line.substring (1, l_newline - 1)
				pending_line.remove_head (l_newline)
				read_line (l_line)
				l_newline := pending_line.index_of ('%N', 1)
			end
		ensure
			reasoning_only_grows: reasoning.starts_with (old reasoning.twin)
			content_only_grows: content.starts_with (old content.twin)
			no_complete_line_left: not pending_line.has ('%N')
		end

	finish
			-- The stream has ended: read a last line that had no newline.
		do
			if not pending_line.is_empty then
				read_line (pending_line.twin)
				pending_line.wipe_out
			end
		ensure
			nothing_pending: pending_line.is_empty
		end

	decode_whole (a_text: READABLE_STRING_GENERAL)
			-- Read `a_text' as one non-streamed reply.
		local
			l_text: STRING_32
		do
			l_text := a_text.to_string_32
			l_text.left_adjust
			l_text.right_adjust
			if l_text.is_empty then
				error_message := {STRING_32} "empty reply from llama-server"
			elseif attached json.parse (l_text) as al_value and then al_value.is_object then
				read_object (al_value.as_object, False)
			else
				error_message := {STRING_32} "reply is not JSON: " + l_text.head (200)
			end
			is_done := True
		ensure
			done: is_done
		end

	clear_fresh
			-- Mark the fresh text as taken.
		do
			fresh_reasoning.wipe_out
			fresh_content.wipe_out
		ensure
			nothing_fresh: not has_fresh_text
			totals_kept: reasoning ~ old reasoning.twin and content ~ old content.twin
		end

feature {NONE} -- Implementation

	pending_line: STRING_32
			-- Start of a line whose newline has not arrived.

	json: SIMPLE_JSON
			-- Parser.

	read_line (a_line: STRING_32)
			-- Read one line of the stream.
		local
			l_payload: STRING_32
		do
			l_payload := a_line.twin
			l_payload.right_adjust
			if l_payload.starts_with ({STRING_32} "data:") then
				l_payload.remove_head (5)
				l_payload.left_adjust
				if l_payload.same_string ({STRING_32} "[DONE]") then
					is_done := True
				elseif not l_payload.is_empty then
					if attached json.parse (l_payload) as al_value and then al_value.is_object then
						read_object (al_value.as_object, True)
					else
						remember_stray (l_payload)
					end
				end
			elseif l_payload.starts_with ({STRING_32} "{") then
					-- An error the server sent as plain JSON, not as an event.
				if attached json.parse (l_payload) as al_value and then al_value.is_object then
					read_object (al_value.as_object, False)
				else
					remember_stray (l_payload)
				end
			elseif not l_payload.is_empty and not l_payload.starts_with ({STRING_32} ":") then
					-- ":" starts an SSE comment; anything else is curl talking.
				remember_stray (l_payload)
			end
		end

	read_object (a_object: SIMPLE_JSON_OBJECT; a_is_event: BOOLEAN)
			-- Take text, figures and errors from one reply object.
		local
			l_part: SIMPLE_JSON_OBJECT
		do
			if attached a_object.object_item ({STRING_32} "error") as al_error then
				if attached al_error.string_item ({STRING_32} "message") as al_message and then not al_message.is_empty then
					error_message := al_message
				else
					error_message := al_error.to_json_string
				end
			elseif attached a_object.string_item ({STRING_32} "error") as al_text and then not al_text.is_empty then
				error_message := al_text
			end
			if attached a_object.array_item ({STRING_32} "choices") as al_choices and then al_choices.count >= 1 and then
				attached al_choices.object_item (1) as al_choice
			then
				if a_is_event then
					l_part := al_choice.object_item ({STRING_32} "delta")
				else
					l_part := al_choice.object_item ({STRING_32} "message")
				end
				if attached l_part as al_part then
					if attached al_part.string_item ({STRING_32} "reasoning_content") as al_thought then
						reasoning.append (al_thought)
						fresh_reasoning.append (al_thought)
					end
					if attached al_part.string_item ({STRING_32} "content") as al_said then
						content.append (al_said)
						fresh_content.append (al_said)
					end
				end
				if attached al_choice.string_item ({STRING_32} "finish_reason") as al_reason and then not al_reason.is_empty then
					finish_reason := al_reason
				end
			end
			if attached a_object.object_item ({STRING_32} "usage") as al_usage then
				prompt_tokens := al_usage.integer_32_item ({STRING_32} "prompt_tokens")
				output_tokens := al_usage.integer_32_item ({STRING_32} "completion_tokens")
			end
			if attached a_object.object_item ({STRING_32} "timings") as al_timings then
				tokens_per_second := al_timings.real_item ({STRING_32} "predicted_per_second")
				if prompt_tokens = 0 then
					prompt_tokens := al_timings.integer_32_item ({STRING_32} "prompt_n")
				end
				if output_tokens = 0 then
					output_tokens := al_timings.integer_32_item ({STRING_32} "predicted_n")
				end
			end
		end

	remember_stray (a_text: STRING_32)
			-- Keep `a_text' (bounded) for error reports.
		do
			if stray_text.count < Stray_limit then
				if not stray_text.is_empty then
					stray_text.append_character ('%N')
				end
				stray_text.append (a_text.head (Stray_limit - stray_text.count))
			end
		ensure
			bounded: stray_text.count <= Stray_limit + 1
		end

	Stray_limit: INTEGER = 2000
			-- Most stray characters kept.

invariant
	fresh_reasoning_attached: fresh_reasoning /= Void
	fresh_content_attached: fresh_content /= Void
	no_complete_line_pending: not pending_line.has ('%N')
	figures_non_negative: prompt_tokens >= 0 and output_tokens >= 0 and tokens_per_second >= 0.0

note
	copyright: "Copyright (c) 2026, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
