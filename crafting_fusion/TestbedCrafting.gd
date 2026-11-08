extends Control

const CraftingEngine = preload("CraftingEngine.gd")

var engine: CraftingEngine
var player_inventory: Dictionary = {}
var player_currency: int = 200

@onready var recipe_option: OptionButton = $Layout/MainArea/Content/Left/RecipePicker
@onready var recipe_details: VBoxContainer = $Layout/MainArea/Content/Left/DetailsBox
@onready var craft_btn: Button = $Layout/MainArea/Content/Left/CraftButton
@onready var status_label: Label = $Layout/MainArea/Content/Left/StatusLabel
@onready var currency_label: Label = $Layout/Sidebar/CurrencyBox/CurrencyValue
@onready var inventory_list: ItemList = $Layout/Sidebar/InventoryList
@onready var stats_preview: Label = $Layout/MainArea/Content/Left/StatsPreview

func _ready() -> void:
	engine = CraftingEngine.new()

	# Connect signals
	engine.crafting_completed.connect(_on_crafting_completed)
	engine.crafting_failed.connect(_on_crafting_failed)

	# Configure quality tiers
	engine.configure_quality_tier(CraftingEngine.QualityTier.STANDARD, "Standard", 1.0)
	engine.configure_quality_tier(CraftingEngine.QualityTier.TIER_1, "Tier 1 (Gold)", 1.10)
	engine.configure_quality_tier(CraftingEngine.QualityTier.TIER_2, "Tier 2 (Obsidian)", 1.25)

	# Register sample recipes
	engine.register_recipe({
		"id": "recipe_flame_sword",
		"output_id": "Flame Greatsword",
		"output_count": 1,
		"cost": 100,
		"quality": CraftingEngine.QualityTier.TIER_1,
		"ingredients": [
			{ "item_id": "Iron Sword", "count": 1 },
			{ "item_id": "Flame Core", "count": 2 }
		],
		"metadata": { "base_atk": 20, "base_def": 10 }
	})

	engine.register_recipe({
		"id": "recipe_void_blade",
		"output_id": "Obsidian Void Blade",
		"output_count": 1,
		"cost": 250,
		"quality": CraftingEngine.QualityTier.TIER_2,
		"ingredients": [
			{ "item_id": "Flame Greatsword", "count": 1 },
			{ "item_id": "Void Shard", "count": 3 }
		],
		"metadata": { "base_atk": 30, "base_def": 15 }
	})

	engine.register_recipe({
		"id": "recipe_vitality_elixir",
		"output_id": "Elixir of Vitality",
		"output_count": 3,
		"cost": 25,
		"quality": CraftingEngine.QualityTier.STANDARD,
		"ingredients": [
			{ "item_id": "Sun Herb", "count": 2 },
			{ "item_id": "Spring Water", "count": 1 }
		],
		"metadata": { "base_heal": 50 }
	})

	# Default starter inventory
	player_inventory = {
		"Iron Sword": 2,
		"Flame Core": 3,
		"Void Shard": 1,
		"Sun Herb": 5,
		"Spring Water": 2
	}

	# Setup UI
	_setup_recipe_picker()
	_update_ui()


func _setup_recipe_picker() -> void:
	recipe_option.clear()
	var all_recipes = engine.get_all_recipes()
	for i in range(all_recipes.size()):
		var r = all_recipes[i]
		recipe_option.add_item("%s (%s)" % [r["output_id"], engine.get_quality_info(r["quality"])["name"]], i)
		recipe_option.set_item_metadata(i, r["id"])

	recipe_option.item_selected.connect(func(_idx): _update_ui())


func _get_selected_recipe() -> Dictionary:
	var idx = recipe_option.selected
	if idx < 0:
		return {}
	var r_id = recipe_option.get_item_metadata(idx)
	return engine.recipes.get(r_id, {})


func _update_ui() -> void:
	currency_label.text = "%d Gold" % player_currency

	# Update inventory list
	inventory_list.clear()
	for item_name in player_inventory.keys():
		var count = player_inventory[item_name]
		if count > 0:
			inventory_list.add_item("%s : x%d" % [item_name, count])

	# Update recipe details
	var recipe = _get_selected_recipe()
	if recipe.is_empty():
		return

	for c in recipe_details.get_children():
		c.queue_free()

	var check = CraftingEngine.check_can_craft(recipe, player_inventory, player_currency)

	# Ingredients breakdown
	for ing in recipe.get("ingredients", []):
		var item_id = ing["item_id"]
		var req = ing["count"]
		var have = player_inventory.get(item_id, 0)
		var lbl = Label.new()
		var ok = have >= req
		lbl.text = " • %s: %d / %d %s" % [item_id, have, req, "✓" if ok else "✗"]
		lbl.modulate = Color(0.4, 0.9, 0.4) if ok else Color(0.9, 0.3, 0.3)
		recipe_details.add_child(lbl)

	# Currency breakdown
	var cost = recipe.get("cost", 0)
	var curr_lbl = Label.new()
	var curr_ok = player_currency >= cost
	curr_lbl.text = " • Cost: %d Gold (%d available) %s" % [cost, player_currency, "✓" if curr_ok else "✗"]
	curr_lbl.modulate = Color(0.4, 0.9, 0.4) if curr_ok else Color(0.9, 0.3, 0.3)
	recipe_details.add_child(curr_lbl)

	# Stats preview
	var meta = recipe.get("metadata", {})
	if not meta.is_empty():
		var scaled = engine.compute_scaled_stats(meta, recipe.get("quality", 0))
		var preview_text = "Stat Scaling: "
		for k in meta.keys():
			preview_text += "%s: %d -> %d  " % [k.to_upper(), meta[k], scaled[k]]
		stats_preview.text = preview_text
	else:
		stats_preview.text = ""

	craft_btn.disabled = not check["can_craft"]
	if check["can_craft"]:
		status_label.text = "Ready to craft!"
		status_label.modulate = Color(0.4, 0.9, 0.4)
	else:
		status_label.text = check["reason"]
		status_label.modulate = Color(0.9, 0.4, 0.4)


func _on_craft_button_pressed() -> void:
	var recipe = _get_selected_recipe()
	if recipe.is_empty():
		return
	var res = engine.craft(recipe["id"], player_inventory, player_currency)
	if res.get("ok", false):
		player_currency = res["remaining_currency"]
	_update_ui()


func _on_crafting_completed(_recipe_id: String, output: Dictionary) -> void:
	status_label.text = output.get("reason", "Craft successful!")
	status_label.modulate = Color(0.3, 1.0, 0.3)


func _on_crafting_failed(_recipe_id: String, reason: String) -> void:
	status_label.text = reason
	status_label.modulate = Color(1.0, 0.3, 0.3)


func _on_add_currency_pressed(amount: int) -> void:
	player_currency += amount
	_update_ui()


func _on_add_ingredient_pressed(item_name: String, amount: int = 1) -> void:
	player_inventory[item_name] = player_inventory.get(item_name, 0) + amount
	_update_ui()
