class_name MatchRulesConfig
extends RefCounted

## MatchRulesConfig: Configuration container for match format, player loadouts, and input device assignments.
## Decoupled from specific game lore, supporting hotseat pass-and-play, dual gamepad, and solo vs AI.

enum MatchMode {
	HOTSEAT_PASS_AND_PLAY,   # 1 device, turns alternate with HotseatCurtain privacy screen
	SHARED_SCREEN_DUAL_PAD,  # 2 gamepads or split keyboard, simultaneous/shared view
	SOLO_VS_AI               # 1 player vs AI bot
}

enum ControllerType {
	KEYBOARD_MOUSE,
	XBOX,
	PLAYSTATION,
	SWITCH,
	STEAM_DECK,
	GENERIC_GAMEPAD
}

var mode: MatchMode = MatchMode.HOTSEAT_PASS_AND_PLAY
var turn_time_limit_sec: int = 0 # 0 = unlimited

# Player 1 Loadout
var p1_name: String = "Player 1"
var p1_hero_id: String = "Hero_1"
var p1_deck: Array[String] = []
var p1_landscapes: Array[String] = []
var p1_device_id: int = -1 # -1 = keyboard/mouse, 0+ = joypad device index

# Player 2 Loadout
var p2_name: String = "Player 2"
var p2_hero_id: String = "Hero_2"
var p2_deck: Array[String] = []
var p2_landscapes: Array[String] = []
var p2_device_id: int = 0
var p2_is_ai: bool = false


func _init(match_mode: MatchMode = MatchMode.HOTSEAT_PASS_AND_PLAY) -> void:
	mode = match_mode


func set_player_loadout(slot: int, player_name: String, hero_id: String, deck: Array[String], landscapes: Array[String], device_id: int = -1) -> void:
	if slot == 0:
		p1_name = player_name
		p1_hero_id = hero_id
		p1_deck = deck.duplicate()
		p1_landscapes = landscapes.duplicate()
		p1_device_id = device_id
	else:
		p2_name = player_name
		p2_hero_id = hero_id
		p2_deck = deck.duplicate()
		p2_landscapes = landscapes.duplicate()
		p2_device_id = device_id


func get_player_name(slot: int) -> String:
	return p1_name if slot == 0 else p2_name


func get_player_device(slot: int) -> int:
	return p1_device_id if slot == 0 else p2_device_id


func get_player_deck(slot: int) -> Array[String]:
	return p1_deck if slot == 0 else p2_deck


func get_player_landscapes(slot: int) -> Array[String]:
	return p1_landscapes if slot == 0 else p2_landscapes


func is_hotseat() -> bool:
	return mode == MatchMode.HOTSEAT_PASS_AND_PLAY


func is_shared_screen() -> bool:
	return mode == MatchMode.SHARED_SCREEN_DUAL_PAD


func is_vs_ai() -> bool:
	return mode == MatchMode.SOLO_VS_AI or p2_is_ai


func serialize() -> Dictionary:
	return {
		"mode": mode,
		"turn_time_limit_sec": turn_time_limit_sec,
		"p1": {
			"name": p1_name,
			"hero_id": p1_hero_id,
			"deck": p1_deck,
			"landscapes": p1_landscapes,
			"device_id": p1_device_id
		},
		"p2": {
			"name": p2_name,
			"hero_id": p2_hero_id,
			"deck": p2_deck,
			"landscapes": p2_landscapes,
			"device_id": p2_device_id,
			"is_ai": p2_is_ai
		}
	}


func deserialize(data: Dictionary) -> void:
	if data.is_empty():
		return
	mode = int(data.get("mode", MatchMode.HOTSEAT_PASS_AND_PLAY)) as MatchMode
	turn_time_limit_sec = int(data.get("turn_time_limit_sec", 0))

	if data.has("p1") and typeof(data["p1"]) == TYPE_DICTIONARY:
		var p1 = data["p1"]
		p1_name = str(p1.get("name", "Player 1"))
		p1_hero_id = str(p1.get("hero_id", "Hero_1"))
		p1_deck.clear()
		for c in p1.get("deck", []): p1_deck.append(str(c))
		p1_landscapes.clear()
		for l in p1.get("landscapes", []): p1_landscapes.append(str(l))
		p1_device_id = int(p1.get("device_id", -1))

	if data.has("p2") and typeof(data["p2"]) == TYPE_DICTIONARY:
		var p2 = data["p2"]
		p2_name = str(p2.get("name", "Player 2"))
		p2_hero_id = str(p2.get("hero_id", "Hero_2"))
		p2_deck.clear()
		for c in p2.get("deck", []): p2_deck.append(str(c))
		p2_landscapes.clear()
		for l in p2.get("landscapes", []): p2_landscapes.append(str(l))
		p2_device_id = int(p2.get("device_id", 0))
		p2_is_ai = bool(p2.get("is_ai", false))
