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

	resolver.free()

	print("==================================================")
	print("ALL ABILITY ENGINE UNIT TESTS PASSED (100%)")
	print("==================================================")
	quit(0)
