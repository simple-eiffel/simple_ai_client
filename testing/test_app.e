note
	description: "Test application for SIMPLE_AI_CLIENT"
	author: "Larry Rix"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run the tests.
		do
			print ("Running SIMPLE_AI_CLIENT tests...%N%N")
			passed := 0
			failed := 0

			run_lib_tests
			run_embedding_tests
			run_claude_offline_tests
			run_claude_code_tests
			run_utf8_boundary_tests
			-- Note: the Ollama and Claude tests in TEST_OLLAMA_CLIENT and
			-- TEST_CLAUDE_CLIENT need network access and a paid API call, so
			-- they stay out of the automated runner. TEST_CLAUDE_CLIENT_OFFLINE
			-- needs neither and does run here.

			print ("%N========================%N")
			print ("Results: " + passed.out + " passed, " + failed.out + " failed%N")

			if failed > 0 then
				print ("TESTS FAILED%N")
			else
				print ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Test Runners

	run_lib_tests
		do
			create lib_tests
			run_test (agent lib_tests.test_message_make_user, "test_message_make_user")
			run_test (agent lib_tests.test_message_make_system, "test_message_make_system")
			run_test (agent lib_tests.test_response_make, "test_response_make")
			run_test (agent lib_tests.test_response_error, "test_response_error")
		end

	run_claude_offline_tests
		do
			create claude_offline_tests
			run_test (agent claude_offline_tests.test_curl_command_omits_api_key, "test_curl_command_omits_api_key")
			run_test (agent claude_offline_tests.test_model_family_classification, "test_model_family_classification")
			run_test (agent claude_offline_tests.test_pricing_lookup, "test_pricing_lookup")
			run_test (agent claude_offline_tests.test_defaults, "test_defaults")
			run_test (agent claude_offline_tests.test_set_max_tokens, "test_set_max_tokens")
		end

	run_claude_code_tests
		do
			create claude_code_tests
			run_test (agent claude_code_tests.test_batch_script_clears_api_key, "test_batch_script_clears_api_key")
			run_test (agent claude_code_tests.test_batch_script_reads_prompt_from_stdin, "test_batch_script_reads_prompt_from_stdin")
			run_test (agent claude_code_tests.test_batch_script_includes_system_prompt, "test_batch_script_includes_system_prompt")
			run_test (agent claude_code_tests.test_defaults, "test_cc_defaults")
			run_test (agent claude_code_tests.test_set_working_directory, "test_set_working_directory")
			run_test (agent claude_code_tests.test_sandbox_flags_off_by_default, "test_sandbox_flags_off_by_default")
			run_test (agent claude_code_tests.test_sandbox_flags_reach_the_command, "test_sandbox_flags_reach_the_command")
			run_test (agent claude_code_tests.test_resume_session_reaches_the_command, "test_resume_session_reaches_the_command")
			run_test (agent claude_code_tests.test_session_id_shape_is_a_uuid, "test_session_id_shape_is_a_uuid")
			run_test (agent claude_code_tests.test_live_round_trip, "test_live_round_trip")
		end

	run_utf8_boundary_tests
		do
			create utf8_boundary_tests
			run_test (agent utf8_boundary_tests.test_decode_process_bytes_em_dash, "test_decode_process_bytes_em_dash")
			run_test (agent utf8_boundary_tests.test_decode_process_bytes_hebrew, "test_decode_process_bytes_hebrew")
			run_test (agent utf8_boundary_tests.test_decode_process_bytes_emoji, "test_decode_process_bytes_emoji")
			run_test (agent utf8_boundary_tests.test_decode_process_bytes_greek, "test_decode_process_bytes_greek")
			run_test (agent utf8_boundary_tests.test_decode_process_bytes_combined, "test_decode_process_bytes_combined")
			run_test (agent utf8_boundary_tests.test_decode_process_bytes_ascii_passthrough, "test_decode_process_bytes_ascii_passthrough")
			run_test (agent utf8_boundary_tests.test_decode_process_bytes_empty, "test_decode_process_bytes_empty")
			run_test (agent utf8_boundary_tests.test_decode_process_bytes_leaves_real_unicode_alone, "test_decode_process_bytes_leaves_real_unicode_alone")
			run_test (agent utf8_boundary_tests.test_real_process_round_trip, "test_real_process_round_trip")
			run_test (agent utf8_boundary_tests.test_json_body_not_narrowable_to_string_8, "test_json_body_not_narrowable_to_string_8")
			run_test (agent utf8_boundary_tests.test_utf8_encode_decode_round_trip, "test_utf8_encode_decode_round_trip")
			run_test (agent utf8_boundary_tests.test_request_body_round_trip_through_a_real_process, "test_request_body_round_trip_through_a_real_process")
		end

	run_embedding_tests
		do
			create embedding_tests
			run_test (agent embedding_tests.test_make_creates_zero_vector, "test_make_creates_zero_vector")
			run_test (agent embedding_tests.test_make_from_array, "test_make_from_array")
			run_test (agent embedding_tests.test_source_text, "test_source_text")
			run_test (agent embedding_tests.test_cosine_similarity_identical_vectors, "test_cosine_similarity_identical_vectors")
			run_test (agent embedding_tests.test_cosine_similarity_opposite_vectors, "test_cosine_similarity_opposite_vectors")
			run_test (agent embedding_tests.test_cosine_similarity_orthogonal_vectors, "test_cosine_similarity_orthogonal_vectors")
			run_test (agent embedding_tests.test_cosine_similarity_similar_vectors, "test_cosine_similarity_similar_vectors")
			run_test (agent embedding_tests.test_cosine_similarity_is_symmetric, "test_cosine_similarity_is_symmetric")
			run_test (agent embedding_tests.test_euclidean_distance_identical, "test_euclidean_distance_identical")
			run_test (agent embedding_tests.test_euclidean_distance_known_value, "test_euclidean_distance_known_value")
			run_test (agent embedding_tests.test_euclidean_distance_is_symmetric, "test_euclidean_distance_is_symmetric")
			run_test (agent embedding_tests.test_dot_product, "test_dot_product")
			run_test (agent embedding_tests.test_magnitude, "test_magnitude")
			run_test (agent embedding_tests.test_unit_vector_magnitude, "test_unit_vector_magnitude")
			run_test (agent embedding_tests.test_normalized, "test_normalized")
			run_test (agent embedding_tests.test_normalized_preserves_direction, "test_normalized_preserves_direction")
			run_test (agent embedding_tests.test_blob_roundtrip, "test_blob_roundtrip")
			run_test (agent embedding_tests.test_blob_size, "test_blob_size")
			run_test (agent embedding_tests.test_to_json_array, "test_to_json_array")
			run_test (agent embedding_tests.test_is_similar_to_above_threshold, "test_is_similar_to_above_threshold")
			run_test (agent embedding_tests.test_is_similar_to_below_threshold, "test_is_similar_to_below_threshold")
			run_test (agent embedding_tests.test_high_dimensional_embedding, "test_high_dimensional_embedding")
			run_test (agent embedding_tests.test_put_value, "test_put_value")
		end

feature {NONE} -- Implementation

	lib_tests: LIB_TESTS
	embedding_tests: TEST_AI_EMBEDDING
	claude_offline_tests: TEST_CLAUDE_CLIENT_OFFLINE
	claude_code_tests: TEST_CLAUDE_CODE_CLIENT
	utf8_boundary_tests: TEST_UTF8_BOUNDARY

	passed: INTEGER
	failed: INTEGER

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test and update counters.
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
