# Timing Wheel System (Standalone Godot 4 Module)

A completely decoupled, customizable reaction roulette and timing wheel minigame system for Godot 4.

Designed following the **Systems-First** architecture: zero project-specific coupling, fully unit-testable in isolation, and ready to be dropped directly into any Godot project (racing games, casino UI, reaction minigames, combat clash meters, loot spinners).

---

## Features

- **Custom Vector Graphics**: Procedural pie slice rendering with customizable colors, boundary lines, and animated needle with drop shadow.
- **Data-Driven Configuration (`WheelConfig.gd`)**:
  - Arbitrary number of sectors with custom IDs, names, ratios, multipliers, and colors.
  - Neutral built-in factory presets:
    - `create_tiered()` (3-tier standard / bonus / failure outcome)
    - `create_coin_flip()` (50/50 binary choice)
    - `create_quadrants()` (4 equal quadrants)
    - `create_custom()` (arbitrary sectors and speeds)
  - Rotational speed control (degrees per second, clockwise or counter-clockwise).
- **Smooth Kinetics & Deceleration**:
  - Minimum spin duration to prevent premature instant taps.
  - Smooth deceleration curve when stopping.
- **Quick-Resolve Mode**:
  - Deterministic instantaneous roll mode for AI, automated simulations, or players who want to skip the spinner animation.
- **Isolated Testbed Scene (`testbed_wheel.tscn`)**:
  - Run the testbed directly to tweak parameters, test presets, and run 1,000-spin Monte Carlo tests.

---

## Quick Start / Integration

> [!NOTE]
> Examples use relative preloads; adjust paths to match wherever you installed or cloned the module folder in your project.

### 1. Instantiate the Spinner
```gdscript
const WheelSpinner = preload("WheelSpinner.gd")
const WheelConfig = preload("WheelConfig.gd")

var wheel_scene = preload("WheelSpinner.tscn")
var wheel = wheel_scene.instantiate() as WheelSpinner
add_child(wheel)
```

### 2. Configure Sectors & Speed

#### Option A: Using a Neutral Preset
```gdscript
# 3-Tier Wheel: 70% Success, 10% Bonus, 20% Failure
var config = WheelConfig.create_tiered(0.70, 0.10)
wheel.setup(config)

wheel.spin_completed.connect(_on_wheel_result)
wheel.start_spin()
```

#### Option B: Building a Custom Wheel
```gdscript
var sectors = [
    {
        "id": "jackpot",
        "name": "JACKPOT!",
        "ratio": 0.05,
        "color": Color(1.0, 0.85, 0.2),
        "multiplier": 5.0,
        "is_success": true
    },
    {
        "id": "regular",
        "name": "REGULAR PRIZE",
        "ratio": 0.75,
        "color": Color(0.2, 0.7, 1.0),
        "multiplier": 1.0,
        "is_success": true
    },
    {
        "id": "miss",
        "name": "TRY AGAIN",
        "ratio": 0.20,
        "color": Color(0.85, 0.25, 0.25),
        "multiplier": 0.0,
        "is_success": false
    }
]
var config = WheelConfig.create_custom(sectors, 1600.0)
wheel.setup(config)
```

### 3. Handle the Result
```gdscript
func _on_wheel_result(result: Dictionary) -> void:
    print("Landed on: ", result.name)              # "JACKPOT!"
    print("Multiplier: ", result.multiplier)       # 5.0
    print("Final Angle: ", result.angle_deg)       # 45.2°
```

### 4. Typed Result Contract (`WheelResult`)

Outcomes from `wheel.get_last_result()`, `config.get_sector_at_angle()`, and `config.roll_quick_resolve()` return typed `WheelConfig.WheelResult` instances with full GDScript static type safety:

```gdscript
var outcome: WheelConfig.WheelResult = wheel.get_last_result()
if outcome.id == WheelConfig.ID_PARTIAL:
    print("Bonus multiplier: ", outcome.multiplier)
elif outcome.id == WheelConfig.ID_SUCCESS:
    print("Standard success: ", outcome.multiplier)

# Dict access or serialization:
var outcome_dict: Dictionary = outcome.to_dict()
# Or direct dictionary methods on config:
var dict_res = config.roll_quick_resolve_dict()
```

Generic outcome constants available: `WheelConfig.ID_SUCCESS`, `WheelConfig.ID_PARTIAL`, `WheelConfig.ID_FAILURE`.

---

## Extracting to Another Godot Project

Simply copy the `timing_wheel/` folder into your new project, or add `godot-systems-library` as a Git Submodule. No external plugins or assets required!
