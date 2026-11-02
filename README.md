# Godot Modular Game Systems Library

A collection of polished, reusable, completely decoupled game systems and isolated testbeds for **Godot 4**.

> **"Build systems, not monolithic games."**
> Monolithic game code becomes tangled and abandoned. By building independent, extraction-ready modules — each with its own data contracts, isolated testbed scene (`testbed_*.tscn`), and zero game-specific coupling — you accumulate a personal library of production-ready systems that can be dropped into any present or future game.

---

## 📦 Systems Catalog

| System | Directory | Description | Status |
| :--- | :--- | :--- | :---: |
| **Timing Wheel** | [`timing_wheel/`](./timing_wheel/) | Procedural roulette / reaction timing wheel minigame with needle kinetics & quick-resolve math. | ✅ **Production Ready** |
| **Audio Jukebox** | [`audio_jukebox/`](./audio_jukebox/) | Dual-BGM crossfader, SFX bus player pool with pitch variation, and volume persistence. | ✅ **Production Ready** |
| **Deck Engine** | [`deck_engine/`](./deck_engine/) | Universal card model, draw/discard piles, Fisher-Yates shuffle, and parabolic fan hand layout. | ✅ **Production Ready** |
| **Board System** | [`board_system/`](./board_system/) | Universal lane & grid board slotting, drop target arbitration, and placement affinity. | ✅ **Production Ready** |
| **Ability Engine** | [`ability_engine/`](./ability_engine/) | Universal trigger/action effect resolver, queue processor, and event bus. | ✅ **Production Ready** |
| **Save Vault** | [`save_vault/`](./save_vault/) | Secure JSON save state manager, atomic writes, slot backups, and schema migration. | ✅ **Production Ready** |

---

## 🏷️ Global Type Registry & Reserved Names

This library registers clean, idiomatic GDScript classes (`class_name`) to serve as universal data contracts across your projects. If your project already defines one of these names, you can safely alias it via `const CustomName = preload("path/to/File.gd")` or adopt the library's contracts directly.

| Module | Global `class_name` | Type | Purpose |
| :--- | :--- | :--- | :--- |
| **`timing_wheel`** | `WheelConfig` | `Resource` | Roulette sector configuration and hit/crit ratios |
| | `WheelSpinner` | `Control` | Procedural wheel UI with deceleration physics |
| **`audio_jukebox`** | `AudioManager` | `Node` | Dual BGM crossfader & zero-allocation SFX pool |
| **`deck_engine`** | `CardData` | `Resource` | Universal card attributes and metadata model |
| | `Deck` | `RefCounted` | Draw, discard, banish piles with Fisher-Yates |
| | `HandManager` | `Control` | Parabolic fan hand positioning with hover kinetics |
| | `GenericCardView` | `Control` | Themed vector card display component |
| **`board_system`** | `SlotData` | `Resource` | Slot coordinate, multi-occupant, and affinity model |
| | `BoardSlot` | `Control` | Visual slot with damage shake and drop handling |
| | `BoardGrid` | `Control` | Multi-side opposing lane matrix and placement validator |
| **`ability_engine`** | `EffectData` | `Resource` | Discrete action definition (Damage, Heal, Buff, Draw) |
| | `EffectContext` | `RefCounted` | Execution context (source, targets, coordinates) |
| | `AbilityDefinition` | `Resource` | Trigger-to-effects composite container |
| | `AbilityResolver` | `Node` | Priority FIFO action queue and reaction engine |
| **`save_vault`** | `SaveVault` | `Node` | Atomic JSON serializer with SHA-256 and `.bak` recovery |

---

## 🚀 How to Use in Any Godot Project

### Option A: As a Git Submodule (Recommended)
Add this library directly to your project's `src/systems/` or `addons/`:

```bash
cd /path/to/your/godot-project
git submodule add https://github.com/Veras-D/godot-systems-library.git src/systems
```

To update all systems in your project to the latest version at any time:
```bash
git submodule update --remote --merge
```

### Option B: Standalone Copy-Paste
Every folder (e.g. `timing_wheel/`) is 100% self-contained with no external dependencies:
1. Copy the system directory (e.g. `timing_wheel/`) into your game's folder.
2. Open its `testbed_*.tscn` scene to verify it runs.
3. Integrate its API into your game logic.

---

## 🧪 Running the Systems Hub & Automated Tests

### Run All System Tests (Headless)
To run the automated regression test suite across all modules:
```bash
godot --headless -s res://run_tests.gd
```
This discovers all `test_*.gd` suites, executes them in isolated processes, logs diagnostics on failure, and exits with code 0/1 for CI/CD.

### Open the Interactive Systems Hub in Godot
This repository is itself a runnable Godot 4 project:
1. Open Godot 4 and click **Import**.
2. Select the repository root folder (or `project.godot`).
3. Press **F5** to run the default testbed, or open any `testbed_*.tscn` inside the system folders to test that system in complete isolation.

---

## 📐 Architecture Rules for Contributing Systems

Any new module added to this library must adhere to these directives:
1. **Zero Game Coupling**: No game-specific asset imports, character names, or domain logic. Systems operate exclusively on generic configurations (`WheelConfig`, `DeckData`, etc.).
2. **Relative Preloads**: Do not use hardcoded absolute `res://` paths in scripts; use relative `preload("File.gd")` so the module works in any subfolder of any project.
3. **Isolated Testbed Scene**: Every system must include a standalone runnable `testbed_<name>.tscn` with UI controls to demonstrate and verify all features.
4. **Standalone Documentation**: Every system directory must contain its own `README.md` with integration examples and API documentation.
