# TestbedSettings.gd
# Interactive testbed for SYS-12 (settings_vault).
extends Control

const SettingsManagerClass = preload("SettingsManager.gd")

@onready var manager: SettingsManager = $SettingsManager

# Audio UI
@onready var master_slider: HSlider = %MasterSlider
@onready var master_label: Label = %MasterLabel
@onready var master_mute_check: CheckBox = %MasterMuteCheck

@onready var bgm_slider: HSlider = %BgmSlider
@onready var bgm_label: Label = %BgmLabel
@onready var bgm_mute_check: CheckBox = %BgmMuteCheck

@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_label: Label = %SfxLabel
@onready var sfx_mute_check: CheckBox = %SfxMuteCheck

@onready var vo_slider: HSlider = %VoSlider
@onready var vo_label: Label = %VoLabel
@onready var vo_mute_check: CheckBox = %VoMuteCheck

# Display UI
@onready var mode_option: OptionButton = %ModeOption
@onready var res_option: OptionButton = %ResOption
@onready var vsync_option: OptionButton = %VsyncOption
@onready var fps_option: OptionButton = %FpsOption
@onready var scale_slider: HSlider = %ScaleSlider
@onready var scale_label: Label = %ScaleLabel

# Action Bar
@onready var save_btn: Button = %SaveBtn
@onready var load_btn: Button = %LoadBtn
@onready var reset_btn: Button = %ResetBtn
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	_setup_options()
	_connect_events()
	_sync_ui_from_manager()
	status_label.text = "Settings Vault ready."


func _setup_options() -> void:
	# Window Mode
	mode_option.clear()
	mode_option.add_item("Windowed", DisplayServer.WINDOW_MODE_WINDOWED)
	mode_option.add_item("Fullscreen", DisplayServer.WINDOW_MODE_FULLSCREEN)
	mode_option.add_item("Exclusive Fullscreen", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	mode_option.add_item("Maximized", DisplayServer.WINDOW_MODE_MAXIMIZED)

	# Resolutions
	res_option.clear()
	for i in range(SettingsManagerClass.RESOLUTIONS.size()):
		var r = SettingsManagerClass.RESOLUTIONS[i]
		var tag = " (Steam Deck)" if r == Vector2i(1280, 800) else ""
		res_option.add_item("%dx%d%s" % [r.x, r.y, tag], i)

	# VSync
	vsync_option.clear()
	vsync_option.add_item("Disabled", DisplayServer.VSYNC_DISABLED)
	vsync_option.add_item("Enabled", DisplayServer.VSYNC_ENABLED)
	vsync_option.add_item("Adaptive", DisplayServer.VSYNC_ADAPTIVE)
	vsync_option.add_item("Mailbox", DisplayServer.VSYNC_MAILBOX)

	# Target FPS
	fps_option.clear()
	fps_option.add_item("30 FPS", 30)
	fps_option.add_item("60 FPS", 60)
	fps_option.add_item("120 FPS", 120)
	fps_option.add_item("144 FPS", 144)
	fps_option.add_item("Unlimited", 0)


func _connect_events() -> void:
	master_slider.value_changed.connect(func(v):
		manager.set_bus_volume("Master", v)
		master_label.text = "%d%%" % int(v * 100)
	)
	master_mute_check.toggled.connect(func(m):
		manager.set_bus_mute("Master", m)
	)

	bgm_slider.value_changed.connect(func(v):
		manager.set_bus_volume("BGM", v)
		bgm_label.text = "%d%%" % int(v * 100)
	)
	bgm_mute_check.toggled.connect(func(m):
		manager.set_bus_mute("BGM", m)
	)

	sfx_slider.value_changed.connect(func(v):
		manager.set_bus_volume("SFX", v)
		sfx_label.text = "%d%%" % int(v * 100)
	)
	sfx_mute_check.toggled.connect(func(m):
		manager.set_bus_mute("SFX", m)
	)

	vo_slider.value_changed.connect(func(v):
		manager.set_bus_volume("VO", v)
		vo_label.text = "%d%%" % int(v * 100)
	)
	vo_mute_check.toggled.connect(func(m):
		manager.set_bus_mute("VO", m)
	)

	mode_option.item_selected.connect(func(_idx):
		var val = mode_option.get_selected_id()
		manager.set_window_mode(val)
	)

	res_option.item_selected.connect(func(_idx):
		var id = res_option.get_selected_id()
		if id < SettingsManagerClass.RESOLUTIONS.size():
			manager.set_resolution(SettingsManagerClass.RESOLUTIONS[id])
	)

	vsync_option.item_selected.connect(func(_idx):
		var val = vsync_option.get_selected_id()
		manager.set_vsync_mode(val)
	)

	fps_option.item_selected.connect(func(_idx):
		var val = fps_option.get_selected_id()
		manager.set_target_fps(val)
	)

	scale_slider.value_changed.connect(func(v):
		manager.set_ui_scale(v)
		scale_label.text = "%.2fx" % v
	)

	save_btn.pressed.connect(_on_save_pressed)
	load_btn.pressed.connect(_on_load_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)


func _on_save_pressed() -> void:
	if manager.save_settings():
		status_label.text = "Settings successfully saved to %s" % manager.settings_file_path


func _on_load_pressed() -> void:
	if manager.load_settings():
		_sync_ui_from_manager()
		status_label.text = "Settings successfully loaded."
	else:
		status_label.text = "No saved settings found."


func _on_reset_pressed() -> void:
	manager.reset_to_defaults()
	_sync_ui_from_manager()
	status_label.text = "Settings reset to defaults."


func _sync_ui_from_manager() -> void:
	var m_vol = manager.get_bus_volume("Master")
	master_slider.value = m_vol
	master_label.text = "%d%%" % int(m_vol * 100)
	master_mute_check.button_pressed = manager.is_bus_muted("Master")

	var b_vol = manager.get_bus_volume("BGM")
	bgm_slider.value = b_vol
	bgm_label.text = "%d%%" % int(b_vol * 100)
	bgm_mute_check.button_pressed = manager.is_bus_muted("BGM")

	var s_vol = manager.get_bus_volume("SFX")
	sfx_slider.value = s_vol
	sfx_label.text = "%d%%" % int(s_vol * 100)
	sfx_mute_check.button_pressed = manager.is_bus_muted("SFX")

	var v_vol = manager.get_bus_volume("VO")
	vo_slider.value = v_vol
	vo_label.text = "%d%%" % int(v_vol * 100)
	vo_mute_check.button_pressed = manager.is_bus_muted("VO")

	# Display UI
	var wmode = int(manager.display_settings.get("window_mode", 0))
	for i in range(mode_option.item_count):
		if mode_option.get_item_id(i) == wmode:
			mode_option.selected = i
			break

	var cur_res = manager.display_settings.get("resolution", Vector2i(1280, 720))
	for i in range(SettingsManagerClass.RESOLUTIONS.size()):
		if SettingsManagerClass.RESOLUTIONS[i] == cur_res:
			res_option.selected = i
			break

	var cur_vsync = int(manager.display_settings.get("vsync_mode", 1))
	for i in range(vsync_option.item_count):
		if vsync_option.get_item_id(i) == cur_vsync:
			vsync_option.selected = i
			break

	var cur_fps = int(manager.display_settings.get("target_fps", 60))
	for i in range(fps_option.item_count):
		if fps_option.get_item_id(i) == cur_fps:
			fps_option.selected = i
			break

	var cur_scale = float(manager.display_settings.get("ui_scale", 1.0))
	scale_slider.value = cur_scale
	scale_label.text = "%.2fx" % cur_scale
