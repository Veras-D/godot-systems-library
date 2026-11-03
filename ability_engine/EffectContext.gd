class_name EffectContext
extends RefCounted

## Context bundle passed along during effect resolution.
## Contains source references, selected targets, coordinates, and arbitrary game-state bindings.

var source: Variant = null               # Node or dictionary representing the source entity
var source_side: int = 0                 # Allegiance / Team (0 = Friendly / Player, 1 = Opponent)
var source_lane: int = 0                 # 0-indexed lane/column (backwards compatibility)
var source_coord: Variant = null         # Generic spatial coordinate (Vector2i lane/grid, Vector3i axial/cube hex)
var targets: Array = []                  # Resolved array of target nodes or dictionaries
var trigger_name: String = ""            # The trigger that fired this (e.g. "ON_PLAY", "ON_SUMMON")
var variables: Dictionary = {}           # Dynamic state (e.g. {"roll_multiplier": 2.0, "board": board_node})


static func create(
	p_source: Variant = null,
	p_source_side: int = 0,
	p_source_lane: int = 0,
	p_targets: Array = [],
	p_trigger: String = "",
	p_source_coord: Variant = null
) -> EffectContext:
	var ctx = new()
	ctx.source = p_source
	ctx.source_side = p_source_side
	ctx.source_lane = p_source_lane
	ctx.source_coord = p_source_coord if p_source_coord != null else Vector2i(p_source_side, p_source_lane)
	ctx.targets = p_targets.duplicate()
	ctx.trigger_name = p_trigger
	return ctx


func get_coordinate() -> Variant:
	return source_coord if source_coord != null else Vector2i(source_side, source_lane)


func set_var(key: String, val: Variant) -> void:
	variables[key] = val


func get_var(key: String, default_val: Variant = null) -> Variant:
	return variables.get(key, default_val)
