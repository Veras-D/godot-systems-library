extends SceneTree

const CraftingEngine = preload("CraftingEngine.gd")

func _init() -> void:
	print("==> Running CraftingEngine Unit & Regression Tests...")

	var engine = CraftingEngine.new()

	# --------------------------------------------------------------------------
	# 1. Quality Tiers & Stat Scaling
	# --------------------------------------------------------------------------
	print("Test 1: Quality Tier & Multiplier Scaling...")
	var std_info = engine.get_quality_info(CraftingEngine.QualityTier.STANDARD)
	assert(std_info["multiplier"] == 1.0, "Standard tier multiplier should be 1.0")

	var t1_info = engine.get_quality_info(CraftingEngine.QualityTier.TIER_1)
	assert(is_equal_approx(t1_info["multiplier"], 1.10), "Tier 1 multiplier should be 1.10")

	var t2_info = engine.get_quality_info(CraftingEngine.QualityTier.TIER_2)
	assert(is_equal_approx(t2_info["multiplier"], 1.25), "Tier 2 multiplier should be 1.25")

	var base_stats = { "atk": 10, "def": 20, "speed": 5.0 }
	var scaled_t1 = engine.compute_scaled_stats(base_stats, CraftingEngine.QualityTier.TIER_1)
	assert(scaled_t1["atk"] == 11, "ATK 10 * 1.10 = 11")
	assert(scaled_t1["def"] == 22, "DEF 20 * 1.10 = 22")
	assert(is_equal_approx(scaled_t1["speed"], 5.5), "Speed 5.0 * 1.10 = 5.5")

	var scaled_t2 = engine.compute_scaled_stats(base_stats, CraftingEngine.QualityTier.TIER_2)
	assert(scaled_t2["atk"] == 13, "ATK 10 * 1.25 ceil = 13")
	assert(scaled_t2["def"] == 25, "DEF 20 * 1.25 ceil = 25")

	# Custom quality tier configuration
	engine.configure_quality_tier(3, "Mythic", 1.50)
	var mythic_scaled = engine.compute_scaled_stats(base_stats, 3)
	assert(mythic_scaled["atk"] == 15, "Mythic ATK 10 * 1.50 = 15")
	print("  ✔ Quality scaling passed.")

	# --------------------------------------------------------------------------
	# 2. Recipe Registration & Discovery
	# --------------------------------------------------------------------------
	print("Test 2: Recipe Registration & Discovery...")
	var r1 = {
		"id": "recipe_flame_sword",
		"output_id": "item_flame_sword",
		"output_count": 1,
		"cost": 100,
		"quality": 1,
		"ingredients": [
			{ "item_id": "item_iron_sword", "count": 1 },
			{ "item_id": "item_fire_gem", "count": 2 }
		]
	}
	var r2 = {
		"id": "recipe_fire_potion",
		"output_id": "item_fire_potion",
		"output_count": 3,
		"cost": 25,
		"quality": 0,
		"ingredients": [
			{ "item_id": "item_water_vial", "count": 1 },
			{ "item_id": "item_fire_gem", "count": 1 }
		]
	}

	assert(engine.register_recipe(r1) == true, "Recipe 1 should register successfully")
	assert(engine.register_recipe(r2) == true, "Recipe 2 should register successfully")

	# Invalid recipe with no ingredients
	var r_invalid = { "id": "invalid", "output_id": "item_nothing", "ingredients": [] }
	assert(engine.register_recipe(r_invalid) == false, "Empty recipe should fail registration")

	# Discovery by ingredient
	var fire_gem_recipes = engine.find_recipes_for_ingredient("item_fire_gem")
	assert(fire_gem_recipes.size() == 2, "Both recipes require item_fire_gem")

	var iron_sword_recipes = engine.find_recipes_for_ingredient("item_iron_sword")
	assert(iron_sword_recipes.size() == 1, "Only recipe 1 requires item_iron_sword")

	# Discovery by output
	var sword_outputs = engine.find_recipes_for_output("item_flame_sword")
	assert(sword_outputs.size() == 1, "Should find 1 recipe producing item_flame_sword")
	print("  ✔ Registration & discovery passed.")

	# --------------------------------------------------------------------------
	# 3. Validation & Execution
	# --------------------------------------------------------------------------
	print("Test 3: Crafting Validation & Execution...")
	var inventory: Dictionary = {
		"item_iron_sword": 1,
		"item_fire_gem": 1 # Needs 2!
	}
	var currency: int = 50 # Needs 100!

	# Check fails: missing 1 fire gem and 50 coins
	var check = CraftingEngine.check_can_craft(r1, inventory, currency)
	assert(check["can_craft"] == false, "Crafting should be invalid")
	assert(check["missing_currency"] == 50, "Should be missing 50 currency")
	assert(check["missing_ingredients"].size() == 1, "Should be missing 1 ingredient type")
	assert(check["missing_ingredients"][0]["missing"] == 1, "Missing 1 fire gem")

	# Add missing resources
	inventory["item_fire_gem"] = 3
	currency = 150

	var check_ok = CraftingEngine.check_can_craft(r1, inventory, currency)
	assert(check_ok["can_craft"] == true, "Crafting should now be valid")

	# Track signals
	var signal_completed: Array = []
	engine.crafting_completed.connect(func(r_id, out): signal_completed.append({ "id": r_id, "out": out }))

	# Execute craft
	var result = engine.craft("recipe_flame_sword", inventory, currency)
	assert(result["ok"] == true, "Craft execution should succeed")
	assert(result["output_id"] == "item_flame_sword", "Output should match recipe")
	assert(result["output_quality"] == 1, "Quality should be tier 1")
	assert(result["remaining_currency"] == 50, "Currency 150 - 100 = 50")
	assert(inventory["item_iron_sword"] == 0, "Iron sword should be consumed (1 - 1 = 0)")
	assert(inventory["item_fire_gem"] == 1, "Fire gems should be consumed (3 - 2 = 1)")
	assert(inventory["item_flame_sword"] == 1, "Flame sword should be added to inventory")

	assert(signal_completed.size() == 1, "crafting_completed signal should have fired once")
	assert(signal_completed[0]["id"] == "recipe_flame_sword", "Signal recipe ID should match")
	print("  ✔ Validation & execution passed.")

	print("\nALL CRAFTING TESTS COMPLETED SUCCESSFULLY!")
	quit(0)
