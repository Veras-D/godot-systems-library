# Universal Board & Lane System (Standalone Godot 4 Module)

A completely decoupled, customizable board and lane layout system for Godot 4.

Designed following the **Systems-First** architecture: zero game-specific coupling, self-contained testbeds, multi-layered slot occupancy, terrain/affinity validation, and extraction-ready for any lane battler, card game, or tactical grid game.

---

## Features

- **Generic Data Model (`SlotData.gd`)**:
  - Encapsulates side/owner index, lane index, affinity/element tag, slot state (`EMPTY`, `OCCUPIED`, `LOCKED`, `DISABLED`), primary occupant, attached occupant (structure/enchantment), and arbitrary modifiers (`atk`, `armor`, etc.).
  - Built-in affinity matching engine (`can_accept_affinity()`) supporting exact matches, blank/unrestricted slots, and universal wildcards.
- **Universal Slot Component (`BoardSlot.gd` / `BoardSlot.tscn`)**:
  - Clean vector/themed UI container for primary units and attached structures.
  - Interactive highlight states: `DEFAULT`, `HOVERED`, `SELECTED`, `VALID_TARGET` (green outline), `INVALID_TARGET` (red outline).
  - Built-in Godot native Drag-and-Drop support (`_can_drop_data`, `_drop_data`) alongside click-to-select and hover signals.
  - Procedural tween feedback: damage shake animation (`play_damage_shake()`) and summon pulse (`play_summon_pulse()`).
- **Configurable Grid Manager (`BoardGrid.gd` / `BoardGrid.tscn`)**:
  - Dynamically builds rows for opposing sides (e.g. Side 0 = Friendly / Player, Side 1 = Opponent / Enemy) with $N$ configurable lanes per side.
  - Coordinate system based on `Vector2i(side, lane_index)`.
  - Opposing lane lookup (`get_opposing_slot()`) for 1-on-1 lane combat resolution.
  - Batch queries: `get_all_slots()`, `get_empty_slots()`, `get_occupied_slots()`, `get_slots_by_affinity()`.
  - Placement validation engine (`validate_placement()`).
  - State serialization (`serialize_grid()`) into standard dictionaries.
- **Standalone Interactive Testbed (`testbed_board.tscn`)**:
  - Fully runnable isolated scene (`godot board_system/testbed_board.tscn`) featuring live lane resizing, affinity cycling, mock unit summoning, structure attachments, lane clash combat simulation, and real-time event logging.
- **Automated Regression Test Suite (`test_board_system.gd`)**:
  - 100% headless test coverage verified in local test runner and GitHub Actions CI.

---

## Integration Guide

### 1. Adding BoardGrid to Your Scene

Instantiate `BoardGrid.tscn` in your battle or board UI:

```gdscript
# Example path when included as a submodule in a host project (e.g. res://src/systems/ or res://addons/):
const BoardGrid = preload("res://src/systems/board_system/BoardGrid.gd")
# Or if placed directly at your project root:
# const BoardGrid = preload("res://board_system/BoardGrid.gd")

@onready var board_grid: BoardGrid = $BoardGrid

func _ready() -> void:
    # Configure 2 opposing sides with 4 lanes each
    board_grid.sides_count = 2
    board_grid.lanes_per_side = 4
    board_grid.rebuild_grid()

    # Assign terrain affinities per lane
    board_grid.set_side_affinities(0, ["Forest", "Mountain", "Swamp", "Desert"])
    board_grid.set_side_affinities(1, ["Mountain", "Forest", "Desert", "Swamp"])

    # Connect signals
    board_grid.slot_selected.connect(_on_slot_selected)
    board_grid.occupant_dropped_on_slot.connect(_on_card_dropped)
```

### 2. Validating Card Placement & Affinity Rules

`board_system` integrates directly with `deck_engine`'s `CardData`:

1. **Deterministic Affinity**:
   - `CardData.get_affinity()` returns a single string (`affinity`) with zero fallbacks.
   - `SlotData.can_accept_affinity(occupant_affinity)` evaluates whether the card fits the slot.
2. **Standard Precedence & Wildcard Rules**:
   - If the slot is locked or disabled -> **REJECT** (`false`).
   - If the slot's affinity is blank (`""`) -> **ACCEPT** (`true`).
   - If the occupant's affinity is blank (`""`) or `"Universal"` (`SlotData.UNIVERSAL_TAG`) -> **ACCEPT** (`true`).
   - If the slot's affinity is `"Universal"` -> **ACCEPT** (`true`).
   - Exact string match (`occupant_affinity == slot.affinity`) -> **ACCEPT** (`true`).
   - Otherwise -> **REJECT** (`false`).

```gdscript
func try_play_card(card: CardData, side: int, lane: int) -> bool:
    var validation = board_grid.validate_placement(card.get_affinity(), side, lane)
    if not validation.allowed:
        print("Cannot place card: ", validation.reason)
        return false

    var slot = board_grid.get_slot(side, lane)
    var creature_node = create_creature_view(card)
    slot.set_primary_view(creature_node)
    slot.play_summon_pulse()
    return true
}
```

### 3. Resolving Lane Combat

```gdscript
func execute_lane_combat(attacker_slot: BoardSlot) -> void:
    var defender_slot = board_grid.get_opposing_slot(attacker_slot)
    if defender_slot and defender_slot.slot_data.has_primary():
        # Clash between opposing units
        attacker_slot.play_damage_shake(6.0, 0.2)
        defender_slot.play_damage_shake(12.0, 0.4)
    else:
        # Direct attack against opposing player
        attacker_slot.play_damage_shake(4.0, 0.15)
```

### 4. Audio & VFX Animation Signal Hooks

`BoardGrid` bubbles up animation events, allowing audio jukeboxes or screen shake handlers to react without coupling:

```gdscript
# Connect audio triggers to board animation events:
board_grid.slot_damage_shaken.connect(func(slot, intensity):
    Audio.play_sfx(hit_sfx, 0.0, 0.1)
)
board_grid.slot_summon_pulsed.connect(func(slot):
    Audio.play_sfx(summon_sfx)
)
```

### 5. Drag-and-Drop Card Contract

`BoardSlot` natively understands the card payload returned by `GenericCardView._get_drag_data()`:

```gdscript
# Card Drag Payload Schema:
{
    "type": "card",
    "card_data": CardData,
    "source_view": GenericCardView
}
```

---

## API Reference

### `BoardGrid`
| Method | Description |
| :--- | :--- |
| `rebuild_grid()` | Reconstructs the visual and logical slot matrix. |
| `get_slot(side: int, lane: int) -> BoardSlot` | Returns the slot at coordinate `(side, lane)`. |
| `get_opposing_slot(slot: BoardSlot) -> BoardSlot` | Returns the directly opposite slot on the other side. |
| `get_all_slots(side: int = -1) -> Array[BoardSlot]` | Returns all slots, optionally filtered by side. |
| `get_empty_slots(side: int = -1) -> Array[BoardSlot]` | Returns all unoccupied slots. |
| `get_occupied_slots(side: int = -1) -> Array[BoardSlot]` | Returns all slots with a primary occupant. |
| `get_slots_by_affinity(affinity: String, side: int = -1)` | Returns slots matching a specific affinity tag. |
| `validate_placement(affinity: String, side: int, lane: int, is_attachment: bool = false) -> Dictionary` | Validates placement; returns `{ "allowed": bool, "reason": String }`. |
| `highlight_valid_slots(affinity: String, target_side: int)` | Highlights valid target slots green and invalid slots red. |
| `clear_all_highlights()` | Resets all slot highlights to normal. |
| `clear_all_slots()` | Removes all occupants and resets modifiers on all slots. |
| `serialize_grid() -> Array[Dictionary]` | Exports the entire board state to serializable dictionaries. |

### `BoardSlot`
| Method | Description |
| :--- | :--- |
| `set_primary_view(node: Node)` | Mounts a visual occupant into the primary slot area. |
| `set_attachment_view(node: Node)` | Mounts a structure or aura view into the attachment area. |
| `clear_occupants()` | Removes all visual children and clears logical slot data. |
| `set_highlight(mode: HighlightMode)` | Sets overlay (`NONE`, `HOVERED`, `SELECTED`, `VALID_TARGET`, `INVALID_TARGET`). |
| `play_damage_shake(intensity: float, duration: float)` | Plays a procedural horizontal shake animation. |
| `play_summon_pulse()` | Plays a scale-bounce entry animation. |

---

## Standalone Testbed

Launch the standalone testbed with Godot:

```bash
godot board_system/testbed_board.tscn
```
