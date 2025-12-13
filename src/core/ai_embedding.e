note
	description: "Vector embedding with similarity operations"

class
	AI_EMBEDDING

create
	make,
	make_from_array,
	make_from_json,
	make_from_blob

feature {NONE} -- Initialization

	make (a_dimension: INTEGER)
		require
			valid_dimension: a_dimension >= 1
		do
			create vector.make_filled (0.0, 1, a_dimension)
			source_text := ""
		end

	make_from_array (a_values: ARRAY [REAL_64])
		require
			values_not_empty: a_values.count >= 1
		local
			i: INTEGER
		do
			create vector.make_filled (0.0, 1, a_values.count)
			from i := a_values.lower until i > a_values.upper loop
				vector [i - a_values.lower + 1] := a_values [i]
				i := i + 1
			end
			source_text := ""
		end

	make_from_json (a_json: STRING_32)
			-- Create from JSON array "[1.0, 2.0, ...]"
		require
			json_not_empty: not a_json.is_empty
		local
			l_json: SIMPLE_JSON
			l_value: SIMPLE_JSON_VALUE
			l_array: SIMPLE_JSON_ARRAY
			i: INTEGER
		do
			create l_json
			l_value := l_json.deserialize (a_json)
			if attached l_value as al_val and then al_val.is_array then
				l_array := al_val.as_array
				create vector.make_filled (0.0, 1, l_array.count)
				from i := 1 until i > l_array.count loop
					if attached l_array.item (i) as l_item and then l_item.is_number then
						vector [i] := l_item.as_real
					end
					i := i + 1
				end
			else
				create vector.make_filled (0.0, 1, 1)
			end
			source_text := ""
		end

	make_from_blob (a_blob: MANAGED_POINTER)
			-- Create from binary blob (serialized REAL_64 array)
		require
			valid_size: a_blob.count > 0 and a_blob.count \\ 8 = 0
		local
			l_dim, i: INTEGER
		do
			l_dim := a_blob.count // 8
			create vector.make_filled (0.0, 1, l_dim)
			from i := 1 until i > l_dim loop
				vector [i] := a_blob.read_real_64 ((i - 1) * 8)
				i := i + 1
			end
			source_text := ""
		end

feature -- Access

	vector: ARRAY [REAL_64]
	source_text: STRING_32

	dimension: INTEGER
		do
			Result := vector.count
		end

	item (i: INTEGER): REAL_64
		require
			valid_index: i >= 1 and i <= dimension
		do
			Result := vector [i]
		end

feature -- Element change

	set_source_text (a_text: STRING_32)
		do
			source_text := a_text
		end

	put (a_value: REAL_64; i: INTEGER)
		require
			valid_index: i >= 1 and i <= dimension
		do
			vector [i] := a_value
		end

feature -- Similarity

	cosine_similarity (other: AI_EMBEDDING): REAL_64
		require
			same_dimension: other.dimension = dimension
		local
			l_dot, l_norm_self, l_norm_other: REAL_64
			i: INTEGER
		do
			from i := 1 until i > dimension loop
				l_dot := l_dot + (vector [i] * other.vector [i])
				l_norm_self := l_norm_self + (vector [i] * vector [i])
				l_norm_other := l_norm_other + (other.vector [i] * other.vector [i])
				i := i + 1
			end
			if l_norm_self > 0.0 and l_norm_other > 0.0 then
				Result := l_dot / (math.sqrt (l_norm_self) * math.sqrt (l_norm_other))
				Result := Result.max (-1.0).min (1.0)
			end
		end

	euclidean_distance (other: AI_EMBEDDING): REAL_64
		require
			same_dimension: other.dimension = dimension
		local
			l_sum, l_diff: REAL_64
			i: INTEGER
		do
			from i := 1 until i > dimension loop
				l_diff := vector [i] - other.vector [i]
				l_sum := l_sum + (l_diff * l_diff)
				i := i + 1
			end
			Result := math.sqrt (l_sum)
		end

	is_similar_to (other: AI_EMBEDDING; threshold: REAL_64): BOOLEAN
		require
			same_dimension: other.dimension = dimension
		do
			Result := cosine_similarity (other) >= threshold
		end

feature -- Measurement

	magnitude: REAL_64
		local
			l_sum: REAL_64
			i: INTEGER
		do
			from i := 1 until i > dimension loop
				l_sum := l_sum + (vector [i] * vector [i])
				i := i + 1
			end
			Result := math.sqrt (l_sum)
		end

	dot_product (other: AI_EMBEDDING): REAL_64
		require
			same_dimension: other.dimension = dimension
		local
			i: INTEGER
		do
			from i := 1 until i > dimension loop
				Result := Result + (vector [i] * other.vector [i])
				i := i + 1
			end
		end

	is_normalized: BOOLEAN
		do
			Result := (magnitude - 1.0).abs < 0.0001
		end

	normalized: AI_EMBEDDING
		local
			l_mag: REAL_64
			i: INTEGER
		do
			l_mag := magnitude
			create Result.make (dimension)
			if l_mag > 0.0 then
				from i := 1 until i > dimension loop
					Result.put (vector [i] / l_mag, i)
					i := i + 1
				end
			end
		end

feature -- Serialization

	to_json_array: STRING_32
		local
			i: INTEGER
		do
			create Result.make (dimension * 12)
			Result.append_character ('[')
			from i := 1 until i > dimension loop
				if i > 1 then
					Result.append_character (',')
				end
				Result.append (vector [i].out)
				i := i + 1
			end
			Result.append_character (']')
		end

	to_blob: MANAGED_POINTER
		local
			i: INTEGER
		do
			create Result.make (dimension * 8)
			from i := 1 until i > dimension loop
				Result.put_real_64 (vector [i], (i - 1) * 8)
				i := i + 1
			end
		end

feature {NONE} -- Implementation

	math: DOUBLE_MATH
		once
			create Result
		end

invariant
	vector_attached: vector /= Void
	source_text_attached: source_text /= Void

end
