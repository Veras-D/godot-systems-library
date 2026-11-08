# SYS-11: Network Multiplayer & LAN Discovery

Universal Host-Authoritative Turn-Action RPC networking and Zero-Configuration LAN UDP Discovery module for Godot 4.x.

---

## 📦 Features

- **`LanDiscovery.gd`**:
  - Zero-configuration local network discovery using `PacketPeerUDP`.
  - Non-blocking ephemeral port binding (`bind(0)`) on broadcaster to avoid local machine socket collisions.
  - Periodic heartbeat beacons (1.5s interval) to `255.255.255.255:47777`.
  - Dynamic discovery and automated expiry of unresponsive LAN hosts (4.5s timeout).
- **`NetworkSessionManager.gd`**:
  - High-level `ENetMultiplayerPeer` session lifecycle manager.
  - Role management (`HOST`, `CLIENT`, `NONE`).
  - Standard connection signals (`session_created`, `peer_connected`, `peer_disconnected`, `connected_to_host`, `connection_failed`).
- **`TurnActionProtocol.gd`**:
  - High-level reliable RPC action dispatcher (`@rpc("any_peer", "call_local", "reliable")` & `@rpc("authority", "call_local", "reliable")`).
  - Pre-built action helpers for turn-based card and board games:
    - Handshake metadata (`send_handshake`)
    - Card plays (`send_play_card`)
    - Ability activations / Floop (`send_floop`)
    - Leader powers (`send_leader_power`)
    - Turn end notifications (`send_end_turn`)
    - RNG wheel synchronization (`send_wheel_result`)
    - Match forfeit (`send_surrender`)
- **Interactive Testbed (`testbed_network_multiplayer.tscn`)**:
  - Live LAN scanner, host broadcaster, direct IP connect, and interactive turn action inspection.

---

## 🚀 Quick Integration

### 1. Host a LAN Session
```gdscript
var session = NetworkSessionManager.new()
var discovery = LanDiscovery.new()
add_child(session)
add_child(discovery)

# Host game on port 8910
session.host_session(8910)
# Broadcast discovery beacon on UDP port 47777
discovery.start_broadcasting("Alice's Room", 8910)
```

### 2. Scan and Connect as Client
```gdscript
discovery.server_discovered.connect(func(ip, port, info):
    print("Found server: ", info["server_name"], " at ", ip)
    discovery.stop()
    session.join_session(ip, port)
)
discovery.start_listening()
```

### 3. Send Turn Actions
```gdscript
var protocol = TurnActionProtocol.new()
add_child(protocol)

protocol.action_executed.connect(func(sender_id, action_type, payload):
    print("Action executed: ", action_type, " from peer ", sender_id)
)

# Play a card on slot 1
protocol.send_play_card("CREATURE_001", 1)
```

---

## 🧪 Testing

Run headless unit tests:
```bash
godot --headless -s network_multiplayer/test_network_multiplayer.gd
```
