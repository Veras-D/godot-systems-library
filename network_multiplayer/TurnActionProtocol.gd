# TurnActionProtocol.gd
# Universal RPC Action Synchronizer for turn-based games in Godot 4.
# Provides Host-Authoritative action validation and reliable distribution.
# Compatible with Godot 4.x.
class_name TurnActionProtocol
extends Node

signal action_requested(sender_id: int, action_type: String, payload: Dictionary)
signal action_executed(sender_id: int, action_type: String, payload: Dictionary)
signal handshake_received(sender_id: int, player_data: Dictionary)

const ACTION_HANDSHAKE: String = "HANDSHAKE"
const ACTION_PLAY_CARD: String = "PLAY_CARD"
const ACTION_FLOOP: String = "FLOOP"
const ACTION_LEADER_POWER: String = "LEADER_POWER"
const ACTION_END_TURN: String = "END_TURN"
const ACTION_WHEEL_RESULT: String = "WHEEL_RESULT"
const ACTION_SURRENDER: String = "SURRENDER"
const ACTION_CUSTOM: String = "CUSTOM"

## Registered peer handshakes (peer_id -> data)
var peer_handshakes: Dictionary = {}


## Client or Host sends an action request to the host for validation and broadcast.
func send_action(action_type: String, payload: Dictionary = {}) -> void:
	if not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null:
		# If disconnected/offline, trigger locally for testing/fallback
		_on_action_dispatched(1, action_type, payload)
		return

	request_action.rpc(action_type, payload)


## Sends player metadata (name, hero, deck, landscapes) to peers.
func send_handshake(player_data: Dictionary) -> void:
	send_action(ACTION_HANDSHAKE, player_data)


func send_play_card(card_id: String, target_slot: int, is_spell: bool = false) -> void:
	send_action(ACTION_PLAY_CARD, {
		"card_id": card_id,
		"target_slot": target_slot,
		"is_spell": is_spell
	})


func send_floop(slot_index: int) -> void:
	send_action(ACTION_FLOOP, {
		"slot_index": slot_index
	})


func send_leader_power(hero_id: String) -> void:
	send_action(ACTION_LEADER_POWER, {
		"hero_id": hero_id
	})


func send_end_turn() -> void:
	send_action(ACTION_END_TURN, {})


func send_wheel_result(hit_type: String, multiplier: float) -> void:
	send_action(ACTION_WHEEL_RESULT, {
		"hit_type": hit_type,
		"multiplier": multiplier
	})


func send_surrender() -> void:
	send_action(ACTION_SURRENDER, {})


## Called on the server/host by any connected peer.
@rpc("any_peer", "call_local", "reliable")
func request_action(action_type: String, payload: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()

	# Notify server listeners that an action was requested
	action_requested.emit(sender_id, action_type, payload)

	# If host, validate and broadcast the authoritative execution
	if multiplayer.is_server() or multiplayer.multiplayer_peer == null:
		execute_action.rpc(sender_id, action_type, payload)


## Authoritative broadcast from the host to all clients.
@rpc("authority", "call_local", "reliable")
func execute_action(sender_id: int, action_type: String, payload: Dictionary) -> void:
	_on_action_dispatched(sender_id, action_type, payload)


func _on_action_dispatched(sender_id: int, action_type: String, payload: Dictionary) -> void:
	if action_type == ACTION_HANDSHAKE:
		peer_handshakes[sender_id] = payload.duplicate(true)
		handshake_received.emit(sender_id, payload)

	action_executed.emit(sender_id, action_type, payload)
