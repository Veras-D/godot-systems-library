extends SceneTree

const NodeMapGraph = preload("NodeMapGraph.gd")
const StarConditionEvaluator = preload("StarConditionEvaluator.gd")

func _init() -> void:
	print("==> Running NodeMapSystem Unit & Regression Tests...")

	# ==========================================================================
	# 1. Graph Construction & Node Registration
	# ==========================================================================
	print("Test 1: Graph Construction & Edge Connections...")
	var graph = NodeMapGraph.new()

	var ok_root = graph.add_node({
		"id": "root",
		"title": "Start",
		"position": Vector2(50, 100),
		"state": NodeMapGraph.NodeState.UNLOCKED
	})
	assert(ok_root == true, "Root node addition should succeed")
	assert(graph.has_node("root") == true, "Graph should contain 'root'")

	graph.add_node({
		"id": "branch_a",
		"title": "Branch A",
		"position": Vector2(150, 50),
		"prerequisites": ["root"]
	})
	graph.add_node({
		"id": "branch_b",
		"title": "Branch B",
		"position": Vector2(150, 150),
		"prerequisites": ["root"]
	})
	graph.add_node({
		"id": "leaf",
		"title": "Final Boss",
		"position": Vector2(250, 100),
		"prerequisites": ["branch_a", "branch_b"]
	})

	assert(graph.get_all_nodes().size() == 4, "Graph should have 4 nodes")
	assert(graph.get_outgoing("root").size() == 2, "Root should have 2 outgoing edges")
	assert(graph.get_incoming("leaf").size() == 2, "Leaf should have 2 incoming prerequisites")

	# ==========================================================================
	# 2. Sequential Unlocking & Multi-Prerequisite Convergence
	# ==========================================================================
	print("Test 2: Sequential Unlocking & Prerequisite Verification...")
	assert(graph.get_node("root")["state"] == NodeMapGraph.NodeState.UNLOCKED, "Root should be unlocked")
	assert(graph.get_node("branch_a")["state"] == NodeMapGraph.NodeState.LOCKED, "Branch A should be locked initially")
	assert(graph.get_node("branch_b")["state"] == NodeMapGraph.NodeState.LOCKED, "Branch B should be locked initially")
	assert(graph.get_node("leaf")["state"] == NodeMapGraph.NodeState.LOCKED, "Leaf should be locked initially")

	var unlocked_signals: Array[String] = []
	graph.node_unlocked.connect(func(nid): unlocked_signals.append(nid))

	# Complete Root
	var res_root = graph.complete_node("root", 2)
	assert(res_root.get("ok", false) == true, "Root completion should succeed")
	assert(res_root.get("first_clear", false) == true, "Root should be first clear")
	assert(res_root.get("stars", 0) == 2, "Root stars should be 2")
	assert(graph.get_node("root")["state"] == NodeMapGraph.NodeState.COMPLETED, "Root should be marked COMPLETED")

	# Both Branch A and Branch B should now be unlocked
	assert(graph.get_node("branch_a")["state"] == NodeMapGraph.NodeState.UNLOCKED, "Branch A should be unlocked")
	assert(graph.get_node("branch_b")["state"] == NodeMapGraph.NodeState.UNLOCKED, "Branch B should be unlocked")
	assert(unlocked_signals.has("branch_a"), "node_unlocked signal fired for Branch A")
	assert(unlocked_signals.has("branch_b"), "node_unlocked signal fired for Branch B")

	# Leaf requires BOTH Branch A and Branch B. Completing only Branch A should NOT unlock Leaf
	graph.complete_node("branch_a", 3)
	assert(graph.get_node("branch_a")["state"] == NodeMapGraph.NodeState.COMPLETED, "Branch A should be COMPLETED")
	assert(graph.get_node("leaf")["state"] == NodeMapGraph.NodeState.LOCKED, "Leaf must remain LOCKED until Branch B is also clear")

	# Now complete Branch B -> Leaf should unlock!
	var res_b = graph.complete_node("branch_b", 1)
	assert(res_b.get("unlocked_nodes", []).has("leaf"), "Branch B completion should unlock Leaf")
	assert(graph.get_node("leaf")["state"] == NodeMapGraph.NodeState.UNLOCKED, "Leaf should now be UNLOCKED")

	# ==========================================================================
	# 3. Star High-Score Tracking & Progress Metrics
	# ==========================================================================
	print("Test 3: Star High-Scores & Completion Metrics...")
	# Re-completing Branch B with fewer stars should preserve high score (1 -> 1)
	graph.complete_node("branch_b", 1)
	assert(graph.get_node("branch_b")["stars"] == 1, "Branch B stars should remain 1")

	# Re-completing Branch B with higher stars upgrades high score (1 -> 3)
	var res_upgrade = graph.complete_node("branch_b", 3)
	assert(res_upgrade.get("first_clear", true) == false, "Re-clear is not first clear")
	assert(graph.get_node("branch_b")["stars"] == 3, "Branch B stars should upgrade to 3")

	# Complete leaf
	graph.complete_node("leaf", 3)
	# Root (2) + Branch A (3) + Branch B (3) + Leaf (3) = 11 stars
	assert(graph.get_total_stars() == 11, "Total stars should be 11 (got %d)" % graph.get_total_stars())
	assert(is_equal_approx(graph.get_completion_percentage(), 100.0), "Completion should be 100%")

	# ==========================================================================
	# 4. StarConditionEvaluator Rules Testing
	# ==========================================================================
	print("Test 4: StarConditionEvaluator Matching & Telemetry...")
	var won_stats = {
		"won": true,
		"turns": 4,
		"player_hp_lost": 2,
		"player_creatures_lost": 1,
		"enemy_creatures_defeated": 5,
		"card_types_played": ["CREATURE", "BUILDING"],
		"factions_played": ["Plains", "Cotton"],
		"landscapes_count": 3,
		"deck_cost": 22
	}

	var lost_stats = {
		"won": false,
		"turns": 8,
		"player_hp_lost": 25
	}

	# JustWin
	assert(StarConditionEvaluator.evaluate_condition({"id": "JustWin"}, won_stats) == true, "JustWin true on victory")
	assert(StarConditionEvaluator.evaluate_condition({"id": "JustWin"}, lost_stats) == false, "JustWin false on defeat")

	# FastWin (turns <= 5)
	assert(StarConditionEvaluator.evaluate_condition({"id": "FastWin5"}, won_stats) == true, "FastWin5 true when turns=4")
	assert(StarConditionEvaluator.evaluate_condition({"id": "FastWin3"}, won_stats) == false, "FastWin3 false when turns=4")

	# HP Lost limit
	assert(StarConditionEvaluator.evaluate_condition({"id": "Only5HP"}, won_stats) == true, "Only5HP true when lost 2 HP")
	assert(StarConditionEvaluator.evaluate_condition({"id": "Only1HP", "max_hp_lost": 1}, won_stats) == false, "Only1HP false when lost 2 HP")

	# Creatures lost limit
	assert(StarConditionEvaluator.evaluate_condition({"id": "OnlyLose2Creatures"}, won_stats) == true, "OnlyLose2Creatures true when lost 1")
	assert(StarConditionEvaluator.evaluate_condition({"id": "OnlyLose0Creatures", "max_creatures_lost": 0}, won_stats) == false, "OnlyLose0 false when lost 1")

	# Enemy creatures defeated
	assert(StarConditionEvaluator.evaluate_condition({"id": "Defeat5"}, won_stats) == true, "Defeat5 true when defeated 5")
	assert(StarConditionEvaluator.evaluate_condition({"id": "Defeat10"}, won_stats) == false, "Defeat10 false when defeated 5")

	# Type restrictions
	assert(StarConditionEvaluator.evaluate_condition({"id": "Forbid_Spells"}, won_stats) == true, "Forbid_Spells true when no spells played")
	var spells_stats = won_stats.duplicate(true)
	spells_stats["card_types_played"] = ["CREATURE", "SPELL"]
	assert(StarConditionEvaluator.evaluate_condition({"id": "Forbid_Spells"}, spells_stats) == false, "Forbid_Spells false when spell played")

	# Landscapes count
	assert(StarConditionEvaluator.evaluate_condition({"id": "Landscapes_Three"}, won_stats) == true, "Landscapes_Three true when 3 used")
	assert(StarConditionEvaluator.evaluate_condition({"id": "Landscapes_Four"}, won_stats) == false, "Landscapes_Four false when only 3 used")

	# Multi-Condition Star Counting
	var three_conditions = [
		{"id": "JustWin"},
		{"id": "FastWin5"},
		{"id": "Forbid_Spells"}
	]
	var stars_earned = StarConditionEvaluator.count_stars_earned(three_conditions, won_stats)
	assert(stars_earned == 3, "All 3 conditions should be met (earned 3 stars)")

	# ==========================================================================
	# 5. Serialization & Deserialization
	# ==========================================================================
	print("Test 5: Graph State Serialization & Restoration...")
	var serialized = graph.serialize()
	assert(serialized.has("progress"), "Serialized dict should contain 'progress'")

	var new_graph = NodeMapGraph.new()
	new_graph.add_node({"id": "root", "prerequisites": []})
	new_graph.add_node({"id": "branch_a", "prerequisites": ["root"]})
	new_graph.add_node({"id": "branch_b", "prerequisites": ["root"]})
	new_graph.add_node({"id": "leaf", "prerequisites": ["branch_a", "branch_b"]})

	new_graph.deserialize(serialized)
	assert(new_graph.get_node("root")["state"] == NodeMapGraph.NodeState.COMPLETED, "Restored root state should be COMPLETED")
	assert(new_graph.get_node("leaf")["stars"] == 3, "Restored leaf stars should be 3")
	assert(new_graph.get_total_stars() == 11, "Restored total stars should be 11")

	print("\n==> ALL NodeMapSystem Tests PASSED SUCCESSFULLY!")
	quit(0)
