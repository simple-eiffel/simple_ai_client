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
			-- Note: Ollama and Claude tests require network access
			-- They are not included in the automated runner

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
