note
	description: "Storage and retrieval of embeddings using SQLite"

class
	AI_EMBEDDING_STORE

create
	make

feature {NONE} -- Initialization

	make (a_db: SIMPLE_SQL_DATABASE; a_client: OLLAMA_EMBEDDING_CLIENT)
		require
			db_attached: a_db /= Void
			client_attached: a_client /= Void
		do
			db := a_db
			embedding_client := a_client
			ensure_tables_exist
		end

feature -- Access

	db: SIMPLE_SQL_DATABASE
	embedding_client: OLLAMA_EMBEDDING_CLIENT

feature -- Storage

	store_error_resolution (a_error: STRING_32; a_resolution: STRING_32): BOOLEAN
		require
			error_not_empty: not a_error.is_empty
			resolution_not_empty: not a_resolution.is_empty
		local
			l_response: AI_EMBEDDING_RESPONSE
			l_sql: STRING_8
		do
			l_response := embedding_client.embed (a_error)
			if l_response.is_success and then attached l_response.embedding as l_emb then
				l_sql := "INSERT INTO error_resolutions (error_text, error_embedding, resolution_code) VALUES ('" 
					+ escape_sql (a_error) + "', '" 
					+ escape_sql (l_emb.to_json_array) + "', '" 
					+ escape_sql (a_resolution) + "')"
				db.execute (l_sql)
				Result := not db.has_error
			end
		end

	store_code_pattern (a_name, a_description, a_code: STRING_32): BOOLEAN
		local
			l_response: AI_EMBEDDING_RESPONSE
			l_sql: STRING_8
		do
			l_response := embedding_client.embed (a_description)
			if l_response.is_success and then attached l_response.embedding as l_emb then
				l_sql := "INSERT INTO code_patterns (pattern_name, description, description_embedding, example_code) VALUES ('"
					+ escape_sql (a_name) + "', '"
					+ escape_sql (a_description) + "', '"
					+ escape_sql (l_emb.to_json_array) + "', '"
					+ escape_sql (a_code) + "')"
				db.execute (l_sql)
				Result := not db.has_error
			end
		end

	store_generated_class (a_class_name, a_spec, a_source: STRING_32): BOOLEAN
		local
			l_response: AI_EMBEDDING_RESPONSE
			l_sql: STRING_8
		do
			l_response := embedding_client.embed (a_spec)
			if l_response.is_success and then attached l_response.embedding as l_emb then
				l_sql := "INSERT INTO generated_classes (class_name, specification, spec_embedding, source_code, status) VALUES ('"
					+ escape_sql (a_class_name) + "', '"
					+ escape_sql (a_spec) + "', '"
					+ escape_sql (l_emb.to_json_array) + "', '"
					+ escape_sql (a_source) + "', 'generated')"
				db.execute (l_sql)
				Result := not db.has_error
			end
		end

feature -- Search

	find_similar_errors (a_query: STRING_32; a_threshold: REAL_64; a_max: INTEGER): ARRAYED_LIST [TUPLE [id: INTEGER; error_text: STRING_32; resolution_code: STRING_32; similarity: REAL_64]]
		local
			l_response: AI_EMBEDDING_RESPONSE
			l_query_emb, l_stored_emb: AI_EMBEDDING
			l_result: SIMPLE_SQL_RESULT
			l_row: SIMPLE_SQL_ROW
			l_sim: REAL_64
			i: INTEGER
		do
			create Result.make (a_max)
			l_response := embedding_client.embed (a_query)
			if l_response.is_success and then attached l_response.embedding as l_qe then
				l_query_emb := l_qe
				l_result := db.query ("SELECT id, error_text, error_embedding, resolution_code FROM error_resolutions")
				from i := 1 until i > l_result.count loop
					l_row := l_result [i]
					create l_stored_emb.make_from_json (l_row.string_value ("error_embedding"))
					if l_stored_emb.dimension = l_query_emb.dimension then
						l_sim := l_query_emb.cosine_similarity (l_stored_emb)
						if l_sim >= a_threshold then
							Result.extend ([l_row.integer_value ("id"), l_row.string_value ("error_text"), l_row.string_value ("resolution_code"), l_sim])
						end
					end
					i := i + 1
				end
				sort_results (Result)
				trim_results (Result, a_max)
			end
		end

	find_similar_patterns (a_query: STRING_32; a_threshold: REAL_64; a_max: INTEGER): ARRAYED_LIST [TUPLE [name: STRING_32; description: STRING_32; example_code: STRING_32; similarity: REAL_64]]
		local
			l_response: AI_EMBEDDING_RESPONSE
			l_query_emb, l_stored_emb: AI_EMBEDDING
			l_result: SIMPLE_SQL_RESULT
			l_row: SIMPLE_SQL_ROW
			l_sim: REAL_64
			i: INTEGER
		do
			create Result.make (a_max)
			l_response := embedding_client.embed (a_query)
			if l_response.is_success and then attached l_response.embedding as l_qe then
				l_query_emb := l_qe
				l_result := db.query ("SELECT pattern_name, description, description_embedding, example_code FROM code_patterns")
				from i := 1 until i > l_result.count loop
					l_row := l_result [i]
					create l_stored_emb.make_from_json (l_row.string_value ("description_embedding"))
					if l_stored_emb.dimension = l_query_emb.dimension then
						l_sim := l_query_emb.cosine_similarity (l_stored_emb)
						if l_sim >= a_threshold then
							Result.extend ([l_row.string_value ("pattern_name"), l_row.string_value ("description"), l_row.string_value ("example_code"), l_sim])
						end
					end
					i := i + 1
				end
				sort_pattern_results (Result)
				trim_pattern_results (Result, a_max)
			end
		end

	find_similar_specs (a_query: STRING_32; a_threshold: REAL_64; a_max: INTEGER): ARRAYED_LIST [TUPLE [class_name: STRING_32; specification: STRING_32; source_code: STRING_32; similarity: REAL_64]]
		local
			l_response: AI_EMBEDDING_RESPONSE
			l_query_emb, l_stored_emb: AI_EMBEDDING
			l_result: SIMPLE_SQL_RESULT
			l_row: SIMPLE_SQL_ROW
			l_sim: REAL_64
			i: INTEGER
		do
			create Result.make (a_max)
			l_response := embedding_client.embed (a_query)
			if l_response.is_success and then attached l_response.embedding as l_qe then
				l_query_emb := l_qe
				l_result := db.query ("SELECT class_name, specification, spec_embedding, source_code FROM generated_classes")
				from i := 1 until i > l_result.count loop
					l_row := l_result [i]
					create l_stored_emb.make_from_json (l_row.string_value ("spec_embedding"))
					if l_stored_emb.dimension = l_query_emb.dimension then
						l_sim := l_query_emb.cosine_similarity (l_stored_emb)
						if l_sim >= a_threshold then
							Result.extend ([l_row.string_value ("class_name"), l_row.string_value ("specification"), l_row.string_value ("source_code"), l_sim])
						end
					end
					i := i + 1
				end
				sort_spec_results (Result)
				trim_spec_results (Result, a_max)
			end
		end

feature -- Statistics

	error_count: INTEGER
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := db.query ("SELECT COUNT(*) as cnt FROM error_resolutions")
			if not l_result.is_empty then
				Result := l_result.first.integer_value ("cnt")
			end
		end

	pattern_count: INTEGER
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := db.query ("SELECT COUNT(*) as cnt FROM code_patterns")
			if not l_result.is_empty then
				Result := l_result.first.integer_value ("cnt")
			end
		end

	class_count: INTEGER
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := db.query ("SELECT COUNT(*) as cnt FROM generated_classes")
			if not l_result.is_empty then
				Result := l_result.first.integer_value ("cnt")
			end
		end

feature {NONE} -- Implementation

	ensure_tables_exist
		do
			db.execute ("CREATE TABLE IF NOT EXISTS error_resolutions (id INTEGER PRIMARY KEY AUTOINCREMENT, error_text TEXT, error_embedding TEXT, resolution_code TEXT)")
			db.execute ("CREATE TABLE IF NOT EXISTS code_patterns (id INTEGER PRIMARY KEY AUTOINCREMENT, pattern_name TEXT, description TEXT, description_embedding TEXT, example_code TEXT)")
			db.execute ("CREATE TABLE IF NOT EXISTS generated_classes (id INTEGER PRIMARY KEY AUTOINCREMENT, class_name TEXT, specification TEXT, spec_embedding TEXT, source_code TEXT, status TEXT)")
		end

	escape_sql (a_str: STRING_32): STRING_8
		do
			create Result.make_from_string (a_str.to_string_8)
			Result.replace_substring_all ("'", "''")
		end

	sort_results (a_list: ARRAYED_LIST [TUPLE [id: INTEGER; error_text: STRING_32; resolution_code: STRING_32; similarity: REAL_64]])
		local
			i, j: INTEGER
			l_temp: TUPLE [id: INTEGER; error_text: STRING_32; resolution_code: STRING_32; similarity: REAL_64]
		do
			from i := 2 until i > a_list.count loop
				l_temp := a_list [i]
				from j := i - 1 until j < 1 or else a_list [j].similarity >= l_temp.similarity loop
					a_list [j + 1] := a_list [j]
					j := j - 1
				end
				a_list [j + 1] := l_temp
				i := i + 1
			end
		end

	sort_pattern_results (a_list: ARRAYED_LIST [TUPLE [name: STRING_32; description: STRING_32; example_code: STRING_32; similarity: REAL_64]])
		local
			i, j: INTEGER
			l_temp: TUPLE [name: STRING_32; description: STRING_32; example_code: STRING_32; similarity: REAL_64]
		do
			from i := 2 until i > a_list.count loop
				l_temp := a_list [i]
				from j := i - 1 until j < 1 or else a_list [j].similarity >= l_temp.similarity loop
					a_list [j + 1] := a_list [j]
					j := j - 1
				end
				a_list [j + 1] := l_temp
				i := i + 1
			end
		end

	trim_results (a_list: ARRAYED_LIST [TUPLE [id: INTEGER; error_text: STRING_32; resolution_code: STRING_32; similarity: REAL_64]]; a_max: INTEGER)
		do
			from until a_list.count <= a_max loop
				a_list.finish
				a_list.remove
			end
		end

	trim_pattern_results (a_list: ARRAYED_LIST [TUPLE [name: STRING_32; description: STRING_32; example_code: STRING_32; similarity: REAL_64]]; a_max: INTEGER)
		do
			from until a_list.count <= a_max loop
				a_list.finish
				a_list.remove
			end
		end

	sort_spec_results (a_list: ARRAYED_LIST [TUPLE [class_name: STRING_32; specification: STRING_32; source_code: STRING_32; similarity: REAL_64]])
		local
			i, j: INTEGER
			l_temp: TUPLE [class_name: STRING_32; specification: STRING_32; source_code: STRING_32; similarity: REAL_64]
		do
			from i := 2 until i > a_list.count loop
				l_temp := a_list [i]
				from j := i - 1 until j < 1 or else a_list [j].similarity >= l_temp.similarity loop
					a_list [j + 1] := a_list [j]
					j := j - 1
				end
				a_list [j + 1] := l_temp
				i := i + 1
			end
		end

	trim_spec_results (a_list: ARRAYED_LIST [TUPLE [class_name: STRING_32; specification: STRING_32; source_code: STRING_32; similarity: REAL_64]]; a_max: INTEGER)
		do
			from until a_list.count <= a_max loop
				a_list.finish
				a_list.remove
			end
		end

end
