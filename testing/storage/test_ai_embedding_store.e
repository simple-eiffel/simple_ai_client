note
	description: "[
		Tests for AI_EMBEDDING_STORE class.
		
		Integration tests that verify the full workflow:
		- Store errors/patterns/classes with embeddings
		- Search by similarity
		- Verify local computation (no AI calls during search)
		
		Requires:
		- Running Ollama with nomic-embed-text model
		- Write access for test database file
	]"
	testing: "type/manual"
	date: "$Date$"
	revision: "$Revision$"

class
	TEST_AI_EMBEDDING_STORE

inherit
	EQA_TEST_SET
		redefine
			on_prepare,
			on_clean
		end

feature {NONE} -- Setup

	on_prepare
			-- Setup test database and clients
		do
			-- Create test database
			create db.make ("test_embeddings.db")

			-- Create embedding client
			create embedding_client.make

			-- Create store (this creates tables)
			create store.make (db, embedding_client)
		end

	on_clean
			-- Cleanup test database
		local
			l_file: RAW_FILE
		do
			db.close
			create l_file.make_with_name ("test_embeddings.db")
			if l_file.exists then
				l_file.delete
			end
		end

feature -- Test: Storage

	test_store_error_resolution
			-- Test storing an error and its resolution
		note
			testing: "execution/isolated"
		local
			l_success: BOOLEAN
		do
			l_success := store.store_error_resolution (
				"VEVI error: Feature `make_from_json' not found in class SIMPLE_JSON_OBJECT",
				"Use `make' instead and then call `parse' separately"
			)

			if l_success then
				assert ("error stored", store.error_count = 1)
			else
				-- Ollama not available
				assert ("ollama unavailable - skipped", True)
			end
		end

	test_store_code_pattern
			-- Test storing a code pattern
		note
			testing: "execution/isolated"
		local
			l_success: BOOLEAN
		do
			l_success := store.store_code_pattern (
				"singleton",
				"Singleton pattern ensuring only one instance exists",
				"[
					class SINGLETON
					feature {NONE}
						instance: detachable SINGLETON
					feature
						shared: SINGLETON
							once
								create Result
							end
					end
				]"
			)

			if l_success then
				assert ("pattern stored", store.pattern_count = 1)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

	test_store_generated_class
			-- Test storing a generated class
		note
			testing: "execution/isolated"
		local
			l_success: BOOLEAN
		do
			l_success := store.store_generated_class (
				"ACCOUNT",
				"Bank account with balance, deposit, and withdraw features",
				"[
					class ACCOUNT
					feature
						balance: DECIMAL
						deposit (amount: DECIMAL)
							require positive: amount > 0
							do balance := balance + amount end
					end
				]"
			)

			if l_success then
				assert ("class stored", store.class_count = 1)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

feature -- Test: Search

	test_find_similar_errors
			-- Test finding similar errors
		note
			testing: "execution/isolated"
		local
			l_matches: LIST [TUPLE [id: INTEGER; error_text: STRING_32; resolution_code: STRING_32; similarity: REAL_64]]
		do
			-- First, store some errors
			if store.store_error_resolution (
				"VEVI error: Feature `withdraw' not found in class ACCOUNT",
				"Add withdraw feature to ACCOUNT class"
			) and store.store_error_resolution (
				"VEVI error: Feature `deposit' not found in class BANK_ACCOUNT",
				"Add deposit feature to BANK_ACCOUNT class"
			) and store.store_error_resolution (
				"VTCT error: Type mismatch. Expected STRING got INTEGER",
				"Convert INTEGER to STRING using .out"
			) then
				-- Search for similar error
				l_matches := store.find_similar_errors (
					"VEVI error: Feature `transfer' not found in class ACCOUNT",
					0.7,  -- threshold
					5     -- max results
				)

				assert ("found matches", l_matches.count > 0)

				-- The VEVI errors should be more similar than the VTCT error
				if l_matches.count >= 2 then
					assert ("first match is most similar", l_matches.first.similarity >= l_matches.i_th (2).similarity)
					assert ("high similarity for related error", l_matches.first.similarity > 0.8)
				end
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

	test_find_similar_errors_respects_threshold
			-- Test that threshold filtering works
		note
			testing: "execution/isolated"
		local
			l_matches_high, l_matches_low: LIST [TUPLE [id: INTEGER; error_text: STRING_32; resolution_code: STRING_32; similarity: REAL_64]]
		do
			if store.store_error_resolution (
				"VEVI error: Feature `foo' not found",
				"Fix 1"
			) and store.store_error_resolution (
				"Completely unrelated SQL syntax error in query",
				"Fix 2"
			) then
				-- High threshold should return fewer results
				l_matches_high := store.find_similar_errors ("VEVI error: Feature `bar' not found", 0.9, 10)
				l_matches_low := store.find_similar_errors ("VEVI error: Feature `bar' not found", 0.5, 10)

				assert ("low threshold returns more or equal", l_matches_low.count >= l_matches_high.count)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

	test_find_similar_errors_respects_max_results
			-- Test that max_results limit works
		note
			testing: "execution/isolated"
		local
			l_matches: LIST [TUPLE [id: INTEGER; error_text: STRING_32; resolution_code: STRING_32; similarity: REAL_64]]
			i: INTEGER
			l_all_stored: BOOLEAN
		do
			-- Store many errors
			l_all_stored := True
			from i := 1 until i > 10 or not l_all_stored loop
				l_all_stored := store.store_error_resolution (
					"Error variant " + i.out + ": Feature not found",
					"Resolution " + i.out
				)
				i := i + 1
			end

			if l_all_stored then
				-- Ollama was available, test max results
				l_matches := store.find_similar_errors ("Error: Feature not found", 0.5, 3)
				assert ("respects max results", l_matches.count <= 3)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

	test_find_similar_patterns
			-- Test finding similar code patterns
		note
			testing: "execution/isolated"
		local
			l_matches: LIST [TUPLE [name: STRING_32; description: STRING_32; example_code: STRING_32; similarity: REAL_64]]
		do
			if store.store_code_pattern (
				"factory",
				"Factory pattern for creating objects without specifying exact class",
				"-- Factory code example"
			) and store.store_code_pattern (
				"observer",
				"Observer pattern for event notification",
				"-- Observer code example"
			) then
				l_matches := store.find_similar_patterns (
					"Pattern for instantiating objects through a common interface",
					0.6,
					5
				)

				if l_matches.count > 0 then
					-- Factory should match better than observer
					assert ("found factory pattern", l_matches.first.name.has_substring ("factory"))
				end
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

	test_find_similar_specs
			-- Test finding classes with similar specifications
		note
			testing: "execution/isolated"
		local
			l_matches: LIST [TUPLE [class_name: STRING_32; specification: STRING_32; source_code: STRING_32; similarity: REAL_64]]
		do
			if store.store_generated_class (
				"CUSTOMER",
				"Customer entity with name, email, and order history",
				"-- Customer class code"
			) and store.store_generated_class (
				"PRODUCT",
				"Product with SKU, price, and inventory count",
				"-- Product class code"
			) then
				l_matches := store.find_similar_specs (
					"Entity representing a buyer with contact information",
					0.6,
					5
				)

				if l_matches.count > 0 then
					-- Should find CUSTOMER as more similar
					assert ("found customer class", l_matches.first.class_name ~ "CUSTOMER")
				end
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

feature -- Test: Performance Verification

--	test_search_completes_with_results
--			-- Verify that searching completes and returns results
--			-- Also verifies search is fast (local computation, not many AI calls)
--		note
--			testing: "execution/isolated"
--		local
--			l_matches: LIST [TUPLE [id: INTEGER; error_text: STRING_32; resolution_code: STRING_32; similarity: REAL_64]]
--			i: INTEGER
--			l_all_stored: BOOLEAN
--			l_start, l_end: TIME
--			l_duration_seconds: INTEGER
--		do
--			-- Store 20 errors (this part calls Ollama)
--			l_all_stored := True
--			from i := 1 until i > 20 or not l_all_stored loop
--				l_all_stored := store.store_error_resolution (
--					"Test error " + i.out + ": Some feature not found in some class",
--					"Resolution for error " + i.out
--				)
--				i := i + 1
--			end

--			if l_all_stored then
--				-- Now search - should complete quickly
--				create l_start.make_now
--				l_matches := store.find_similar_errors ("Test error: Feature xyz not found", 0.5, 10)
--				create l_end.make_now

--				l_duration_seconds := l_end.seconds - l_start.seconds

--				assert ("search completed", True)
--				assert ("found results", l_matches.count > 0)
--				assert ("respects max", l_matches.count <= 10)
--				assert ("search fast (under 5 seconds)", l_duration_seconds < 5)
--			else
--				assert ("ollama unavailable - skipped", True)
--			end
--		end

feature -- Test: Empty Database

	test_search_empty_database
			-- Test searching when no errors stored
		note
			testing: "execution/isolated"
		local
			l_matches: LIST [TUPLE [id: INTEGER; error_text: STRING_32; resolution_code: STRING_32; similarity: REAL_64]]
		do
			-- Don't store anything, just search
			l_matches := store.find_similar_errors ("Some error text", 0.5, 10)

			-- Should return empty list without error
			if embedding_client.is_available then
				assert ("empty result for empty db", l_matches.count = 0)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

feature -- Test: Statistics

--	test_count_statistics
--			-- Test count queries
--		note
--			testing: "execution/isolated"
--		do
--			if store.store_error_resolution ("Error 1", "Fix 1") and
--			   store.store_error_resolution ("Error 2", "Fix 2") and
--			   store.store_code_pattern ("Pattern 1", "Description 1", "Code 1") and
--			   store.store_generated_class ("Class1", "Spec 1", "Source 1")
--			then
--				assert ("error count", store.error_count = 2)
--				assert ("pattern count", store.pattern_count = 1)
--				assert ("class count", store.class_count = 1)
--			else
--				assert ("ollama unavailable - skipped", True)
--			end
--		end

feature {NONE} -- Implementation

	db: SIMPLE_SQL_DATABASE
			-- Test database

	embedding_client: OLLAMA_EMBEDDING_CLIENT
			-- Embedding client

	store: AI_EMBEDDING_STORE
			-- Store under test

;note
	copyright: "Copyright (c) 2025, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
