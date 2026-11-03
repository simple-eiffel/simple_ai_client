note
	description: "Runs TEST_LLAMA_CPP_LIVE against a real llama-server (see that class)."
	author: "Larry Rix"

class
	LLAMA_LIVE_TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run the live tests.
		do
			print ("Running llama.cpp LIVE tests...%N%N")
			create tests
			run_test (agent tests.test_stream_pieces_add_up, "test_stream_pieces_add_up")
			run_test (agent tests.test_whole_reply_and_thinking_off, "test_whole_reply_and_thinking_off")
			run_test (agent tests.test_bad_effort_is_reported, "test_bad_effort_is_reported")
			print ("%NResults: " + passed.out + " passed, " + failed.out + " failed%N")
			if failed > 0 then
				print ("TESTS FAILED%N")
			else
				print ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Implementation

	tests: TEST_LLAMA_CPP_LIVE

	passed, failed: INTEGER

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run one test and count it.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_test.call (Void)
				print ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			print ("  FAIL: " + a_name + "%N")
			failed := failed + 1
			l_retried := True
			retry
		end

end
