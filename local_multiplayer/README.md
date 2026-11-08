# SYS-10: Local Multiplayer & Gamepad Controller System (`local_multiplayer/`)

A zero-dependency, modular Godot 4 system providing turn-based hotseat pass-and-play transitions, privacy blinds, dual-gamepad input arbitration, and 2D gamepad focus graph navigation.

## Architecture

```
local_multiplayer/
├── MatchRulesConfig.gd           # Configuration resource for modes, players, and device bindings
├── PlayerInputRouter.gd          # Input isolation, device routing, and controller glyph mapping
├── HotseatCurtain.gd             # Fullscreen privacy curtain state machine for device handoff
├── GamepadNavigator.gd           # 2D focus graph & virtual D-Pad navigator across UI zones
├── testbed_local_multiplayer.tscn # Standalone runnable testbed demo
├── TestbedLocalMultiplayer.gd    # Interactive controller sandbox script
└── test_local_multiplayer.gd     # Automated headless test suite
```

## Features

1. **Match Modes**:
   - `HOTSEAT_PASS_AND_PLAY`: Alternating turns on a single PC or Steam Deck, using `HotseatCurtain` to prevent players from seeing opponent hands.
   - `SHARED_SCREEN_DUAL_PAD`: Dual gamepads or split keyboard with input isolation ensuring Player 2 cannot act during Player 1's turn.
   - `SOLO_VS_AI`: Standard single-player mode.

2. **Controller Glyphs & Steam Deck Detection**:
   - Detects Steam Deck, Xbox, PlayStation, Nintendo Switch, and Generic Gamepads dynamically.
   - Provides accurate glyph descriptions (e.g. `[A]` vs `[✕ Cross]` vs `[B]` for confirm; `[RB]` vs `[R1]` for end turn).

3. **HotseatCurtain Privacy Screen**:
   - Four-state transition: `INACTIVE` $\to$ `LOWERING` $\to$ `AWAITING_HANDOFF` $\to$ `RAISING`.
   - Obfuscates private hand information until the target player presses confirmation.

4. **GamepadNavigator 2D Focus Graph**:
   - Hierarchical grid navigation between card hands, board lanes, leader power buttons, and turn actions via D-Pad or analog sticks.

## Usage Example

```gdscript
# 1. Setup Configuration
var config = MatchRulesConfig.new(MatchRulesConfig.MatchMode.HOTSEAT_PASS_AND_PLAY)
config.set_player_loadout(0, "Finn", "Hero_Finn", ["Card_1", "Card_2"], ["Plains", "Cotton"], -1)
config.set_player_loadout(1, "Jake", "Hero_Jake", ["Card_A", "Card_B"], ["Corn", "Sand"], 0)

# 2. Input Router
var router = PlayerInputRouter.new(config)
var action = router.route_input_event(event)

# 3. Hotseat Handoff
var curtain = HotseatCurtain.new()
add_child(curtain)
curtain.start_handoff(1, "Jake")
```
