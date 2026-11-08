# Node Map System (`node_map_system`)

Universal, decoupled Directed Acyclic Graph (DAG) campaign & quest progression engine for Godot 4.

## Features
- **Generic Graph Model (`NodeMapGraph.gd`)**:
  - Directed Acyclic Graph (DAG) with prerequisites and multi-branch dependency resolution.
  - Three state stages per node: `LOCKED`, `UNLOCKED`, and `COMPLETED`.
  - Star ratings ($0..3$ stars) with high-score preservation.
  - Multi-prerequisite convergence (e.g. Node 6 unlocks only after both Node 3A and Node 3B are cleared).
  - Pure JSON serialization/deserialization for save vaults.
- **Match Telemetry & 3-Star Evaluator (`StarConditionEvaluator.gd`)**:
  - Evaluates match outcomes against modular objective rules.
  - Built-in rules for victory (`JustWin`), turn limits (`FastWin`), health preservation (`OnlyXHP`), casualty limits (`OnlyLoseXCreatures`), kill targets (`DefeatX`), deck restrictions (`Forbid_Spells`, `Only_Creatures`), and custom lambdas.
- **Visual Spline & Pin Renderer (`NodeMapRenderer.gd`)**:
  - Procedural spline/road rendering between nodes with state-based color tints (Locked, Unlocked, Completed).
  - Interactive node pins displaying state badges, icons, and star counters ($★★★$, $★☆☆$).
  - Smooth 2D canvas panning and zooming support for large world maps.
- **Standalone Testbed (`testbed_nodemap.tscn`)**:
  - Complete GUI test scene for experimenting with branching unlocks and star condition evaluations.

---

## API Reference

### `NodeMapGraph`
```gdscript
var graph = NodeMapGraph.new()

# Adding nodes with prerequisites
graph.add_node({
    "id": "quest_1",
    "title": "Training Ground",
    "position": Vector2(100, 200),
    "state": NodeMapGraph.NodeState.UNLOCKED,
    "conditions": [{"id": "JustWin"}, {"id": "FastWin5"}]
})

graph.add_node({
    "id": "quest_2",
    "title": "Goblin Camp",
    "position": Vector2(300, 200),
    "prerequisites": ["quest_1"]
})

# Complete node and automatically unlock qualifying children
var res = graph.complete_node("quest_1", 3)
# res.unlocked_nodes -> ["quest_2"]
```

### `StarConditionEvaluator`
```gdscript
var stats = {
    "won": true,
    "turns": 4,
    "player_hp_lost": 2,
    "card_types_played": ["CREATURE"]
}

var conditions = [
    {"id": "JustWin"},
    {"id": "FastWin5", "max_turns": 5},
    {"id": "Forbid_Spells"}
]

var stars = StarConditionEvaluator.count_stars_earned(conditions, stats) # 3
```

---

## Running Standalone Testbed & Automated Tests

Run the interactive testbed:
```bash
godot node_map_system/testbed_nodemap.tscn
```

Run headless unit tests:
```bash
godot --headless -s res://node_map_system/test_node_map_system.gd
```
