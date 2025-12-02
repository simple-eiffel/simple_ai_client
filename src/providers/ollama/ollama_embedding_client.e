note
	description: "[
		Client for Ollama embedding API.
		
		Generates vector embeddings from text using Ollama's local embedding models.
		Uses curl via SIMPLE_PROCESS_HELPER to communicate with Ollama server.
		
		Supported Models:
		- nomic-embed-text (768 dimensions, recommended)
		- mxbai-embed-large (1024 dimensions)
		- all-minilm (384 dimensions, fastest)
		
		Usage Example:
			create client.make
			client.set_model ("nomic-embed-text")
			response := client.embed ("This is the text to embed")
			if response.is_success and then attached response.embedding as emb then
				-- Use emb.cosine_similarity, emb.to_blob, etc.
			end
		
		Batch Processing:
			responses := client.embed_batch (<<"text1", "text2", "text3">>)
		
		Design by Contract:
		- Text to embed must not be empty
		- Model must be set before embedding
		- Base URL must point to running Ollama server
	]"
	date: "$Date$"
	revision: "$Revision$"

class
	OLLAMA_EMBEDDING_CLIENT

create
	make,
	make_with_base_url

feature {NONE} -- Initialization

	make
			-- Create with default localhost URL and model
		do
			make_with_base_url (Default_base_url)
		ensure
			model_set: model ~ Default_embedding_model
			base_url_set: base_url ~ Default_base_url
		end

	make_with_base_url (a_base_url: STRING_32)
			-- Create with custom base URL
		require
			url_attached: a_base_url /= Void
			url_not_empty: not a_base_url.is_empty
		do
			base_url := a_base_url
			model := Default_embedding_model
			create process_helper
			create json
		ensure
			base_url_set: base_url = a_base_url
			model_set: model ~ Default_embedding_model
		end

feature -- Access

	model: STRING_32
			-- Current embedding model

	base_url: STRING_32
			-- Ollama server base URL

	provider_name: STRING_8 = "ollama"
			-- Provider identifier

feature -- Element change

	set_model (a_model: STRING_32)
			-- Set embedding model to `a_model'
		require
			model_attached: a_model /= Void
			model_not_empty: not a_model.is_empty
		do
			model := a_model
		ensure
			model_set: model = a_model
		end

feature -- Embedding operations

	embed (a_text: STRING_32): AI_EMBEDDING_RESPONSE
			-- Generate embedding for `a_text'
		require
			text_attached: a_text /= Void
			text_not_empty: not a_text.is_empty
		local
			l_request: SIMPLE_JSON_OBJECT
			l_curl_cmd: STRING_32
			l_output: STRING_32
		do
			-- Build request JSON
			create l_request.make
			l_request.put_string (model, Key_model).do_nothing
			l_request.put_string (a_text, Key_prompt).do_nothing

			-- Execute curl command
			l_curl_cmd := build_curl_command (Endpoint_embeddings, l_request.to_json_string)
			l_output := process_helper.output_of_command (l_curl_cmd, Void)

			-- Parse response
			Result := parse_embedding_response (l_output, a_text)
		ensure
			result_attached: Result /= Void
			provider_matches: Result.provider ~ provider_name
		end

	embed_batch (a_texts: ARRAY [STRING_32]): ARRAY [AI_EMBEDDING_RESPONSE]
			-- Generate embeddings for multiple texts
		require
			texts_attached: a_texts /= Void
			texts_not_empty: a_texts.count > 0
			all_texts_valid: across a_texts as ic all
				ic /= Void and then not ic.is_empty
			end
		local
			i: INTEGER
		do
			create Result.make_filled (create {AI_EMBEDDING_RESPONSE}.make_error ("uninitialized", provider_name), 1, a_texts.count)
			from i := a_texts.lower until i > a_texts.upper loop
				Result [i - a_texts.lower + 1] := embed (a_texts [i])
				i := i + 1
			end
		ensure
			result_attached: Result /= Void
			same_count: Result.count = a_texts.count
		end

feature -- Status

	is_available: BOOLEAN
			-- Is the Ollama embedding service available?
		local
			l_test_response: AI_EMBEDDING_RESPONSE
		do
			l_test_response := embed ("test")
			Result := l_test_response.is_success
		end

feature {NONE} -- Implementation

	build_curl_command (a_endpoint: STRING_32; a_json_body: STRING_32): STRING_32
			-- Build curl command for API request
		require
			endpoint_attached: a_endpoint /= Void
			body_attached: a_json_body /= Void
		local
			l_url: STRING_32
		do
			l_url := base_url + a_endpoint
			create Result.make (500)
			Result.append ("curl.exe -s -X POST ")
			Result.append (l_url)
			Result.append (" -H %"Content-Type: application/json%" -d %"")
			Result.append (escape_for_windows (a_json_body))
			Result.append ("%"")
		ensure
			result_attached: Result /= Void
			result_not_empty: not Result.is_empty
		end

	escape_for_windows (a_json: STRING_32): STRING_32
			-- Escape JSON for Windows command line
		require
			json_attached: a_json /= Void
		do
			create Result.make_from_string (a_json)
			Result.replace_substring_all ({STRING_32} "%"", {STRING_32} "\%"")
		ensure
			result_attached: Result /= Void
		end

	parse_embedding_response (a_output: STRING_32; a_source_text: STRING_32): AI_EMBEDDING_RESPONSE
			-- Parse Ollama embedding API response
		require
			output_attached: a_output /= Void
			source_text_attached: a_source_text /= Void
		local
			l_json_value: detachable SIMPLE_JSON_VALUE
			l_obj: SIMPLE_JSON_OBJECT
			l_embedding_array: SIMPLE_JSON_ARRAY
			l_values: ARRAY [REAL_64]
			l_embedding: AI_EMBEDDING
			i: INTEGER
		do
			if not a_output.is_empty then
				l_json_value := json.parse (a_output)
			end

			if attached l_json_value as al_value and then al_value.is_object then
				l_obj := al_value.as_object

				-- Check for error response
				if l_obj.has_key (Key_error) then
					if attached l_obj.string_item (Key_error) as l_err then
						Result := create {AI_EMBEDDING_RESPONSE}.make_error (l_err, provider_name)
					else
						Result := create {AI_EMBEDDING_RESPONSE}.make_error ("Unknown error from Ollama", provider_name)
					end
				elseif l_obj.has_key (Key_embedding) and then
					   attached l_obj.item (Key_embedding) as l_emb_value and then
					   l_emb_value.is_array then
					-- Parse embedding array
					l_embedding_array := l_emb_value.as_array
					create l_values.make_filled (0.0, 1, l_embedding_array.count)

					from i := 1 until i > l_embedding_array.count loop
						if attached l_embedding_array.item (i) as l_item and then l_item.is_number then
							l_values [i] := l_item.as_real
						end
						i := i + 1
					end

					create l_embedding.make_from_array (l_values)
					l_embedding.set_source_text (a_source_text)

					Result := create {AI_EMBEDDING_RESPONSE}.make (l_embedding, model, provider_name)
				else
					Result := create {AI_EMBEDDING_RESPONSE}.make_error ("No embedding in response", provider_name)
				end
			else
				Result := create {AI_EMBEDDING_RESPONSE}.make_error ("Failed to parse Ollama response: " + a_output, provider_name)
			end
		ensure
			result_attached: Result /= Void
		end

feature {NONE} -- Implementation: Attributes

	process_helper: SIMPLE_PROCESS_HELPER
			-- Process helper for executing curl

	json: SIMPLE_JSON
			-- JSON parser

feature {NONE} -- Constants

	Default_base_url: STRING_32 = "http://localhost:11434"
			-- Default Ollama server URL

	Default_embedding_model: STRING_32 = "nomic-embed-text"
			-- Default embedding model (768 dimensions, good quality)

	Endpoint_embeddings: STRING_32 = "/api/embeddings"
			-- Ollama embeddings API endpoint

	Key_model: STRING_32 = "model"
	Key_prompt: STRING_32 = "prompt"
	Key_embedding: STRING_32 = "embedding"
	Key_error: STRING_32 = "error"

invariant
	model_attached: model /= Void
	model_not_empty: not model.is_empty
	base_url_attached: base_url /= Void
	base_url_not_empty: not base_url.is_empty
	process_helper_attached: process_helper /= Void
	json_attached: json /= Void

note
	copyright: "Copyright (c) 2025, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
