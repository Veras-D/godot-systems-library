class_name GachaRoller
extends RefCounted

## Universal Weighted Drop-Table & Gacha Loot Box Roller
##
## Decoupled from specific items or currencies. Supports multiple drop pools,
## weighted probabilistic sampling, pity counters with guaranteed rarity thresholds,
## multi-roll batches, and RNG seed control.

signal item_rolled(pool_name: String, item: Dictionary)
signal pity_triggered(pool_name: String, guaranteed_rarity: String)

# pool_name (String) -> Array[Dictionary]
var _pools: Dictionary = {}

# pool_name (String) -> int (total cumulative weight)
var _total_weights: Dictionary = {}

# pool_name (String) -> int (current rolls without high rarity)
var _pity_counters: Dictionary = {}

# pool_name (String) -> Dictionary { "threshold": int, "guaranteed_rarity": String }
var _pity_rules: Dictionary = {}

var _default_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_default_rng.randomize()


## Registers an array of items for a named drop pool.
## Each item must contain at least:
## { "id": String, "weight": int, "rarity": String (optional), "metadata": Dictionary (optional) }
## Returns total valid items registered in pool.
func register_pool(pool_name: String, items: Array) -> int:
	var clean_name = pool_name.strip_edges()
	if clean_name == "":
		return 0

	var pool: Array[Dictionary] = []
	var total_w: int = 0

	for raw in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item_id = str(raw.get("id", raw.get("card_id", raw.get("CardID", "")))).strip_edges()
		if item_id == "":
			continue

		var w = int(raw.get("weight", raw.get("Weight", 1)))
		if w <= 0:
			continue

		var rarity = str(raw.get("rarity", raw.get("Quality", "Standard"))).strip_edges()
		var meta = raw.get("metadata", {}).duplicate(true)

		pool.append({
			"id": item_id,
			"weight": w,
			"rarity": rarity,
			"metadata": meta
		})
		total_w += w

	_pools[clean_name] = pool
	_total_weights[clean_name] = total_w
	if not _pity_counters.has(clean_name):
		_pity_counters[clean_name] = 0

	return pool.size()


## Configures a pity rule for a pool.
## If threshold rolls occur without rolling `guaranteed_rarity`, the next roll forces `guaranteed_rarity`.
func set_pity_rule(pool_name: String, threshold: int, guaranteed_rarity: String) -> void:
	_pity_rules[pool_name] = {
		"threshold": maxi(1, threshold),
		"guaranteed_rarity": guaranteed_rarity
	}


## Returns the current pity roll count for a pool.
func get_pity_count(pool_name: String) -> int:
	return int(_pity_counters.get(pool_name, 0))


## Manually resets the pity counter for a pool.
func reset_pity(pool_name: String) -> void:
	_pity_counters[pool_name] = 0


## Rolls a single item from the specified pool.
## Returns Dictionary:
## {
##   "ok": bool,
##   "id": String,
##   "rarity": String,
##   "is_pity": bool,
##   "pity_count": int,
##   "metadata": Dictionary
## }
func roll(pool_name: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if not _pools.has(pool_name) or _pools[pool_name].is_empty():
		return {
			"ok": false,
			"id": "",
			"rarity": "",
			"is_pity": false,
			"pity_count": 0,
			"metadata": {}
		}

	var active_rng = rng if rng != null else _default_rng
	var pity_rule = _pity_rules.get(pool_name, {})
	var is_pity_roll = false
	var target_rarity = ""

	if not pity_rule.is_empty():
		var threshold = int(pity_rule.get("threshold", 10))
		target_rarity = str(pity_rule.get("guaranteed_rarity", ""))
		if _pity_counters.get(pool_name, 0) >= threshold - 1:
			is_pity_roll = true

	var chosen_item: Dictionary = {}

	# If pity triggered, roll strictly from guaranteed_rarity sub-pool
	if is_pity_roll and target_rarity != "":
		var filtered = _filter_pool_by_rarity(pool_name, target_rarity)
		if not filtered.is_empty():
			chosen_item = _sample_weighted(filtered, active_rng)
			_pity_counters[pool_name] = 0
			pity_triggered.emit(pool_name, target_rarity)
		else:
			# Fallback if no items of that rarity exist
			chosen_item = _sample_weighted(_pools[pool_name], active_rng)
	else:
		chosen_item = _sample_weighted(_pools[pool_name], active_rng)

	# Update pity counter if not pity
	if not is_pity_roll:
		if not pity_rule.is_empty() and chosen_item.get("rarity", "") == target_rarity:
			_pity_counters[pool_name] = 0
		else:
			_pity_counters[pool_name] = _pity_counters.get(pool_name, 0) + 1

	var result = {
		"ok": true,
		"id": str(chosen_item.get("id", "")),
		"rarity": str(chosen_item.get("rarity", "")),
		"is_pity": is_pity_roll,
		"pity_count": _pity_counters.get(pool_name, 0),
		"metadata": chosen_item.get("metadata", {}).duplicate(true)
	}

	item_rolled.emit(pool_name, result)
	return result


## Rolls multiple items in a batch (e.g. 10x roll).
func roll_multi(pool_name: String, count: int, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for i in range(maxi(1, count)):
		var r = roll(pool_name, rng)
		if r.get("ok", false):
			results.append(r)
	return results


## Internal weighted selection using cumulative distribution.
func _sample_weighted(items: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var total_w = 0
	for it in items:
		total_w += int(it.get("weight", 1))

	if total_w <= 0:
		return items[0]

	var roll_val = rng.randi_range(1, total_w)
	var cumulative = 0
	for it in items:
		cumulative += int(it.get("weight", 1))
		if roll_val <= cumulative:
			return it

	return items[items.size() - 1]


func _filter_pool_by_rarity(pool_name: String, rarity: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for it in _pools.get(pool_name, []):
		if str(it.get("rarity", "")).to_lower() == rarity.to_lower():
			res.append(it)
	return res


## Serializes pity counters for persistence.
func serialize_pity() -> Dictionary:
	return _pity_counters.duplicate(true)


## Deserializes pity counters.
func deserialize_pity(data: Dictionary) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		for k in data.keys():
			_pity_counters[str(k)] = int(data[k])
