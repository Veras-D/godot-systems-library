class_name AudioManager
extends Node

# Universal Audio Jukebox System
# Completely decoupled audio manager featuring:
# - Dual-player seamless BGM crossfading
# - Zero-allocation SFX player pooling with dynamic expansion
# - Audio bus volume management (linear <-> dB)
# - Procedural test-tone generator for isolated testbed usage

signal bgm_started(stream: AudioStream)
signal bgm_crossfade_completed(stream: AudioStream)
signal bgm_stopped
signal sfx_played(stream: AudioStream)

@export var sfx_pool_size: int = 8
@export var default_crossfade_sec: float = 1.0

var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _active_bgm: AudioStreamPlayer
var _inactive_bgm: AudioStreamPlayer
var _bgm_tween: Tween

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_available: Array[AudioStreamPlayer] = []

var _bus_music_name: String = "Master"
var _bus_sfx_name: String = "Master"
var _bus_voice_name: String = "Master"
var _voice_player: AudioStreamPlayer = null

func _init() -> void:
	_setup_buses()

func _ready() -> void:
	if _bgm_a == null:
		_setup_bgm_players()
	if _sfx_pool.is_empty():
		_setup_sfx_pool()
	if _voice_player == null:
		_setup_voice_player()

func _setup_buses() -> void:
	# Check if dedicated buses exist; if not, create them or fall back to Master
	if AudioServer.get_bus_index("Music") != -1:
		_bus_music_name = "Music"
	elif AudioServer.get_bus_index("BGM") != -1:
		_bus_music_name = "BGM"
	else:
		# Auto-create Music bus routed to Master
		var bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "Music")
		AudioServer.set_bus_send(bus_idx, "Master")
		_bus_music_name = "Music"

	if AudioServer.get_bus_index("SFX") != -1:
		_bus_sfx_name = "SFX"
	else:
		# Auto-create SFX bus routed to Master
		var bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "SFX")
		AudioServer.set_bus_send(bus_idx, "Master")
		_bus_sfx_name = "SFX"

	if AudioServer.get_bus_index("Voice") != -1:
		_bus_voice_name = "Voice"
	elif AudioServer.get_bus_index("VO") != -1:
		_bus_voice_name = "VO"
	else:
		# Auto-create Voice bus routed to Master
		var bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "Voice")
		AudioServer.set_bus_send(bus_idx, "Master")
		_bus_voice_name = "Voice"

func _setup_voice_player() -> void:
	if _voice_player == null:
		_voice_player = AudioStreamPlayer.new()
		_voice_player.name = "Voice_Player"
		_voice_player.bus = _bus_voice_name
		add_child(_voice_player)

func _setup_bgm_players() -> void:
	_bgm_a = AudioStreamPlayer.new()
	_bgm_a.name = "BGM_A"
	_bgm_a.bus = _bus_music_name
	_bgm_a.finished.connect(_on_bgm_finished.bind(_bgm_a))
	add_child(_bgm_a)

	_bgm_b = AudioStreamPlayer.new()
	_bgm_b.name = "BGM_B"
	_bgm_b.bus = _bus_music_name
	_bgm_b.finished.connect(_on_bgm_finished.bind(_bgm_b))
	add_child(_bgm_b)

	_active_bgm = _bgm_a
	_inactive_bgm = _bgm_b

func _on_bgm_finished(player: AudioStreamPlayer) -> void:
	if player == _active_bgm and player.stream != null:
		player.play()

func _setup_sfx_pool() -> void:
	for i in range(sfx_pool_size):
		_add_sfx_player()

func _add_sfx_player() -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.name = "SFX_Player_%d" % _sfx_pool.size()
	p.bus = _bus_sfx_name
	add_child(p)
	_sfx_pool.append(p)
	_sfx_available.append(p)
	p.finished.connect(_on_sfx_finished.bind(p))
	return p

func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	player.stream = null
	if not player in _sfx_available:
		_sfx_available.append(player)

# ==============================================================================
# BGM Playback & Crossfading
# ==============================================================================

func play_bgm(stream: AudioStream, crossfade_sec: float = -1.0) -> void:
	if stream == null:
		stop_bgm(crossfade_sec)
		return

	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		stream.loop = true

	if _active_bgm.stream == stream and _active_bgm.playing:
		return

	var fade_time = default_crossfade_sec if crossfade_sec < 0.0 else crossfade_sec

	if _bgm_tween and _bgm_tween.is_running():
		_bgm_tween.kill()

	# If nothing is currently playing or fade_time is near zero, play instantly
	if not _active_bgm.playing or fade_time <= 0.05:
		_active_bgm.stop()
		_active_bgm.stream = stream
		_active_bgm.volume_db = 0.0
		_active_bgm.play()
		bgm_started.emit(stream)
		return

	# Swap active and inactive players for smooth crossfade
	var old_player = _active_bgm
	_active_bgm = _inactive_bgm
	_inactive_bgm = old_player

	_active_bgm.stream = stream
	_active_bgm.volume_db = -80.0
	_active_bgm.play()
	bgm_started.emit(stream)

	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.tween_property(_inactive_bgm, "volume_db", -80.0, fade_time)
	_bgm_tween.tween_property(_active_bgm, "volume_db", 0.0, fade_time)

	_bgm_tween.chain().tween_callback(func():
		_inactive_bgm.stop()
		_inactive_bgm.stream = null
		bgm_crossfade_completed.emit(_active_bgm.stream)
	)

func stop_bgm(fade_out_sec: float = -1.0) -> void:
	var fade_time = default_crossfade_sec if fade_out_sec < 0.0 else fade_out_sec

	if not _active_bgm.playing:
		return

	if _bgm_tween and _bgm_tween.is_running():
		_bgm_tween.kill()

	if fade_time <= 0.05:
		_active_bgm.stop()
		_active_bgm.stream = null
		bgm_stopped.emit()
		return

	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_active_bgm, "volume_db", -80.0, fade_time)
	_bgm_tween.tween_callback(func():
		_active_bgm.stop()
		_active_bgm.stream = null
		bgm_stopped.emit()
	)

func get_active_bgm() -> AudioStream:
	if _active_bgm and _active_bgm.playing:
		return _active_bgm.stream
	return null

func is_bgm_playing() -> bool:
	return _active_bgm != null and _active_bgm.playing

# ==============================================================================
# SFX Playback & Pooling
# ==============================================================================

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if stream == null:
		return null

	if _sfx_available.is_empty():
		# Dynamically expand pool by 4 players when capacity is exhausted
		for i in range(4):
			_add_sfx_player()

	var player = _sfx_available.pop_back()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

	sfx_played.emit(stream)
	return player

func play_sfx_with_variation(stream: AudioStream, volume_db: float = 0.0, pitch_variance: float = 0.1) -> AudioStreamPlayer:
	var pitch = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	return play_sfx(stream, volume_db, pitch)

func get_available_sfx_count() -> int:
	return _sfx_available.size()

func get_total_sfx_pool_size() -> int:
	return _sfx_pool.size()

# ==============================================================================
# Voice Playback (Dedicated Voice Bus)
# ==============================================================================

func play_voice(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	if _voice_player == null:
		_setup_voice_player()

	_voice_player.stop()
	_voice_player.stream = stream
	_voice_player.volume_db = volume_db
	_voice_player.pitch_scale = pitch_scale
	_voice_player.play()
	return _voice_player

func stop_voice() -> void:
	if _voice_player and _voice_player.playing:
		_voice_player.stop()
		_voice_player.stream = null

func is_voice_playing() -> bool:
	return _voice_player != null and _voice_player.playing

# ==============================================================================
# Volume & Bus Controls (0.0 to 1.0 linear, converted to dB)
# ==============================================================================

func set_bus_volume_linear(bus_name: String, linear: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var clamped = clampf(linear, 0.0, 1.0)
	var db = linear_to_db(clamped) if clamped > 0.001 else -80.0
	AudioServer.set_bus_volume_db(idx, db)

func get_bus_volume_linear(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	var db = AudioServer.get_bus_volume_db(idx)
	return db_to_linear(db)

func set_bus_muted(bus_name: String, muted: bool) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)

func is_bus_muted(bus_name: String) -> bool:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return AudioServer.is_bus_mute(idx)
	return false

func set_master_volume(linear: float) -> void:
	set_bus_volume_linear("Master", linear)

func get_master_volume() -> float:
	return get_bus_volume_linear("Master")

func set_music_volume(linear: float) -> void:
	set_bus_volume_linear(_bus_music_name, linear)

func get_music_volume() -> float:
	return get_bus_volume_linear(_bus_music_name)

func set_sfx_volume(linear: float) -> void:
	set_bus_volume_linear(_bus_sfx_name, linear)

func get_sfx_volume() -> float:
	return get_bus_volume_linear(_bus_sfx_name)

func set_voice_volume(linear: float) -> void:
	set_bus_volume_linear(_bus_voice_name, linear)

func get_voice_volume() -> float:
	return get_bus_volume_linear(_bus_voice_name)

# ==============================================================================
# Procedural Audio Synthesizer (Zero-dependency test tones & beeps)
# ==============================================================================

static func create_tone_stream(freq_hz: float = 440.0, duration_sec: float = 0.2, sample_rate: int = 22050) -> AudioStreamWAV:
	var num_samples = int(duration_sec * sample_rate)
	var data = PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		# Smooth attack/decay envelope to prevent clicks
		var env = 1.0
		var attack_samples = int(0.01 * sample_rate)
		var release_samples = int(0.02 * sample_rate)
		if i < attack_samples:
			env = float(i) / float(attack_samples)
		elif i > num_samples - release_samples:
			env = float(num_samples - i) / float(release_samples)

		var sample = sin(2.0 * PI * freq_hz * t) * env
		# 8-bit unsigned PCM: 128 is center
		var val = int(clampf(sample * 120.0 + 128.0, 0.0, 255.0))
		data[i] = val

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
