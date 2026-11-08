class_name ProgressionTracker
extends RefCounted

## Universal Experience & Level Progression Engine
##
## Decoupled leveling system supporting custom XP threshold tables, procedural curves,
## multi-level jumps, level caps (e.g. 1-50), and milestone level-up signals.

signal xp_gained(amount: int, current_xp: int)
signal level_up(old_level: int, new_level: int)
signal max_level_reached()

var current_level: int = 1
var current_xp: int = 0
var max_level: int = 50

# Optional custom XP threshold table: index 0 = XP to go from Lvl 1 -> 2, etc.
var custom_xp_table: Array[int] = []

# Procedural curve fallback parameters: required_xp = int(base_xp * pow(level, exponent))
var base_xp: int = 100
var curve_exponent: float = 1.2


func _init(p_max_level: int = 50, p_base_xp: int = 100, p_exponent: float = 1.2) -> void:
	max_level = maxi(1, p_max_level)
	base_xp = maxi(10, p_base_xp)
	curve_exponent = maxf(0.0, p_exponent)


## Sets a custom XP requirements table.
## table[i] is the XP needed to advance from level (i + 1) to (i + 2).
func set_custom_xp_table(table: Array[int]) -> void:
	custom_xp_table = table.duplicate()
	if not custom_xp_table.is_empty():
		max_level = custom_xp_table.size() + 1


## Returns XP required to advance from `level` to `level + 1`.
## Returns 0 if already at or beyond max_level.
func get_xp_for_level(level: int) -> int:
	if level >= max_level:
		return 0

	var idx = level - 1
	if idx >= 0 and idx < custom_xp_table.size():
		return maxi(1, custom_xp_table[idx])

	# Procedural curve fallback
	return maxi(10, int(round(float(base_xp) * pow(float(level), curve_exponent))))


## Returns the XP needed to advance from current_level to next.
func get_xp_for_next_level() -> int:
	return get_xp_for_level(current_level)


## Returns the current progress ratio towards the next level (0.0 to 1.0).
## Returns 1.0 if at max level.
func get_progress_ratio() -> float:
	if current_level >= max_level:
		return 1.0

	var needed = get_xp_for_next_level()
	if needed <= 0:
		return 1.0
	return clampf(float(current_xp) / float(needed), 0.0, 1.0)


## Checks if the tracker is at the maximum level.
func is_max_level() -> bool:
	return current_level >= max_level


## Adds XP to the tracker. Automatically processes multi-level jumps and caps at max_level.
## Returns Dictionary with progress telemetry:
## {
##   "leveled_up": bool,
##   "old_level": int,
##   "new_level": int,
##   "levels_gained": int,
##   "current_xp": int,
##   "xp_for_next": int,
##   "progress_ratio": float
## }
func add_xp(amount: int) -> Dictionary:
	if amount <= 0 or is_max_level():
		return {
			"leveled_up": false,
			"old_level": current_level,
			"new_level": current_level,
			"levels_gained": 0,
			"current_xp": current_xp,
			"xp_for_next": get_xp_for_next_level(),
			"progress_ratio": get_progress_ratio()
		}

	var start_level = current_level
	current_xp += amount
	xp_gained.emit(amount, current_xp)

	while current_level < max_level:
		var req = get_xp_for_next_level()
		if current_xp >= req:
			current_xp -= req
			var prev_lvl = current_level
			current_level += 1
			level_up.emit(prev_lvl, current_level)
			if current_level >= max_level:
				current_xp = 0
				max_level_reached.emit()
				break
		else:
			break

	var levels_gained = current_level - start_level
	return {
		"leveled_up": levels_gained > 0,
		"old_level": start_level,
		"new_level": current_level,
		"levels_gained": levels_gained,
		"current_xp": current_xp,
		"xp_for_next": get_xp_for_next_level(),
		"progress_ratio": get_progress_ratio()
	}


## Manually sets the level and resets XP to 0. Clamped to [1, max_level].
func set_level(level: int) -> void:
	current_level = clampi(level, 1, max_level)
	current_xp = 0


## Calculates a scaled stat value at current level.
## e.g. base_hp + (level - 1) * per_level_bonus.
func calculate_scaled_stat(base_val: float, per_level_bonus: float) -> float:
	return base_val + float(current_level - 1) * per_level_bonus


## Serializes progression state.
func serialize() -> Dictionary:
	return {
		"current_level": current_level,
		"current_xp": current_xp,
		"max_level": max_level
	}


## Deserializes progression state.
func deserialize(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	max_level = maxi(1, int(data.get("max_level", max_level)))
	current_level = clampi(int(data.get("current_level", 1)), 1, max_level)
	current_xp = maxi(0, int(data.get("current_xp", 0)))
