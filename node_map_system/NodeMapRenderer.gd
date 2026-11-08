class_name NodeMapRenderer
extends Control

## Visual Spline & Pin Renderer for NodeMapGraph
##
## Draws procedural connection lines and interactive node pins with status styling
## (Locked, Unlocked, Completed 1-3 stars) and supports canvas panning & zooming.

const NodeMapGraph = preload("NodeMapGraph.gd")

signal node_selected(node_id: String)
signal node_hovered(node_id: String)

@export var line_color_locked: Color = Color(0.25, 0.28, 0.35, 0.6)
@export var line_color_unlocked: Color = Color(0.3, 0.8, 1.0, 0.85)
@export var line_color_completed: Color = Color(0.95, 0.82, 0.3, 0.95)
@export var line_width: float = 4.0
@export var pin_size: Vector2 = Vector2(70, 70)
@export var enable_pan_zoom: bool = true

var graph: NodeMapGraph = null:
	set(val):
		if graph != null:
			_disconnect_graph_signals()
		graph = val
		if graph != null:
			_connect_graph_signals()
		refresh_map()

var _nodes_container: Control = null
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _canvas_offset: Vector2 = Vector2.ZERO
var _canvas_scale: float = 1.0

# node_id -> Button
var _node_buttons: Dictionary = {}


func _ready() -> void:
	clip_contents = true
	_ensure_containers()
	refresh_map()


func _ensure_containers() -> void:
	if _nodes_container == null:
		_nodes_container = Control.new()
		_nodes_container.name = "CanvasRoot"
		add_child(_nodes_container)


func _connect_graph_signals() -> void:
	if graph == null:
		return
	if not graph.node_updated.is_connected(_on_node_updated):
		graph.node_updated.connect(_on_node_updated)
	if not graph.node_completed.is_connected(_on_node_completed):
		graph.node_completed.connect(_on_node_completed)
	if not graph.node_unlocked.is_connected(_on_node_unlocked):
		graph.node_unlocked.connect(_on_node_unlocked)


func _disconnect_graph_signals() -> void:
	if graph == null:
		return
	if graph.node_updated.is_connected(_on_node_updated):
		graph.node_updated.disconnect(_on_node_updated)
	if graph.node_completed.is_connected(_on_node_completed):
		graph.node_completed.disconnect(_on_node_completed)
	if graph.node_unlocked.is_connected(_on_node_unlocked):
		graph.node_unlocked.disconnect(_on_node_unlocked)


func _on_node_updated(_node_id: String) -> void:
	_update_all_pins()
	queue_redraw()


func _on_node_completed(_node_id: String, _stars: int, _first_clear: bool) -> void:
	_update_all_pins()
	queue_redraw()


func _on_node_unlocked(_node_id: String) -> void:
	_update_all_pins()
	queue_redraw()


## Rebuilds all pins and redraws lines based on graph data.
func refresh_map() -> void:
	_ensure_containers()
	for child in _nodes_container.get_children():
		child.queue_free()
	_node_buttons.clear()

	if graph == null:
		queue_redraw()
		return

	var all_nodes = graph.get_all_nodes()
	for n_data in all_nodes:
		var nid = str(n_data.get("id", ""))
		if nid == "":
			continue

		var btn = Button.new()
		btn.custom_minimum_size = pin_size
		btn.size = pin_size
		btn.pivot_offset = pin_size / 2.0
		btn.position = (n_data.get("position", Vector2.ZERO) - (pin_size / 2.0))

		btn.pressed.connect(func(): _on_pin_pressed(nid))
		btn.mouse_entered.connect(func(): node_hovered.emit(nid))

		_nodes_container.add_child(btn)
		_node_buttons[nid] = btn

	_update_all_pins()
	queue_redraw()


func _update_all_pins() -> void:
	if graph == null:
		return

	for nid in _node_buttons.keys():
		var btn: Button = _node_buttons[nid]
		if not is_instance_valid(btn):
			continue

		var n_data = graph.get_node(nid)
		if n_data.is_empty():
			continue

		var state = int(n_data.get("state", NodeMapGraph.NodeState.LOCKED))
		var stars = int(n_data.get("stars", 0))
		var title = str(n_data.get("title", nid))

		match state:
			NodeMapGraph.NodeState.LOCKED:
				btn.disabled = true
				btn.text = "🔒\n%s" % title
				btn.modulate = Color(0.5, 0.55, 0.65, 0.7)
			NodeMapGraph.NodeState.UNLOCKED:
				btn.disabled = false
				btn.text = "⚔️\n%s\n☆☆☆" % title
				btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			NodeMapGraph.NodeState.COMPLETED:
				btn.disabled = false
				var star_str = ""
				for i in range(3):
					star_str += "★" if i < stars else "☆"
				btn.text = "✓ %s\n%s" % [title, star_str]
				btn.modulate = Color(1.0, 0.9, 0.35, 1.0)


func _on_pin_pressed(node_id: String) -> void:
	node_selected.emit(node_id)


func _draw() -> void:
	if graph == null:
		return

	var all_nodes = graph.get_all_nodes()
	for n_data in all_nodes:
		var from_id = str(n_data.get("id", ""))
		var from_pos = _world_to_canvas(n_data.get("position", Vector2.ZERO))
		var from_state = int(n_data.get("state", NodeMapGraph.NodeState.LOCKED))

		var out_edges = graph.get_outgoing(from_id)
		for to_id in out_edges:
			var target_data = graph.get_node(to_id)
			if target_data.is_empty():
				continue

			var to_pos = _world_to_canvas(target_data.get("position", Vector2.ZERO))
			var to_state = int(target_data.get("state", NodeMapGraph.NodeState.LOCKED))

			var col = line_color_locked
			if from_state == NodeMapGraph.NodeState.COMPLETED and to_state == NodeMapGraph.NodeState.COMPLETED:
				col = line_color_completed
			elif to_state == NodeMapGraph.NodeState.UNLOCKED:
				col = line_color_unlocked

			draw_line(from_pos, to_pos, col, line_width * _canvas_scale, true)

			# Directional dot indicator
			var mid = from_pos.lerp(to_pos, 0.6)
			draw_circle(mid, (line_width + 2.0) * _canvas_scale, col)


func _world_to_canvas(world_pos: Vector2) -> Vector2:
	return (world_pos * _canvas_scale) + _canvas_offset


func _apply_transform() -> void:
	if _nodes_container:
		_nodes_container.position = _canvas_offset
		_nodes_container.scale = Vector2(_canvas_scale, _canvas_scale)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not enable_pan_zoom:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_start_pos = event.position - _canvas_offset
			else:
				_is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 0.9)

	elif event is InputEventMouseMotion and _is_dragging:
		_canvas_offset = event.position - _drag_start_pos
		_apply_transform()


func _zoom_at(pivot: Vector2, factor: float) -> void:
	var old_scale = _canvas_scale
	var new_scale = clampf(_canvas_scale * factor, 0.4, 2.5)
	if is_equal_approx(old_scale, new_scale):
		return
	_canvas_offset = pivot - ((pivot - _canvas_offset) * (new_scale / old_scale))
	_canvas_scale = new_scale
	_apply_transform()


## Resets pan and zoom back to default.
func reset_view() -> void:
	_canvas_offset = Vector2.ZERO
	_canvas_scale = 1.0
	_apply_transform()
