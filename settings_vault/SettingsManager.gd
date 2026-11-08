# SettingsManager.gd
# Standalone Universal Settings & Preferences Manager for Godot 4.x.
# Handles Audio Bus volumes (linear/dB), Display modes, VSync, FPS limits, and Input Remapping.
class_name SettingsManager
extends Node

const DEFAULT_SETTINGS_PATH: String = "user://settings.json"

signal audio_setting_changed(bus_name: String, volume_linear: float, is_muted: bool)
signal display_setting_changed(setting_name: String, value: Variant)
signal control_rebound(action_name: StringName, event: InputEvent)
signal settings_saved(path: String)
signal settings_loaded(path: String)
signal settings_reset

# Standard Supported Resolutions
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),   # 720p 16:9
	Vector2i(1280, 800),   # Steam Deck 16:10
	Vector2i(1600, 900),   # 900p 16:9
	Vector2i(1920, 1080),  # 1080p Full HD
	Vector2i(2560, 1440),  # 1440p 2K
	Vector2i(3840, 2160)   # 4K Ultra HD
]

# Audio State
var audio_settings: Dictionary = {
	"Master": {"volume": 0.8, "muted": false},
	"BGM": {"volume": 0.8, "muted": false},
	"SFX": {"volume": 0.85, "muted": false},
	"VO": {"volume": 0.9, "muted": false}
}

# Display State
var display_settings: Dictionary = {
	"window_mode": DisplayServer.WINDOW_MODE_WINDOWED,
	"resolution": Vector2i(1280, 720),
	"vsync_mode": DisplayServer.VSYNC_ENABLED,
	"target_fps": 60,
	"ui_scale": 1.0
}

# Keybinding Remappings: action_name -> Dictionary
var custom_keybindings: Dictionary = {}
var _default_keybindings: Dictionary = {}

var settings_file_path: String = DEFAULT_SETTINGS_PATH


func _ready() -> void:
	_backup_default_keybindings()


## Backs up default action bindings on startup so they can be restored later.
func _backup_default_keybindings() -> void:
	_default_keybindings.clear()
	for action in InputMap.get_actions():
		if action.begins_with("ui_") or action.begins_with("spatial_"):
			continue
		var events = InputMap.action_get_events(action)
		var list: Array[Dictionary] = []
		for ev in events:
			var serialized = serialize_input_event(ev)
			if not serialized.is_empty():
				list.append(serialized)
		if not list.is_empty():
			_default_keybindings[str(action)] = list


# ==============================================================================
# AUDIO BUS SETTINGS
# ==============================================================================

## Sets audio bus volume linearly [0.0 - 1.0] and applies decibels to AudioServer.
func set_bus_volume(bus_name: String, linear_volume: float) -> void:
	linear_volume = clampf(linear_volume, 0.0, 1.0)
	var bus_data = audio_settings.get(bus_name, {"volume": 0.8, "muted": false})
	bus_data["volume"] = linear_volume
	audio_settings[bus_name] = bus_data

	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		if linear_volume <= 0.001 or bus_data.get("muted", false):
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			var db_vol = linear_to_db(linear_volume)
			AudioServer.set_bus_volume_db(bus_idx, db_vol)

	audio_setting_changed.emit(bus_name, linear_volume, bus_data.get("muted", false))


func set_bus_mute(bus_name: String, is_muted: bool) -> void:
	var bus_data = audio_settings.get(bus_name, {"volume": 0.8, "muted": false})
	bus_data["muted"] = is_muted
	audio_settings[bus_name] = bus_data

	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, is_muted or float(bus_data.get("volume", 0.8)) <= 0.001)

	audio_setting_changed.emit(bus_name, float(bus_data.get("volume", 0.8)), is_muted)


func get_bus_volume(bus_name: String) -> float:
	if audio_settings.has(bus_name):
		return float(audio_settings[bus_name].get("volume", 0.8))
	return 0.8


func is_bus_muted(bus_name: String) -> bool:
	if audio_settings.has(bus_name):
		return bool(audio_settings[bus_name].get("muted", false))
	return false


# ==============================================================================
# DISPLAY & GRAPHICS SETTINGS
# ==============================================================================

## Sets window mode (WINDOWED, FULLSCREEN, EXCLUSIVE_FULLSCREEN, MAXIMIZED).
func set_window_mode(mode: int) -> void:
	display_settings["window_mode"] = mode
	if OS.has_feature("standalone") or not Engine.is_editor_hint():
		DisplayServer.window_set_mode(mode as DisplayServer.WindowMode)
	display_setting_changed.emit("window_mode", mode)


## Sets window size resolution (e.g. 1920x1080 or 1280x800).
func set_resolution(res: Vector2i) -> void:
	display_settings["resolution"] = res
	if display_settings["window_mode"] == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(res)
		# Re-center window on screen
		var screen_id = DisplayServer.window_get_current_screen()
		var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
		var new_pos = screen_rect.position + (screen_rect.size - res) / 2
		DisplayServer.window_set_position(new_pos)
	display_setting_changed.emit("resolution", res)


## Sets V-Sync mode (DISABLED, ENABLED, ADAPTIVE, MAILBOX).
func set_vsync_mode(mode: int) -> void:
	display_settings["vsync_mode"] = mode
	DisplayServer.window_set_vsync_mode(mode as DisplayServer.VSyncMode)
	display_setting_changed.emit("vsync_mode", mode)


## Sets target framerate limit (0 for unlimited).
func set_target_fps(fps: int) -> void:
	display_settings["target_fps"] = fps
	Engine.max_fps = fps
	display_setting_changed.emit("target_fps", fps)


## Sets UI / Canvas scale factor.
func set_ui_scale(scale_factor: float) -> void:
	scale_factor = clampf(scale_factor, 0.5, 3.0)
	display_settings["ui_scale"] = scale_factor
	display_setting_changed.emit("ui_scale", scale_factor)


# ==============================================================================
# INPUT REMAPPING
# ==============================================================================

## Rebinds an action to a new InputEventKey or InputEventJoypadButton.
func rebind_action(action_name: StringName, event: InputEvent) -> bool:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	# Serialize before altering
	var serialized = serialize_input_event(event)
	if serialized.is_empty():
		return false

	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, event)
	custom_keybindings[str(action_name)] = serialized
	control_rebound.emit(action_name, event)
	return true


## Resets all keybindings to startup defaults.
func reset_controls_to_defaults() -> void:
	custom_keybindings.clear()
	for action_str in _default_keybindings.keys():
		var action_name = StringName(action_str)
		if InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
			var events_data = _default_keybindings[action_str]
			for ev_data in events_data:
				var ev = deserialize_input_event(ev_data)
				if ev:
					InputMap.action_add_event(action_name, ev)


# ==============================================================================
# SERIALIZATION & PERSISTENCE
# ==============================================================================

## Saves current configuration to JSON.
func save_settings(path: String = "") -> bool:
	if path.is_empty():
		path = settings_file_path

	var full_dict = {
		"version": 1,
		"audio": audio_settings,
		"display": {
			"window_mode": display_settings["window_mode"],
			"res_x": display_settings["resolution"].x,
			"res_y": display_settings["resolution"].y,
			"vsync_mode": display_settings["vsync_mode"],
			"target_fps": display_settings["target_fps"],
			"ui_scale": display_settings["ui_scale"]
		},
		"controls": custom_keybindings
	}

	var json_str = JSON.stringify(full_dict, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_warning("SettingsManager: Failed to open %s for write." % path)
		return false

	file.store_string(json_str)
	file.close()
	settings_saved.emit(path)
	return true


## Loads configuration from JSON and applies all audio/display/controls parameters.
func load_settings(path: String = "") -> bool:
	if path.is_empty():
		path = settings_file_path

	if not FileAccess.file_exists(path):
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false

	var content = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if not (parsed is Dictionary):
		return false

	# 1. Apply Audio
	if parsed.has("audio") and parsed["audio"] is Dictionary:
		var a_data = parsed["audio"]
		for bus_name in a_data.keys():
			var b = a_data[bus_name]
			if b is Dictionary:
				var vol = float(b.get("volume", 0.8))
				var muted = bool(b.get("muted", false))
				set_bus_volume(bus_name, vol)
				set_bus_mute(bus_name, muted)

	# 2. Apply Display
	if parsed.has("display") and parsed["display"] is Dictionary:
		var d = parsed["display"]
		if d.has("window_mode"):
			set_window_mode(int(d["window_mode"]))
		if d.has("res_x") and d.has("res_y"):
			set_resolution(Vector2i(int(d["res_x"]), int(d["res_y"])))
		if d.has("vsync_mode"):
			set_vsync_mode(int(d["vsync_mode"]))
		if d.has("target_fps"):
			set_target_fps(int(d["target_fps"]))
		if d.has("ui_scale"):
			set_ui_scale(float(d["ui_scale"]))

	# 3. Apply Controls
	if parsed.has("controls") and parsed["controls"] is Dictionary:
		custom_keybindings = parsed["controls"].duplicate(true)
		for action_str in custom_keybindings.keys():
			var action_name = StringName(action_str)
			var ev = deserialize_input_event(custom_keybindings[action_str])
			if ev:
				if not InputMap.has_action(action_name):
					InputMap.add_action(action_name)
				InputMap.action_erase_events(action_name)
				InputMap.action_add_event(action_name, ev)

	settings_loaded.emit(path)
	return true


## Resets all audio, display, and input settings to factory defaults.
func reset_to_defaults() -> void:
	for bus in ["Master", "BGM", "SFX", "VO"]:
		set_bus_volume(bus, 0.85)
		set_bus_mute(bus, false)

	set_window_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	set_resolution(Vector2i(1280, 720))
	set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	set_target_fps(60)
	set_ui_scale(1.0)
	reset_controls_to_defaults()

	settings_reset.emit()


# ==============================================================================
# INPUT EVENT SERIALIZATION HELPERS
# ==============================================================================

static func serialize_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {
			"type": "key",
			"keycode": event.keycode,
			"physical_keycode": event.physical_keycode,
			"unicode": event.unicode,
			"ctrl": event.ctrl_pressed,
			"shift": event.shift_pressed,
			"alt": event.alt_pressed
		}
	elif event is InputEventJoypadButton:
		return {
			"type": "joypad_button",
			"button_index": event.button_index,
			"pressure": event.pressure
		}
	return {}


static func deserialize_input_event(data: Dictionary) -> InputEvent:
	var t = str(data.get("type", ""))
	if t == "key":
		var ev = InputEventKey.new()
		ev.keycode = int(data.get("keycode", 0)) as Key
		ev.physical_keycode = int(data.get("physical_keycode", 0)) as Key
		ev.unicode = int(data.get("unicode", 0))
		ev.ctrl_pressed = bool(data.get("ctrl", false))
		ev.shift_pressed = bool(data.get("shift", false))
		ev.alt_pressed = bool(data.get("alt", false))
		return ev
	elif t == "joypad_button":
		var ev = InputEventJoypadButton.new()
		ev.button_index = int(data.get("button_index", 0)) as JoyButton
		ev.pressure = float(data.get("pressure", 1.0))
		return ev
	return null
