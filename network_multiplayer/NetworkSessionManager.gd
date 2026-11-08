# NetworkSessionManager.gd
# Universal session host and client connector using Godot 4 ENetMultiplayerPeer.
# Compatible with Godot 4.x.
class_name NetworkSessionManager
extends Node

const DEFAULT_PORT: int = 8910
const DEFAULT_MAX_PLAYERS: int = 2

signal session_created(port: int)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_host
signal connection_failed
signal host_disconnected
signal session_closed

enum Role {
	NONE,
	HOST,
	CLIENT
}

var current_role: Role = Role.NONE
var enet_peer: ENetMultiplayerPeer = null
var active_port: int = DEFAULT_PORT
var host_address: String = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_connect_multiplayer_signals()


func _exit_tree() -> void:
	close_session()


func _connect_multiplayer_signals() -> void:
	if not is_inside_tree():
		return
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


## Creates an authoritative host session listening on [param port].
func host_session(port: int = DEFAULT_PORT, max_clients: int = 1) -> Error:
	close_session()
	active_port = port

	enet_peer = ENetMultiplayerPeer.new()
	var err = enet_peer.create_server(port, max_clients)
	if err != OK:
		push_warning("NetworkSessionManager: Failed to create server on port %d: %d" % [port, err])
		enet_peer = null
		return err

	if is_inside_tree() and multiplayer:
		multiplayer.multiplayer_peer = enet_peer
	current_role = Role.HOST
	session_created.emit(port)
	return OK


## Connects to an existing host session at [param address] and [param port].
func join_session(address: String, port: int = DEFAULT_PORT) -> Error:
	close_session()
	active_port = port
	host_address = address

	enet_peer = ENetMultiplayerPeer.new()
	var err = enet_peer.create_client(address, port)
	if err != OK:
		push_warning("NetworkSessionManager: Failed to connect to %s:%d (error %d)" % [address, port, err])
		enet_peer = null
		return err

	if is_inside_tree() and multiplayer:
		multiplayer.multiplayer_peer = enet_peer
	current_role = Role.CLIENT
	return OK


## Closes any active network session and resets the multiplayer peer.
func close_session() -> void:
	if enet_peer != null:
		enet_peer.close()
		enet_peer = null

	if is_inside_tree() and multiplayer and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null

	current_role = Role.NONE
	session_closed.emit()


func is_host() -> bool:
	if not is_inside_tree() or multiplayer == null:
		return current_role == Role.HOST
	return current_role == Role.HOST and multiplayer.is_server()


func is_client() -> bool:
	if not is_inside_tree() or multiplayer == null:
		return current_role == Role.CLIENT
	return current_role == Role.CLIENT and not multiplayer.is_server()


func is_connected_to_session() -> bool:
	if not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null:
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func get_local_peer_id() -> int:
	if is_inside_tree() and multiplayer and multiplayer.multiplayer_peer != null:
		return multiplayer.get_unique_id()
	return 1


func get_connected_peers() -> Array[int]:
	var result: Array[int] = []
	if is_inside_tree() and multiplayer and multiplayer.multiplayer_peer != null:
		for id in multiplayer.get_peers():
			result.append(id)
	return result


# --- Internal Signal Handlers ---

func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)


func _on_connected_to_server() -> void:
	connected_to_host.emit()


func _on_connection_failed() -> void:
	close_session()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	close_session()
	host_disconnected.emit()
