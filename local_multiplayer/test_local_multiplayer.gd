extends SceneTree

## Automated Headless Unit Test Suite for SYS-10 (local_multiplayer)

const MatchRulesConfig = preload("MatchRulesConfig.gd")
const PlayerInputRouter = preload("PlayerInputRouter.gd")
const HotseatCurtain = preload("HotseatCurtain.gd")
const GamepadNavigator = preload("GamepadNavigator.gd")


func _init() -> void:
	print("\n========================================================")
	print("  RUNNING LOCAL MULTIPLAYER SYSTEM TESTS (SYS-10)")
	print("========================================================\n")

	_test_match_rules_config()
	_test_player_input_router()
	_test_controller_glyph_detection()
	_test_hotseat_curtain_lifecycle()
	_test_gamepad_navigator()

	print("\n==> ALL Local Multiplayer Tests PASSED SUCCESSFULLY!")
	quit(0)


func _test_match_rules_config() -> void:
	print("Test 1: MatchRulesConfig Serialization & Loadouts...")
	var config = MatchRulesConfig.new(MatchRulesConfig.MatchMode.HOTSEAT_PASS_AND_PLAY)
	assert(config.is_hotseat() == true, "Config should be HOTSEAT mode")
	assert(config.is_shared_screen() == false, "Config is not shared screen")

	config.set_player_loadout(0, "Alice", "Hero_A", ["Card_1", "Card_2"], ["Plains", "Cotton"], -1)
	config.set_player_loadout(1, "Bob", "Hero_B", ["Card_X", "Card_Y"], ["Corn", "Sand"], 0)

	assert(config.get_player_name(0) == "Alice", "P1 name is Alice")
	assert(config.get_player_name(1) == "Bob", "P2 name is Bob")
	assert(config.get_player_device(0) == -1, "P1 device is -1 (Keyboard)")
	assert(config.get_player_device(1) == 0, "P2 device is 0 (Gamepad)")

	# Serialization / Deserialization
	var data = config.serialize()
	var restored = MatchRulesConfig.new()
	restored.deserialize(data)

	assert(restored.is_hotseat() == true, "Restored mode is HOTSEAT")
	assert(restored.get_player_name(0) == "Alice", "Restored P1 name is Alice")
	assert(restored.get_player_name(1) == "Bob", "Restored P2 name is Bob")
	assert(restored.get_player_deck(0).size() == 2, "Restored P1 deck size is 2")


func _test_player_input_router() -> void:
	print("Test 2: PlayerInputRouter Device Binding & Event Routing...")
	var config = MatchRulesConfig.new(MatchRulesConfig.MatchMode.SHARED_SCREEN_DUAL_PAD)
	config.set_player_loadout(0, "P1", "H1", [], [], 0) # P1 on Gamepad 0
	config.set_player_loadout(1, "P2", "H2", [], [], 1) # P2 on Gamepad 1

	var router = PlayerInputRouter.new(config)
	router.set_active_turn_player(0)

	# 1. Simulate Joypad Button A (Confirm) from Device 0 (P1)
	var joy_a = InputEventJoypadButton.new()
	joy_a.device = 0
	joy_a.button_index = JOY_BUTTON_A
	joy_a.pressed = true

	assert(router.is_event_allowed(joy_a) == true, "Device 0 allowed when P1 is active")
	var res_a = router.route_input_event(joy_a)
	assert(res_a.consumed == true, "Event should be consumed")
	assert(res_a.action == "confirm", "Action should be 'confirm'")
	assert(res_a.player_slot == 0, "Player slot should be 0")

	# 2. Simulate Joypad Button from Device 1 (P2) while P1's turn in Dual-Pad
	var joy_p2 = InputEventJoypadButton.new()
	joy_p2.device = 1
	joy_p2.button_index = JOY_BUTTON_A
	joy_p2.pressed = true

	assert(router.is_event_allowed(joy_p2) == false, "Device 1 should be blocked while P1 is active in Dual-Pad")
	var res_p2 = router.route_input_event(joy_p2)
	assert(res_p2.consumed == false, "Blocked event should not be consumed")

	# 3. Simulate Keyboard Input
	var key_space = InputEventKey.new()
	key_space.keycode = KEY_SPACE
	key_space.pressed = true

	# In Hotseat mode, keyboard works for active player
	config.mode = MatchRulesConfig.MatchMode.HOTSEAT_PASS_AND_PLAY
	assert(router.is_event_allowed(key_space) == true, "Keyboard allowed in Hotseat mode")
	var res_k = router.route_input_event(key_space)
	assert(res_k.consumed == true, "Key event consumed")
	assert(res_k.action == "confirm", "Key space routed to confirm")


func _test_controller_glyph_detection() -> void:
	print("Test 3: Controller Type Detection & Glyphs...")
	# Keyboard / Mouse
	var kbd_type = PlayerInputRouter.detect_controller_type(-1)
	assert(kbd_type == MatchRulesConfig.ControllerType.KEYBOARD_MOUSE, "Device -1 detected as Keyboard/Mouse")
	assert(PlayerInputRouter.get_action_glyph("confirm", kbd_type) == "Enter / Space", "Keyboard confirm glyph is Enter / Space")
	assert(PlayerInputRouter.get_action_glyph("floop", kbd_type) == "F", "Keyboard floop glyph is F")

	# PlayStation
	var ps_glyph = PlayerInputRouter.get_action_glyph("confirm", MatchRulesConfig.ControllerType.PLAYSTATION)
	assert(ps_glyph.contains("Cross"), "PlayStation confirm glyph is Cross")
	assert(PlayerInputRouter.get_action_glyph("end_turn", MatchRulesConfig.ControllerType.PLAYSTATION) == "R1", "PS end_turn is R1")

	# Steam Deck / Xbox
	var deck_glyph = PlayerInputRouter.get_action_glyph("confirm", MatchRulesConfig.ControllerType.STEAM_DECK)
	assert(deck_glyph == "A", "Steam Deck confirm glyph is A")
	assert(PlayerInputRouter.get_action_glyph("end_turn", MatchRulesConfig.ControllerType.STEAM_DECK) == "RB", "Steam Deck end_turn is RB")

	# Switch
	var switch_glyph = PlayerInputRouter.get_action_glyph("confirm", MatchRulesConfig.ControllerType.SWITCH)
	assert(switch_glyph == "B", "Nintendo Switch confirm glyph is B")


func _test_hotseat_curtain_lifecycle() -> void:
	print("Test 4: HotseatCurtain State Machine & Transitions...")
	var root = Control.new()
	root.custom_minimum_size = Vector2(800, 600)

	var curtain = HotseatCurtain.new()
	root.add_child(curtain)
	curtain._ready()

	assert(curtain.current_state == HotseatCurtain.CurtainState.INACTIVE, "Curtain starts INACTIVE")
	assert(curtain.visible == false, "Curtain starts hidden")

	var handoff_fired = [false]
	var unveil_fired = [false]

	curtain.handoff_started.connect(func(_slot, _pname): handoff_fired[0] = true)
	curtain.unveil_confirmed.connect(func(_slot): unveil_fired[0] = true)

	# Trigger handoff
	curtain.start_handoff(1, "Jake", MatchRulesConfig.ControllerType.STEAM_DECK)
	assert(curtain.visible == true, "Curtain visible when handoff started")
	assert(curtain.target_player_slot == 1, "Target slot is 1")
	assert(curtain.target_player_name == "Jake", "Target name is Jake")

	# Simulate immediate finish of lowering
	curtain.current_state = HotseatCurtain.CurtainState.AWAITING_HANDOFF

	# Player confirms unveil
	curtain._on_unveil_pressed()
	assert(unveil_fired[0] == true, "unveil_confirmed signal emitted")
	assert(curtain.current_state == HotseatCurtain.CurtainState.RAISING, "Curtain state is RAISING")

	root.queue_free()


func _test_gamepad_navigator() -> void:
	print("Test 5: GamepadNavigator 2D Focus Graph...")
	var nav = GamepadNavigator.new()

	# Create simulated control nodes
	var hand_nodes: Array[Control] = []
	for i in range(4):
		var btn = Button.new()
		hand_nodes.append(btn)

	var lane_nodes: Array[Control] = []
	for i in range(4):
		var btn = Button.new()
		lane_nodes.append(btn)

	var leader_btn = Button.new()
	var turn_btn = Button.new()

	nav.register_zone_nodes(GamepadNavigator.FocusZone.HAND, hand_nodes)
	nav.register_zone_nodes(GamepadNavigator.FocusZone.LANES, lane_nodes)
	nav.register_zone_nodes(GamepadNavigator.FocusZone.LEADER, [leader_btn])
	nav.register_zone_nodes(GamepadNavigator.FocusZone.END_TURN, [turn_btn])

	# Start focused on Hand index 0
	nav.focus_zone(GamepadNavigator.FocusZone.HAND, 0)
	assert(nav.current_zone == GamepadNavigator.FocusZone.HAND, "Zone is HAND")
	assert(nav.current_index == 0, "Index is 0")

	# Navigate RIGHT in Hand
	nav.navigate(Vector2.RIGHT)
	assert(nav.current_index == 1, "Navigated Right to Hand index 1")

	# Navigate UP from Hand to Lanes
	nav.navigate(Vector2.UP)
	assert(nav.current_zone == GamepadNavigator.FocusZone.LANES, "Navigated UP to LANES")
	assert(nav.current_index == 1, "Lane index preserved at 1")

	# Navigate UP from Lanes to LEADER
	nav.navigate(Vector2.UP)
	assert(nav.current_zone == GamepadNavigator.FocusZone.LEADER, "Navigated UP to LEADER")

	# Navigate RIGHT from Leader to END_TURN
	nav.navigate(Vector2.RIGHT)
	assert(nav.current_zone == GamepadNavigator.FocusZone.END_TURN, "Navigated RIGHT to END_TURN")

	# Navigate DOWN from END_TURN to Lanes
	nav.navigate(Vector2.DOWN)
	assert(nav.current_zone == GamepadNavigator.FocusZone.LANES, "Navigated DOWN to LANES")

	# Navigate DOWN from Lanes back to HAND
	nav.navigate(Vector2.DOWN)
	assert(nav.current_zone == GamepadNavigator.FocusZone.HAND, "Navigated DOWN to HAND")
