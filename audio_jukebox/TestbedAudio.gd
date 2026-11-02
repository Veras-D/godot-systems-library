extends Control

const AudioManager = preload("AudioManager.gd")

@onready var bgm_status_lbl: Label = $MainBox/ContentBox/LeftCol/BgmPanel/Margin/VBox/StatusRow/StatusVal
@onready var bgm_track_option: OptionButton = $MainBox/ContentBox/LeftCol/BgmPanel/Margin/VBox/TrackRow/OptionButton
@onready var crossfade_slider: HSlider = $MainBox/ContentBox/LeftCol/BgmPanel/Margin/VBox/FadeRow/Slider
@onready var crossfade_lbl: Label = $MainBox/ContentBox/LeftCol/BgmPanel/Margin/VBox/FadeRow/ValLabel
@onready var play_bgm_btn: Button = $MainBox/ContentBox/LeftCol/BgmPanel/Margin/VBox/BtnRow/PlayBtn
@onready var stop_bgm_btn: Button = $MainBox/ContentBox/LeftCol/BgmPanel/Margin/VBox/BtnRow/StopBtn

@onready var pool_status_lbl: Label = $MainBox/ContentBox/LeftCol/SfxPanel/Margin/VBox/PoolStatusRow/PoolVal
@onready var pitch_var_check: CheckBox = $MainBox/ContentBox/LeftCol/SfxPanel/Margin/VBox/PitchCheck
@onready var sfx_btn_high: Button = $MainBox/ContentBox/LeftCol/SfxPanel/Margin/VBox/BtnGrid/BtnHigh
@onready var sfx_btn_mid: Button = $MainBox/ContentBox/LeftCol/SfxPanel/Margin/VBox/BtnGrid/BtnMid
@onready var sfx_btn_low: Button = $MainBox/ContentBox/LeftCol/SfxPanel/Margin/VBox/BtnGrid/BtnLow
@onready var sfx_btn_burst: Button = $MainBox/ContentBox/LeftCol/SfxPanel/Margin/VBox/BtnGrid/BtnBurst

@onready var master_slider: HSlider = $MainBox/ContentBox/RightCol/MixerPanel/Margin/VBox/MasterRow/Slider
@onready var master_val_lbl: Label = $MainBox/ContentBox/RightCol/MixerPanel/Margin/VBox/MasterRow/Val
@onready var music_slider: HSlider = $MainBox/ContentBox/RightCol/MixerPanel/Margin/VBox/MusicRow/Slider
@onready var music_val_lbl: Label = $MainBox/ContentBox/RightCol/MixerPanel/Margin/VBox/MusicRow/Val
@onready var sfx_slider: HSlider = $MainBox/ContentBox/RightCol/MixerPanel/Margin/VBox/SfxRow/Slider
@onready var sfx_val_lbl: Label = $MainBox/ContentBox/RightCol/MixerPanel/Margin/VBox/SfxRow/Val
@onready var mute_btn: Button = $MainBox/ContentBox/RightCol/MixerPanel/Margin/VBox/MuteBtn

@onready var log_label: RichTextLabel = $MainBox/ContentBox/RightCol/LogPanel/Margin/VBox/LogScroll/LogText

var audio: AudioManager
var _test_tracks: Array[Dictionary] = []
var _test_sfx: Dictionary = {}

func _ready() -> void:
	# Instantiate decoupled AudioManager
	audio = AudioManager.new()
	add_child(audio)

	# Connect audio manager signals
	audio.bgm_started.connect(_on_bgm_started)
	audio.bgm_crossfade_completed.connect(_on_bgm_crossfade_completed)
	audio.bgm_stopped.connect(_on_bgm_stopped)
	audio.sfx_played.connect(_on_sfx_played)

	# Generate procedural tracks for testing
	_setup_procedural_audio()

	# Connect UI controls
	play_bgm_btn.pressed.connect(_on_play_bgm_pressed)
	stop_bgm_btn.pressed.connect(_on_stop_bgm_pressed)
	crossfade_slider.value_changed.connect(_on_crossfade_slider_changed)

	sfx_btn_high.pressed.connect(func(): _play_test_sfx("high"))
	sfx_btn_mid.pressed.connect(func(): _play_test_sfx("mid"))
	sfx_btn_low.pressed.connect(func(): _play_test_sfx("low"))
	sfx_btn_burst.pressed.connect(_on_sfx_burst_pressed)

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	mute_btn.pressed.connect(_on_mute_pressed)

	_update_pool_label()
	_log("[color=#44ff88]Audio Jukebox Testbed Ready.[/color]")

func _setup_procedural_audio() -> void:
	_test_tracks = [
		{ "name": "BGM Track 1 (Chamber: 330 Hz)", "stream": AudioManager.create_tone_stream(330.0, 1.5) },
		{ "name": "BGM Track 2 (Battle: 440 Hz)", "stream": AudioManager.create_tone_stream(440.0, 1.5) },
		{ "name": "BGM Track 3 (Victory: 660 Hz)", "stream": AudioManager.create_tone_stream(660.0, 1.5) },
	]

	for i in range(_test_tracks.size()):
		bgm_track_option.add_item(_test_tracks[i].name, i)

	_test_sfx = {
		"high": AudioManager.create_tone_stream(880.0, 0.15),
		"mid": AudioManager.create_tone_stream(440.0, 0.15),
		"low": AudioManager.create_tone_stream(220.0, 0.20),
	}

func _on_play_bgm_pressed() -> void:
	var idx = bgm_track_option.selected
	if idx < 0 or idx >= _test_tracks.size():
		return
	var item = _test_tracks[idx]
	var fade = crossfade_slider.value
	_log("[color=#ffff66]▶ Switching BGM to: %s (Fade: %.1fs)[/color]" % [item.name, fade])
	audio.play_bgm(item.stream, fade)
	bgm_status_lbl.text = "Playing: %s" % item.name
	bgm_status_lbl.modulate = Color(0.3, 1.0, 0.4)

func _on_stop_bgm_pressed() -> void:
	var fade = crossfade_slider.value
	_log("[color=#ff6666]■ Stopping BGM (Fade: %.1fs)[/color]" % fade)
	audio.stop_bgm(fade)

func _on_crossfade_slider_changed(val: float) -> void:
	crossfade_lbl.text = "%.1fs" % val

func _play_test_sfx(key: String) -> void:
	var stream = _test_sfx.get(key)
	if not stream:
		return
	var use_pitch = pitch_var_check.button_pressed
	if use_pitch:
		audio.play_sfx_with_variation(stream, 0.0, 0.15)
	else:
		audio.play_sfx(stream, 0.0, 1.0)
	_update_pool_label()

func _on_sfx_burst_pressed() -> void:
	_log("[color=#ffaa33]💥 Playing 6 Rapid SFX (testing pool auto-expansion)...[/color]")
	for i in range(6):
		var key = ["high", "mid", "low"][i % 3]
		_play_test_sfx(key)
		await get_tree().create_timer(0.04).timeout
	_update_pool_label()

func _update_pool_label() -> void:
	if not audio:
		return
	var avail = audio.get_available_sfx_count()
	var total = audio.get_total_sfx_pool_size()
	pool_status_lbl.text = "%d / %d" % [avail, total]

func _on_master_changed(val: float) -> void:
	audio.set_master_volume(val)
	master_val_lbl.text = "%d%%" % int(val * 100)

func _on_music_changed(val: float) -> void:
	audio.set_music_volume(val)
	music_val_lbl.text = "%d%%" % int(val * 100)

func _on_sfx_changed(val: float) -> void:
	audio.set_sfx_volume(val)
	sfx_val_lbl.text = "%d%%" % int(val * 100)

func _on_mute_pressed() -> void:
	var is_muted = audio.is_bus_muted("Master")
	audio.set_bus_muted("Master", not is_muted)
	mute_btn.text = "Unmute Master" if not is_muted else "Mute Master"
	_log("[color=#cc88ff]Mute state changed: %s[/color]" % ("MUTED" if not is_muted else "UNMUTED"))

func _on_bgm_started(stream: AudioStream) -> void:
	_log("[color=#88ffaa]✓ BGM stream started.[/color]")

func _on_bgm_crossfade_completed(stream: AudioStream) -> void:
	_log("[color=#88ccff]✓ BGM crossfade completed.[/color]")

func _on_bgm_stopped() -> void:
	bgm_status_lbl.text = "Stopped"
	bgm_status_lbl.modulate = Color(0.7, 0.7, 0.7)
	_log("[color=#aaaaaa]BGM fully stopped.[/color]")

func _on_sfx_played(stream: AudioStream) -> void:
	_update_pool_label()

func _log(msg: String) -> void:
	var time_str = Time.get_time_string_from_system()
	log_label.append_text("[%s] %s\n" % [time_str, msg])
