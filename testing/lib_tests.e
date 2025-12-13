note
	description: "Tests for SIMPLE_AI_CLIENT"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"
	testing: "covers"

class
	LIB_TESTS

inherit
	TEST_SET_BASE

feature -- Test: Message Creation

	test_message_make_user
			-- Test creating user message.
		note
			testing: "covers/{AI_MESSAGE}.make_user"
		local
			msg: AI_MESSAGE
		do
			create msg.make_user ("Hello AI")
			assert_attached ("message created", msg)
		end

	test_message_make_system
			-- Test creating system message.
		note
			testing: "covers/{AI_MESSAGE}.make_system"
		local
			msg: AI_MESSAGE
		do
			create msg.make_system ("You are helpful")
			assert_attached ("message created", msg)
		end

feature -- Test: Response

	test_response_make
			-- Test response success creation.
		note
			testing: "covers/{AI_RESPONSE}.make"
		local
			response: AI_RESPONSE
		do
			create response.make ("Hello!", "test-model", "test-provider")
			assert_true ("is success", response.is_success)
			assert_strings_equal ("text set", "Hello!", response.text)
		end

	test_response_error
			-- Test response error creation.
		note
			testing: "covers/{AI_RESPONSE}.make_error"
		local
			response: AI_RESPONSE
		do
			create response.make_error ("API error", "test-provider")
			assert_true ("is error", response.is_error)
		end

end
