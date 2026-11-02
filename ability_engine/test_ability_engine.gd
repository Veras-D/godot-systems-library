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

	resolver.free()

	print("==================================================")
	print("ALL ABILITY ENGINE UNIT TESTS PASSED (100%)")
	print("==================================================")
	quit(0)
