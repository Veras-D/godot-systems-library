extends SceneTree

## Automated Headless Unit Test Suite for SYS-11 (network_multiplayer)

const LanDiscovery = preload("LanDiscovery.gd")
const NetworkSessionManager = preload("NetworkSessionManager.gd")
const TurnActionProtocol = preload("TurnActionProtocol.gd")


func _init() -> void:
	print("\n========================================================")
	print("  RUNNING NETWORK MULTIPLAYER SYSTEM TESTS (SYS-11)")
	print("========================================================\n")

	_test_lan_discovery_payload_and_expiry()
	_test_network_session_manager_lifecycle()
	_test_turn_action_protocol_dispatch()
	_test_turn_action_payloads()

	print("\n==> ALL Network Multiplayer Tests PASSED SUCCESSFULLY!")
	quit(0)


func _test_lan_discovery_payload_and_expiry() -> void:
	print("Test 1: LanDiscovery Payload Generation & Expiry...")
	var discovery = LanDiscovery.new()
	assert(discovery.game_identifier == LanDiscovery.DEFAULT_GAME_ID, "Default game ID mismatch")
	assert(discovery.discovery_port == LanDiscovery.DEFAULT_DISCOVERY_PORT, "Default discovery port mismatch")

	# Test broadcast initialization
	var err = discovery.start_broadcasting("Test Host", 8910, {"room_id": "ROOM_123"})
	assert(err == OK, "start_broadcasting returned non-OK: %d" % err)
	assert(discovery.is_broadcaster == true, "Should be in broadcaster state")
	assert(discovery.is_listener == false, "Should not be in listener state")

	# Simulate packet reception directly
	var mock_info = {
		"ip": "192.168.1.50",
		"game_port": 8910,
		"server_name": "Test Host",
		"extra_info": {"room_id": "ROOM_123"},
		"last_seen": (Time.get_ticks_msec() / 1000.0) - 10.0 # Force expired
	}
	discovery._discovered_servers["192.168.1.50"] = mock_info

	var servers = discovery.get_discovered_servers()
	assert(servers.has("192.168.1.50"), "Server should exist before cleanup")

	var state = {"expired": false}
	discovery.server_expired.connect(func(ip):
		if ip == "192.168.1.50":
			state["expired"] = true
	)

	discovery._clean_expired_servers()
	assert(state["expired"] == true, "Server should have expired after 10 seconds")
	assert(not discovery.get_discovered_servers().has("192.168.1.50"), "Server should be removed from dictionary")

	discovery.stop()
	assert(discovery.is_broadcaster == false, "Broadcaster should be false after stop()")
	assert(discovery.udp == null, "UDP socket should be closed and null")
	discovery.free()
	print("  ✔ LanDiscovery passed")


func _test_network_session_manager_lifecycle() -> void:
	print("Test 2: NetworkSessionManager Lifecycle & Roles...")
	var session = NetworkSessionManager.new()
	assert(session.current_role == NetworkSessionManager.Role.NONE, "Default role should be NONE")
	assert(session.is_host() == false, "Should not be host initially")
	assert(session.is_client() == false, "Should not be client initially")

	# Verify state reset on close
	session.current_role = NetworkSessionManager.Role.HOST
	session.close_session()
	assert(session.current_role == NetworkSessionManager.Role.NONE, "Role should be NONE after close_session")
	assert(session.enet_peer == null, "enet_peer should be null")
	session.free()
	print("  ✔ NetworkSessionManager lifecycle passed")


func _test_turn_action_protocol_dispatch() -> void:
	print("Test 3: TurnActionProtocol Action Dispatch...")
	var protocol = TurnActionProtocol.new()

	var state = {
		"action_received": false,
		"action_type": "",
		"payload": {},
		"handshake_received": false
	}

	protocol.action_executed.connect(func(sender_id: int, action_type: String, payload: Dictionary):
		state["action_received"] = true
		state["action_type"] = action_type
		state["payload"] = payload
	)

	# Offline / local dispatch test
	protocol.send_play_card("CARD_PIG", 2, false)
	assert(state["action_received"] == true, "Action should be executed")
	assert(state["action_type"] == TurnActionProtocol.ACTION_PLAY_CARD, "Action type should be PLAY_CARD")
	assert(state["payload"].get("card_id") == "CARD_PIG", "Payload card_id mismatch")
	assert(state["payload"].get("target_slot") == 2, "Payload target_slot mismatch")
	assert(state["payload"].get("is_spell") == false, "Payload is_spell mismatch")

	# Handshake test
	protocol.handshake_received.connect(func(sender_id: int, data: Dictionary):
		state["handshake_received"] = true
	)

	var p_data = {
		"player_name": "Finn",
		"hero": "finn_hero",
		"deck": ["C1", "C2", "C3"],
		"landscapes": ["Plains", "Plains", "Cotton", "Plains"]
	}
	protocol.send_handshake(p_data)
	assert(state["handshake_received"] == true, "Handshake signal should be emitted")
	assert(protocol.peer_handshakes.has(1), "Handshake should be saved for peer 1")
	assert(protocol.peer_handshakes[1]["player_name"] == "Finn", "Handshake name mismatch")

	protocol.free()
	print("  ✔ TurnActionProtocol dispatch passed")


func _test_turn_action_payloads() -> void:
	print("Test 4: Action Helper Methods & Payloads...")
	var protocol = TurnActionProtocol.new()
	var state = {
		"last_action": "",
		"last_payload": {}
	}

	protocol.action_executed.connect(func(sender_id: int, action_type: String, payload: Dictionary):
		state["last_action"] = action_type
		state["last_payload"] = payload
	)

	# Floop
	protocol.send_floop(3)
	assert(state["last_action"] == TurnActionProtocol.ACTION_FLOOP, "Action was not FLOOP")
	assert(state["last_payload"].get("slot_index") == 3, "Floop slot mismatch")

	# Leader Power
	protocol.send_leader_power("jake")
	assert(state["last_action"] == TurnActionProtocol.ACTION_LEADER_POWER, "Action was not LEADER_POWER")
	assert(state["last_payload"].get("hero_id") == "jake", "Leader hero mismatch")

	# Wheel Result
	protocol.send_wheel_result("CRITICAL", 2.0)
	assert(state["last_action"] == TurnActionProtocol.ACTION_WHEEL_RESULT, "Action was not WHEEL_RESULT")
	assert(state["last_payload"].get("hit_type") == "CRITICAL", "Hit type mismatch")
	assert(state["last_payload"].get("multiplier") == 2.0, "Multiplier mismatch")

	# End Turn
	protocol.send_end_turn()
	assert(state["last_action"] == TurnActionProtocol.ACTION_END_TURN, "Action was not END_TURN")

	# Surrender
	protocol.send_surrender()
	assert(state["last_action"] == TurnActionProtocol.ACTION_SURRENDER, "Action was not SURRENDER")

	protocol.free()
	print("  ✔ Action helper methods passed")
