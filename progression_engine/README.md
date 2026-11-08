# Universal Progression & Economy Engine (`progression_engine`)

A standalone, completely decoupled economy, experience progression, and gacha drop-table system for **Godot 4**.

---

## 🎯 Features

- **Multi-Currency Wallet (`CurrencyWallet`)**:
  - Atomic transactions for soft currency (coins), premium currency (gems), and energy/stamina timers.
  - Maximum balance caps, overflow protection, and overdraft safeguards.
  - Inter-wallet transfers and JSON serialization.
  - Real-time balance change and insufficient funds signals.
- **Universal Experience & Level Progression (`ProgressionTracker`)**:
  - Custom XP requirements tables or procedural exponential curves (`base_xp * level^exponent`).
  - Seamless multi-level jumps when large XP batches are awarded.
  - Level caps (e.g. 1 to 50) and progress ratios (0.0 to 1.0).
  - Scaled stat calculation helpers (`calculate_scaled_stat`).
- **Gacha Drop-Table & Pity Roller (`GachaRoller`)**:
  - Weighted probabilistic selection across customizable item pools.
  - Configurable pity counter rules with guaranteed rarity thresholds.
  - Multi-roll batch execution (1x, 10x).
  - Seed-controlled RNG for reproducible rolls and testing.
- **Standalone Testbed (`testbed_progression.tscn`)**:
  - Interactive workbench with wallet buttons, XP granting, live progress bars, level-up notifications, and loot box pull telemetry.

---

## 📂 File Structure

```text
progression_engine/
├── CurrencyWallet.gd          # Multi-currency ledger & transaction safe
├── ProgressionTracker.gd      # XP curves, level caps & stat scaling
├── GachaRoller.gd             # Weighted drop-tables & pity counters
├── TestbedProgression.gd      # Interactive testbed controller
├── testbed_progression.tscn   # Runnable UI workbench
├── test_progression_engine.gd # Headless unit test suite
└── README.md                  # System documentation
```

---

## 🚀 Quick Start Examples

### Multi-Currency Wallet
```gdscript
const CurrencyWallet = preload("res://src/systems/progression_engine/CurrencyWallet.gd")

var wallet = CurrencyWallet.new()
wallet.register_currency("gold", 500, 10000)
wallet.register_currency("gems", 10, 100)

if wallet.withdraw("gold", 100):
    print("Remaining gold: ", wallet.get_balance("gold"))
```

### Level Progression
```gdscript
const ProgressionTracker = preload("res://src/systems/progression_engine/ProgressionTracker.gd")

var hero_level = ProgressionTracker.new(50, 100, 1.2)
hero_level.level_up.connect(func(old_lvl, new_lvl): print("Level Up! ", old_lvl, " -> ", new_lvl))

var res = hero_level.add_xp(350)
print("Current Level: ", hero_level.current_level)
```

### Gacha Roller with Pity
```gdscript
const GachaRoller = preload("res://src/systems/progression_engine/GachaRoller.gd")

var gacha = GachaRoller.new()
gacha.register_pool("chests", [
    { "id": "iron_sword", "weight": 90, "rarity": "Common" },
    { "id": "mythic_blade", "weight": 10, "rarity": "Legendary" }
])
gacha.set_pity_rule("chests", 10, "Legendary")

var item = gacha.roll("chests")
print("Rolled: ", item["id"], " (Pity: ", item["is_pity"], ")")
```

---

## 🧪 Running the Automated Test Suite

```bash
godot --headless -s res://progression_engine/test_progression_engine.gd
```
Or run the full systems suite via `res://run_tests.gd`.
