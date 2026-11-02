class_name SlotData
extends Resource

## Generic Data Model for a Board Slot
## Represents the logical state of a single cell/lane in a lane-based or grid-based game board.
## Completely decoupled from any specific game theme or ruleset.

signal occupant_changed(slot_data: Resource)
signal affinity_changed(slot_data: Resource, new_affinity: String)
signal modifiers_changed(slot_data: Resource)

enum SlotState {
	EMPTY,
	OCCUPIED,
	LOCKED,
	DISABLED
}

@export var side: int = 0                  # 0 = Side A (e.g. Player), 1 = Side B (e.g. Opponent), or custom ID
@export var lane_index: int = 0            # 0-indexed column or lane along the board
@export var affinity: String = ""          # Terrain/elemental affinity tag (e.g. "Grass", "Fire", "Universal", or "")
@export var is_locked: bool = false        # Whether cards can currently be placed
@export var is_disabled: bool = false      # Whether the slot is inactive in current layout
@export var modifiers: Dictionary = {}      # Dynamic modifiers (e.g. {"atk_bonus": 2, "def_bonus": 1})

var primary_occupant: Variant = null:      # Main occupant (e.g. Unit, Creature, Champion)
	set(val):
		primary_occupant = val
		occupant_changed.emit(self)

var attached_occupant: Variant = null:     # Secondary occupant (e.g. Building, Structure, Aura, Trap)
	set(val):
		attached_occupant = val
		occupant_changed.emit(self)


static func create(p_side: int, p_lane: int, p_affinity: String = "") -> Resource:
	var slot = new()
	slot.side = p_side
	slot.lane_index = p_lane
	slot.affinity = p_affinity
	return slot


func get_coordinate() -> Vector2i:
	return Vector2i(side, lane_index)


func get_state() -> SlotState:
	if is_disabled:
		return SlotState.DISABLED
	if is_locked:
		return SlotState.LOCKED
	if primary_occupant != null:
		return SlotState.OCCUPIED
	return SlotState.EMPTY


func is_empty() -> bool:
	return primary_occupant == null and not is_locked and not is_disabled


func has_primary() -> bool:
	return primary_occupant != null


func has_attachment() -> bool:
	return attached_occupant != null


## Validates whether an occupant with the specified affinity can be placed in this slot.
## If universal_affinity_tag is passed, occupants with that affinity can occupy any slot,
## and slots with that affinity accept any occupant.
func can_accept_affinity(
	occupant_affinity: String,
	universal_affinity_tag: String = "Universal"
) -> bool:
	if is_locked or is_disabled:
		return false
	if affinity.is_empty():
		return true
	if occupant_affinity.is_empty():
		return true
	if occupant_affinity == universal_affinity_tag or affinity == universal_affinity_tag:
		return true
	return occupant_affinity == affinity


## Clears occupants and resets modifiers
func clear() -> void:
	primary_occupant = null
	attached_occupant = null
	modifiers.clear()
	modifiers_changed.emit(self)


## Set or update a numeric/string modifier
func set_modifier(key: String, value: Variant) -> void:
	modifiers[key] = value
	modifiers_changed.emit(self)


## Remove a modifier
func remove_modifier(key: String) -> void:
	if modifiers.erase(key):
		modifiers_changed.emit(self)


## Get modifier value with fallback
func get_modifier(key: String, default_value: Variant = 0) -> Variant:
	return modifiers.get(key, default_value)


## Serializes slot state into a standard Dictionary
func to_dict() -> Dictionary:
	return {
		"side": side,
		"lane_index": lane_index,
		"affinity": affinity,
		"is_locked": is_locked,
		"is_disabled": is_disabled,
		"has_primary": primary_occupant != null,
		"has_attachment": attached_occupant != null,
		"modifiers": modifiers.duplicate()
	}
