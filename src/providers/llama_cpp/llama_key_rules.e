note
	description: "[
		The one rule for a llama-server API key, shared by the settings
		that start a server with a key and the client that sends it.

		A key travels on a command line ("--api-key KEY") and in a curl
		header, so it may hold only ASCII letters, digits, "-" and "_":
		nothing that could end an argument or a quoted string. It must be
		at least `Minimum_key_length' characters, long enough that a web
		page cannot guess it.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LLAMA_KEY_RULES

feature -- Status report

	is_valid_api_key (a_key: READABLE_STRING_GENERAL): BOOLEAN
			-- Is `a_key' safe to pass on a command line and long enough?
		do
			Result := a_key.count >= Minimum_key_length and a_key.count <= Maximum_key_length and then
				across 1 |..| a_key.count as i all is_key_character (a_key.item (i)) end
		ensure
			long_enough: Result implies a_key.count >= Minimum_key_length
		end

	is_key_character (a_character: CHARACTER_32): BOOLEAN
			-- Is `a_character' an ASCII letter, digit, "-" or "_"?
		do
			Result := a_character.is_character_8 and then
				(a_character.to_character_8.is_alpha_numeric or a_character = '-' or a_character = '_')
		end

feature -- Constants

	Minimum_key_length: INTEGER = 16
			-- Shortest key accepted.

	Maximum_key_length: INTEGER = 128
			-- Longest key accepted.

note
	copyright: "Copyright (c) 2026, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
