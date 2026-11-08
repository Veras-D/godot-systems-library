class_name StarConditionEvaluator
extends RefCounted

## Universal 3-Star Objective & Match Telemetry Evaluator
##
## Evaluates post-match outcome telemetry against modular rule conditions.
## Decoupled from specific game lore, supporting turn limits, health loss bounds,
## deck type/faction constraints, kill counts, and custom lambdas.


## Evaluates a single condition against a match_stats dictionary.
## Returns true if the condition was met.
static func evaluate_condition(condition: Dictionary, stats: Dictionary) -> bool:
	if condition.is_empty():
		return false

	# Must at least have won the match unless specifically stated otherwise
	var require_win = bool(condition.get("require_win", true))
	if require_win and not bool(stats.get("won", false)):
		return false

	var cond_id = str(condition.get("id", condition.get("type", ""))).strip_edges()

	# 1. Direct Rule: JustWin
	if cond_id == "JustWin":
		return bool(stats.get("won", false))

	# 2. Turn Limits (FastWin)
	var max_turns = int(condition.get("max_turns", condition.get("MaxTurns", 0)))
	if max_turns <= 0 and cond_id.begins_with("FastWin"):
		var suffix = cond_id.replace("FastWin", "")
		if suffix.is_valid_int():
			max_turns = int(suffix)
	if max_turns > 0:
		var turns_taken = int(stats.get("turns", 0))
		if turns_taken > max_turns:
			return false

	# 3. Maximum HP Lost
	var max_hp = int(condition.get("max_hp_lost", condition.get("MaxHPLost", -1)))
	if max_hp < 0 and cond_id.begins_with("Only") and cond_id.ends_with("HP"):
		var num_str = cond_id.replace("Only", "").replace("HP", "")
		if num_str.is_valid_int():
			max_hp = int(num_str)
	if max_hp >= 0:
		var hp_lost = int(stats.get("player_hp_lost", 0))
		if hp_lost > max_hp:
			return false

	# 4. Maximum Friendly Creatures Lost
	var max_creatures_lost = int(condition.get("max_creatures_lost", condition.get("MaxNumCreaturesLost", -1)))
	if max_creatures_lost < 0 and cond_id.begins_with("OnlyLose") and cond_id.ends_with("Creatures"):
		var num_str = cond_id.replace("OnlyLose", "").replace("Creatures", "")
		if num_str.is_valid_int():
			max_creatures_lost = int(num_str)
	if max_creatures_lost >= 0:
		var creatures_lost = int(stats.get("player_creatures_lost", 0))
		if creatures_lost > max_creatures_lost:
			return false

	# 5. Minimum Enemy Creatures Defeated
	var min_defeated = int(condition.get("min_creatures_defeated", condition.get("MinCreaturesDefeated", 0)))
	if min_defeated <= 0 and cond_id.begins_with("Defeat"):
		var num_str = cond_id.replace("Defeat", "")
		if num_str.is_valid_int():
			min_defeated = int(num_str)
	elif min_defeated <= 0 and cond_id.begins_with("Deafeat"): # Handles typo in legacy data
		var num_str = cond_id.replace("Deafeat", "")
		if num_str.is_valid_int():
			min_defeated = int(num_str)
	if min_defeated > 0:
		var defeated_count = int(stats.get("enemy_creatures_defeated", 0))
		if defeated_count < min_defeated:
			return false

	# 6. Minimum Landscapes Used
	var min_lands = int(condition.get("min_landscapes", condition.get("MinLandscapesUsed", 0)))
	if min_lands <= 0 and cond_id.begins_with("Landscapes_"):
		var suffix = cond_id.replace("Landscapes_", "").to_lower()
		match suffix:
			"two", "2": min_lands = 2
			"three", "3": min_lands = 3
			"four", "4": min_lands = 4
	if min_lands > 0:
		var lands_count = int(stats.get("landscapes_count", 0))
		if lands_count < min_lands:
			return false

	# 7. Maximum Deck Cost
	var max_deck_cost = int(condition.get("max_deck_cost", condition.get("MaxDeckCost", 0)))
	if max_deck_cost <= 0 and cond_id.begins_with("MaxCost"):
		var num_str = cond_id.replace("MaxCost", "")
		if num_str.is_valid_int():
			max_deck_cost = int(num_str)
	if max_deck_cost > 0:
		var deck_cost = int(stats.get("deck_cost", 0))
		if deck_cost > max_deck_cost:
			return false

	# 8. Card Type Restrictions (Allowed / Forbidden)
	var played_types: Array = stats.get("card_types_played", [])
	var allowed_types: Array[String] = _parse_string_or_array(condition.get("allowed_types", condition.get("AllowedTypes", [])))
	var forbidden_types: Array[String] = _parse_string_or_array(condition.get("forbidden_types", condition.get("ForbiddenTypes", [])))

	# Handle condition ID shortcuts (e.g. Forbid_Spells, Only_Creatures)
	if cond_id == "Forbid_Spells" and forbidden_types.is_empty():
		forbidden_types.append("spell")
	elif cond_id == "Forbid_Creatures" and forbidden_types.is_empty():
		forbidden_types.append("creature")
	elif cond_id == "Forbid_Buildings" and forbidden_types.is_empty():
		forbidden_types.append("building")
	elif cond_id == "Only_Creatures" and allowed_types.is_empty():
		allowed_types.append("creature")
	elif cond_id == "Only_Spells" and allowed_types.is_empty():
		allowed_types.append("spell")

	for t in played_types:
		var norm_t = str(t).to_lower().strip_edges()
		if not forbidden_types.is_empty() and _matches_list(norm_t, forbidden_types):
			return false
		if not allowed_types.is_empty() and not _matches_list(norm_t, allowed_types):
			return false

	# 9. Faction Restrictions (Allowed / Forbidden)
	var played_factions: Array = stats.get("factions_played", [])
	var allowed_factions: Array[String] = _parse_string_or_array(condition.get("allowed_factions", condition.get("AllowedFactions", [])))
	var forbidden_factions: Array[String] = _parse_string_or_array(condition.get("forbidden_factions", condition.get("ForbiddenFactions", [])))

	# Handle condition ID shortcuts (e.g. Forbid_Corn, Only_Plains)
	if cond_id.begins_with("Forbid_") and forbidden_factions.is_empty():
		var fac = cond_id.replace("Forbid_", "")
		if fac != "Spells" and fac != "Creatures" and fac != "Buildings":
			forbidden_factions.append(fac.to_lower())
	elif cond_id.begins_with("Only_") and allowed_factions.is_empty():
		var fac = cond_id.replace("Only_", "")
		if fac != "Spells" and fac != "Creatures":
			allowed_factions.append(fac.to_lower())
		if fac != "Spells" and fac != "Creatures":
			allowed_factions = [fac]

	for f in played_factions:
		var norm_f = str(f).to_lower().strip_edges()
		if not forbidden_factions.is_empty() and _matches_list(norm_f, forbidden_factions):
			return false
		if not allowed_factions.is_empty() and not _matches_list(norm_f, allowed_factions):
			return false

	# 10. Custom Callable / Lambda Evaluation
	if condition.has("evaluator") and condition["evaluator"] is Callable:
		var callable: Callable = condition["evaluator"]
		if not callable.call(stats):
			return false

	return true


## Evaluates an array of up to 3 conditions and returns an Array[bool] results.
static func evaluate_star_conditions(conditions: Array, stats: Dictionary) -> Array[bool]:
	var results: Array[bool] = []
	for cond in conditions:
		if typeof(cond) == TYPE_DICTIONARY:
			results.append(evaluate_condition(cond, stats))
		else:
			results.append(false)
	return results


## Evaluates an array of conditions and returns the total number of stars earned (0 to 3).
static func count_stars_earned(conditions: Array, stats: Dictionary) -> int:
	var stars = 0
	for cond in conditions:
		if typeof(cond) == TYPE_DICTIONARY and evaluate_condition(cond, stats):
			stars += 1
	return clampi(stars, 0, 3)


# Helper: Parses string ("Plains, Corn") or Array into a clean lowercased Array[String]
static func _parse_string_or_array(raw) -> Array[String]:
	var res: Array[String] = []
	if typeof(raw) == TYPE_STRING:
		var s = str(raw).strip_edges()
		if s != "":
			for part in s.split(","):
				var item = part.strip_edges().to_lower()
				if item != "":
					res.append(item)
	elif typeof(raw) == TYPE_ARRAY:
		for item in raw:
			var s = str(item).strip_edges().to_lower()
			if s != "":
				res.append(s)
	return res


static func _matches_list(val: String, list: Array) -> bool:
	var target = val.to_lower().strip_edges()
	for it in list:
		if target == it.to_lower().strip_edges():
			return true
	return false
