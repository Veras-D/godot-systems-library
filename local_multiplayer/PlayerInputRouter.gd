class_name PlayerInputRouter
extends RefCounted

## PlayerInputRouter: Dispatches hardware input events to virtual player slots (P1 vs P2).
## Enforces input isolation in hotseat and dual gamepad matches, plus controller glyph detection.

const MatchRulesConfig = preload("MatchRulesConfig.gd")

signal action_routed(player_slot: int, action: String, data: Dictionary)
signal device_assigned(player_slot: int, device_id: int)

var config: MatchRulesConfig
var active_turn_player: int = 0 # 0 for P1, 1 for P2
var _player_devices: Dictionary = {
	0: -1, # P1: -1 = Keyboard/Mouse or Gamepad 0
	1: 0   # P2: 0 = Gamepad 0 or Gamepad 1
}


func _init(match_config: MatchRulesConfig = null) -> void:
	if match_config:
		config = match_config
		_player_devices[0] = config.p1_device_id
		_player_devices[1] = config.p2_device_id
	else:
		config = MatchRulesConfig.new()


func bind_device(player_slot: int, device_id: int) -> void:
	_player_devices[player_slot] = device_id
	if config:
		if player_slot == 0:
			config.p1_device_id = device_id
		else:
			config.p2_device_id = device_id
	device_assigned.emit(player_slot, device_id)


func get_bound_device(player_slot: int) -> int:
	return int(_player_devices.get(player_slot, -1))


func set_active_turn_player(player_slot: int) -> void:
	active_turn_player = clampi(player_slot, 0, 1)


## Evaluates whether an input event is valid for the current match state and active player.
func is_event_allowed(event: InputEvent) -> bool:
	if event == null:
		return false

	var event_device = event.device
	var is_joypad = (event is InputEventJoypadButton or event is InputEventJoypadMotion)
	var is_kbd_mouse = (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion)

	if config == null or config.is_hotseat():
		# In hotseat pass-and-play, any active hardware event belongs to the current turn player
		return true

	if config.is_shared_screen():
		# In dual-pad shared screen, verify that the event device matches the active player's bound device
		var expected_device = get_bound_device(active_turn_player)
		if is_joypad:
			return event_device == expected_device
		elif is_kbd_mouse:
			# Keyboard/mouse bound to player -1
			return expected_device == -1

	return true


## Routes an input event into a standardized action dictionary.
## Returns {"consumed": bool, "player_slot": int, "action": String, "direction": Vector2}
func route_input_event(event: InputEvent) -> Dictionary:
	var result = {
		"consumed": false,
		"player_slot": active_turn_player,
		"action": "",
		"direction": Vector2.ZERO
	}

	if not is_event_allowed(event):
		return result

	# Joypad Button
	if event is InputEventJoypadButton and event.is_pressed():
		var btn = event.button_index
		match btn:
			JOY_BUTTON_A:
				result.action = "confirm"
				result.consumed = true
			JOY_BUTTON_B:
				result.action = "cancel"
				result.consumed = true
			JOY_BUTTON_X:
				result.action = "floop"
				result.consumed = true
			JOY_BUTTON_Y:
				result.action = "leader_power"
				result.consumed = true
			JOY_BUTTON_RIGHT_SHOULDER:
				result.action = "end_turn"
				result.consumed = true
			JOY_BUTTON_LEFT_SHOULDER:
				result.action = "inspect"
				result.consumed = true
			JOY_BUTTON_DPAD_LEFT:
				result.action = "navigate"
				result.direction = Vector2.LEFT
				result.consumed = true
			JOY_BUTTON_DPAD_RIGHT:
				result.action = "navigate"
				result.direction = Vector2.RIGHT
				result.consumed = true
			JOY_BUTTON_DPAD_UP:
				result.action = "navigate"
				result.direction = Vector2.UP
				result.consumed = true
			JOY_BUTTON_DPAD_DOWN:
				result.action = "navigate"
				result.direction = Vector2.DOWN
				result.consumed = true

	# Joypad Motion (Stick navigation with 0.5 deadzone)
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
		var axis = event.axis
		match axis:
			JOY_AXIS_LEFT_X:
				result.action = "navigate"
				result.direction = Vector2.RIGHT if event.axis_value > 0 else Vector2.LEFT
				result.consumed = true
			JOY_AXIS_LEFT_Y:
				result.action = "navigate"
				result.direction = Vector2.DOWN if event.axis_value > 0 else Vector2.UP
				result.consumed = true

	# Keyboard Keys
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key = event.keycode
		match key:
			KEY_ENTER, KEY_SPACE:
				result.action = "confirm"
				result.consumed = true
			KEY_ESCAPE, KEY_BACKSPACE:
				result.action = "cancel"
				result.consumed = true
			KEY_F:
				result.action = "floop"
				result.consumed = true
			KEY_Q:
				result.action = "leader_power"
				result.consumed = true
			KEY_E, KEY_TAB:
				result.action = "end_turn"
				result.consumed = true
			KEY_LEFT, KEY_A:
				result.action = "navigate"
				result.direction = Vector2.LEFT
				result.consumed = true
			KEY_RIGHT, KEY_D:
				result.action = "navigate"
				result.direction = Vector2.RIGHT
				result.consumed = true
			KEY_UP, KEY_W:
				result.action = "navigate"
				result.direction = Vector2.UP
				result.consumed = true
			KEY_DOWN, KEY_S:
				result.action = "navigate"
				result.direction = Vector2.DOWN
				result.consumed = true

	if result.consumed:
		action_routed.emit(result.player_slot, result.action, result)

	return result


## Identifies the controller type for glyph representation (Steam Deck, Xbox, PlayStation, Switch).
static func detect_controller_type(device_id: int) -> int:
	if device_id < 0:
		return MatchRulesConfig.ControllerType.KEYBOARD_MOUSE

	var joy_name = Input.get_joy_name(device_id).to_lower()
	if joy_name.contains("steam") or joy_name.contains("deck") or joy_name.contains("valve"):
		return MatchRulesConfig.ControllerType.STEAM_DECK
	elif joy_name.contains("playstation") or joy_name.contains("ps4") or joy_name.contains("ps5") or joy_name.contains("dualshock") or joy_name.contains("dualsense"):
		return MatchRulesConfig.ControllerType.PLAYSTATION
	elif joy_name.contains("switch") or joy_name.contains("nintendo") or joy_name.contains("joy-con") or joy_name.contains("pro controller"):
		return MatchRulesConfig.ControllerType.SWITCH
	elif joy_name.contains("xbox") or joy_name.contains("x-box") or joy_name.contains("microsoft"):
		return MatchRulesConfig.ControllerType.XBOX

	return MatchRulesConfig.ControllerType.GENERIC_GAMEPAD


## Returns the button label or unicode symbol glyph for an action.
static func get_action_glyph(action: String, controller_type: int) -> String:
	match controller_type:
		MatchRulesConfig.ControllerType.KEYBOARD_MOUSE:
			match action:
				"confirm": return "Enter / Space"
				"cancel": return "Esc"
				"floop": return "F"
				"leader_power": return "Q"
				"end_turn": return "E"
				"inspect": return "I"
				_: return action.capitalize()

		MatchRulesConfig.ControllerType.PLAYSTATION:
			match action:
				"confirm": return "✕ (Cross)"
				"cancel": return "○ (Circle)"
				"floop": return "□ (Square)"
				"leader_power": return "△ (Triangle)"
				"end_turn": return "R1"
				"inspect": return "L1"
				_: return action.capitalize()

		MatchRulesConfig.ControllerType.SWITCH:
			match action:
				"confirm": return "B"
				"cancel": return "A"
				"floop": return "Y"
				"leader_power": return "X"
				"end_turn": return "R"
				"inspect": return "L"
				_: return action.capitalize()

		MatchRulesConfig.ControllerType.STEAM_DECK, MatchRulesConfig.ControllerType.XBOX, _:
			match action:
				"confirm": return "A"
				"cancel": return "B"
				"floop": return "X"
				"leader_power": return "Y"
				"end_turn": return "RB"
				"inspect": return "LB"
				_: return action.capitalize()
