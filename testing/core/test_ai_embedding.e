note
	description: "[
		Tests for AI_EMBEDDING class.
		
		Tests cover:
		- Creation from various sources (array, blob)
		- Similarity calculations (cosine, euclidean)
		- Serialization (to_blob, from_blob roundtrip)
		- Normalization
		- Edge cases
	]"
	testing: "covers"
	date: "$Date$"
	revision: "$Revision$"

class
	TEST_AI_EMBEDDING

inherit
	EQA_TEST_SET

feature -- Test: Creation

	test_make_creates_zero_vector
			-- Test that make creates zero-initialized embedding
		local
			l_emb: AI_EMBEDDING
		do
			create l_emb.make (768)
			assert ("correct dimension", l_emb.dimension = 768)
			assert ("all zeros", across l_emb.vector as ic all ic = 0.0 end)
		end

	test_make_from_array
			-- Test creation from array
		local
			l_emb: AI_EMBEDDING
			l_values: ARRAY [REAL_64]
		do
			l_values := <<1.0, 2.0, 3.0, 4.0, 5.0>>
			create l_emb.make_from_array (l_values)

			assert ("correct dimension", l_emb.dimension = 5)
			assert ("value 1", l_emb.item (1) = 1.0)
			assert ("value 3", l_emb.item (3) = 3.0)
			assert ("value 5", l_emb.item (5) = 5.0)
		end

	test_source_text
			-- Test source text storage
		local
			l_emb: AI_EMBEDDING
		do
			create l_emb.make (10)
			assert ("initial empty", l_emb.source_text.is_empty)

			l_emb.set_source_text ("Test embedding source")
			assert ("source set", l_emb.source_text ~ "Test embedding source")
		end

feature -- Test: Cosine Similarity

	test_cosine_similarity_identical_vectors
			-- Identical vectors should have similarity 1.0
		local
			l_emb1, l_emb2: AI_EMBEDDING
		do
			create l_emb1.make_from_array (<<1.0, 2.0, 3.0>>)
			create l_emb2.make_from_array (<<1.0, 2.0, 3.0>>)

			assert ("identical = 1.0", (l_emb1.cosine_similarity (l_emb2) - 1.0).abs < 0.0001)
		end

	test_cosine_similarity_opposite_vectors
			-- Opposite vectors should have similarity -1.0
		local
			l_emb1, l_emb2: AI_EMBEDDING
		do
			create l_emb1.make_from_array (<<1.0, 2.0, 3.0>>)
			create l_emb2.make_from_array (<<-1.0, -2.0, -3.0>>)

			assert ("opposite = -1.0", (l_emb1.cosine_similarity (l_emb2) + 1.0).abs < 0.0001)
		end

	test_cosine_similarity_orthogonal_vectors
			-- Orthogonal vectors should have similarity 0.0
		local
			l_emb1, l_emb2: AI_EMBEDDING
		do
			create l_emb1.make_from_array (<<1.0, 0.0, 0.0>>)
			create l_emb2.make_from_array (<<0.0, 1.0, 0.0>>)

			assert ("orthogonal = 0.0", l_emb1.cosine_similarity (l_emb2).abs < 0.0001)
		end

	test_cosine_similarity_similar_vectors
			-- Similar vectors should have high similarity
		local
			l_emb1, l_emb2: AI_EMBEDDING
			l_sim: REAL_64
		do
			create l_emb1.make_from_array (<<1.0, 2.0, 3.0>>)
			create l_emb2.make_from_array (<<1.1, 2.1, 3.1>>)

			l_sim := l_emb1.cosine_similarity (l_emb2)
			assert ("high similarity", l_sim > 0.99)
		end

	test_cosine_similarity_is_symmetric
			-- Cosine similarity should be symmetric
		local
			l_emb1, l_emb2: AI_EMBEDDING
		do
			create l_emb1.make_from_array (<<1.0, 2.0, 3.0, 4.0>>)
			create l_emb2.make_from_array (<<4.0, 3.0, 2.0, 1.0>>)

			assert ("symmetric", (l_emb1.cosine_similarity (l_emb2) - l_emb2.cosine_similarity (l_emb1)).abs < 0.0001)
		end

feature -- Test: Euclidean Distance

	test_euclidean_distance_identical
			-- Identical vectors should have distance 0
		local
			l_emb1, l_emb2: AI_EMBEDDING
		do
			create l_emb1.make_from_array (<<1.0, 2.0, 3.0>>)
			create l_emb2.make_from_array (<<1.0, 2.0, 3.0>>)

			assert ("zero distance", l_emb1.euclidean_distance (l_emb2) < 0.0001)
		end

	test_euclidean_distance_known_value
			-- Test with known distance
		local
			l_emb1, l_emb2: AI_EMBEDDING
			l_dist: REAL_64
		do
			-- Distance should be sqrt((3-0)^2 + (4-0)^2) = sqrt(9+16) = 5
			create l_emb1.make_from_array (<<0.0, 0.0>>)
			create l_emb2.make_from_array (<<3.0, 4.0>>)

			l_dist := l_emb1.euclidean_distance (l_emb2)
			assert ("distance = 5", (l_dist - 5.0).abs < 0.0001)
		end

	test_euclidean_distance_is_symmetric
			-- Distance should be symmetric
		local
			l_emb1, l_emb2: AI_EMBEDDING
		do
			create l_emb1.make_from_array (<<1.0, 2.0, 3.0>>)
			create l_emb2.make_from_array (<<4.0, 5.0, 6.0>>)

			assert ("symmetric", (l_emb1.euclidean_distance (l_emb2) - l_emb2.euclidean_distance (l_emb1)).abs < 0.0001)
		end

feature -- Test: Dot Product

	test_dot_product
			-- Test dot product calculation
		local
			l_emb1, l_emb2: AI_EMBEDDING
			l_dot: REAL_64
		do
			-- (1*4) + (2*5) + (3*6) = 4 + 10 + 18 = 32
			create l_emb1.make_from_array (<<1.0, 2.0, 3.0>>)
			create l_emb2.make_from_array (<<4.0, 5.0, 6.0>>)

			l_dot := l_emb1.dot_product (l_emb2)
			assert ("dot product = 32", (l_dot - 32.0).abs < 0.0001)
		end

feature -- Test: Magnitude

	test_magnitude
			-- Test magnitude calculation
		local
			l_emb: AI_EMBEDDING
			l_mag: REAL_64
		do
			-- sqrt(3^2 + 4^2) = sqrt(9+16) = 5
			create l_emb.make_from_array (<<3.0, 4.0>>)

			l_mag := l_emb.magnitude
			assert ("magnitude = 5", (l_mag - 5.0).abs < 0.0001)
		end

	test_unit_vector_magnitude
			-- Unit vector should have magnitude 1
		local
			l_emb: AI_EMBEDDING
		do
			create l_emb.make_from_array (<<1.0, 0.0, 0.0>>)
			assert ("unit magnitude", (l_emb.magnitude - 1.0).abs < 0.0001)
			assert ("is normalized", l_emb.is_normalized)
		end

feature -- Test: Normalization

	test_normalized
			-- Test normalization produces unit vector
		local
			l_emb, l_norm: AI_EMBEDDING
		do
			create l_emb.make_from_array (<<3.0, 4.0>>)
			l_norm := l_emb.normalized

			assert ("normalized magnitude = 1", (l_norm.magnitude - 1.0).abs < 0.0001)
			assert ("is normalized", l_norm.is_normalized)
			assert ("same dimension", l_norm.dimension = l_emb.dimension)
		end

	test_normalized_preserves_direction
			-- Normalization should preserve direction (cosine sim = 1)
		local
			l_emb, l_norm: AI_EMBEDDING
		do
			create l_emb.make_from_array (<<1.0, 2.0, 3.0, 4.0>>)
			l_norm := l_emb.normalized

			assert ("same direction", (l_emb.cosine_similarity (l_norm) - 1.0).abs < 0.0001)
		end

feature -- Test: Serialization

	test_blob_roundtrip
			-- Test to_blob and from_blob produce identical embedding
		local
			l_original, l_restored: AI_EMBEDDING
			l_blob: MANAGED_POINTER
			i: INTEGER
		do
			create l_original.make_from_array (<<1.5, 2.5, 3.5, 4.5, 5.5>>)
			l_blob := l_original.to_blob
			create l_restored.make_from_blob (l_blob)

			assert ("same dimension", l_original.dimension = l_restored.dimension)
			from i := 1 until i > l_original.dimension loop
				assert ("value " + i.out + " matches",
					(l_original.item (i) - l_restored.item (i)).abs < 0.0000001)
				i := i + 1
			end
		end

	test_blob_size
			-- Test blob has correct size
		local
			l_emb: AI_EMBEDDING
			l_blob: MANAGED_POINTER
		do
			create l_emb.make (768)
			l_blob := l_emb.to_blob

			-- 768 dimensions * 8 bytes per REAL_64 = 6144 bytes
			assert ("correct blob size", l_blob.count = 768 * 8)
		end

	test_to_json_array
			-- Test JSON array output
		local
			l_emb: AI_EMBEDDING
			l_json: STRING_32
		do
			create l_emb.make_from_array (<<1.0, 2.0, 3.0>>)
			l_json := l_emb.to_json_array

			assert ("starts with [", l_json.item (1) = '[')
			assert ("ends with ]", l_json.item (l_json.count) = ']')
			assert ("contains values", l_json.has_substring ("1"))
			assert ("contains values", l_json.has_substring ("2"))
			assert ("contains values", l_json.has_substring ("3"))
		end

feature -- Test: is_similar_to

	test_is_similar_to_above_threshold
			-- Test is_similar_to with similar vectors
		local
			l_emb1, l_emb2: AI_EMBEDDING
		do
			create l_emb1.make_from_array (<<1.0, 2.0, 3.0>>)
			create l_emb2.make_from_array (<<1.0, 2.0, 3.0>>)

			assert ("identical is similar", l_emb1.is_similar_to (l_emb2, 0.9))
			assert ("identical is similar at 1.0", l_emb1.is_similar_to (l_emb2, 1.0))
		end

	test_is_similar_to_below_threshold
			-- Test is_similar_to with dissimilar vectors
		local
			l_emb1, l_emb2: AI_EMBEDDING
		do
			create l_emb1.make_from_array (<<1.0, 0.0, 0.0>>)
			create l_emb2.make_from_array (<<0.0, 1.0, 0.0>>)

			assert ("orthogonal not similar at 0.5", not l_emb1.is_similar_to (l_emb2, 0.5))
		end

feature -- Test: Edge Cases

	test_high_dimensional_embedding
			-- Test with realistic embedding dimension (768)
		local
			l_emb1, l_emb2: AI_EMBEDDING
			l_values1, l_values2: ARRAY [REAL_64]
			i: INTEGER
			l_sim: REAL_64
		do
			-- Create two 768-dimensional embeddings with known similarity
			create l_values1.make_filled (0.0, 1, 768)
			create l_values2.make_filled (0.0, 1, 768)

			from i := 1 until i > 768 loop
				l_values1 [i] := (i \\ 10) / 10.0
				l_values2 [i] := (i \\ 10) / 10.0 + 0.01
				i := i + 1
			end

			create l_emb1.make_from_array (l_values1)
			create l_emb2.make_from_array (l_values2)

			l_sim := l_emb1.cosine_similarity (l_emb2)
			assert ("high dimensional similarity works", l_sim > 0.99)
		end

	test_put_value
			-- Test setting individual values
		local
			l_emb: AI_EMBEDDING
		do
			create l_emb.make (5)
			l_emb.put (99.9, 3)

			assert ("value set", (l_emb.item (3) - 99.9).abs < 0.0001)
			assert ("other values unchanged", l_emb.item (1) = 0.0)
		end

note
	copyright: "Copyright (c) 2025, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
