extends Control

## TestbedLocalMultiplayer: Interactive sandbox demonstrating SYS-10 Local Multiplayer.
## Showcases Hotseat Pass & Play transitions, Dual-Pad input routing, and Gamepad focus navigation.

const MatchRulesConfig = preload("MatchRulesConfig.gd")
const PlayerInputRouter = preload("PlayerInputRouter.gd")
const HotseatCurtain = preload("HotseatCurtain.gd")
const GamepadNavigator = preload("GamepadNavigator.gd")

@onready var status_label: Label = $VBox/Header/StatusLabel
@onready var turn_indicator: Label = $VBox/Header/TurnIndicator
@onready var mode_button: OptionButton = $VBox/Header/ModeButton
@onready var p1_hand_box: HBoxContainer = $VBox/P1Area/HandContainer
@onready var lanes_box: HBoxContainer = $VBox/LanesArea
@onready var end_turn_btn: Button = $VBox/Controls/EndTurnBtn
@onready var glyph_label: Label = $VBox/Controls/GlyphLabel
@onready var curtain: HotseatCurtain = $HotseatCurtain

var config: MatchRulesConfig
var router: PlayerInputRouter
var navigator: GamepadNavigator
var current_turn: int = 0 # 0 for P1, 1 for P2
var turn_number: int = 1


func _ready() -> void:
	config = MatchRulesConfig.new(MatchRulesConfig.MatchMode.HOTSEAT_PASS_AND_PLAY)
	config.set_player_loadout(0, "Finn", "Hero_Finn", ["Card_1", "Card_2", "Card_3", "Card_4"], ["Plains", "Plains", "Cotton", "Plains"])
	config.set_player_loadout(1, "Jake", "Hero_Jake", ["Card_A", "Card_B", "Card_C", "Card_D"], ["Corn", "Corn", "Sand", "Corn"])

	router = PlayerInputRouter.new(config)
	navigator = GamepadNavigator.new()

	_setup_ui()
	_update_turn_display()


func _setup_ui() -> void:
	mode_button.clear()
	mode_button.add_item("Hotseat Pass & Play (1 Device)", MatchRulesConfig.MatchMode.HOTSEAT_PASS_AND_PLAY)
	mode_button.add_item("Shared Screen (Dual Gamepad)", MatchRulesConfig.MatchMode.SHARED_SCREEN_DUAL_PAD)
	mode_button.item_selected.connect(_on_mode_changed)

	end_turn_btn.pressed.connect(_on_end_turn_pressed)

	curtain.handoff_started.connect(func(_slot, pname):
		status_label.text = "Handing off device to %s..." % pname
	)
	curtain.unveil_confirmed.connect(func(slot):
		current_turn = slot
		router.set_active_turn_player(slot)
		_update_turn_display()
		status_label.text = "Turn started for %s!" % config.get_player_name(slot)
	)

	# Register navigator zones
	var hand_buttons: Array = p1_hand_box.get_children()
	var lane_buttons: Array = lanes_box.get_children()
	navigator.register_zone_nodes(GamepadNavigator.FocusZone.HAND, hand_buttons)
	navigator.register_zone_nodes(GamepadNavigator.FocusZone.LANES, lane_buttons)
	navigator.register_zone_nodes(GamepadNavigator.FocusZone.END_TURN, [end_turn_btn])

	var detected_type = PlayerInputRouter.detect_controller_type(0)
	var a_glyph = PlayerInputRouter.get_action_glyph("confirm", detected_type)
	var rb_glyph = PlayerInputRouter.get_action_glyph("end_turn", detected_type)
	glyph_label.text = "Controls: [%s] Play/Select • [%s] End Turn • [D-Pad] Navigate" % [a_glyph, rb_glyph]


func _on_mode_changed(idx: int) -> void:
	config.mode = idx as MatchRulesConfig.MatchMode
	status_label.text = "Mode set to: %s" % mode_button.get_item_text(idx)


func _on_end_turn_pressed() -> void:
	var next_slot = 1 if current_turn == 0 else 0
	var next_name = config.get_player_name(next_slot)
	turn_number += 1

	if config.is_hotseat():
		curtain.start_handoff(next_slot, next_name)
	else:
		# Instant transition for shared screen
		current_turn = next_slot
		router.set_active_turn_player(next_slot)
		_update_turn_display()
		status_label.text = "Turn switched to %s (Dual-Pad)!" % next_name


func _update_turn_display() -> void:
	var pname = config.get_player_name(current_turn)
	turn_indicator.text = "TURN %d — Active: %s" % [turn_number, pname]
	turn_indicator.modulate = Color(0.4, 0.8, 1.0) if current_turn == 0 else Color(1.0, 0.8, 0.2)

	# Update hand cards
	var current_deck = config.get_player_deck(current_turn)
	var hand_children = p1_hand_box.get_children()
	for i in range(hand_children.size()):
		var btn: Button = hand_children[i]
		if i < current_deck.size():
			btn.text = "%s's %s" % [pname, current_deck[i]]
			btn.visible = true
		else:
			btn.visible = false

	# Focus first hand card
	navigator.focus_zone(GamepadNavigator.FocusZone.HAND, 0)


func _unhandled_input(event: InputEvent) -> void:
	var routed = router.route_input_event(event)
	if routed.consumed:
		if routed.action == "navigate":
			navigator.navigate(routed.direction)
		elif routed.action == "end_turn":
			_on_end_turn_pressed()
		elif routed.action == "confirm":
			var focused = navigator.get_focused_node()
			if focused is Button:
				focused.emit_signal("pressed")
