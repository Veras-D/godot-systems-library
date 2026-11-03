extends SceneTree

const EffectData = preload("EffectData.gd")
const EffectContext = preload("EffectContext.gd")
const AbilityDefinition = preload("AbilityDefinition.gd")
const AbilityResolver = preload("AbilityResolver.gd")
const SystemEventBus = preload("SystemEventBus.gd")

func _init() -> void:
	print("==> Running AbilityEngine Unit Tests...")

	# 1. Test EffectData Creation
	var dmg_eff: EffectData = EffectData.create_damage(6, EffectData.TargetScope.TARGET_SINGLE)
	assert(dmg_eff.type == EffectData.EffectType.DAMAGE, "Effect type must be DAMAGE")
	assert(dmg_eff.amount == 6, "Damage amount must be 6")
	assert(dmg_eff.target_scope == EffectData.TargetScope.TARGET_SINGLE, "Target scope must be TARGET_SINGLE")

	var heal_eff: EffectData = EffectData.create_heal(4, EffectData.TargetScope.SELF)
	assert(heal_eff.type == EffectData.EffectType.HEAL, "Effect type must be HEAL")
	assert(heal_eff.amount == 4, "Heal amount must be 4")

	var buff_eff: EffectData = EffectData.create_buff("atk", 3, EffectData.TargetScope.ALL_FRIENDLY)
	assert(buff_eff.type == EffectData.EffectType.BUFF_STAT, "Effect type must be BUFF_STAT")
	assert(buff_eff.stat_name == "atk", "Stat name must be 'atk'")
	assert(buff_eff.amount == 3, "Buff amount must be 3")
	print("EffectData creation verified.")

	# 2. Test EffectContext
	var ctx = EffectContext.create({"name": "Caster"}, 0, 1, [{"name": "Target"}], "ON_PLAY")
	assert(ctx.source["name"] == "Caster", "Source name must match")
	assert(ctx.source_side == 0, "Source side must match")
	assert(ctx.source_lane == 1, "Source lane must match")
	assert(ctx.targets.size() == 1, "Target count must match")
	ctx.set_var("crit_multiplier", 2.0)
	assert(ctx.get_var("crit_multiplier") == 2.0, "Context variable must be retrieved")
	print("EffectContext verified.")

	# 3. Test AbilityDefinition
	var ability = AbilityDefinition.create(
		"ab_fireball",
		"Fireball",
		"ON_PLAY",
		[dmg_eff, heal_eff],
		"Deals damage and heals caster"
	)
	assert(ability.id == "ab_fireball", "Ability ID must match")
	assert(ability.effects.size() == 2, "Ability must contain 2 effects")
	print("AbilityDefinition verified.")

	# 4. Test AbilityResolver Queue & Damage Execution
	var resolver = AbilityResolver.new()
	var enemy_unit = {"name": "Goblin", "def": 10, "max_def": 10, "atk": 2}
	var test_ctx = EffectContext.create(null, 0, 0, [enemy_unit])

	resolver.enqueue_effect(dmg_eff, test_ctx)
	assert(resolver.get_queue_size() == 1, "Queue size must be 1")

	resolver.resolve_all_sync()
	assert(resolver.get_queue_size() == 0, "Queue must be empty after resolve_all_sync()")
	assert(enemy_unit["def"] == 4, "Enemy def should be 10 - 6 = 4")
	print("Damage resolution verified.")

	# 5. Test Healing Execution (with max_def cap)
	var heal_ctx = EffectContext.create(null, 0, 0, [enemy_unit])
	var heal_action = EffectData.create_heal(10, EffectData.TargetScope.TARGET_SINGLE)
	resolver.enqueue_effect(heal_action, heal_ctx)
	resolver.resolve_all_sync()
	assert(enemy_unit["def"] == 10, "Enemy def capped at max_def 10 after healing 10 to 4")
	print("Healing resolution verified.")

	# 6. Test Stat Buff Execution
	var buff_ctx = EffectContext.create(null, 0, 0, [enemy_unit])
	resolver.enqueue_effect(buff_eff, buff_ctx)
	resolver.resolve_all_sync()
	assert(enemy_unit["atk"] == 5, "Enemy atk should be 2 + 3 = 5")
	print("Stat buff resolution verified.")

	# 7. Test Stat Swapping
	var swap_eff = EffectData.new()
	swap_eff.type = EffectData.EffectType.SWAP_STATS
	swap_eff.stat_name = "atk"
	swap_eff.metadata = {"stat_b": "def"}
	var swap_ctx = EffectContext.create(null, 0, 0, [enemy_unit])
	resolver.enqueue_effect(swap_eff, swap_ctx)
	resolver.resolve_all_sync()
	# Previous: atk=5, def=10 -> After swap: atk=10, def=5
	assert(enemy_unit["atk"] == 10, "Swapped ATK should be 10")
	assert(enemy_unit["def"] == 5, "Swapped DEF should be 5")
	print("Stat swapping verified.")

	# 8. Test Priority Queue Ordering
	var player_state = {"magic": 0, "cards_drawn": 0}
	var res_ctx = EffectContext.create(player_state, 0, 0, [player_state])

	var low_priority_eff = EffectData.create_resource_gain(2)
	var high_priority_eff = EffectData.create_draw(1)

	# Enqueue low priority first, then high priority with priority = 10
	resolver.enqueue_effect(low_priority_eff, res_ctx, 0)
	resolver.enqueue_effect(high_priority_eff, res_ctx, 10)

	# Connect signal to record execution order
	var executed_types: Array[int] = []
	resolver.effect_started.connect(func(eff: Resource, _ctx: RefCounted):
		executed_types.append(eff.type)
	)

	resolver.resolve_all_sync()
	assert(executed_types.size() == 2, "Both effects should have executed")
	assert(executed_types[0] == EffectData.EffectType.DRAW_CARD, "High priority DRAW_CARD must execute first")
	assert(executed_types[1] == EffectData.EffectType.GAIN_RESOURCE, "Low priority GAIN_RESOURCE must execute second")
	assert(player_state["magic"] == 2, "Player gained 2 magic")
	assert(player_state["cards_drawn"] == 1, "Player drew 1 card")
	print("Priority queue ordering verified.")

	# 9. Test Trigger Dispatching & Reaction Ability
	var thorn_target = {"name": "Attacker", "def": 8, "max_def": 8}
	var defender_unit = {"name": "Defender", "def": 12}

	var thorns_ability = AbilityDefinition.create(
		"ab_thorns",
		"Thorns",
		"ON_DAMAGE_TAKEN",
		[EffectData.create_damage(3, EffectData.TargetScope.TARGET_SINGLE)]
	)

	resolver.register_trigger_listener(thorns_ability, defender_unit, 0)

	# When defender takes damage, dispatch "ON_DAMAGE_TAKEN"
	var reaction_ctx = EffectContext.create(defender_unit, 0, 0, [thorn_target])
	resolver.dispatch_trigger("ON_DAMAGE_TAKEN", defender_unit, reaction_ctx)

	assert(resolver.get_queue_size() == 1, "Thorns ability should be queued upon trigger dispatch")
	resolver.resolve_all_sync()
	assert(thorn_target["def"] == 5, "Attacker took 3 thorns damage (8 - 3 = 5)")
	print("Trigger dispatching & reaction ability verified.")

	# 10. Test SystemEventBus Auto-Bridge
	var bus = SystemEventBus.new()
	bus.connect_resolver(resolver)
	# Emit damage_dealt -> should trigger ON_DAMAGE_TAKEN on registered defender
	bus.damage_dealt.emit(thorn_target, defender_unit, 2)
	assert(resolver.get_queue_size() == 1, "EventBus damage_dealt should enqueue Thorns reaction")
	resolver.clear_queue()
	bus.free()
	print("SystemEventBus integration verified.")

	# Test SystemEventBus Opt-in Adapter Bindings (N8)
	var bus_adapters = SystemEventBus.new()
	var dummy_grid = Node.new()
	dummy_grid.add_user_signal("slot_damage_shaken", [{"name": "slot", "type": TYPE_OBJECT}, {"name": "intensity", "type": TYPE_FLOAT}])
	bus_adapters.bind_board_grid(dummy_grid)
	var bridge_box = {"damaged": false}
	bus_adapters.damage_dealt.connect(func(_s, _t, _a): bridge_box["damaged"] = true)
	dummy_grid.emit_signal("slot_damage_shaken", null, 15.0)
	assert(bridge_box["damaged"] == true, "SystemEventBus.bind_board_grid should bridge slot_damage_shaken to damage_dealt")
	dummy_grid.free()
	bus_adapters.free()
	print("SystemEventBus opt-in adapter bindings (N8) verified.")

	# 11. Test TargetScopes (N4)
	var f0 = {"name": "Friendly0", "side": 0, "lane": 0, "atk": 1}
	var f1 = {"name": "Friendly1", "side": 0, "lane": 1, "atk": 1}
	var f2 = {"name": "Friendly2", "side": 0, "lane": 2, "atk": 1}
	var e0 = {"name": "Enemy0", "side": 1, "lane": 0, "atk": 1}
	var e1 = {"name": "Enemy1", "side": 1, "lane": 1, "atk": 1}

	var scope_ctx = EffectContext.create(f1, 0, 1, [f0, f1, f2, e0, e1])
	scope_ctx.set_var("friendly_units", [f0, f1, f2])
	scope_ctx.set_var("enemy_units", [e0, e1])

	# ALL_FRIENDLY
	var res_all_friendly = resolver._resolve_targets(EffectData.TargetScope.ALL_FRIENDLY, scope_ctx)
	assert(res_all_friendly.size() == 3, "ALL_FRIENDLY should resolve all 3 friendly units")

	# ALL_ENEMY
	var res_all_enemy = resolver._resolve_targets(EffectData.TargetScope.ALL_ENEMY, scope_ctx)
	assert(res_all_enemy.size() == 2, "ALL_ENEMY should resolve all 2 enemy units")

	# ADJACENT_FRIENDLY (f1 is at lane 1, adjacent are f0 at lane 0 and f2 at lane 2)
	var res_adj = resolver._resolve_targets(EffectData.TargetScope.ADJACENT_FRIENDLY, scope_ctx)
	assert(res_adj.size() == 2, "ADJACENT_FRIENDLY should resolve lanes 0 and 2 (count: 2)")

	# OPPOSING_LANE (f1 is at lane 1, opposing enemy is e1 at lane 1)
	var res_opp = resolver._resolve_targets(EffectData.TargetScope.OPPOSING_LANE, scope_ctx)
	assert(res_opp.size() == 1 and res_opp[0]["name"] == "Enemy1", "OPPOSING_LANE should resolve Enemy1 at lane 1")

	# RANDOM_ENEMY (1 random enemy from [e0, e1])
	scope_ctx.set_var("random_count", 1)
	var res_rand = resolver._resolve_targets(EffectData.TargetScope.RANDOM_ENEMY, scope_ctx)
	assert(res_rand.size() == 1 and (res_rand[0]["name"] == "Enemy0" or res_rand[0]["name"] == "Enemy1"), "RANDOM_ENEMY should resolve 1 enemy")

	# ALL_UNITS
	var res_all_units = resolver._resolve_targets(EffectData.TargetScope.ALL_UNITS, scope_ctx)
	assert(res_all_units.size() == 5, "ALL_UNITS should resolve all 5 units")
	print("TargetScope resolution (N4) verified.")

	# 12. Test DISCARD_CARD (N5)
	var discard_eff = EffectData.create_discard(2)
	assert(discard_eff.type == EffectData.EffectType.DISCARD_CARD, "Type must be DISCARD_CARD")
	assert(discard_eff.amount == 2, "Discard amount must be 2")

	var hand_state = {"hand": ["card1", "card2", "card3", "card4"]}
	var discard_ctx = EffectContext.create(hand_state, 0, 0, [hand_state])
	resolver.enqueue_effect(discard_eff, discard_ctx)
	resolver.resolve_all_sync()
	assert(hand_state["hand"].size() == 2, "Hand size should decrease from 4 to 2 after discarding 2")
	assert(hand_state["cards_discarded"] == 2, "cards_discarded should be 2")
	print("DISCARD_CARD effect (N5) verified.")

	# 13. Test Target Shape Mismatch (N6)
	var invalid_target = "string_cannot_take_damage"
	var invalid_ctx = EffectContext.create(null, 0, 0, [invalid_target])
	resolver.enqueue_effect(dmg_eff, invalid_ctx)
	# Should not crash, safely logs warning and returns 0 applied
	resolver.resolve_all_sync()
	print("Target shape mismatch handling (N6) verified.")

	# 14. Test Universal Spatial Topology Protocol on Hex Mock (N7)
	var hex_dragon = {"name": "Dragon", "side": 0}
	var hex_neighbor_1 = {"name": "HexGoblin1", "side": 0}
	var hex_neighbor_2 = {"name": "HexGoblin2", "side": 0}
	var hex_neighbor_3 = {"name": "HexGoblin3", "side": 0}
	var hex_opposing = {"name": "HexBoss", "side": 1}

	var mock_board = RefCounted.new()
	# Add script with protocol methods
	var mock_script = GDScript.new()
	mock_script.source_code = """
extends RefCounted
var adj = []
var opp = []
func get_adjacent_units(_origin): return adj
func get_opposing_units(_origin): return opp
"""
	mock_script.reload()
	mock_board.set_script(mock_script)
	mock_board.adj = [hex_neighbor_1, hex_neighbor_2, hex_neighbor_3]
	mock_board.opp = [hex_opposing]

	# Create context with 3D axial/cube coordinate Vector3i(1, -1, 0)
	var hex_ctx = EffectContext.create(hex_dragon, 0, 0, [], "", Vector3i(1, -1, 0))
	assert(hex_ctx.get_coordinate() == Vector3i(1, -1, 0), "Context should store and return Vector3i hex coordinate")
	hex_ctx.set_var("board", mock_board)

	var resolved_hex_adj = resolver._resolve_targets(EffectData.TargetScope.ADJACENT_FRIENDLY, hex_ctx)
	assert(resolved_hex_adj.size() == 3, "Hex board protocol must resolve 3 adjacent hex units (not 2 lane units)")
	assert(hex_neighbor_1 in resolved_hex_adj, "Hex neighbor 1 resolved")

	var resolved_hex_opp = resolver._resolve_targets(EffectData.TargetScope.OPPOSING_LANE, hex_ctx)
	assert(resolved_hex_opp.size() == 1 and resolved_hex_opp[0]["name"] == "HexBoss", "Hex board protocol must resolve HexBoss")
	print("Universal Spatial Topology Protocol with Hex Mock (N7) verified.")

	resolver.free()

	# 15. Regression Test: SystemEventBus Auto-Bridges to Real BoardGrid and HandManager
	var reg_bus = SystemEventBus.new()
	var mock_resolver = Node.new()
	var mock_resolver_script = GDScript.new()
	mock_resolver_script.source_code = """
extends Node
var triggers_fired = []
func dispatch_trigger(trigger_name: String, source: Variant = null, context: Variant = null) -> void:
	triggers_fired.append({"trigger": trigger_name, "source": source, "context": context})
"""
	mock_resolver_script.reload()
	mock_resolver.set_script(mock_resolver_script)
	reg_bus.connect_resolver(mock_resolver)

	# A. Instantiate REAL BoardGrid
	var board_grid_scene_path = "res://board_system/BoardGrid.tscn"
	assert(ResourceLoader.exists(board_grid_scene_path), "BoardGrid.tscn must exist")
	var grid = load(board_grid_scene_path).instantiate()
	root.add_child(grid)
	grid.sides_count = 2
	grid.lanes_per_side = 4
	grid.rebuild_grid()

	# Bind grid to bus
	reg_bus.bind_board_grid(grid)

	# Verify real signal: occupant_dropped_on_slot on BoardGrid
	var test_slot = grid.get_slot(0, 1) # Side 0, Lane 1
	assert(test_slot != null, "BoardSlot must exist at (0, 1)")
	var dropped_card_data = {"id": "c_hero", "name": "HeroUnit", "atk": 4, "def": 6}

	# Fire the actual signal emitted by BoardGrid
	grid.occupant_dropped_on_slot.emit(test_slot, {"type": "card", "card_data": dropped_card_data})

	assert(mock_resolver.triggers_fired.size() == 1, "occupant_dropped_on_slot must trigger dispatch_trigger on resolver")
	assert(mock_resolver.triggers_fired[0]["trigger"] == "ON_SUMMON", "Trigger must be ON_SUMMON")
	assert(mock_resolver.triggers_fired[0]["source"]["name"] == "HeroUnit", "Source must be the unwrapped dropped card")

	# Test slot_damage_shaken on BoardGrid
	grid.slot_damage_shaken.emit(test_slot, 5.0)
	assert(mock_resolver.triggers_fired.size() == 2, "slot_damage_shaken must trigger dispatch_trigger on resolver")
	assert(mock_resolver.triggers_fired[1]["trigger"] == "ON_DAMAGE_TAKEN", "Trigger must be ON_DAMAGE_TAKEN")
	assert(mock_resolver.triggers_fired[1]["source"] == test_slot, "Source must be the shaken slot")

	# B. Instantiate REAL HandManager
	var hand_manager_scene_path = "res://deck_engine/HandManager.tscn"
	assert(ResourceLoader.exists(hand_manager_scene_path), "HandManager.tscn must exist")
	var hand = load(hand_manager_scene_path).instantiate()
	root.add_child(hand)
	reg_bus.bind_hand_manager(hand, 0)

	# Add card to real HandManager (fires card_drawn signal)
	var CardData = load("res://deck_engine/CardData.gd")
	var drawn_spell = CardData.create("spell_01", "Magic Missile", 2, "Spell", "Arcane", 0, 0)
	var card_view = hand.add_card(drawn_spell)
	assert(card_view != null, "CardView must be added to hand")

	assert(mock_resolver.triggers_fired.size() == 3, "HandManager.add_card must trigger ON_DRAW via card_drawn")
	assert(mock_resolver.triggers_fired[2]["trigger"] == "ON_DRAW", "Trigger must be ON_DRAW")
	assert(mock_resolver.triggers_fired[2]["source"] == drawn_spell, "Source must be drawn_spell")

	# Play card through real HandManager (fires card_played signal)
	hand.play_card(card_view)
	assert(mock_resolver.triggers_fired.size() == 4, "HandManager.play_card must trigger ON_PLAY via card_played")
	assert(mock_resolver.triggers_fired[3]["trigger"] == "ON_PLAY", "Trigger must be ON_PLAY")
	assert(mock_resolver.triggers_fired[3]["source"] == drawn_spell, "Source must be drawn_spell")

	# Clean up nodes
	grid.free()
	hand.free()
	mock_resolver.free()
	reg_bus.free()
	print("SystemEventBus real BoardGrid and HandManager auto-bridges verified.")

	# 13. Test Target Mutation Policy & Immutability / Preview Helpers
	var immut_resolver = AbilityResolver.new()
	immut_resolver.mutate_targets_in_place = false # Immutable mode

	var immutable_target = {"name": "Shield Guardian", "def": 20, "max_def": 20, "atk": 5}
	var immut_ctx = EffectContext.create(null, 0, 0, [immutable_target])
	var test_dmg = EffectData.create_damage(8, EffectData.TargetScope.TARGET_SINGLE)

	immut_resolver.clear_deltas()
	immut_resolver.enqueue_effect(test_dmg, immut_ctx)
	immut_resolver.resolve_all_sync()

	# In immutable mode, input target MUST NOT be mutated
	assert(immutable_target["def"] == 20, "Target def must NOT mutate when mutate_targets_in_place is false")
	assert(immut_resolver.last_applied_deltas.size() == 1, "last_applied_deltas should contain 1 delta record")
	var recorded_delta = immut_resolver.last_applied_deltas[0]
	assert(recorded_delta["op"] == "damage", "Recorded delta op must be 'damage'")
	assert(recorded_delta["stat"] == "def", "Recorded delta stat must be 'def'")
	assert(recorded_delta["old_value"] == 20, "Old value must be 20")
	assert(recorded_delta["new_value"] == 12, "New value must be 12")
	assert(recorded_delta["delta"] == -8, "Delta amount must be -8")

	# Test preview_effect_delta() helper
	var preview_source = {"name": "Test Beast", "def": 15, "max_def": 15, "atk": 4}
	var preview_result = immut_resolver.preview_effect_delta(test_dmg, preview_source)

	# Verify preview does NOT touch preview_source
	assert(preview_source["def"] == 15, "preview_source def must remain unmodified at 15")
	assert(preview_result["mutated_state"]["def"] == 7, "preview mutated_state def should be 15 - 8 = 7")
	assert(preview_result["result_value"] == 8, "preview result_value should be 8")
	assert(preview_result["deltas"].size() == 1, "preview deltas should have 1 entry")
	assert(preview_result["deltas"][0]["new_value"] == 7, "preview delta new_value should be 7")

	immut_resolver.free()
	print("AbilityResolver target mutation policy, immutable mode, and preview_effect_delta verified.")

	# 14. Test Multi-Faction TargetScope Resolution for Arbitrary sides_count (1, 2, 3, N)
	var multi_res = AbilityResolver.new()
	var BoardGridScene = load("res://board_system/BoardGrid.tscn")
	var multi_board = BoardGridScene.instantiate()
	root.add_child(multi_board)

	multi_board.sides_count = 3
	multi_board.lanes_per_side = 2
	multi_board.rebuild_grid()

	var u_side0 = {"name": "Hero Side 0", "side": 0, "lane": 1, "def": 10}
	var u_side1 = {"name": "Hero Side 1", "side": 1, "lane": 1, "def": 10}
	var u_side2 = {"name": "Hero Side 2", "side": 2, "lane": 1, "def": 10}

	multi_board.get_slot(0, 1).slot_data.primary_occupant = u_side0
	multi_board.get_slot(1, 1).slot_data.primary_occupant = u_side1
	multi_board.get_slot(2, 1).slot_data.primary_occupant = u_side2

	# A. Test OPPOSING_LANE on 3-sided board
	var opp_eff = EffectData.create_damage(3, EffectData.TargetScope.OPPOSING_LANE)
	var opp_ctx_s0 = EffectContext.create(u_side0, 0, 1)
	opp_ctx_s0.set_var("board_grid", multi_board)
	var s0_targets = multi_res._resolve_targets(EffectData.TargetScope.OPPOSING_LANE, opp_ctx_s0)
	assert(s0_targets.size() == 1 and s0_targets[0] == u_side1, "Side 0 OPPOSING_LANE must target Side 1 in 3-way rotation")

	var opp_ctx_s2 = EffectContext.create(u_side2, 2, 1)
	opp_ctx_s2.set_var("board_grid", multi_board)
	var s2_targets = multi_res._resolve_targets(EffectData.TargetScope.OPPOSING_LANE, opp_ctx_s2)
	assert(s2_targets.size() == 1 and s2_targets[0] == u_side0, "Side 2 OPPOSING_LANE must target Side 0 in 3-way rotation")

	# B. Test ALL_ENEMY across multi-faction board
	var all_enemy_ctx = EffectContext.create(u_side0, 0, 1)
	all_enemy_ctx.set_var("board_grid", multi_board)
	var enemies = multi_res._resolve_targets(EffectData.TargetScope.ALL_ENEMY, all_enemy_ctx)
	assert(enemies.size() == 2, "ALL_ENEMY for Side 0 on 3-sided board must find 2 enemy units")
	assert(u_side1 in enemies and u_side2 in enemies, "ALL_ENEMY must contain Side 1 and Side 2 units")
	assert(not u_side0 in enemies, "ALL_ENEMY must NOT contain caster Side 0 unit")

	# C. Test ALL_ENEMY with specific enemy_sides filter
	all_enemy_ctx.set_var("enemy_sides", [2])
	var filtered_enemies = multi_res._resolve_targets(EffectData.TargetScope.ALL_ENEMY, all_enemy_ctx)
	assert(filtered_enemies.size() == 1 and filtered_enemies[0] == u_side2, "enemy_sides=[2] must filter strictly to Side 2")

	# D. Test ALL_FRIENDLY with allied alliance sides
	var friendly_ctx = EffectContext.create(u_side0, 0, 1)
	friendly_ctx.set_var("board_grid", multi_board)
	friendly_ctx.set_var("friendly_sides", [0, 1]) # 0 and 1 are allied against 2
	var friends = multi_res._resolve_targets(EffectData.TargetScope.ALL_FRIENDLY, friendly_ctx)
	assert(friends.size() == 2, "friendly_sides=[0, 1] must find 2 friendly units")
	assert(u_side0 in friends and u_side1 in friends, "Friendly units must be Side 0 and Side 1")
	assert(not u_side2 in friends, "Enemy Side 2 must not be in friendly units")

	multi_res.free()
	multi_board.free()
	print("Multi-faction TargetScope resolution for arbitrary sides_count verified.")

	print("==================================================")
	print("ALL ABILITY ENGINE UNIT TESTS PASSED (100%)")
	print("==================================================")
	quit(0)
