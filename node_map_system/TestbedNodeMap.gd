extends Control

const NodeMapGraph = preload("NodeMapGraph.gd")
const StarConditionEvaluator = preload("StarConditionEvaluator.gd")
const NodeMapRenderer = preload("NodeMapRenderer.gd")

@onready var map_renderer: NodeMapRenderer = $HBox/MapArea/MapRenderer
@onready var details_panel: PanelContainer = $HBox/Sidebar/DetailsPanel
@onready var node_title_label: Label = $HBox/Sidebar/DetailsPanel/VBox/NodeTitle
@onready var node_state_label: Label = $HBox/Sidebar/DetailsPanel/VBox/NodeState
@onready var node_prereq_label: Label = $HBox/Sidebar/DetailsPanel/VBox/NodePrereqs
@onready var node_stars_label: Label = $HBox/Sidebar/DetailsPanel/VBox/NodeStars

@onready var complete_1_btn: Button = $HBox/Sidebar/DetailsPanel/VBox/Actions/Complete1Btn
@onready var complete_2_btn: Button = $HBox/Sidebar/DetailsPanel/VBox/Actions/Complete2Btn
@onready var complete_3_btn: Button = $HBox/Sidebar/DetailsPanel/VBox/Actions/Complete3Btn

@onready var total_stars_label: Label = $HBox/Sidebar/StatsPanel/VBox/TotalStarsLabel
@onready var completion_label: Label = $HBox/Sidebar/StatsPanel/VBox/CompletionLabel

@onready var reset_btn: Button = $HBox/Sidebar/ActionsPanel/VBox/ResetBtn
@onready var save_btn: Button = $HBox/Sidebar/ActionsPanel/VBox/SaveBtn
@onready var load_btn: Button = $HBox/Sidebar/ActionsPanel/VBox/LoadBtn
@onready var eval_test_btn: Button = $HBox/Sidebar/ActionsPanel/VBox/EvalTestBtn
@onready var eval_result_label: Label = $HBox/Sidebar/ActionsPanel/VBox/EvalResultLabel

var graph: NodeMapGraph
var _selected_node_id: String = ""
var _saved_state: Dictionary = {}


func _ready() -> void:
	_init_sample_graph()

	if map_renderer:
		map_renderer.node_selected.connect(_on_node_selected)

	if complete_1_btn:
		complete_1_btn.pressed.connect(func(): _on_complete_pressed(1))
	if complete_2_btn:
		complete_2_btn.pressed.connect(func(): _on_complete_pressed(2))
	if complete_3_btn:
		complete_3_btn.pressed.connect(func(): _on_complete_pressed(3))

	if reset_btn:
		reset_btn.pressed.connect(_init_sample_graph)
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
	if load_btn:
		load_btn.pressed.connect(_on_load_pressed)
	if eval_test_btn:
		eval_test_btn.pressed.connect(_on_eval_test_pressed)

	_update_stats()
	_select_node("node_1")


func _init_sample_graph() -> void:
	graph = NodeMapGraph.new()

	# Node 1 (Root, Unlocked)
	graph.add_node({
		"id": "node_1",
		"title": "1: Training Camp",
		"position": Vector2(100, 260),
		"state": NodeMapGraph.NodeState.UNLOCKED,
		"conditions": [
			{"id": "JustWin"},
			{"id": "FastWin5", "max_turns": 5},
			{"id": "OnlyLose2Creatures", "max_creatures_lost": 2}
		]
	})

	# Branch A
	graph.add_node({
		"id": "node_2",
		"title": "2A: Whispering Woods",
		"position": Vector2(300, 150),
		"prerequisites": ["node_1"],
		"conditions": [
			{"id": "JustWin"},
			{"id": "Forbid_Spells", "forbidden_types": ["SPELL"]},
			{"id": "Only5HP", "max_hp_lost": 5}
		]
	})
	graph.add_node({
		"id": "node_3",
		"title": "3A: Griffin's Peak",
		"position": Vector2(500, 150),
		"prerequisites": ["node_2"]
	})

	# Branch B
	graph.add_node({
		"id": "node_4",
		"title": "2B: Murky Marsh",
		"position": Vector2(300, 370),
		"prerequisites": ["node_1"],
		"conditions": [
			{"id": "JustWin"},
			{"id": "Only_Creatures", "allowed_types": ["CREATURE"]},
			{"id": "Defeat5", "min_creatures_defeated": 5}
		]
	})
	graph.add_node({
		"id": "node_5",
		"title": "3B: Sunken Keep",
		"position": Vector2(500, 370),
		"prerequisites": ["node_4"]
	})

	# Convergence Node (Requires both 3A and 3B completed)
	graph.add_node({
		"id": "node_6",
		"title": "4: Royal Citadel",
		"position": Vector2(700, 260),
		"prerequisites": ["node_3", "node_5"],
		"conditions": [
			{"id": "JustWin"},
			{"id": "FastWin7", "max_turns": 7},
			{"id": "Landscapes_Three", "min_landscapes": 3}
		]
	})

	if map_renderer:
		map_renderer.graph = graph
	_update_stats()


func _on_node_selected(node_id: String) -> void:
	_select_node(node_id)


func _select_node(node_id: String) -> void:
	_selected_node_id = node_id
	if graph == null or not graph.has_node(node_id):
		return

	var n_data = graph.get_node(node_id)
	var state = int(n_data.get("state", NodeMapGraph.NodeState.LOCKED))
	var stars = int(n_data.get("stars", 0))
	var prereqs = n_data.get("prerequisites", [])

	node_title_label.text = str(n_data.get("title", node_id))
	node_stars_label.text = "Stars: %d / 3" % stars

	match state:
		NodeMapGraph.NodeState.LOCKED:
			node_state_label.text = "State: 🔒 LOCKED"
			node_state_label.modulate = Color(0.7, 0.7, 0.7)
			complete_1_btn.disabled = true
			complete_2_btn.disabled = true
			complete_3_btn.disabled = true
		NodeMapGraph.NodeState.UNLOCKED:
			node_state_label.text = "State: ⚔️ UNLOCKED (Ready)"
			node_state_label.modulate = Color(0.3, 0.9, 1.0)
			complete_1_btn.disabled = false
			complete_2_btn.disabled = false
			complete_3_btn.disabled = false
		NodeMapGraph.NodeState.COMPLETED:
			node_state_label.text = "State: ✓ COMPLETED"
			node_state_label.modulate = Color(0.95, 0.85, 0.3)
			complete_1_btn.disabled = false
			complete_2_btn.disabled = false
			complete_3_btn.disabled = false

	if prereqs.is_empty():
		node_prereq_label.text = "Prerequisites: None (Root)"
	else:
		node_prereq_label.text = "Prerequisites: " + ", ".join(prereqs)


func _on_complete_pressed(stars: int) -> void:
	if _selected_node_id == "" or graph == null:
		return
	graph.complete_node(_selected_node_id, stars)
	_select_node(_selected_node_id)
	_update_stats()


func _update_stats() -> void:
	if graph == null:
		return
	total_stars_label.text = "Total Stars: %d" % graph.get_total_stars()
	completion_label.text = "Progress: %.1f%%" % graph.get_completion_percentage()


func _on_save_pressed() -> void:
	if graph == null:
		return
	_saved_state = graph.serialize()
	eval_result_label.text = "Saved %d node states!" % _saved_state.get("progress", {}).size()


func _on_load_pressed() -> void:
	if graph == null or _saved_state.is_empty():
		return
	graph.deserialize(_saved_state)
	_update_stats()
	_select_node(_selected_node_id)
	eval_result_label.text = "Loaded saved states!"


func _on_eval_test_pressed() -> void:
	var mock_stats = {
		"won": true,
		"turns": 4,
		"player_hp_lost": 3,
		"player_creatures_lost": 1,
		"enemy_creatures_defeated": 6,
		"card_types_played": ["CREATURE"],
		"factions_played": ["Plains", "Corn", "Sand"],
		"landscapes_count": 3
	}

	var test_conditions = [
		{"id": "JustWin"},
		{"id": "FastWin5", "max_turns": 5},
		{"id": "Forbid_Spells", "forbidden_types": ["SPELL"]}
	]

	var stars = StarConditionEvaluator.count_stars_earned(test_conditions, mock_stats)
	eval_result_label.text = "Evaluator: Awarded %d / 3 Stars!" % stars
