# LanDiscovery.gd
# Standalone UDP Broadcast & Listener for Zero-Configuration Local Area Network discovery.
# Compatible with Godot 4.x.
class_name LanDiscovery
extends Node

const DEFAULT_DISCOVERY_PORT: int = 47777
const DEFAULT_BROADCAST_INTERVAL: float = 1.5
const DEFAULT_EXPIRY_SECONDS: float = 4.5
const DEFAULT_GAME_ID: String = "godot_systems_net"

signal server_discovered(ip: String, port: int, info: Dictionary)
signal server_expired(ip: String)
signal broadcast_started(port: int)
signal listening_started(port: int)
signal stopped

@export var game_identifier: String = DEFAULT_GAME_ID
@export var discovery_port: int = DEFAULT_DISCOVERY_PORT
@export var broadcast_interval: float = DEFAULT_BROADCAST_INTERVAL
@export var expiry_seconds: float = DEFAULT_EXPIRY_SECONDS

var is_broadcaster: bool = false
var is_listener: bool = false
var udp: PacketPeerUDP = null

var _broadcast_timer: float = 0.0
var _broadcast_data: Dictionary = {}
var _discovered_servers: Dictionary = {} # ip -> { "port": int, "info": Dictionary, "last_seen": float }


func _ready() -> void:
	set_process(true)


func _exit_tree() -> void:
	stop()


func start_broadcasting(server_name: String, game_port: int = 8910, extra_info: Dictionary = {}, port: int = DEFAULT_DISCOVERY_PORT) -> Error:
	stop()
	discovery_port = port

	udp = PacketPeerUDP.new()
	# Bind to ephemeral port (0) so multiple host/client instances can coexist on local machine
	var err = udp.bind(0)
	if err != OK:
		push_warning("LanDiscovery: Failed to bind broadcast socket: %d" % err)
		return err

	udp.set_broadcast_enabled(true)
	udp.set_dest_address("255.255.255.255", discovery_port)

	_broadcast_data = {
		"game_id": game_identifier,
		"server_name": server_name,
		"game_port": game_port,
		"extra_info": extra_info,
		"timestamp": Time.get_unix_time_from_system()
	}

	is_broadcaster = true
	_broadcast_timer = broadcast_interval # Trigger immediately on first frame
	broadcast_started.emit(discovery_port)
	return OK


func start_listening(port: int = DEFAULT_DISCOVERY_PORT) -> Error:
	stop()
	discovery_port = port
	_discovered_servers.clear()

	udp = PacketPeerUDP.new()
	var err = udp.bind(discovery_port)
	if err != OK:
		push_warning("LanDiscovery: Failed to bind listening socket on port %d: %d" % [discovery_port, err])
		return err

	is_listener = true
	listening_started.emit(discovery_port)
	return OK


func stop() -> void:
	if udp:
		udp.close()
		udp = null
	is_broadcaster = false
	is_listener = false
	_broadcast_timer = 0.0
	_discovered_servers.clear()
	stopped.emit()


func get_discovered_servers() -> Dictionary:
	return _discovered_servers.duplicate(true)


func _process(delta: float) -> void:
	if is_broadcaster and udp:
		_broadcast_timer += delta
		if _broadcast_timer >= broadcast_interval:
			_broadcast_timer = 0.0
			_send_broadcast()

	if is_listener and udp:
		_receive_packets()
		_clean_expired_servers()


func _send_broadcast() -> void:
	if not udp:
		return
	_broadcast_data["timestamp"] = Time.get_unix_time_from_system()
	var packet_str = JSON.stringify(_broadcast_data)
	var err = udp.put_packet(packet_str.to_utf8_buffer())
	if err != OK:
		push_warning("LanDiscovery: Error sending broadcast packet: %d" % err)


func _receive_packets() -> void:
	while udp and udp.get_available_packet_count() > 0:
		var sender_ip = udp.get_packet_ip()
		var packet_bytes = udp.get_packet()
		var text = packet_bytes.get_string_from_utf8()
		var parsed = JSON.parse_string(text)

		if parsed is Dictionary and parsed.get("game_id", "") == game_identifier:
			var g_port = int(parsed.get("game_port", 8910))
			var now = Time.get_ticks_msec() / 1000.0

			var is_new = not _discovered_servers.has(sender_ip)
			_discovered_servers[sender_ip] = {
				"ip": sender_ip,
				"game_port": g_port,
				"server_name": str(parsed.get("server_name", "Game Room")),
				"extra_info": parsed.get("extra_info", {}),
				"last_seen": now
			}

			server_discovered.emit(sender_ip, g_port, _discovered_servers[sender_ip])


func _clean_expired_servers() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var to_remove: Array[String] = []

	for ip in _discovered_servers.keys():
		var server = _discovered_servers[ip]
		if (now - float(server.get("last_seen", now))) > expiry_seconds:
			to_remove.append(ip)

	for ip in to_remove:
		_discovered_servers.erase(ip)
		server_expired.emit(ip)
