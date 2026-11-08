class_name CraftingEngine
extends RefCounted

## Universal Crafting, Recipe Matching, and Quality Multiplier Engine
##
## Decoupled from any specific game rules, asset databases, or inventory formats.
## Operates purely on generic item IDs, ingredient requirements, quality tiers,
## currency costs, and mutable inventory dictionaries.

enum QualityTier {
	STANDARD = 0,
	TIER_1 = 1,
	TIER_2 = 2
}

const DEFAULT_STANDARD_MULT: float = 1.0
const DEFAULT_TIER_1_MULT: float = 1.10
const DEFAULT_TIER_2_MULT: float = 1.25

# Quality tier configuration: tier (int) -> { "name": String, "multiplier": float }
var quality_tiers: Dictionary = {
	QualityTier.STANDARD: { "name": "Standard", "multiplier": DEFAULT_STANDARD_MULT },
	QualityTier.TIER_1: { "name": "Tier 1", "multiplier": DEFAULT_TIER_1_MULT },
	QualityTier.TIER_2: { "name": "Tier 2", "multiplier": DEFAULT_TIER_2_MULT }
}

# Recipe store: recipe_id (String) -> Dictionary
var recipes: Dictionary = {}

signal crafting_started(recipe_id: String)
signal crafting_completed(recipe_id: String, output: Dictionary)
signal crafting_failed(recipe_id: String, reason: String)


# ==============================================================================
# QUALITY TIER & STAT SCALING
# ==============================================================================

## Configures or updates a quality tier's display name and stat multiplier.
func configure_quality_tier(tier: int, name: String, multiplier: float) -> void:
	quality_tiers[tier] = {
		"name": name,
		"multiplier": maxf(0.0, multiplier)
	}


## Returns quality tier info dictionary { "name": String, "multiplier": float }.
func get_quality_info(tier: int) -> Dictionary:
	return quality_tiers.get(tier, { "name": "Standard", "multiplier": 1.0 })


## Returns stat multiplier for a quality tier.
func get_stat_multiplier(tier: int) -> float:
	var info = get_quality_info(tier)
	return float(info.get("multiplier", 1.0))


## Computes scaled numeric stats for a dictionary of { "stat_name": int/float } at a given tier.
## Guarantees scaled stat is at least base + 1 when base > 0 and multiplier > 1.0.
func compute_scaled_stats(base_stats: Dictionary, tier: int) -> Dictionary:
	var mult = get_stat_multiplier(tier)
	var scaled: Dictionary = {}
	for key in base_stats.keys():
		var val = base_stats[key]
		if typeof(val) == TYPE_INT:
			if mult == 1.0 or val == 0:
				scaled[key] = val
			else:
				scaled[key] = int(ceil(float(val) * mult))
		elif typeof(val) == TYPE_FLOAT:
			scaled[key] = float(val) * mult
		else:
			scaled[key] = val
	return scaled


# ==============================================================================
# RECIPE REGISTRATION & DISCOVERY
# ==============================================================================

## Registers a recipe dictionary.
## Expected schema:
## {
##   "id": String (optional, defaults to output_id),
##   "output_id": String,
##   "output_count": int (default 1),
##   "cost": int (default 0),
##   "quality": int (default 0),
##   "ingredients": Array[Dictionary] (each { "item_id": String, "count": int }),
##   "metadata": Dictionary (optional)
## }
func register_recipe(recipe_dict: Dictionary) -> bool:
	var out_id = str(recipe_dict.get("output_id", recipe_dict.get("card_id", ""))).strip_edges()
	if out_id == "":
		return false

	var r_id = str(recipe_dict.get("id", out_id)).strip_edges()
	var cost = int(recipe_dict.get("cost", 0))
	var out_count = int(recipe_dict.get("output_count", 1))
	var quality = int(recipe_dict.get("quality", 0))
	var metadata = recipe_dict.get("metadata", {}).duplicate(true)

	var ingredients: Array[Dictionary] = []
	for raw_ing in recipe_dict.get("ingredients", []):
		if typeof(raw_ing) != TYPE_DICTIONARY:
			continue
		var i_id = str(raw_ing.get("item_id", raw_ing.get("card_id", ""))).strip_edges()
		if i_id == "":
			continue
		var i_cnt = int(raw_ing.get("count", 1))
		if i_cnt <= 0:
			i_cnt = 1
		ingredients.append({
			"item_id": i_id,
			"count": i_cnt
		})

	if ingredients.is_empty():
		return false

	var normalized: Dictionary = {
		"id": r_id,
		"output_id": out_id,
		"output_count": out_count,
		"cost": cost,
		"quality": quality,
		"ingredients": ingredients,
		"metadata": metadata
	}

	recipes[r_id] = normalized
	return true


## Loads an array of raw recipe dictionaries into the engine. Returns number of registered recipes.
func load_recipes_from_array(recipe_list: Array) -> int:
	var count: int = 0
	for raw in recipe_list:
		if typeof(raw) == TYPE_DICTIONARY:
			if register_recipe(raw):
				count += 1
	return count


## Returns all recipes that require the given ingredient item_id.
func find_recipes_for_ingredient(item_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for r in recipes.values():
		for ing in r.get("ingredients", []):
			if str(ing.get("item_id", "")) == item_id:
				result.append(r)
				break
	return result


## Returns all recipes that produce the given output_id.
func find_recipes_for_output(output_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for r in recipes.values():
		if str(r.get("output_id", "")) == output_id:
			result.append(r)
	return result


## Returns all registered recipes as an Array.
func get_all_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for r in recipes.values():
		result.append(r)
	return result


# ==============================================================================
# VALIDATION & CRAFTING EXECUTION
# ==============================================================================

## Checks if a recipe can be crafted with current inventory and available currency.
## Inventory is a Dictionary mapping item_id (String) -> count (int).
## Returns { "can_craft": bool, "missing_currency": int, "missing_ingredients": Array[Dictionary], "reason": String }
static func check_can_craft(
	recipe: Dictionary,
	inventory: Dictionary,
	available_currency: int = 0
) -> Dictionary:
	var cost: int = int(recipe.get("cost", 0))
	var missing_currency: int = maxi(0, cost - available_currency)
	var missing_ingredients: Array[Dictionary] = []

	var ingredients: Array = recipe.get("ingredients", [])
	for ing in ingredients:
		var item_id = str(ing.get("item_id", ing.get("card_id", "")))
		var req = int(ing.get("count", 1))
		var have = int(inventory.get(item_id, 0))
		if have < req:
			missing_ingredients.append({
				"item_id": item_id,
				"required": req,
				"owned": have,
				"missing": req - have
			})

	var can_craft = (missing_currency == 0) and missing_ingredients.is_empty()
	var reason = ""
	if not missing_ingredients.is_empty():
		var first = missing_ingredients[0]
		reason = "Missing %dx %s (%d/%d owned)." % [first["missing"], first["item_id"], first["owned"], first["required"]]
	elif missing_currency > 0:
		reason = "Need %d more currency (Cost: %d, Available: %d)." % [missing_currency, cost, available_currency]

	return {
		"can_craft": can_craft,
		"missing_currency": missing_currency,
		"missing_ingredients": missing_ingredients,
		"reason": reason
	}


## Executes a craft: deducts ingredients and currency, increments output count, and returns execution result.
## Modifies inventory dictionary in-place and returns:
## {
##   "ok": bool,
##   "output_id": String,
##   "output_quality": int,
##   "output_count": int,
##   "remaining_currency": int,
##   "inventory": Dictionary,
##   "reason": String
## }
static func execute_craft(
	recipe: Dictionary,
	inventory: Dictionary,
	available_currency: int = 0
) -> Dictionary:
	var check = check_can_craft(recipe, inventory, available_currency)
	if not check.get("can_craft", false):
		return {
			"ok": false,
			"output_id": "",
			"output_quality": 0,
			"output_count": 0,
			"remaining_currency": available_currency,
			"inventory": inventory,
			"reason": str(check.get("reason", "Requirements not met."))
		}

	var cost: int = int(recipe.get("cost", 0))
	var remaining_curr: int = available_currency - cost

	# Deduct ingredients
	for ing in recipe.get("ingredients", []):
		var item_id = str(ing.get("item_id", ing.get("card_id", "")))
		var req = int(ing.get("count", 1))
		inventory[item_id] = maxi(0, int(inventory.get(item_id, 0)) - req)

	# Increment output
	var out_id = str(recipe.get("output_id", recipe.get("card_id", "")))
	var out_count = int(recipe.get("output_count", 1))
	var quality = int(recipe.get("quality", 0))

	inventory[out_id] = int(inventory.get(out_id, 0)) + out_count

	return {
		"ok": true,
		"output_id": out_id,
		"output_quality": quality,
		"output_count": out_count,
		"remaining_currency": remaining_curr,
		"inventory": inventory,
		"reason": "Successfully crafted %dx %s!" % [out_count, out_id]
	}


## Instance wrapper around execute_craft that also emits signals.
func craft(recipe_id: String, inventory: Dictionary, available_currency: int = 0) -> Dictionary:
	if not recipes.has(recipe_id):
		var err = "Recipe '%s' not registered." % recipe_id
		crafting_failed.emit(recipe_id, err)
		return {
			"ok": false,
			"output_id": "",
			"output_quality": 0,
			"output_count": 0,
			"remaining_currency": available_currency,
			"inventory": inventory,
			"reason": err
		}

	crafting_started.emit(recipe_id)
	var recipe = recipes[recipe_id]
	var res = execute_craft(recipe, inventory, available_currency)
	if res.get("ok", false):
		crafting_completed.emit(recipe_id, res)
	else:
		crafting_failed.emit(recipe_id, str(res.get("reason", "")))
	return res
