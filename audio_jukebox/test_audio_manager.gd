extends SceneTree

const AudioManager = preload("AudioManager.gd")

func _init() -> void:
	print("==> Running AudioManager Unit & Regression Tests...")

	# 1. Instantiate AudioManager
	var audio_mgr: AudioManager = AudioManager.new()
	assert(audio_mgr != null, "AudioManager should instantiate")
	root.add_child(audio_mgr)
	await process_frame

	# 2. Test Audio Bus Setup
	assert(AudioServer.get_bus_index("Music") != -1, "Music bus must exist")
	assert(AudioServer.get_bus_index("SFX") != -1, "SFX bus must exist")
	print("Audio buses verified: Music and SFX active.")

	# 3. Test Volume Controls
	audio_mgr.set_master_volume(0.75)
	var v_master = audio_mgr.get_bus_volume_linear("Master")
	assert(abs(v_master - 0.75) < 0.05, "Master volume should be ~0.75")

	audio_mgr.set_music_volume(0.5)
	var v_music = audio_mgr.get_bus_volume_linear("Music")
	assert(abs(v_music - 0.5) < 0.05, "Music volume should be ~0.5")

	audio_mgr.set_sfx_volume(1.0)
	var v_sfx = audio_mgr.get_bus_volume_linear("SFX")
	assert(abs(v_sfx - 1.0) < 0.05, "SFX volume should be ~1.0")
	print("Volume setting and linear conversions verified.")

	# 4. Test Procedural Tone Generator
	var tone_a = AudioManager.create_tone_stream(440.0, 0.3)
	assert(tone_a != null, "Tone stream A should generate")
	assert(tone_a.data.size() > 0, "Tone stream A data must not be empty")

	var tone_b = AudioManager.create_tone_stream(880.0, 0.3)
	assert(tone_b != null, "Tone stream B should generate")

	# 5. Test BGM Playback & Crossfade
	var bgm_started_called = { "flag": false }
	audio_mgr.bgm_started.connect(func(_stream):
		bgm_started_called["flag"] = true
	)

	audio_mgr.play_bgm(tone_a, 0.1) # Fast 0.1s crossfade
	assert(audio_mgr.is_bgm_playing(), "BGM should be marked as playing")
	assert(audio_mgr.get_active_bgm() == tone_a, "Active BGM should be tone_a")
	assert(bgm_started_called["flag"], "bgm_started signal should fire")
	print("BGM playback started verified.")

	# Test crossfade to tone_b
	var crossfade_done = { "flag": false }
	audio_mgr.bgm_crossfade_completed.connect(func(_stream):
		crossfade_done["flag"] = true
	)
	audio_mgr.play_bgm(tone_b, 0.1)
	assert(audio_mgr.get_active_bgm() == tone_b, "Active BGM should now be tone_b")

	# Wait for crossfade completion
	var wait_timer = create_timer(0.2)
	while not crossfade_done["flag"] and wait_timer.time_left > 0.0:
		await process_frame

	assert(crossfade_done["flag"], "Crossfade completed signal should fire")
	print("BGM crossfade transition verified.")

	# Stop BGM
	var bgm_stopped_called = { "flag": false }
	audio_mgr.bgm_stopped.connect(func():
		bgm_stopped_called["flag"] = true
	)
	audio_mgr.stop_bgm(0.05)
	await create_timer(0.1).timeout
	assert(bgm_stopped_called["flag"], "bgm_stopped signal should fire")
	assert(not audio_mgr.is_bgm_playing(), "BGM should be stopped")
	print("BGM stop verified.")

	# 6. Test SFX Pooling & Dynamic Expansion
	var initial_pool_size = audio_mgr.get_total_sfx_pool_size()
	assert(initial_pool_size >= 8, "Initial pool size should be >= 8")
	var initial_available = audio_mgr.get_available_sfx_count()

	var sfx_tone = AudioManager.create_tone_stream(1200.0, 0.1)
	var player = audio_mgr.play_sfx(sfx_tone)
	assert(player != null, "SFX player should be returned")
	assert(audio_mgr.get_available_sfx_count() == initial_available - 1, "Available players should decrement by 1")

	# Test pool auto-expansion by playing more sounds than initial pool size
	var active_players: Array = []
	for i in range(initial_pool_size + 2):
		var p = audio_mgr.play_sfx(sfx_tone)
		active_players.append(p)

	assert(audio_mgr.get_total_sfx_pool_size() > initial_pool_size, "Pool should have auto-expanded")
	print("SFX pool dynamic expansion verified. New size: %d" % audio_mgr.get_total_sfx_pool_size())

	# Clean up
	for child in audio_mgr.get_children():
		child.free()
	audio_mgr.free()
	print("==> All AudioManager Unit & Regression Tests PASSED!")
	quit(0)
