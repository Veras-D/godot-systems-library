extends Control

const WheelConfig = preload("WheelConfig.gd")
const WheelSpinner = preload("WheelSpinner.gd")

@onready var wheel: WheelSpinner = $HBox/WheelArea/WheelSpinner
@onready var status_label: Label = $HBox/WheelArea/StatusLabel
@onready var spin_btn: Button = $HBox/WheelArea/BtnBox/SpinBtn
@onready var stop_btn: Button = $HBox/WheelArea/BtnBox/StopBtn

@onready var preset_option: OptionButton = $HBox/ControlPanel/VBox/PresetOption
@onready var hit_slider: HSlider = $HBox/ControlPanel/VBox/HitSlider
@onready var hit_val_label: Label = $HBox/ControlPanel/VBox/HitValLabel
@onready var crit_slider: HSlider = $HBox/ControlPanel/VBox/CritSlider
@onready var crit_val_label: Label = $HBox/ControlPanel/VBox/CritValLabel
@onready var miss_val_label: Label = $HBox/ControlPanel/VBox/MissValLabel
@onready var speed_slider: HSlider = $HBox/ControlPanel/VBox/SpeedSlider
@onready var speed_val_label: Label = $HBox/ControlPanel/VBox/SpeedValLabel

@onready var quick_resolve_check: CheckBox = $HBox/ControlPanel/VBox/QuickResolveCheck
@onready var batch_btn: Button = $HBox/ControlPanel/VBox/BatchBtn
@onready var batch_results_label: Label = $HBox/ControlPanel/VBox/BatchResultsLabel
@onready var log_text: RichTextLabel = $HBox/ControlPanel/VBox/LogText

var current_cfg: WheelConfig = null

func _ready() -> void:
	# Configure neutral preset options
	preset_option.add_item("3-Tier Outcome (70% Success, 10% Bonus, 20% Failure)", 0)
	preset_option.add_item("50/50 Binary Coin Flip (Heads / Tails)", 1)
	preset_option.add_item("4-Quadrant Spinner (Equal 25% Sectors)", 2)
	preset_option.add_item("8-Sector Precision Dial (12.5% Each)", 3)
	preset_option.item_selected.connect(_on_preset_selected)

	spin_btn.pressed.connect(_on_spin_pressed)
	stop_btn.pressed.connect(_on_stop_pressed)

	hit_slider.value_changed.connect(func(_v): _on_slider_changed())
	crit_slider.value_changed.connect(func(_v): _on_slider_changed())
	speed_slider.value_changed.connect(func(_v): _on_slider_changed())
	quick_resolve_check.toggled.connect(func(v): if current_cfg: current_cfg.quick_resolve = v)
	batch_btn.pressed.connect(_run_batch_simulation)

	wheel.spin_started.connect(_on_wheel_spin_started)
	wheel.sector_crossed.connect(_on_wheel_sector_crossed)
	wheel.spin_completed.connect(_on_wheel_spin_completed)

	_apply_preset(0)

func _apply_preset(idx: int) -> void:
	match idx:
		0: # 3-Tier Outcome
			current_cfg = WheelConfig.create_tiered(0.70, 0.10, 1600.0)
			hit_slider.value = 70
			crit_slider.value = 10
			speed_slider.value = 1600
		1: # 50/50
			current_cfg = WheelConfig.create_coin_flip(0.50, "HEADS", "TAILS", 1400.0)
			hit_slider.value = 50
			crit_slider.value = 0
			speed_slider.value = 1400
		2: # 4 Quadrants
			current_cfg = WheelConfig.create_quadrants(["North", "East", "South", "West"], 1500.0)
			hit_slider.value = 25
			crit_slider.value = 25
			speed_slider.value = 1500
		3: # 8 Sectors
			var sectors: Array = []
			var colors = [
				Color(0.2, 0.65, 0.95), Color(0.95, 0.85, 0.2),
				Color(0.2, 0.85, 0.45), Color(0.95, 0.5, 0.2),
				Color(0.85, 0.35, 0.85), Color(0.2, 0.8, 0.8),
				Color(0.9, 0.3, 0.3), Color(0.65, 0.85, 0.25)
			]
			for i in range(8):
				sectors.append({
					"id": "sec_%d" % (i + 1),
					"name": "Sector %d" % (i + 1),
					"ratio": 0.125,
					"color": colors[i % colors.size()],
					"multiplier": 1.0,
					"is_success": true
				})
			current_cfg = WheelConfig.create_custom(sectors, 1800.0)
			hit_slider.value = 12.5
			crit_slider.value = 12.5
			speed_slider.value = 1800

	current_cfg.quick_resolve = quick_resolve_check.button_pressed
	_update_slider_labels()
	wheel.setup(current_cfg)
	status_label.text = "Wheel configured. Click Spin or press Space!"
	_update_buttons()

func _on_preset_selected(idx: int) -> void:
	_apply_preset(idx)

func _on_slider_changed() -> void:
	var prim_r = hit_slider.value / 100.0
	var sec_r = crit_slider.value / 100.0
	if (prim_r + sec_r) > 0.99:
		sec_r = max(0.01, 0.99 - prim_r)
		crit_slider.value = sec_r * 100.0

	current_cfg = WheelConfig.create_tiered(prim_r, sec_r, speed_slider.value)
	current_cfg.quick_resolve = quick_resolve_check.button_pressed
	_update_slider_labels()
	wheel.setup(current_cfg)
	_update_buttons()

func _update_slider_labels() -> void:
	var prim = hit_slider.value
	var bonus = crit_slider.value
	var rem = max(0.0, 100.0 - (prim + bonus))
	hit_val_label.text = "Primary Sector: %.1f%%" % prim
	crit_val_label.text = "Bonus Sector: %.1f%%" % bonus
	miss_val_label.text = "Remaining / Fallback: %.1f%%" % rem
	speed_val_label.text = "Rotation Speed: %d deg/s" % int(speed_slider.value)

func _on_spin_pressed() -> void:
	wheel.start_spin()
	_update_buttons()

func _on_stop_pressed() -> void:
	wheel.stop_spin()
	_update_buttons()

func _on_wheel_spin_started() -> void:
	status_label.text = "🌀 Spinning... Click STOP or tap Space to land!"
	_update_buttons()

func _on_wheel_sector_crossed(_sector: Dictionary) -> void:
	# Real-time needle ticking event
	pass

func _on_wheel_spin_completed(result: Dictionary) -> void:
	var name_str = result.get("name", "Unknown")
	var mult = result.get("multiplier", 1.0)
	var angle = result.get("angle_deg", 0.0)
	var qr = result.get("quick_resolved", false)

	var color_hex = "green" if mult > 1.0 else ("yellow" if mult > 0.0 else "red")
	status_label.text = "🎯 RESULT: %s (%.1fx) at %.1f°" % [name_str, mult, angle]

	var entry = "[color=%s]• %s (%.1fx) [Angle: %.1f°]%s[/color]\n" % [
		color_hex, name_str, mult, angle, " [Instant]" if qr else ""
	]
	log_text.append_text(entry)
	_update_buttons()

func _update_buttons() -> void:
	match wheel.state:
		WheelSpinner.State.IDLE, WheelSpinner.State.RESOLVED:
			spin_btn.disabled = false
			stop_btn.disabled = true
		WheelSpinner.State.SPINNING:
			spin_btn.disabled = true
			stop_btn.disabled = false
		WheelSpinner.State.STOPPING:
			spin_btn.disabled = true
			stop_btn.disabled = true

func _run_batch_simulation() -> void:
	if current_cfg == null:
		return

	var count = 1000
	var counts: Dictionary = {}
	for sector in current_cfg.sectors:
		var s_id = sector.get("id", "")
		counts[s_id] = 0

	for _i in range(count):
		var res = current_cfg.roll_quick_resolve()
		var s_id = res.id
		if counts.has(s_id):
			counts[s_id] += 1

	var summary = "Simulated 1,000 Spins:\n"
	for sector in current_cfg.sectors:
		var s_id = sector.get("id", "")
		var actual = counts.get(s_id, 0)
		var actual_pct = (float(actual) / float(count)) * 100.0
		var exp_pct = sector.get("ratio", 0.0) * 100.0
		summary += "• %s: %d (%.1f%%) [Exp: %.1f%%]\n" % [
			sector.get("name", s_id), actual, actual_pct, exp_pct
		]

	batch_results_label.text = summary
	log_text.append_text("[color=cyan]=== Ran 1,000 Spin Empirical Verification ===[/color]\n")
