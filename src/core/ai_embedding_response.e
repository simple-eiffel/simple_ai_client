note
	description: "[
		Response from an embedding API request.
		
		Contains either a successful embedding result or error information.
		Follows the same pattern as AI_RESPONSE for consistency.
		
		Design by Contract:
		- Response is either successful (has embedding) or error (has error message)
		- Successful responses always have a non-void embedding
		- Error responses always have a non-empty error message
	]"
	date: "$Date$"
	revision: "$Revision$"

class
	AI_EMBEDDING_RESPONSE

create
	make,
	make_error

feature {NONE} -- Initialization

	make (a_embedding: AI_EMBEDDING; a_model: STRING_32; a_provider: STRING_8)
			-- Create successful response with `a_embedding'
		require
			embedding_attached: a_embedding /= Void
			model_attached: a_model /= Void
			model_not_empty: not a_model.is_empty
			provider_attached: a_provider /= Void
			provider_not_empty: not a_provider.is_empty
		do
			embedding := a_embedding
			model := a_model
			provider := a_provider
			is_success := True
			error_message := ""
		ensure
			embedding_set: embedding = a_embedding
			model_set: model = a_model
			provider_set: provider = a_provider
			is_successful: is_success
			no_error: error_message.is_empty
		end

	make_error (a_message: STRING_32; a_provider: STRING_8)
			-- Create error response with `a_message'
		require
			message_attached: a_message /= Void
			message_not_empty: not a_message.is_empty
			provider_attached: a_provider /= Void
			provider_not_empty: not a_provider.is_empty
		do
			error_message := a_message
			provider := a_provider
			is_success := False
			model := ""
		ensure
			error_set: error_message = a_message
			provider_set: provider = a_provider
			not_successful: not is_success
			no_embedding: embedding = Void
		end

feature -- Access

	embedding: detachable AI_EMBEDDING
			-- The embedding result (only if successful)

	model: STRING_32
			-- Model that generated the embedding

	provider: STRING_8
			-- Provider name (e.g., "ollama")

	error_message: STRING_32
			-- Error message if request failed

feature -- Status report

	is_success: BOOLEAN
			-- Was the request successful?

	is_error: BOOLEAN
			-- Did the request fail?
		do
			Result := not is_success
		ensure
			definition: Result = not is_success
		end

	has_embedding: BOOLEAN
			-- Is an embedding available?
		do
			Result := is_success and then attached embedding
		ensure
			definition: Result = (is_success and then attached embedding)
		end

feature -- Access: Safe

	embedding_or_default (a_default: AI_EMBEDDING): AI_EMBEDDING
			-- Return embedding if successful, otherwise `a_default'
		require
			default_attached: a_default /= Void
		do
			if attached embedding as l_emb then
				Result := l_emb
			else
				Result := a_default
			end
		ensure
			result_attached: Result /= Void
		end

invariant
	provider_attached: provider /= Void
	provider_not_empty: not provider.is_empty
	error_message_attached: error_message /= Void
	model_attached: model /= Void
	
	-- Success implies embedding exists
	success_has_embedding: is_success implies attached embedding
	
	-- Error implies no embedding and has message
	error_has_message: is_error implies not error_message.is_empty
	error_no_embedding: is_error implies embedding = Void
	
	-- Mutually exclusive states
	exclusive_states: is_success xor is_error

note
	copyright: "Copyright (c) 2025, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
