# Universal Ability & Effect Engine (Standalone Godot 4 Module)

A completely decoupled, data-driven trigger and effect resolver system for Godot 4.

Designed following the **Systems-First** architecture: zero game-specific coupling, self-contained testbeds, deterministic action queues, priority-based resolution, and extraction-ready for any TCG, turn-based battler, RPG, or board game.

---

## Features

- **Generic Effect Data Model (`EffectData.gd`)**:
  - Discrete action definitions: `DAMAGE`, `HEAL`, `BUFF_STAT`, `GAIN_RESOURCE`, `DRAW_CARD`, `DISCARD_CARD`, `DESTROY`, `SWAP_STATS`, `CUSTOM`.
  - Scopes: `SELF`, `TARGET_SINGLE`, `ALL_FRIENDLY`, `ALL_ENEMY`, `ADJACENT_FRIENDLY`, `OPPOSING_LANE`, `RANDOM_ENEMY`, `ALL_UNITS`.
  - Static factory constructors (`create_damage`, `create_heal`, `create_buff`, `create_draw`, `create_resource_gain`).
- **Flexible Execution Context (`EffectContext.gd`)**:
  - Encapsulates source entity, source coordinate `(side, lane)`, resolved targets list, triggering event name, and arbitrary runtime variables (e.g. crit multipliers).
- **Composite Ability Container (`AbilityDefinition.gd`)**:
  - Binds a trigger event (`ON_PLAY`, `ON_SUMMON`, `ON_DEATH`, `ON_TURN_START`, `ON_TURN_END`, `ON_ATTACK`, `ON_DAMAGE_TAKEN`, `ON_ACTIVATE`) to an ordered sequence of `EffectData` actions.
- **Queue & Action Resolver (`AbilityResolver.gd`)**:
  - Deterministic FIFO execution queue with priority support.
  - Asynchronous animated step-by-step resolution (`process_queue_async(step_delay)`) and instantaneous synchronous resolution (`resolve_all_sync()`).
  - Native target mutation support for Godot Nodes, Objects (method calls `take_damage`, `heal`, `apply_buff`), and standard Dictionaries (`def`, `hp`, `atk`).
  - Trigger listener registration for reactive abilities (e.g. Deathrattles, Thorns, Counterattacks).
- **Standalone Interactive Testbed (`testbed_abilities.tscn`)**:
  - Isolated runnable GUI scene featuring 4 mock combatants, 6 castable spells/abilities, reactive Thorns counters, a step-by-step queue visualizer, and a real-time event log.
- **Automated Regression Test Suite (`test_ability_engine.gd`)**:
  - 100% headless test coverage running locally and on GitHub Actions CI.

---

## Architecture Diagram

```mermaid
flowchart TD
    Trigger["Game Event / Trigger<br>(e.g. ON_PLAY, ON_DAMAGE_TAKEN)"] --> Resolver["AbilityResolver Engine"]
    Ability["AbilityDefinition<br>(Trigger + Array of EffectData)"] --> Resolver
    Context["EffectContext<br>(Source, Targets, Coordinates)"] --> Resolver
    Resolver --> Queue["Priority Action Queue<br>(FIFO Order)"]
    Queue --> Step["Execute Step"]
    Step --> Targets["Resolve TargetScope"]
    Targets --> Apply["Apply Effect Logic<br>(Damage, Heal, Buff, Draw)"]
    Apply --> Signal["Emit Signals<br>(effect_started, effect_applied)"]
    Apply -.-> TriggerReaction["Dispatch Secondary Triggers<br>(e.g. Reaction Abilities)"]
    TriggerReaction --> Queue
```

---

## Integration Guide

### 1. Defining an Ability

> [!NOTE]
> Examples use relative preloads; adjust paths to match wherever you installed or cloned the module folder in your project.

```gdscript
const EffectData = preload("EffectData.gd")
const AbilityDefinition = preload("AbilityDefinition.gd")

# Create a spell that deals 5 damage to target and heals caster for 3
var fireball = AbilityDefinition.create(
    "spell_fireball",
    "Fireball",
    "ON_PLAY",
    [
        EffectData.create_damage(5, EffectData.TargetScope.TARGET_SINGLE),
        EffectData.create_heal(3, EffectData.TargetScope.SELF)
    ]
)
```

### 2. Enqueuing and Resolving

```gdscript
const EffectContext = preload("EffectContext.gd")
const AbilityResolver = preload("AbilityResolver.gd")

@onready var resolver: AbilityResolver = $AbilityResolver

func cast_spell(caster_entity, target_entity) -> void:
    var context = EffectContext.create(caster_entity, 0, 0, [target_entity])
    resolver.enqueue_ability(fireball, context)
    resolver.process_queue_async(0.2) # Animate with 0.2s delay between effects
```

### 3. Setting Up a Reactive Ability (e.g. Thorns)

```gdscript
var thorns = AbilityDefinition.create(
    "passive_thorns",
    "Thorns",
    "ON_DAMAGE_TAKEN",
    [EffectData.create_damage(2, EffectData.TargetScope.TARGET_SINGLE)]
)

# Register defender to listen for damage reaction
resolver.register_trigger_listener(thorns, defender_unit)

# When defender takes damage:
resolver.dispatch_trigger("ON_DAMAGE_TAKEN", defender_unit, reaction_context)
```

### 4. Shared Event Bus Integration (`SystemEventBus`)

Connect game events automatically to the ability engine without coupling your gameplay controllers:

```gdscript
const SystemEventBus = preload("SystemEventBus.gd")

var event_bus = SystemEventBus.new()
event_bus.connect_resolver(resolver)

# Emitting standard game events automatically dispatches triggers to registered abilities:
event_bus.damage_dealt.emit(attacker, defender, 6) # Automatically dispatches ON_DAMAGE_TAKEN
event_bus.unit_defeated.emit(dying_unit, 0, 1)     # Automatically dispatches ON_DEATH (Deathrattles)

# Automatically bridge BoardGrid and HandManager signals directly into the bus:
event_bus.bind_board_grid(board_grid)
event_bus.bind_hand_manager(hand_manager, 0) # 0 = player side index
```

### 5. Target Mutation & Immutability Policy

By default, `AbilityResolver` mutates dictionary and object targets in place (`mutate_targets_in_place = true`). For consumers managing immutable state trees or who need non-destructive previews:

- **Immutable Execution**: Set `resolver.mutate_targets_in_place = false`. In this mode, input targets are left unmodified, and computed state changes are logged to `resolver.last_applied_deltas`.
- **Preview Helper**: Call `resolver.preview_effect_delta(effect, target_dict)` to compute the prospective delta and mutated state without changing the original dictionary.

```gdscript
# Non-destructive effect preview
var target_state = {"name": "Golem", "def": 12, "max_def": 12}
var preview = resolver.preview_effect_delta(damage_effect, target_state)

print(preview.result_value)    # e.g. 5
print(preview.mutated_state)   # {"name": "Golem", "def": 7, "max_def": 12}
print(target_state.def)        # 12 (original dictionary remains untouched)
```

### 6. Multi-Faction & Arbitrary Side Target Scopes

`AbilityResolver` dynamically routes effects across arbitrary side counts (1, 2, 3, or N players):

- **`OPPOSING_LANE`**: Resolves facing units using the board's `get_opposing_units()` or `get_opposing_side()`, falling back to deterministic modulo rotation (`(side + 1) % sides_count` for odd ring topologies, `(side + N/2) % N` for opposing cross layouts).
- **`ALL_ENEMY` & `RANDOM_ENEMY`**: Automatically selects all occupants on any side different from `context.source_side`. Callers can provide `context.set_var("enemy_sides", [target_side])` to focus on specific hostile factions.
- **`ALL_FRIENDLY` & `ADJACENT_FRIENDLY`**: Filters units belonging to `context.source_side`, or an allied team specified via `context.set_var("friendly_sides", [0, 1])`.

---

## API Reference

### `AbilityResolver`
| Method / Property | Description |
| :--- | :--- |
| `mutate_targets_in_place: bool` | When true (default), mutates target dictionaries/objects. When false, computes deltas without writing. |
| `last_applied_deltas: Array[Dictionary]` | Audit log of recently applied/computed effect deltas. |
| `enqueue_ability(ability, context, priority = 0)` | Appends all effects in an ability to the queue. |
| `enqueue_effect(effect, context, priority = 0)` | Appends a single effect into the queue. |
| `resolve_all_sync()` | Instantly resolves all queued effects without delay. |
| `process_queue_async(step_delay = -1.0)` | Asynchronously steps through queue with optional delay. |
| `preview_effect_delta(effect, target_dict) -> Dictionary` | Computes effect deltas on a dictionary clone without mutating the target. |
| `clear_deltas()` | Clears the audit history of recorded deltas. |
| `register_trigger_listener(ability, entity, side)` | Registers a reactive trigger listener. |
| `unregister_entity_listeners(entity)` | Removes all listeners registered to an entity. |
| `dispatch_trigger(trigger_name, source, context)` | Fires an event trigger and enqueues matching listeners. |
| `get_queue_size() -> int` | Returns the count of pending effects in queue. |
| `clear_queue()` | Clears all pending effects in queue. |

---

## Standalone Testbed

Launch the isolated testbed scene:

```bash
godot ability_engine/testbed_abilities.tscn
```
