class_name NodeMapGraph
extends RefCounted

## Universal Directed Acyclic Graph (DAG) for Quest & Campaign Maps
##
## Decoupled from specific game lore, art, or rules. Manages node dependencies,
## prerequisite unlocking, completion states, star ratings, and persistence.

signal node_unlocked(node_id: String)
signal node_completed(node_id: String, stars: int, first_clear: bool)
signal node_updated(node_id: String)

enum NodeState {
	LOCKED = 0,
	UNLOCKED = 1,
	COMPLETED = 2
}

# node_id -> Dictionary
var _nodes: Dictionary = {}

# from_id -> Array[String] (outgoing edge targets)
var _outgoing_edges: Dictionary = {}

# to_id -> Array[String] (incoming edge sources)
var _incoming_edges: Dictionary = {}


## Registers a node in the graph.
## Required fields in node_data:
## - "id": String
## Optional fields:
## - "title": String (default = id)
## - "position": Vector2 (default = Vector2.ZERO)
## - "state": int (default = LOCKED)
## - "stars": int (default = 0)
## - "prerequisites": Array[String] (default = [])
## - "connections": Array[String] (outgoing connections, default = [])
## - "conditions": Array[Dictionary] (default = [])
## - "rewards": Dictionary (default = {})
## - "metadata": Dictionary (default = {})
func add_node(node_data: Dictionary) -> bool:
	var nid = str(node_data.get("id", "")).strip_edges()
	if nid == "":
		return false

	var prereqs: Array[String] = []
	for p in node_data.get("prerequisites", []):
		prereqs.append(str(p).strip_edges())

	var conns: Array[String] = []
	for c in node_data.get("connections", []):
		conns.append(str(c).strip_edges())

	var conditions: Array[Dictionary] = []
	for cond in node_data.get("conditions", []):
		if typeof(cond) == TYPE_DICTIONARY:
			conditions.append(cond.duplicate(true))

	var pos = node_data.get("position", Vector2.ZERO)
	if typeof(pos) == TYPE_ARRAY and pos.size() >= 2:
		pos = Vector2(float(pos[0]), float(pos[1]))
	elif typeof(pos) != TYPE_VECTOR2:
		pos = Vector2.ZERO

	var node_entry = {
		"id": nid,
		"title": str(node_data.get("title", nid)),
		"position": pos,
		"state": int(node_data.get("state", NodeState.LOCKED)),
		"stars": clampi(int(node_data.get("stars", 0)), 0, 3),
		"prerequisites": prereqs,
		"connections": conns,
		"conditions": conditions,
		"rewards": node_data.get("rewards", {}).duplicate(true),
		"metadata": node_data.get("metadata", {}).duplicate(true)
	}

	_nodes[nid] = node_entry
	if not _outgoing_edges.has(nid):
		_outgoing_edges[nid] = []
	if not _incoming_edges.has(nid):
		_incoming_edges[nid] = []

	for target_id in conns:
		connect_nodes(nid, target_id)

	# If prerequisites were declared, link them as incoming edges
	for prereq_id in prereqs:
		connect_nodes(prereq_id, nid)

	return true


## Checks if a node exists.
func has_node(node_id: String) -> bool:
	return _nodes.has(node_id)


## Returns node dictionary or empty dictionary if missing.
func get_node(node_id: String) -> Dictionary:
	return _nodes.get(node_id, {}).duplicate(true)


## Returns all registered nodes.
func get_all_nodes() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for k in _nodes.keys():
		res.append(_nodes[k].duplicate(true))
	return res


## Returns nodes filtered by state.
func get_nodes_by_state(state: int) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for k in _nodes.keys():
		if int(_nodes[k]["state"]) == state:
			res.append(_nodes[k].duplicate(true))
	return res


## Connects from_node to to_node with a directed edge.
func connect_nodes(from_id: String, to_id: String) -> bool:
	if from_id == "" or to_id == "" or from_id == to_id:
		return false

	if not _outgoing_edges.has(from_id):
		_outgoing_edges[from_id] = []
	if not _outgoing_edges[from_id].has(to_id):
		_outgoing_edges[from_id].append(to_id)

	if not _incoming_edges.has(to_id):
		_incoming_edges[to_id] = []
	if not _incoming_edges[to_id].has(from_id):
		_incoming_edges[to_id].append(from_id)

	# Update node internal lists if present
	if _nodes.has(from_id):
		var conns: Array = _nodes[from_id]["connections"]
		if not conns.has(to_id):
			conns.append(to_id)

	if _nodes.has(to_id):
		var prereqs: Array = _nodes[to_id]["prerequisites"]
		if not prereqs.has(from_id):
			prereqs.append(from_id)

	return true


## Returns all outgoing node IDs from a given node.
func get_outgoing(from_id: String) -> Array[String]:
	var res: Array[String] = []
	for it in _outgoing_edges.get(from_id, []):
		res.append(str(it))
	return res


## Returns all incoming node IDs into a given node.
func get_incoming(to_id: String) -> Array[String]:
	var res: Array[String] = []
	for it in _incoming_edges.get(to_id, []):
		res.append(str(it))
	return res


## Sets state of a node directly.
func set_node_state(node_id: String, new_state: int) -> void:
	if not _nodes.has(node_id):
		return
	var prev_state = int(_nodes[node_id]["state"])
	_nodes[node_id]["state"] = new_state
	if prev_state != new_state:
		if new_state == NodeState.UNLOCKED:
			node_unlocked.emit(node_id)
		node_updated.emit(node_id)


## Checks whether all prerequisites for a node are completed.
func can_unlock(node_id: String) -> bool:
	if not _nodes.has(node_id):
		return false
	var prereqs: Array = _nodes[node_id].get("prerequisites", [])
	if prereqs.is_empty():
		return true

	for pid in prereqs:
		if not _nodes.has(pid):
			return false
		if int(_nodes[pid]["state"]) != NodeState.COMPLETED:
			return false

	return true


## Evaluates all locked nodes and unlocks any whose prerequisites are satisfied.
## Returns an array of newly unlocked node IDs.
func evaluate_unlocks() -> Array[String]:
	var newly_unlocked: Array[String] = []
	for nid in _nodes.keys():
		if int(_nodes[nid]["state"]) == NodeState.LOCKED and can_unlock(nid):
			_nodes[nid]["state"] = NodeState.UNLOCKED
			newly_unlocked.append(nid)
			node_unlocked.emit(nid)
			node_updated.emit(nid)
	return newly_unlocked


## Marks a node as COMPLETED, records stars earned, and unlocks dependent nodes.
func complete_node(node_id: String, stars_earned: int = 1) -> Dictionary:
	if not _nodes.has(node_id):
		return {
			"ok": false,
			"reason": "Node not found: " + node_id,
			"unlocked_nodes": [],
			"first_clear": false
		}

	var node_ref = _nodes[node_id]
	var was_completed = (int(node_ref["state"]) == NodeState.COMPLETED)
	var first_clear = not was_completed

	node_ref["state"] = NodeState.COMPLETED
	var prev_stars = int(node_ref["stars"])
	var new_stars = clampi(maxi(prev_stars, stars_earned), 1, 3)
	node_ref["stars"] = new_stars

	node_completed.emit(node_id, new_stars, first_clear)
	node_updated.emit(node_id)

	var newly_unlocked = evaluate_unlocks()

	return {
		"ok": true,
		"node_id": node_id,
		"stars": new_stars,
		"first_clear": first_clear,
		"unlocked_nodes": newly_unlocked
	}


## Returns the sum of all stars earned across all nodes.
func get_total_stars() -> int:
	var total = 0
	for nid in _nodes.keys():
		total += int(_nodes[nid].get("stars", 0))
	return total


## Returns completion percentage (0.0 to 100.0).
func get_completion_percentage() -> float:
	if _nodes.is_empty():
		return 0.0
	var completed = 0
	for nid in _nodes.keys():
		if int(_nodes[nid]["state"]) == NodeState.COMPLETED:
			completed += 1
	return (float(completed) / float(_nodes.size())) * 100.0


## Serializes progression state (states and stars).
func serialize() -> Dictionary:
	var progress: Dictionary = {}
	for nid in _nodes.keys():
		progress[nid] = {
			"state": int(_nodes[nid]["state"]),
			"stars": int(_nodes[nid]["stars"])
		}
	return {
		"version": 1,
		"progress": progress
	}


## Restores progression state and re-evaluates unlocks.
func deserialize(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var prog = data.get("progress", {})
	if typeof(prog) != TYPE_DICTIONARY:
		return

	for nid in prog.keys():
		if _nodes.has(nid):
			var entry = prog[nid]
			if typeof(entry) == TYPE_DICTIONARY:
				_nodes[nid]["state"] = int(entry.get("state", NodeState.LOCKED))
				_nodes[nid]["stars"] = int(entry.get("stars", 0))
				node_updated.emit(nid)

	evaluate_unlocks()
