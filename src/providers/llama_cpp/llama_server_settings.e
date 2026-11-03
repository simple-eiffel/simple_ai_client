note
	description: "[
		How to launch a local llama.cpp `llama-server': which executable,
		which GGUF model, and the options that decide whether the model
		fits on the GPU and how fast it runs.

		The server always listens on 127.0.0.1 only: a model server bound
		to every interface would answer anyone on the network.

		    l_settings: LLAMA_SERVER_SETTINGS
		    create l_settings.make ("D:\llama\llama-server.exe", "D:\models\swift.gguf")
		    l_settings.set_port (8790)
		    l_settings.set_context_size (0)        -- fit to free GPU memory
		    l_settings.set_kv_cache_type ("q8_0")
		    l_settings.enable_mtp (3)
		    -- l_settings.command_line is what LLAMA_SERVER runs.

		Every option has a default that reproduces a plain
		`llama-server -m MODEL --host 127.0.0.1 --port N -ngl 99 -c 4096',
		which is what RixQwen 1.0 ran.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LLAMA_SERVER_SETTINGS

create
	make

feature {NONE} -- Initialization

	make (a_server_exe, a_model_path: READABLE_STRING_GENERAL)
			-- Settings that run `a_server_exe' over the GGUF at `a_model_path'.
		require
			server_exe_not_empty: not a_server_exe.is_empty
			model_path_not_empty: not a_model_path.is_empty
			server_exe_has_no_quote: not a_server_exe.has ('"')
			model_path_has_no_quote: not a_model_path.has ('"')
		do
			server_exe := a_server_exe.to_string_32
			model_path := a_model_path.to_string_32
			port := Default_port
			context_size := Default_context_size
			gpu_layers := Default_gpu_layers
			kv_cache_type := Default_kv_cache_type
			flash_attention := Flash_auto
			slot_count := 1
			mtp_draft_max := 0
		ensure
			server_exe_set: server_exe.same_string_general (a_server_exe)
			model_path_set: model_path.same_string_general (a_model_path)
			default_port: port = Default_port
			default_context: context_size = Default_context_size
			default_layers: gpu_layers = Default_gpu_layers
			default_cache: kv_cache_type.same_string (Default_kv_cache_type)
			default_flash: flash_attention.same_string (Flash_auto)
			one_slot: slot_count = 1
			no_mtp: not uses_mtp
		end

feature -- Access

	server_exe: STRING_32
			-- Path to llama-server.exe.

	model_path: STRING_32
			-- Path to the GGUF weights.

	host: STRING_32
			-- Interface the server listens on: always the loopback.
		once
			Result := {STRING_32} "127.0.0.1"
		ensure
			loopback: Result.same_string ({STRING_32} "127.0.0.1")
		end

	port: INTEGER
			-- Localhost port.

	context_size: INTEGER
			-- Context window in tokens ("-c"); 0 lets llama.cpp fit the
			-- largest window the GPU's free memory allows (see `fits_to_memory').

	gpu_layers: INTEGER
			-- Layers offloaded to the GPU ("-ngl"); 99 means all of them.
			-- Not sent when `fits_to_memory': llama.cpp's fit gives up when
			-- the layer count is set by hand.

	kv_cache_type: STRING_32
			-- Data type of the attention cache, for both K and V ("-ctk", "-ctv").
			-- "q8_0" halves the cache's memory against "f16" at a small cost.

	flash_attention: STRING_32
			-- "on", "off" or "auto" ("-fa").

	slot_count: INTEGER
			-- Parallel conversations the server holds ("-np"). Each slot
			-- gets its own share of `context_size', so one slot gives a
			-- single user the whole window.

	mtp_draft_max: INTEGER
			-- Tokens the model's multi-token-prediction head drafts per
			-- step; 0 when MTP is off.

	base_url: STRING_32
			-- Root URL of the server these settings describe.
		do
			Result := {STRING_32} "http://" + host + {STRING_32} ":" + port.out
		ensure
			loopback_url: Result.starts_with ({STRING_32} "http://127.0.0.1:")
		end

	command_line: STRING_32
			-- The command that starts the server.
		do
			create Result.make (300)
			Result.append_character ('"')
			Result.append (server_exe)
			Result.append ({STRING_32} "%" -m %"")
			Result.append (model_path)
			Result.append ({STRING_32} "%" --host ")
			Result.append (host)
			Result.append ({STRING_32} " --port ")
			Result.append (port.out)
			if not fits_to_memory then
				Result.append ({STRING_32} " -ngl ")
				Result.append (gpu_layers.out)
				Result.append ({STRING_32} " -c ")
				Result.append (context_size.out)
			end
			Result.append ({STRING_32} " -np ")
			Result.append (slot_count.out)
			if not flash_attention.same_string (Flash_auto) then
				Result.append ({STRING_32} " -fa ")
				Result.append (flash_attention)
			end
			if not kv_cache_type.same_string (Default_kv_cache_type) then
				Result.append ({STRING_32} " -ctk ")
				Result.append (kv_cache_type)
				Result.append ({STRING_32} " -ctv ")
				Result.append (kv_cache_type)
			end
			if uses_mtp then
				Result.append ({STRING_32} " --spec-type draft-mtp --spec-draft-n-max ")
				Result.append (mtp_draft_max.out)
			end
		ensure
			starts_with_server: Result.starts_with ({STRING_32} "%"" + server_exe + {STRING_32} "%"")
			names_model: Result.has_substring ({STRING_32} "-m %"" + model_path + {STRING_32} "%"")
			loopback_only: Result.has_substring ({STRING_32} "--host 127.0.0.1 ")
			names_port: Result.has_substring ({STRING_32} "--port " + port.out + {STRING_32} " ")
			names_context_unless_fitting: not fits_to_memory implies Result.has_substring ({STRING_32} " -c " + context_size.out + {STRING_32} " ")
			fitting_leaves_size_unset: fits_to_memory implies not Result.has_substring ({STRING_32} " -c ")
			mtp_iff_enabled: Result.has_substring ({STRING_32} "draft-mtp") = uses_mtp
			cache_iff_changed: Result.has_substring ({STRING_32} " -ctk ") = not kv_cache_type.same_string (Default_kv_cache_type)
		end

feature -- Status report

	fits_to_memory: BOOLEAN
			-- Does llama.cpp choose the context (and layers) to fit free GPU
			-- memory with a 1 GB margin? (Its "--fit", on by default, works
			-- only while "-c" and "-ngl" are unset.) Measured 2026-11-03 on
			-- the RTX 5070 Ti: a hand-set 110,000 window over-filled the card
			-- and Windows spilled into system memory - 11 tokens/s against 87.
		do
			Result := context_size = 0
		ensure
			definition: Result = (context_size = 0)
		end

	uses_mtp: BOOLEAN
			-- Is multi-token-prediction drafting on?
		do
			Result := mtp_draft_max > 0
		ensure
			definition: Result = (mtp_draft_max > 0)
		end

	is_valid_cache_type (a_type: READABLE_STRING_GENERAL): BOOLEAN
			-- Is `a_type' a cache type llama-server accepts?
		do
			Result := across Cache_types as ic some ic.same_string_general (a_type) end
		end

	is_valid_flash_mode (a_mode: READABLE_STRING_GENERAL): BOOLEAN
			-- Is `a_mode' one of "on", "off", "auto"?
		do
			Result := a_mode.same_string (Flash_on) or a_mode.same_string (Flash_off) or a_mode.same_string (Flash_auto)
		end

feature -- Element change

	set_port (a_port: INTEGER)
			-- Listen on `a_port'.
		require
			user_port: a_port >= 1024 and a_port <= 65535
		do
			port := a_port
		ensure
			set: port = a_port
		end

	set_context_size (a_tokens: INTEGER)
			-- Use a context window of `a_tokens' (0: largest that fits).
		require
			non_negative: a_tokens >= 0
		do
			context_size := a_tokens
		ensure
			set: context_size = a_tokens
		end

	set_gpu_layers (a_layers: INTEGER)
			-- Offload `a_layers' layers to the GPU.
		require
			non_negative: a_layers >= 0
		do
			gpu_layers := a_layers
		ensure
			set: gpu_layers = a_layers
		end

	set_kv_cache_type (a_type: READABLE_STRING_GENERAL)
			-- Store the attention cache as `a_type'.
		require
			valid: is_valid_cache_type (a_type)
		do
			kv_cache_type := a_type.to_string_32
		ensure
			set: kv_cache_type.same_string_general (a_type)
		end

	set_flash_attention (a_mode: READABLE_STRING_GENERAL)
			-- Use flash attention mode `a_mode'.
		require
			valid: is_valid_flash_mode (a_mode)
		do
			flash_attention := a_mode.to_string_32
		ensure
			set: flash_attention.same_string_general (a_mode)
		end

	set_slot_count (a_slots: INTEGER)
			-- Hold `a_slots' parallel conversations.
		require
			at_least_one: a_slots >= 1
		do
			slot_count := a_slots
		ensure
			set: slot_count = a_slots
		end

	enable_mtp (a_draft_max: INTEGER)
			-- Draft `a_draft_max' tokens per step with the model's MTP head.
			-- The GGUF must carry one (an "-mtp" build).
		require
			positive: a_draft_max >= 1
			sensible: a_draft_max <= 8
		do
			mtp_draft_max := a_draft_max
		ensure
			on: uses_mtp
			set: mtp_draft_max = a_draft_max
		end

	disable_mtp
			-- Decode one token at a time.
		do
			mtp_draft_max := 0
		ensure
			off: not uses_mtp
		end

feature -- Constants

	Default_port: INTEGER = 8737
			-- RixQwen's port.

	Default_context_size: INTEGER = 4096
			-- RixQwen 1.0's window.

	Default_gpu_layers: INTEGER = 99
			-- Everything on the GPU.

	Default_kv_cache_type: STRING_32 = "f16"
			-- llama-server's own default.

	Flash_on: STRING_32 = "on"
	Flash_off: STRING_32 = "off"
	Flash_auto: STRING_32 = "auto"

	Cache_types: ARRAY [STRING_32]
			-- The cache types llama-server (build 12069) accepts.
		once
			Result := <<{STRING_32} "f32", {STRING_32} "f16", {STRING_32} "bf16", {STRING_32} "q8_0",
				{STRING_32} "q4_0", {STRING_32} "q4_1", {STRING_32} "iq4_nl", {STRING_32} "q5_0", {STRING_32} "q5_1">>
		end

invariant
	server_exe_not_empty: not server_exe.is_empty
	model_path_not_empty: not model_path.is_empty
	port_in_user_range: port >= 1024 and port <= 65535
	context_non_negative: context_size >= 0
	layers_non_negative: gpu_layers >= 0
	cache_type_valid: is_valid_cache_type (kv_cache_type)
	flash_mode_valid: is_valid_flash_mode (flash_attention)
	slots_positive: slot_count >= 1
	mtp_non_negative: mtp_draft_max >= 0

note
	copyright: "Copyright (c) 2026, Larry Rix"
	license: "MIT License"
	source: "SIMPLE_AI_CLIENT - Unified AI Provider Library"

end
