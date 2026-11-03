class_name BoardGrid
extends Control

## Universal Lane/Grid Board Manager.
## Organizes slots into configurable sides (default 2: Friendly/Enemy) and N lanes per side.
## Handles slot lookups, opposing lane resolution, affinity validation, and highlight states.
## Completely decoupled from any specific game rules or card designs.

const SlotData = preload("SlotData.gd")
const BoardSlot = preload("BoardSlot.gd")
const BoardSlotScene = preload("BoardSlot.tscn")

signal slot_selected(slot: BoardSlot)
signal slot_hover_changed(slot: BoardSlot, is_hovered: bool)
signal occupant_dropped_on_slot(slot: BoardSlot, data: Variant)
signal slot_damage_shaken(slot: BoardSlot, intensity: float)
signal slot_summon_pulsed(slot: BoardSlot)
signal grid_rebuilt()

@export var sides_count: int = 2:
	set(val):
		sides_count = max(1, val)
		if is_inside_tree():
			rebuild_grid()

@export var lanes_per_side: int = 4:
	set(val):
		lanes_per_side = max(1, val)
		if is_inside_tree():
			rebuild_grid()

@export var slot_spacing: int = 12
@export var universal_affinity_tag: String = "Universal"

## Optional custom affinity validator hook: func(occupant_affinity: String, slot_affinity: String) -> bool
var custom_affinity_validator: Callable = Callable():
	set(val):
		custom_affinity_validator = val
		for slot in _slots_map.values():
			if slot != null and "custom_affinity_validator" in slot:
				slot.custom_affinity_validator = val

@onready var sides_container: VBoxContainer = $SidesContainer

# Internal 2D array or lookup map: key = Vector2i(side, lane), value = BoardSlot
var _slots_map: Dictionary = {}
var _selected_slot: BoardSlot = null


func _ready() -> void:
	if _slots_map.is_empty():
		rebuild_grid()


## Rebuilds the entire visual and logical board grid
func rebuild_grid() -> void:
	if sides_container == null:
		sides_container = get_node_or_null("SidesContainer")
		if sides_container == null:
			return

	# Clear previous children
	for child in sides_container.get_children():
		child.queue_free()
	_slots_map.clear()
	_selected_slot = null

	# Create rows for each side
	# For standard 2-player opposing layouts:
	# Side 1 (Opponent) is at the top, Side 0 (Player) is at the bottom.
	# We iterate backwards through sides so higher side indices render on top if side_count == 2.
	var side_order: Array[int] = []
	if sides_count == 2:
		side_order = [1, 0] # Top = Side 1, Bottom = Side 0
	else:
		for s in range(sides_count):
			side_order.append(s)

	for side_idx in side_order:
		var row_box = HBoxContainer.new()
		row_box.name = "Side_%d_Row" % side_idx
		row_box.add_theme_constant_override("separation", slot_spacing)
		row_box.alignment = BoxContainer.ALIGNMENT_CENTER
		sides_container.add_child(row_box)

		for lane_idx in range(lanes_per_side):
			var slot_node = BoardSlotScene.instantiate() as BoardSlot
			var s_data = SlotData.create(side_idx, lane_idx, "")
			slot_node.name = "Slot_%d_%d" % [side_idx, lane_idx]
			slot_node.grid_owner = self
			if custom_affinity_validator.is_valid():
				slot_node.custom_affinity_validator = custom_affinity_validator
			row_box.add_child(slot_node)
			slot_node.setup(s_data)

			# Connect slot signals
			slot_node.slot_clicked.connect(_on_slot_clicked)
			slot_node.slot_hovered.connect(_on_slot_hovered)
			slot_node.slot_dropped.connect(_on_slot_dropped)
			slot_node.damage_shake_started.connect(func(s, i): slot_damage_shaken.emit(s, i))
			slot_node.summon_pulse_started.connect(func(s): slot_summon_pulsed.emit(s))

			var coord = Vector2i(side_idx, lane_idx)
			_slots_map[coord] = slot_node

	grid_rebuilt.emit()


## Set affinities for an entire side at once
func set_side_affinities(side: int, affinities: Array) -> void:
	for lane in range(lanes_per_side):
		var slot = get_slot(side, lane)
		if slot and slot.slot_data:
			var aff = affinities[lane] if lane < affinities.size() else ""
			slot.slot_data.affinity = aff
			slot.update_views()


## Set affinity for a specific slot
func set_slot_affinity(side: int, lane: int, affinity: String) -> void:
	var slot = get_slot(side, lane)
	if slot and slot.slot_data:
		slot.slot_data.affinity = affinity
		slot.update_views()


## Retrieve a slot by side and lane index
func get_slot(side: int, lane: int) -> BoardSlot:
	return _slots_map.get(Vector2i(side, lane), null)


## Retrieve the directly opposite slot (e.g. for lane combat resolution)
## In a 2-sided board, Side 0 lane X opposes Side 1 lane X.
func get_opposing_slot(slot: BoardSlot) -> BoardSlot:
	if slot == null or slot.slot_data == null:
		return null
	var cur_side = slot.slot_data.side
	var cur_lane = slot.slot_data.lane_index
	if sides_count == 2:
		var opp_side = 1 if cur_side == 0 else 0
		return get_slot(opp_side, cur_lane)
	return null


## Universal Spatial Topology Protocol: returns adjacent units to an origin slot, unit, or coordinate
func get_adjacent_units(origin: Variant) -> Array:
	var origin_slot: BoardSlot = _resolve_slot_from_origin(origin)
	if origin_slot == null or origin_slot.slot_data == null:
		return []

	var side = origin_slot.slot_data.side
	var lane = origin_slot.slot_data.lane_index
	var result: Array = []
	for offset in [-1, 1]:
		var adj = get_slot(side, lane + offset)
		if adj != null and adj.slot_data and not adj.slot_data.is_empty():
			result.append(adj.slot_data.primary_occupant if adj.slot_data.has_primary() else adj)
	return result


## Universal Spatial Topology Protocol: returns opposing / facing units
func get_opposing_units(origin: Variant) -> Array:
	var origin_slot: BoardSlot = _resolve_slot_from_origin(origin)
	if origin_slot == null:
		return []

	var opp = get_opposing_slot(origin_slot)
	if opp != null and opp.slot_data and not opp.slot_data.is_empty():
		return [opp.slot_data.primary_occupant if opp.slot_data.has_primary() else opp]
	return []


## Universal Spatial Topology Protocol: returns units within radius
func get_units_in_radius(origin: Variant, radius: int = 1) -> Array:
	var origin_slot: BoardSlot = _resolve_slot_from_origin(origin)
	if origin_slot == null or origin_slot.slot_data == null:
		return []

	var side = origin_slot.slot_data.side
	var lane = origin_slot.slot_data.lane_index
	var result: Array = []
	for l in range(max(0, lane - radius), min(lanes_per_side, lane + radius + 1)):
		if l == lane:
			continue
		var s = get_slot(side, l)
		if s != null and s.slot_data and not s.slot_data.is_empty():
			result.append(s.slot_data.primary_occupant if s.slot_data.has_primary() else s)
	return result


func _resolve_slot_from_origin(origin: Variant) -> BoardSlot:
	if origin is BoardSlot:
		return origin
	if origin is Object and "slot_data" in origin and origin.slot_data is SlotData:
		return get_slot(origin.slot_data.side, origin.slot_data.lane_index)
	if origin is Vector2i:
		return get_slot(origin.x, origin.y)
	if origin is Dictionary:
		if origin.has("side") and origin.has("lane"):
			return get_slot(int(origin["side"]), int(origin["lane"]))
		if origin.has("side") and origin.has("lane_index"):
			return get_slot(int(origin["side"]), int(origin["lane_index"]))
	# Search occupants
	for s in _slots_map.values():
		if s.slot_data and s.slot_data.primary_occupant == origin:
			return s
	return null


## Retrieve all slots matching criteria
func get_all_slots(side: int = -1) -> Array[BoardSlot]:
	var result: Array[BoardSlot] = []
	for coord in _slots_map:
		if side == -1 or coord.x == side:
			result.append(_slots_map[coord])
	return result


func get_empty_slots(side: int = -1) -> Array[BoardSlot]:
	var result: Array[BoardSlot] = []
	for coord in _slots_map:
		if side == -1 or coord.x == side:
			var s: BoardSlot = _slots_map[coord]
			if s.slot_data and s.slot_data.is_empty():
				result.append(s)
	return result


func get_occupied_slots(side: int = -1) -> Array[BoardSlot]:
	var result: Array[BoardSlot] = []
	for coord in _slots_map:
		if side == -1 or coord.x == side:
			var s: BoardSlot = _slots_map[coord]
			if s.slot_data and s.slot_data.has_primary():
				result.append(s)
	return result


func get_slots_by_affinity(affinity: String, side: int = -1) -> Array[BoardSlot]:
	var result: Array[BoardSlot] = []
	for coord in _slots_map:
		if side == -1 or coord.x == side:
			var s: BoardSlot = _slots_map[coord]
			if s.slot_data and s.slot_data.affinity == affinity:
				result.append(s)
	return result


## Validates whether an occupant can be placed on a slot
func validate_placement(
	occupant_affinity: String,
	side: int,
	lane: int,
	is_attachment: bool = false
) -> Dictionary:
	var slot = get_slot(side, lane)
	if slot == null:
		return {"allowed": false, "reason": "Slot does not exist."}
	if slot.slot_data == null:
		return {"allowed": false, "reason": "No slot data."}
	if slot.slot_data.is_locked:
		return {"allowed": false, "reason": "Slot is locked."}
	if slot.slot_data.is_disabled:
		return {"allowed": false, "reason": "Slot is disabled."}

	if not is_attachment:
		if slot.slot_data.has_primary():
			return {"allowed": false, "reason": "Slot already contains a primary occupant."}
		if custom_affinity_validator.is_valid():
			var custom_res = custom_affinity_validator.call(occupant_affinity, slot.slot_data.affinity)
			if not custom_res:
				return {"allowed": false, "reason": "Custom affinity check failed."}
		elif not slot.slot_data.can_accept_affinity(occupant_affinity, universal_affinity_tag):
			return {"allowed": false, "reason": "Affinity mismatch (%s required)." % slot.slot_data.affinity}
	else:
		if slot.slot_data.has_attachment():
			return {"allowed": false, "reason": "Slot already has an attached structure."}

	return {"allowed": true, "reason": ""}


## Highlights all valid target slots for an affinity and side
func highlight_valid_slots(affinity: String, target_side: int, is_attachment: bool = false) -> void:
	for coord in _slots_map:
		var slot: BoardSlot = _slots_map[coord]
		if target_side != -1 and coord.x != target_side:
			slot.set_highlight(BoardSlot.HighlightMode.NONE)
			continue

		var val = validate_placement(affinity, coord.x, coord.y, is_attachment)
		if val.allowed:
			slot.set_highlight(BoardSlot.HighlightMode.VALID_TARGET)
		else:
			slot.set_highlight(BoardSlot.HighlightMode.INVALID_TARGET)


## Clears all visual highlights across all slots
func clear_all_highlights() -> void:
	for coord in _slots_map:
		var slot: BoardSlot = _slots_map[coord]
		slot.set_highlight(BoardSlot.HighlightMode.NONE)


## Clears all slots of occupants and resets modifiers
func clear_all_slots() -> void:
	for coord in _slots_map:
		var slot: BoardSlot = _slots_map[coord]
		slot.clear_occupants()


## Serializes all slot states to an Array of Dictionaries
func serialize_grid() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for coord in _slots_map:
		var slot: BoardSlot = _slots_map[coord]
		if slot.slot_data:
			data.append(slot.slot_data.to_dict())
	return data


func _on_slot_clicked(slot: BoardSlot) -> void:
	if _selected_slot and _selected_slot != slot:
		_selected_slot.set_highlight(BoardSlot.HighlightMode.NONE)
	_selected_slot = slot
	_selected_slot.set_highlight(BoardSlot.HighlightMode.SELECTED)
	slot_selected.emit(slot)


func _on_slot_hovered(slot: BoardSlot, is_hovered: bool) -> void:
	slot_hover_changed.emit(slot, is_hovered)


func _on_slot_dropped(slot: BoardSlot, data: Variant) -> void:
	occupant_dropped_on_slot.emit(slot, data)
