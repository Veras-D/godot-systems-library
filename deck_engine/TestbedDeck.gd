extends Control

const CardData = preload("CardData.gd")
const Deck = preload("Deck.gd")
const HandManager = preload("HandManager.gd")
const GenericCardView = preload("GenericCardView.gd")

@onready var draw_count_lbl: Label = $MainBox/TopBox/StatsPanel/Margin/HBox/DrawBadge/Val
@onready var discard_count_lbl: Label = $MainBox/TopBox/StatsPanel/Margin/HBox/DiscardBadge/Val
@onready var banish_count_lbl: Label = $MainBox/TopBox/StatsPanel/Margin/HBox/BanishBadge/Val
@onready var hand_count_lbl: Label = $MainBox/TopBox/StatsPanel/Margin/HBox/HandBadge/Val

@onready var btn_draw_1: Button = $MainBox/TopBox/ActionPanel/Margin/VBox/BtnRow1/Draw1Btn
@onready var btn_draw_3: Button = $MainBox/TopBox/ActionPanel/Margin/VBox/BtnRow1/Draw3Btn
@onready var btn_discard_sel: Button = $MainBox/TopBox/ActionPanel/Margin/VBox/BtnRow1/DiscardSelBtn
@onready var btn_discard_all: Button = $MainBox/TopBox/ActionPanel/Margin/VBox/BtnRow2/DiscardAllBtn
@onready var btn_shuffle: Button = $MainBox/TopBox/ActionPanel/Margin/VBox/BtnRow2/ShuffleBtn
@onready var btn_recycle: Button = $MainBox/TopBox/ActionPanel/Margin/VBox/BtnRow2/RecycleBtn
@onready var btn_reset: Button = $MainBox/TopBox/ActionPanel/Margin/VBox/ResetBtn

@onready var slider_width: HSlider = $MainBox/ControlsBox/SlidersPanel/Margin/VBox/WidthRow/Slider
@onready var lbl_width: Label = $MainBox/ControlsBox/SlidersPanel/Margin/VBox/WidthRow/Val
@onready var slider_arc: HSlider = $MainBox/ControlsBox/SlidersPanel/Margin/VBox/ArcRow/Slider
@onready var lbl_arc: Label = $MainBox/ControlsBox/SlidersPanel/Margin/VBox/ArcRow/Val
@onready var slider_angle: HSlider = $MainBox/ControlsBox/SlidersPanel/Margin/VBox/AngleRow/Slider
@onready var lbl_angle: Label = $MainBox/ControlsBox/SlidersPanel/Margin/VBox/AngleRow/Val

@onready var log_label: RichTextLabel = $MainBox/ControlsBox/LogPanel/Margin/VBox/LogScroll/LogText
@onready var hand_manager: HandManager = $MainBox/HandContainer/HandManager

var deck: Deck
var selected_card: GenericCardView = null

func _ready() -> void:
	deck = Deck.new()
	deck.card_drawn.connect(func(c): _log("[color=#44ff88]▶ Drew card: %s[/color]" % c.name))
	deck.card_discarded.connect(func(c): _log("[color=#ffaa44]▼ Discarded card: %s[/color]" % c.name))
	deck.discard_recycled.connect(func(cnt): _log("[color=#44ccff]♻ Recycled %d cards from discard into draw pile.[/color]" % cnt))
	deck.deck_shuffled.connect(func(): _log("[color=#dd88ff]🔀 Draw pile shuffled.[/color]"))

	# Connect HandManager signals
	hand_manager.card_clicked.connect(_on_card_clicked)
	hand_manager.card_hovered.connect(func(c): pass)

	# Connect Buttons
	btn_draw_1.pressed.connect(_on_draw_1_pressed)
	btn_draw_3.pressed.connect(_on_draw_3_pressed)
	btn_discard_sel.pressed.connect(_on_discard_selected_pressed)
	btn_discard_all.pressed.connect(_on_discard_all_pressed)
	btn_shuffle.pressed.connect(func(): deck.shuffle(); _update_stats())
	btn_recycle.pressed.connect(func(): deck.recycle_discard_into_draw(true); _update_stats())
	btn_reset.pressed.connect(_setup_demo_deck)

	# Connect Sliders
	slider_width.value_changed.connect(_on_width_changed)
	slider_arc.value_changed.connect(_on_arc_changed)
	slider_angle.value_changed.connect(_on_angle_changed)

	_setup_demo_deck()
	_log("[color=#44ff88]Deck Engine Testbed Ready.[/color]")

func _setup_demo_deck() -> void:
	deck.clear()
	hand_manager.clear_hand()
	selected_card = null

	var archetype_names = [
		["Iron Knight", 2, "Creature", "Steel", 4, 10, "Heavily armored sentinel."],
		["Flame Archer", 1, "Creature", "Fire", 5, 4, "Deals ranged fire strikes."],
		["Mystic Pixie", 1, "Creature", "Arcane", 2, 3, "Draws a card on summon."],
		["Shadow Assassin", 3, "Creature", "Void", 8, 5, "Strikes enemy directly."],
		["Frost Barrier", 2, "Spell", "Frost", 0, 8, "Freezes target opposing lane."],
		["Healing Nectar", 1, "Spell", "Nature", 0, 0, "Restores 5 HP to hero."],
		["Earth Golem", 4, "Creature", "Earth", 7, 16, "Immense defensive presence."],
		["Thunderbolt", 2, "Spell", "Storm", 6, 0, "Deals 6 damage to any target."]
	]

	for i in range(20):
		var arch = archetype_names[i % archetype_names.size()]
		var c = CardData.create(
			"card_%03d" % (i + 1),
			arch[0] + (" #%d" % ((i / archetype_names.size()) + 1)),
			arch[1], arch[2], arch[3], arch[4], arch[5], arch[6]
		)
		deck.add_card(c)

	deck.shuffle()
	# Draw starting hand of 4
	for i in range(4):
		var c = deck.draw_one(true)
		if c:
			hand_manager.add_card(c)

	_update_stats()
	_log("[color=#88ccff]Initialized demo deck with 20 cards and drew 4 cards.[/color]")

func _on_draw_1_pressed() -> void:
	var c = deck.draw_one(true)
	if c:
		hand_manager.add_card(c)
	else:
		_log("[color=#ff6666]Draw pile and discard pile are empty![/color]")
	_update_stats()

func _on_draw_3_pressed() -> void:
	for i in range(3):
		var c = deck.draw_one(true)
		if c:
			hand_manager.add_card(c)
	_update_stats()

func _on_discard_selected_pressed() -> void:
	if selected_card == null:
		_log("[color=#ffaa33]No card selected! Click a card in your hand first.[/color]")
		return
	var card_data = selected_card.card_data
	deck.discard(card_data)
	hand_manager.remove_card(selected_card)
	selected_card = null
	_update_stats()

func _on_discard_all_pressed() -> void:
	var cards = hand_manager.get_cards().duplicate()
	for c_view in cards:
		deck.discard(c_view.card_data)
		hand_manager.remove_card(c_view)
	selected_card = null
	_update_stats()

func _on_card_clicked(card_view: GenericCardView) -> void:
	if selected_card == card_view:
		selected_card.set_selected(false)
		selected_card = null
		_log("Deselected card.")
	else:
		if selected_card != null:
			selected_card.set_selected(false)
		selected_card = card_view
		selected_card.set_selected(true)
		_log("[color=#ffff88]Selected %s (Cost: %d, Atk: %d, Def: %d)[/color]" % [
			card_view.card_data.name,
			card_view.card_data.cost,
			card_view.card_data.attack,
			card_view.card_data.defense
		])

func _on_width_changed(val: float) -> void:
	hand_manager.max_hand_width = val
	lbl_width.text = "%dpx" % int(val)
	hand_manager.update_hand_layout(true)

func _on_arc_changed(val: float) -> void:
	hand_manager.arc_height = val
	lbl_arc.text = "%dpx" % int(val)
	hand_manager.update_hand_layout(true)

func _on_angle_changed(val: float) -> void:
	hand_manager.max_angle_spread_deg = val
	lbl_angle.text = "%d°" % int(val)
	hand_manager.update_hand_layout(true)

func _update_stats() -> void:
	draw_count_lbl.text = str(deck.get_draw_count())
	discard_count_lbl.text = str(deck.get_discard_count())
	banish_count_lbl.text = str(deck.get_banish_count())
	hand_count_lbl.text = "%d / %d" % [hand_manager.get_card_count(), hand_manager.max_hand_size]

func _log(msg: String) -> void:
	var time_str = Time.get_time_string_from_system()
	log_label.append_text("[%s] %s\n" % [time_str, msg])
