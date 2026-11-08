# TestbedNetworkMultiplayer.gd
# Interactive testbed demonstrating LAN discovery, connection, and action RPC synchronization.
extends Control

const LanDiscoveryClass = preload("LanDiscovery.gd")
const NetworkSessionManagerClass = preload("NetworkSessionManager.gd")
const TurnActionProtocolClass = preload("TurnActionProtocol.gd")

@onready var discovery: LanDiscovery = $LanDiscovery
@onready var session: NetworkSessionManager = $NetworkSessionManager
@onready var protocol: TurnActionProtocol = $TurnActionProtocol

@onready var host_btn: Button = %HostBtn
@onready var scan_btn: Button = %ScanBtn
@onready var direct_connect_btn: Button = %DirectConnectBtn
@onready var disconnect_btn: Button = %DisconnectBtn
@onready var ip_input: LineEdit = %IpInput
@onready var port_input: LineEdit = %PortInput
@onready var server_list: ItemList = %ServerList
@onready var status_label: Label = %StatusLabel
@onready var log_text: RichTextLabel = %LogText

# Actions
@onready var action_panel: PanelContainer = %ActionPanel
@onready var play_card_btn: Button = %PlayCardBtn
@onready var floop_btn: Button = %FloopBtn
@onready var leader_btn: Button = %LeaderBtn
@onready var end_turn_btn: Button = %EndTurnBtn


func _ready() -> void:
	discovery.server_discovered.connect(_on_server_discovered)
	discovery.server_expired.connect(_on_server_expired)

	session.session_created.connect(_on_session_created)
	session.peer_connected.connect(_on_peer_connected)
	session.peer_disconnected.connect(_on_peer_disconnected)
	session.connected_to_host.connect(_on_connected_to_host)
	session.connection_failed.connect(_on_connection_failed)
	session.host_disconnected.connect(_on_host_disconnected)
	session.session_closed.connect(_on_session_closed)

	protocol.action_executed.connect(_on_action_executed)
	protocol.handshake_received.connect(_on_handshake_received)

	host_btn.pressed.connect(_on_host_pressed)
	scan_btn.pressed.connect(_on_scan_pressed)
	direct_connect_btn.pressed.connect(_on_direct_connect_pressed)
	disconnect_btn.pressed.connect(_on_disconnect_pressed)
	server_list.item_selected.connect(_on_server_selected)

	play_card_btn.pressed.connect(func(): protocol.send_play_card("CARD_001", 0))
	floop_btn.pressed.connect(func(): protocol.send_floop(0))
	leader_btn.pressed.connect(func(): protocol.send_leader_power("finn"))
	end_turn_btn.pressed.connect(func(): protocol.send_end_turn())

	_update_ui()
	_log("Ready. Choose Host or Scan LAN.")


func _on_host_pressed() -> void:
	var port = int(port_input.text)
	var err = session.host_session(port, 2)
	if err == OK:
		discovery.start_broadcasting("Testbed LAN Room", port)
		_log("Hosting on port %d, broadcasting LAN beacons..." % port)
		_update_ui()
	else:
		_log("Failed to host on port %d: %d" % [port, err])


func _on_scan_pressed() -> void:
	server_list.clear()
	var err = discovery.start_listening()
	if err == OK:
		_log("Scanning local network for games on UDP 47777...")
	else:
		_log("Failed to start LAN scan: %d" % err)


func _on_direct_connect_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	var port = int(port_input.text)
	discovery.stop()
	var err = session.join_session(ip, port)
	if err == OK:
		_log("Connecting to %s:%d..." % [ip, port])
	else:
		_log("Connection error: %d" % err)


func _on_server_selected(idx: int) -> void:
	var metadata = server_list.get_item_metadata(idx)
	if metadata is Dictionary:
		ip_input.text = str(metadata.get("ip", "127.0.0.1"))
		port_input.text = str(metadata.get("game_port", 8910))


func _on_disconnect_pressed() -> void:
	discovery.stop()
	session.close_session()
	_log("Disconnected.")
	_update_ui()


func _on_server_discovered(ip: String, port: int, info: Dictionary) -> void:
	var label = "%s (%s:%d)" % [info.get("server_name", "Game"), ip, port]
	for i in range(server_list.item_count):
		var meta = server_list.get_item_metadata(i)
		if meta is Dictionary and meta.get("ip") == ip:
			server_list.set_item_text(i, label)
			return
	var new_idx = server_list.add_item(label)
	server_list.set_item_metadata(new_idx, info)
	_log("Discovered LAN Server: %s" % label)


func _on_server_expired(ip: String) -> void:
	for i in range(server_list.item_count):
		var meta = server_list.get_item_metadata(i)
		if meta is Dictionary and meta.get("ip") == ip:
			server_list.remove_item(i)
			_log("Server expired from LAN: %s" % ip)
			break


func _on_session_created(port: int) -> void:
	status_label.text = "Status: Hosting (Port %d)" % port
	_update_ui()


func _on_peer_connected(id: int) -> void:
	_log("Peer joined session: Peer ID %d" % id)
	# Send handshake
	protocol.send_handshake({
		"player_name": "HostPlayer" if session.is_host() else "ClientPlayer",
		"hero": "finn",
		"deck_size": 15
	})


func _on_peer_disconnected(id: int) -> void:
	_log("Peer disconnected: Peer ID %d" % id)


func _on_connected_to_host() -> void:
	status_label.text = "Status: Connected to Host!"
	_log("Successfully connected to host!")
	_update_ui()
	protocol.send_handshake({
		"player_name": "ClientPlayer",
		"hero": "jake",
		"deck_size": 15
	})


func _on_connection_failed() -> void:
	status_label.text = "Status: Connection Failed"
	_log("Failed to connect to host.")
	_update_ui()


func _on_host_disconnected() -> void:
	status_label.text = "Status: Host Disconnected"
	_log("Host closed the session.")
	_update_ui()


func _on_session_closed() -> void:
	status_label.text = "Status: Offline"
	_update_ui()


func _on_action_executed(sender_id: int, action_type: String, payload: Dictionary) -> void:
	_log("[RPC Action] From Peer %d: %s -> %s" % [sender_id, action_type, JSON.stringify(payload)])


func _on_handshake_received(sender_id: int, data: Dictionary) -> void:
	_log("[Handshake] Peer %d identified as '%s' (Hero: %s)" % [
		sender_id,
		data.get("player_name", "Unknown"),
		data.get("hero", "None")
	])


func _update_ui() -> void:
	var connected = session.is_connected_to_session() or session.is_host()
	action_panel.visible = connected
	disconnect_btn.disabled = not connected
	host_btn.disabled = connected
	direct_connect_btn.disabled = connected
	scan_btn.disabled = connected


func _log(msg: String) -> void:
	var line = "[%s] %s" % [Time.get_time_string_from_system(), msg]
	print(line)
	if log_text:
		log_text.append_text(line + "\n")
