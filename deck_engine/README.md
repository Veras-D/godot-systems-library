# Deck & Hand Engine (Standalone Godot 4 Module)

A completely decoupled, customizable card deck and hand layout system for Godot 4.

Designed following the **Systems-First** architecture: zero game-specific coupling, self-contained testbeds, smooth parabolic hand fanning, and extraction-ready for any card game, TCG, or deckbuilder.

---

## Features

- **Generic Data Model (`CardData.gd`)**:
  - Encapsulates ID, name, cost, type, affinity, attack, defense, description, category (subtype/tribe), and custom metadata dictionary.
  - Zero coupling to any specific IP or mechanics.
  - Unified **`affinity`** field with `"Universal"` wildcard support for seamless board placement validation.
- **Universal Deck Manager (`Deck.gd`)**:
  - Draw pile, Discard pile (Graveyard), and Banished pile management.
  - Fisher-Yates shuffle algorithm.
  - Automatic discard-to-draw recycling when draw pile is exhausted.
  - Top-of-deck peeking and batch drawing.
- **Parabolic Arc & Fan Hand Layout (`HandManager.gd`)**:
  - Smooth fan curvature using parabolic positioning (`y = x² * arc_height`).
  - Dynamic angular rotation outward from hand center (`rotation = norm * max_angle`).
  - Auto-compression when hand card count exceeds layout width.
  - Bottom-center card pivots (`pivot_offset = Vector2(w / 2, h)`).
  - Hover pop-up kinetics: hovered card raises up, straightens to 0°, scales up (1.15x), and raises `z_index` to render above neighboring cards.
- **Universal Card Visual (`GenericCardView.gd`)**:
  - Vector/procedural card component with cost bubble, stats badges, and selection glow.
- **Standalone Interactive Testbed (`testbed_deck.tscn`)**:
  - Interactive table with real-time sliders for arc height, spread angle, and hand width, along with deck statistics and an event log.

---

## Affinity & Board Interoperability Contract

To eliminate hidden mismatch bugs across modules, `deck_engine` and `board_system` share a single, unified affinity vocabulary:

1. **Single Source of Truth (`affinity`)**:
   - `CardData.affinity: String` stores the terrain or elemental affinity tag (e.g. `"Fire"`, `"Forest"`, `"Universal"`).
   - Defaults to `CardData.UNIVERSAL_TAG` (`"Universal"`).
   - The deprecated `faction` getter/setter alias has been removed.
2. **Direct Getter with Zero Fallback**:
   - `CardData.get_affinity() -> String` returns `affinity` directly.
   - It **does not** fall back to tribe/category or aliases. Exactly one deterministic string is returned.
3. **Decoupled Subtypes (`category`)**:
   - `CardData.category: String` represents card tribe or archetype (e.g. `"Knight"`, `"Dragon"`, `"Beast"`).
   - `category` is completely separate from board slot placement rules.
4. **Universal Wildcard (`"Universal"`)**:
   - Cards with `affinity = "Universal"` (or `""`) can be placed on any board slot.
   - Slots with `affinity = "Universal"` (or `""`) accept any card.

---

## Mathematical Model: Parabolic Arc Layout

For $N$ cards in hand, each card $i \in [0, N-1]$ is mapped to a normalized coordinate:

$$\text{norm}_i = \frac{i}{N - 1} - 0.5 \quad \in [-0.5, +0.5]$$

1. **Horizontal Position**:
   $$X_i = \text{Center}_X + (\text{norm}_i \times \text{spacing} \times (N - 1)) - \frac{\text{CardWidth}}{2}$$
2. **Vertical Parabolic Drop**:
   $$Y_i = \text{Base}_Y + (\text{norm}_i)^2 \times \text{ArcHeight} \times 4.0$$
3. **Angular Fan Rotation**:
   $$\text{Rot}_i = \text{norm}_i \times \text{MaxAngleSpread}$$

---

## Integration Guide

### 1. Instantiate Deck & Hand
```gdscript
var deck = Deck.new()
var hand_scene = preload("res://deck_engine/HandManager.tscn")
var hand = hand_scene.instantiate() as HandManager
add_child(hand)
```

### 2. Populate Deck & Draw
```gdscript
# Creates a Fire affinity card:
var card = CardData.create("c_01", "Flame Dragon", 3, "Creature", "Fire", 6, 8, "Spits fire")
deck.add_card(card)
deck.shuffle()

# Draw 4 cards into hand
var drawn_cards = deck.draw(4)
for c in drawn_cards:
    hand.add_card(c)
```

### 3. Handle Card Clicks & Discards
```gdscript
hand.card_clicked.connect(func(card_view: GenericCardView):
    print("Clicked card: ", card_view.card_data.name)
    deck.discard(card_view.card_data)
    hand.remove_card(card_view)
)
```

### 4. Dynamic Card View Updates (`GenericCardView`)
```gdscript
var card_view_scene = preload("res://deck_engine/GenericCardView.tscn")
var card_view = card_view_scene.instantiate() as GenericCardView
add_child(card_view)

# Assigning card_data immediately renders stats, cost, and name labels:
card_view.card_data = card_a

# Reassigning card_data at runtime immediately re-renders the UI:
card_view.card_data = card_b
```

---

## Running the Isolated Testbed

Run the interactive testbed scene directly:
```bash
godot deck_engine/testbed_deck.tscn
```
Or run the automated unit test headlessly:
```bash
godot --headless -s res://deck_engine/test_deck_engine.gd
```
