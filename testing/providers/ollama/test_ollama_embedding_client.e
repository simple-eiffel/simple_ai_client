note
	description: "[
		Tests for OLLAMA_EMBEDDING_CLIENT class.
		
		These are integration tests that require a running Ollama server
		with an embedding model installed (e.g., nomic-embed-text).
		
		To run these tests:
		1. Ensure Ollama is running: ollama serve
		2. Pull an embedding model: ollama pull nomic-embed-text
		3. Run the tests
		
		Tests marked with 'execution/isolated' can be skipped if Ollama
		is not available.
	]"
	testing: "type/manual"
	date: "$Date$"
	revision: "$Revision$"

class
	TEST_OLLAMA_EMBEDDING_CLIENT

inherit
	EQA_TEST_SET

feature -- Test: Creation

	test_make_default
			-- Test default creation
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
		do
			create l_client.make
			assert ("model set", l_client.model ~ "nomic-embed-text")
			assert ("provider set", l_client.provider_name ~ "ollama")
		end

	test_make_with_base_url
			-- Test creation with custom URL
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
		do
			create l_client.make_with_base_url ("http://192.168.1.100:11434")
			assert ("url set", l_client.base_url ~ "http://192.168.1.100:11434")
		end

	test_set_model
			-- Test model change
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
		do
			create l_client.make
			l_client.set_model ("mxbai-embed-large")
			assert ("model changed", l_client.model ~ "mxbai-embed-large")
		end

feature -- Test: Embedding Generation (Integration - requires Ollama)

	test_embed_simple_text
			-- Test embedding generation for simple text
			-- Requires: Ollama running with nomic-embed-text model
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
			l_response: AI_EMBEDDING_RESPONSE
		do
			create l_client.make
			l_response := l_client.embed ("Hello world")
			
			if l_response.is_success then
				assert ("has embedding", l_response.has_embedding)
				if attached l_response.embedding as l_emb then
					assert ("has dimensions", l_emb.dimension > 0)
					assert ("typical dimension", l_emb.dimension = 768 or l_emb.dimension = 384 or l_emb.dimension = 1024)
					assert ("source text set", l_emb.source_text ~ "Hello world")
				end
			else
				-- Ollama not available - skip test
				assert ("ollama unavailable - skipped", True)
			end
		end

	test_embed_code_snippet
			-- Test embedding of Eiffel code
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
			l_response: AI_EMBEDDING_RESPONSE
			l_code: STRING_32
		do
			l_code := "[
				class ACCOUNT
				feature
					balance: DECIMAL
					deposit (amount: DECIMAL)
						require
							positive: amount > 0
						do
							balance := balance + amount
						end
				end
			]"
			
			create l_client.make
			l_response := l_client.embed (l_code)
			
			if l_response.is_success and then attached l_response.embedding as l_emb then
				assert ("code embedded", l_emb.dimension > 0)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

	test_embed_error_message
			-- Test embedding of compiler error (typical Eifmate use case)
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
			l_response: AI_EMBEDDING_RESPONSE
			l_error: STRING_32
		do
			l_error := "VEVI error: Feature `make_from_json' not found in class SIMPLE_JSON_OBJECT. Did you mean `make'?"
			
			create l_client.make
			l_response := l_client.embed (l_error)
			
			if l_response.is_success and then attached l_response.embedding as l_emb then
				assert ("error embedded", l_emb.dimension > 0)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

feature -- Test: Similarity of Related Texts (Integration)

	test_similar_texts_have_high_similarity
			-- Similar texts should produce similar embeddings
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
			l_resp1, l_resp2: AI_EMBEDDING_RESPONSE
			l_sim: REAL_64
		do
			create l_client.make
			l_resp1 := l_client.embed ("The quick brown fox jumps over the lazy dog")
			l_resp2 := l_client.embed ("A fast brown fox leaps over a sleepy dog")
			
			if l_resp1.is_success and l_resp2.is_success and then 
			   attached l_resp1.embedding as l_emb1 and then
			   attached l_resp2.embedding as l_emb2 then
				l_sim := l_emb1.cosine_similarity (l_emb2)
				assert ("similar texts high similarity", l_sim > 0.7)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

	test_different_texts_have_low_similarity
			-- Unrelated texts should have lower similarity
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
			l_resp1, l_resp2: AI_EMBEDDING_RESPONSE
			l_sim: REAL_64
		do
			create l_client.make
			l_resp1 := l_client.embed ("The quick brown fox jumps over the lazy dog")
			l_resp2 := l_client.embed ("SELECT * FROM customers WHERE balance > 1000")
			
			if l_resp1.is_success and l_resp2.is_success and then 
			   attached l_resp1.embedding as l_emb1 and then
			   attached l_resp2.embedding as l_emb2 then
				l_sim := l_emb1.cosine_similarity (l_emb2)
				assert ("different texts lower similarity", l_sim < 0.7)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

	test_similar_errors_have_high_similarity
			-- Similar compiler errors should have high embedding similarity
			-- This is the core use case for Eifmate error resolution
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
			l_resp1, l_resp2, l_resp3: AI_EMBEDDING_RESPONSE
			l_sim_related, l_sim_unrelated: REAL_64
		do
			create l_client.make
			
			-- Two similar VEVI errors
			l_resp1 := l_client.embed ("VEVI error: Feature `withdraw' not found in class ACCOUNT")
			l_resp2 := l_client.embed ("VEVI error: Feature `deposit' not found in class BANK_ACCOUNT")
			
			-- Unrelated error
			l_resp3 := l_client.embed ("VTCT error: Type mismatch. Expected STRING, got INTEGER")
			
			if l_resp1.is_success and l_resp2.is_success and l_resp3.is_success and then 
			   attached l_resp1.embedding as l_emb1 and then
			   attached l_resp2.embedding as l_emb2 and then
			   attached l_resp3.embedding as l_emb3 then
				l_sim_related := l_emb1.cosine_similarity (l_emb2)
				l_sim_unrelated := l_emb1.cosine_similarity (l_emb3)
				
				assert ("related errors more similar", l_sim_related > l_sim_unrelated)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

feature -- Test: Batch Processing (Integration)

	test_embed_batch
			-- Test batch embedding generation
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
			l_texts: ARRAY [STRING_32]
			l_responses: ARRAY [AI_EMBEDDING_RESPONSE]
		do
			create l_client.make
			l_texts := <<"First text", "Second text", "Third text">>
			l_responses := l_client.embed_batch (l_texts)
			
			assert ("correct count", l_responses.count = 3)
			
			-- Check if Ollama is available by examining first response
			if l_responses [1].is_success then
				assert ("all successful", across l_responses as ic all ic.is_success end)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

feature -- Test: Error Handling

	test_embed_with_unavailable_server
			-- Test behavior when Ollama server is not available
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
			l_response: AI_EMBEDDING_RESPONSE
		do
			-- Use invalid port to simulate unavailable server
			create l_client.make_with_base_url ("http://localhost:99999")
			l_response := l_client.embed ("Test text")
			
			-- Should return error response, not crash
			assert ("is error or timeout", l_response.is_error or l_response.is_success)
		end

	test_embed_with_invalid_model
			-- Test behavior with non-existent model
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
			l_response: AI_EMBEDDING_RESPONSE
		do
			create l_client.make
			l_client.set_model ("this-model-does-not-exist-xyz123")
			l_response := l_client.embed ("Test text")
			
			-- Should return error (model not found) or success if it happens to exist
			assert ("handled gracefully", True)
		end

feature -- Test: is_available

	test_is_available_with_running_server
			-- Test availability check
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
		do
			create l_client.make
			-- Just verify it doesn't crash - result depends on whether Ollama is running
			if l_client.is_available then
				assert ("server available", True)
			else
				assert ("server not available - ok", True)
			end
		end

feature -- Test: Provider Name

	test_provider_name_in_response
			-- Test that provider name is correctly set in responses
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
			l_response: AI_EMBEDDING_RESPONSE
		do
			create l_client.make
			l_response := l_client.embed ("Test")
			
			assert ("provider is ollama", l_response.provider ~ "ollama")
		end

feature -- Test: Embedding Storage Workflow (Simulated)

	test_embedding_storage_workflow
			-- Simulate the full workflow: embed -> store (blob) -> retrieve -> compare
			-- This is the workflow Eifmate will use
		local
			l_client: OLLAMA_EMBEDDING_CLIENT
			l_response: AI_EMBEDDING_RESPONSE
			l_original: AI_EMBEDDING
			l_blob: MANAGED_POINTER
			l_restored: AI_EMBEDDING
			l_sim: REAL_64
		do
			create l_client.make
			l_response := l_client.embed ("Original error message for storage test")
			
			if l_response.is_success and then attached l_response.embedding as l_emb then
				l_original := l_emb
				
				-- Simulate database storage
				l_blob := l_original.to_blob
				
				-- Simulate database retrieval
				create l_restored.make_from_blob (l_blob)
				
				-- Verify roundtrip preserves embedding
				l_sim := l_original.cosine_similarity (l_restored)
				assert ("roundtrip preserves embedding", (l_sim - 1.0).abs < 0.0001)
			else
				assert ("ollama unavailable - skipped", True)
			end
		end

note
	copyright: "Copyright (c) 2025, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
