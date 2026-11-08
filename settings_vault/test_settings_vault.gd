extends SceneTree

## Automated Headless Unit Test Suite for SYS-12 (settings_vault)

const SettingsManager = preload("SettingsManager.gd")
const TEST_SETTINGS_FILE = "user://test_settings_temp.json"


func _init() -> void:
	print("\n========================================================")
	print("  RUNNING SETTINGS VAULT SYSTEM TESTS (SYS-12)")
	print("========================================================\n")

	_test_audio_settings()
	_test_display_settings()
	_test_input_serialization()
	_test_input_remapping()
	_test_json_save_and_reload()
	_test_reset_to_defaults()

	print("\n==> ALL Settings Vault Tests PASSED SUCCESSFULLY!")
	quit(0)


func _test_audio_settings() -> void:
	print("Test 1: Audio Volume & Mute Management...")
	var mgr = SettingsManager.new()
	mgr.settings_file_path = TEST_SETTINGS_FILE

	mgr.set_bus_volume("Master", 0.5)
	assert(is_equal_approx(mgr.get_bus_volume("Master"), 0.5), "Master volume should be 0.5")
	assert(mgr.is_bus_muted("Master") == false, "Master should not be muted")

	mgr.set_bus_mute("Master", true)
	assert(mgr.is_bus_muted("Master") == true, "Master should be muted")

	# Test clamping
	mgr.set_bus_volume("SFX", 1.5)
	assert(mgr.get_bus_volume("SFX") <= 1.0, "Volume should clamp to 1.0")

	mgr.set_bus_volume("BGM", -0.5)
	assert(mgr.get_bus_volume("BGM") >= 0.0, "Volume should clamp to 0.0")

	mgr.free()
	print("  ✔ Audio Settings passed")


func _test_display_settings() -> void:
	print("Test 2: Display Modes, Resolution, VSync & FPS...")
	var mgr = SettingsManager.new()

	mgr.set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert(mgr.display_settings["window_mode"] == DisplayServer.WINDOW_MODE_FULLSCREEN, "Window mode mismatch")

	var steam_deck_res = Vector2i(1280, 800)
	mgr.set_resolution(steam_deck_res)
	assert(mgr.display_settings["resolution"] == steam_deck_res, "Resolution mismatch for Steam Deck")

	mgr.set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	assert(mgr.display_settings["vsync_mode"] == DisplayServer.VSYNC_DISABLED, "VSync mode mismatch")

	mgr.set_target_fps(144)
	assert(mgr.display_settings["target_fps"] == 144, "Target FPS mismatch")
	assert(Engine.max_fps == 144, "Engine max_fps mismatch")

	mgr.set_ui_scale(1.25)
	assert(is_equal_approx(float(mgr.display_settings["ui_scale"]), 1.25), "UI scale mismatch")

	mgr.free()
	print("  ✔ Display Settings passed")


func _test_input_serialization() -> void:
	print("Test 3: InputEvent Serialization & Deserialization...")
	var key_event = InputEventKey.new()
	key_event.keycode = KEY_SPACE
	key_event.physical_keycode = KEY_SPACE
	key_event.ctrl_pressed = true
	key_event.shift_pressed = false

	var serialized = SettingsManager.serialize_input_event(key_event)
	assert(serialized["type"] == "key", "Serialized type should be key")
	assert(serialized["keycode"] == KEY_SPACE, "Serialized keycode mismatch")
	assert(serialized["ctrl"] == true, "Serialized ctrl modifier mismatch")

	var restored_key = SettingsManager.deserialize_input_event(serialized)
	assert(restored_key is InputEventKey, "Restored event should be InputEventKey")
	assert(restored_key.keycode == KEY_SPACE, "Restored keycode mismatch")
	assert(restored_key.ctrl_pressed == true, "Restored ctrl modifier mismatch")

	# Joypad Button
	var joy_event = InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_A
	joy_event.pressure = 1.0

	var joy_serialized = SettingsManager.serialize_input_event(joy_event)
	assert(joy_serialized["type"] == "joypad_button", "Serialized type should be joypad_button")
	assert(joy_serialized["button_index"] == JOY_BUTTON_A, "Serialized button_index mismatch")

	var restored_joy = SettingsManager.deserialize_input_event(joy_serialized)
	assert(restored_joy is InputEventJoypadButton, "Restored event should be InputEventJoypadButton")
	assert(restored_joy.button_index == JOY_BUTTON_A, "Restored joy button mismatch")
	print("  ✔ Input Serialization passed")


func _test_input_remapping() -> void:
	print("Test 4: InputMap Action Remapping...")
	var mgr = SettingsManager.new()
	var test_action = StringName("custom_test_jump")

	var key_f = InputEventKey.new()
	key_f.keycode = KEY_F

	var ok = mgr.rebind_action(test_action, key_f)
	assert(ok == true, "rebind_action should succeed")
	assert(InputMap.has_action(test_action), "InputMap should have action")

	var events = InputMap.action_get_events(test_action)
	assert(events.size() == 1, "Should have 1 event mapped")
	assert(events[0] is InputEventKey and events[0].keycode == KEY_F, "Action should be mapped to KEY_F")

	# Clean up action
	InputMap.erase_action(test_action)
	mgr.free()
	print("  ✔ Input Remapping passed")


func _test_json_save_and_reload() -> void:
	print("Test 5: Atomic JSON Save & Reload...")
	var mgr = SettingsManager.new()
	mgr.settings_file_path = TEST_SETTINGS_FILE

	mgr.set_bus_volume("Master", 0.42)
	mgr.set_bus_volume("SFX", 0.95)
	mgr.set_bus_mute("BGM", true)
	mgr.set_window_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	mgr.set_resolution(Vector2i(1920, 1080))
	mgr.set_target_fps(120)

	var saved = mgr.save_settings()
	assert(saved == true, "Save should succeed")
	assert(FileAccess.file_exists(TEST_SETTINGS_FILE), "Settings file should exist on disk")

	# New manager instance reading from file
	var loader = SettingsManager.new()
	loader.settings_file_path = TEST_SETTINGS_FILE
	var loaded = loader.load_settings()
	assert(loaded == true, "Load should succeed")

	assert(is_equal_approx(loader.get_bus_volume("Master"), 0.42), "Loaded Master volume mismatch")
	assert(is_equal_approx(loader.get_bus_volume("SFX"), 0.95), "Loaded SFX volume mismatch")
	assert(loader.is_bus_muted("BGM") == true, "Loaded BGM mute mismatch")
	assert(loader.display_settings["resolution"] == Vector2i(1920, 1080), "Loaded resolution mismatch")
	assert(loader.display_settings["target_fps"] == 120, "Loaded target FPS mismatch")

	# Clean up
	DirAccess.remove_absolute(TEST_SETTINGS_FILE)
	mgr.free()
	loader.free()
	print("  ✔ JSON Save & Reload passed")


func _test_reset_to_defaults() -> void:
	print("Test 6: Factory Reset to Defaults...")
	var mgr = SettingsManager.new()

	mgr.set_bus_volume("Master", 0.1)
	mgr.set_target_fps(30)
	mgr.reset_to_defaults()

	assert(is_equal_approx(mgr.get_bus_volume("Master"), 0.85), "Reset volume mismatch")
	assert(mgr.display_settings["target_fps"] == 60, "Reset target FPS mismatch")
	assert(mgr.display_settings["window_mode"] == DisplayServer.WINDOW_MODE_WINDOWED, "Reset window mode mismatch")

	mgr.free()
	print("  ✔ Reset to Defaults passed")
