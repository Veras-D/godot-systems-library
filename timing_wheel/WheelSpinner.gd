class_name WheelSpinner
extends Control

const WheelConfig = preload("WheelConfig.gd")

signal spin_started
signal sector_crossed(sector: Dictionary)
signal spin_completed(result: Dictionary)

enum State { IDLE, SPINNING, STOPPING, RESOLVED }

@export var radius: float = 110.0
@export var show_labels: bool = true

var config: WheelConfig = null
var state: State = State.IDLE
var current_angle_deg: float = 0.0
var _current_speed: float = 0.0
var _spin_elapsed: float = 0.0
var _last_sector_id: String = ""
var _decel_rate: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2 + 40, radius * 2 + 40)
	if config == null:
		# Default fallback config if none provided
		setup(WheelConfig.create_card_wars_attacker())
	gui_input.connect(_on_gui_input)

func setup(p_config: WheelConfig) -> void:
	config = p_config
	state = State.IDLE
	current_angle_deg = 0.0
	_current_speed = 0.0
	_last_sector_id = ""
	queue_redraw()

func start_spin() -> void:
	if config == null:
		return

	if config.quick_resolve:
		var q_res = config.roll_quick_resolve()
		state = State.RESOLVED
		spin_completed.emit(q_res)
		return

	state = State.SPINNING
	_spin_elapsed = 0.0
	_current_speed = config.spin_speed_deg_sec
	spin_started.emit()

func stop_spin() -> void:
	if state != State.SPINNING:
		return

	# Prevent instant stop before minimum spin duration
	if _spin_elapsed < config.min_spin_time:
		return

	state = State.STOPPING
	# Calculate quick deceleration (stops in ~0.25 seconds)
	_decel_rate = _current_speed / 0.25

func _process(delta: float) -> void:
	if state == State.SPINNING:
		_spin_elapsed += delta
		var dir = 1.0 if config.clockwise else -1.0
		current_angle_deg = fposmod(current_angle_deg + dir * _current_speed * delta, 360.0)
		_check_sector_tick()
		queue_redraw()

	elif state == State.STOPPING:
		_current_speed = max(0.0, _current_speed - _decel_rate * delta)
		var dir = 1.0 if config.clockwise else -1.0
		current_angle_deg = fposmod(current_angle_deg + dir * _current_speed * delta, 360.0)
		_check_sector_tick()
		queue_redraw()

		if _current_speed <= 0.0:
			_resolve_final_result()

func _check_sector_tick() -> void:
	if config == null:
		return
	var cur_sector = config.get_sector_at_angle(current_angle_deg)
	var s_id = cur_sector.get("id", "")
	if s_id != _last_sector_id and s_id != "":
		_last_sector_id = s_id
		sector_crossed.emit(cur_sector)

func _resolve_final_result() -> void:
	state = State.RESOLVED
	var result = config.get_sector_at_angle(current_angle_deg)
	spin_completed.emit(result)
	queue_redraw()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == State.IDLE:
			start_spin()
		elif state == State.SPINNING:
			stop_spin()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if state == State.IDLE:
			start_spin()
		elif state == State.SPINNING:
			stop_spin()

func _draw() -> void:
	var center = size * 0.5
	if config == null or config.sectors.is_empty():
		draw_circle(center, radius, Color(0.2, 0.2, 0.2, 1.0))
		return

	# 1. Draw outer shadow ring
	draw_circle(center, radius + 8.0, Color(0.05, 0.05, 0.08, 0.8))
	draw_circle(center, radius + 4.0, Color(0.85, 0.70, 0.25, 1.0)) # Gold outer rim

	# 2. Draw Sectors
	var current_deg = -90.0 # Start from top (12 o'clock)
	for sector in config.sectors:
		var span_deg = sector.get("ratio", 0.0) * 360.0
		var start_rad = deg_to_rad(current_deg)
		var end_rad = deg_to_rad(current_deg + span_deg)
		var color: Color = sector.get("color", Color.WHITE)

		_draw_pie_slice(center, radius, start_rad, end_rad, color)

		# Sector boundary divider
		var edge_pt = center + Vector2(cos(start_rad), sin(start_rad)) * radius
		draw_line(center, edge_pt, Color(0.1, 0.1, 0.1, 0.8), 2.0, true)

		current_deg += span_deg

	# 3. Inner hub rim
	draw_circle(center, radius * 0.25, Color(0.15, 0.18, 0.25, 1.0))
	draw_circle(center, radius * 0.22, Color(0.85, 0.70, 0.25, 1.0))
	draw_circle(center, radius * 0.12, Color(0.10, 0.12, 0.18, 1.0))

	# 4. Needle / Pointer (pointing from center outward at current_angle_deg)
	var needle_angle_rad = deg_to_rad(current_angle_deg - 90.0)
	var needle_tip = center + Vector2(cos(needle_angle_rad), sin(needle_angle_rad)) * (radius + 2.0)
	var needle_left = center + Vector2(cos(needle_angle_rad + 2.5), sin(needle_angle_rad + 2.5)) * 14.0
	var needle_right = center + Vector2(cos(needle_angle_rad - 2.5), sin(needle_angle_rad - 2.5)) * 14.0

	var needle_pts = PackedVector2Array([needle_tip, needle_left, needle_right])
	# Needle shadow
	var shadow_pts = PackedVector2Array([
		needle_tip + Vector2(2, 2),
		needle_left + Vector2(2, 2),
		needle_right + Vector2(2, 2)
	])
	draw_polygon(shadow_pts, PackedColorArray([Color(0, 0, 0, 0.5)]))
	draw_polygon(needle_pts, PackedColorArray([Color(1.0, 0.2, 0.2, 1.0)])) # Red needle
	draw_polyline(needle_pts, Color.WHITE, 1.5, true)

func _draw_pie_slice(center: Vector2, r: float, start_rad: float, end_rad: float, color: Color) -> void:
	var span = abs(end_rad - start_rad)
	var nb_points = max(3, int(ceil(span / (PI / 24.0))))
	var points = PackedVector2Array()
	points.append(center)
	for i in range(nb_points + 1):
		var a = start_rad + i * (end_rad - start_rad) / nb_points
		points.append(center + Vector2(cos(a), sin(a)) * r)
	draw_polygon(points, PackedColorArray([color]))
