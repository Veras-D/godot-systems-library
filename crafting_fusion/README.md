# Universal Crafting & Quality Engine (`crafting_fusion`)

A standalone, completely decoupled crafting, recipe matching, and item quality scaling system for **Godot 4**.

---

## 🎯 Features

- **Universal Recipe Matcher**: Register recipes with dynamic ingredient requirements, output quantities, currency costs, and quality tiers.
- **Inventory & Currency Ledger**: Validates required ingredients vs owned counts with detailed deficiency telemetry (`missing_ingredients`, `missing_currency`).
- **Quality Tier Stat Multipliers**: Configurable quality levels (e.g. Standard `1.0x`, Tier 1 / Gold `1.10x`, Tier 2 / Obsidian `1.25x`) with automatic rounding and integer preservation.
- **Bidirectional Recipe Discovery**: Query recipes that consume an ingredient or produce a target output.
- **Signal-Driven Workflow**: Emits `crafting_started`, `crafting_completed`, and `crafting_failed` signals.
- **Standalone Testbed**: Runnable isolated scene (`testbed_crafting.tscn`) to test and simulate recipes without any game client.

---

## 📂 File Structure

```text
crafting_fusion/
├── CraftingEngine.gd        # Core engine, quality scaler & static helpers
├── TestbedCrafting.gd       # Interactive testbed controller
├── testbed_crafting.tscn    # Runnable UI workbench
├── test_crafting_engine.gd  # Headless unit test suite
└── README.md                # System documentation
```

---

## 🚀 Quick Start Example

```gdscript
const CraftingEngine = preload("res://src/systems/crafting_fusion/CraftingEngine.gd")

var engine = CraftingEngine.new()

# 1. Register a recipe
engine.register_recipe({
    "id": "recipe_iron_shield",
    "output_id": "Iron Shield",
    "output_count": 1,
    "cost": 50,
    "quality": CraftingEngine.QualityTier.STANDARD,
    "ingredients": [
        { "item_id": "Iron Ingot", "count": 2 },
        { "item_id": "Wood Plank", "count": 1 }
    ]
})

# 2. Check if player can craft
var inventory = { "Iron Ingot": 2, "Wood Plank": 1 }
var player_coins = 100

var check = CraftingEngine.check_can_craft(engine.recipes["recipe_iron_shield"], inventory, player_coins)
if check["can_craft"]:
    var result = engine.craft("recipe_iron_shield", inventory, player_coins)
    print("Crafted: ", result["output_id"])
    print("Remaining Coins: ", result["remaining_currency"])
```

---

## 🧪 Running the Testbed

In Godot 4:
```bash
godot crafting_fusion/testbed_crafting.tscn
```
Or run the headless automated test suite:
```bash
godot --headless -s res://crafting_fusion/test_crafting_engine.gd
```
