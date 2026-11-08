class_name GamepadNavigator
extends RefCounted

## GamepadNavigator: Universal UI focus graph & virtual D-Pad/stick navigator.
## Manages 2D hierarchical grid navigation across card hands, board lanes, leader powers, and turn buttons.

signal focus_changed(zone: int, index: int, node: Control)
signal action_triggered(action_name: String, focused_node: Control)

enum FocusZone {
	HAND = 0,
	LANES = 1,
	LEADER = 2,
	END_TURN = 3
}

var current_zone: FocusZone = FocusZone.HAND
var current_index: int = 0

var _zone_nodes: Dictionary = {
	FocusZone.HAND: [],
	FocusZone.LANES: [],
	FocusZone.LEADER: [],
	FocusZone.END_TURN: []
}


func register_zone_nodes(zone: FocusZone, nodes: Array) -> void:
	var clean: Array[Control] = []
	for n in nodes:
		if n is Control:
			clean.append(n)
	_zone_nodes[zone] = clean


func get_focused_node() -> Control:
	var list: Array = _zone_nodes.get(current_zone, [])
	if list.is_empty() or current_index < 0 or current_index >= list.size():
		return null
	return list[current_index]


func focus_zone(zone: FocusZone, index: int = 0) -> bool:
	var list: Array = _zone_nodes.get(zone, [])
	if list.is_empty():
		return false

	current_zone = zone
	current_index = clampi(index, 0, list.size() - 1)

	var node: Control = list[current_index]
	if is_instance_valid(node):
		node.grab_focus()
		focus_changed.emit(current_zone, current_index, node)
		return true
	return false


## Navigates focus in the specified 2D direction (LEFT, RIGHT, UP, DOWN).
func navigate(direction: Vector2) -> bool:
	if direction == Vector2.ZERO:
		return false

	var list: Array = _zone_nodes.get(current_zone, [])

	# Horizontal navigation within current zone
	if abs(direction.x) > abs(direction.y):
		if direction.x < 0:
			# Move Left
			if current_index > 0:
				return focus_zone(current_zone, current_index - 1)
			elif current_zone == FocusZone.END_TURN:
				return focus_zone(FocusZone.LEADER, 0)
		elif direction.x > 0:
			# Move Right
			if current_index < list.size() - 1:
				return focus_zone(current_zone, current_index + 1)
			elif current_zone == FocusZone.LEADER:
				return focus_zone(FocusZone.END_TURN, 0)

	# Vertical navigation across zones
	else:
		if direction.y < 0:
			# Move UP
			match current_zone:
				FocusZone.HAND:
					# Hand -> Lanes (map index proportionately)
					var lane_idx = clampi(current_index, 0, _zone_nodes[FocusZone.LANES].size() - 1)
					return focus_zone(FocusZone.LANES, lane_idx)
				FocusZone.LANES:
					# Lanes -> Leader or End Turn
					if current_index >= 2:
						return focus_zone(FocusZone.END_TURN, 0)
					else:
						return focus_zone(FocusZone.LEADER, 0)
		elif direction.y > 0:
			# Move DOWN
			match current_zone:
				FocusZone.LEADER, FocusZone.END_TURN:
					# Leader/EndTurn -> Lanes
					return focus_zone(FocusZone.LANES, 0 if current_zone == FocusZone.LEADER else 3)
				FocusZone.LANES:
					# Lanes -> Hand
					var hand_idx = clampi(current_index, 0, _zone_nodes[FocusZone.HAND].size() - 1)
					return focus_zone(FocusZone.HAND, hand_idx)

	return false
