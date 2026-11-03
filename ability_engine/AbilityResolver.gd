class_name AbilityResolver
extends Node

## Universal Data-Driven Ability & Effect Queue Resolver.
## Executes effects in a deterministic, FIFO queue with priority support.
## Completely decoupled: resolves effects against abstract targets (Nodes, Dictionaries, or Objects).
##
## TARGET MUTATION & IMMUTABILITY POLICY:
## By default, AbilityResolver operates with `mutate_targets_in_place = true`,
## mutating numerical stat properties ('def', 'hp', 'atk', etc.) directly on Dictionary
## and Object targets.
## - Callers who manage immutable state stores should duplicate targets before resolution
##   (`target.duplicate()`), use `preview_effect_delta()`, or set `mutate_targets_in_place = false`
##   to compute state changes and inspect `last_applied_deltas` without touching the input dictionary.

const EffectData = preload("EffectData.gd")
const EffectContext = preload("EffectContext.gd")
const AbilityDefinition = preload("AbilityDefinition.gd")

signal effect_queued(effect: Resource, context: RefCounted)
signal effect_started(effect: Resource, context: RefCounted)
signal effect_applied(effect: Resource, target: Variant, result_value: int)
signal trigger_dispatched(trigger_name: String, source: Variant)
signal queue_empty()

@export var default_step_delay: float = 0.0

## Target Mutation Policy: when true, Dictionary/Object targets have stats modified in place.
## When false, deltas are computed and emitted via signals without mutating the input target.
@export var mutate_targets_in_place: bool = true

## Audit log of the most recently computed/applied effect deltas.
var last_applied_deltas: Array[Dictionary] = []

var _queue: Array[Dictionary] = []
var _registered_listeners: Array[Dictionary] = [] # Array of {"ability": AbilityDefinition, "entity": Variant, "side": int}
var is_resolving: bool = false

## Optional custom target resolver callable: func(scope: EffectData.TargetScope, context: EffectContext) -> Array
var custom_target_resolver: Callable = Callable()

## Optional custom effect executor callable: func(effect: EffectData, context: EffectContext, target: Variant) -> int
var custom_effect_handler: Callable = Callable()


## Record an applied/computed delta into the audit history
func _record_delta(target: Variant, op: String, stat: String, old_val: Variant, new_val: Variant, delta: Variant) -> void:
	last_applied_deltas.append({
		"target": target,
		"op": op,
		"stat": stat,
		"old_value": old_val,
		"new_value": new_val,
		"delta": delta
	})


## Clear the history of recorded deltas
func clear_deltas() -> void:
	last_applied_deltas.clear()


## Non-mutating preview helper that computes the state delta without touching the input target dictionary.
func preview_effect_delta(effect: EffectData, target: Dictionary) -> Dictionary:
	var dup = target.duplicate(true)
	var prev_mutate = mutate_targets_in_place
	var prev_deltas = last_applied_deltas.duplicate()
	last_applied_deltas.clear()
	mutate_targets_in_place = true
	var res_val = _execute_effect_on_target(effect, EffectContext.create(), dup)
	var preview_deltas = last_applied_deltas.duplicate()
	mutate_targets_in_place = prev_mutate
	last_applied_deltas = prev_deltas
	return {
		"result_value": res_val,
		"mutated_state": dup,
		"deltas": preview_deltas
	}


## Enqueues all effects from an AbilityDefinition
func enqueue_ability(
	ability: Resource,
	context: RefCounted,
	priority: int = 0
) -> void:
	if ability == null or not ability is AbilityDefinition:
		return

	for eff in ability.effects:
		enqueue_effect(eff, context, priority, ability)


## Enqueues a single discrete effect
func enqueue_effect(
	effect: Resource,
	context: RefCounted,
	priority: int = 0,
	source_ability: Resource = null
) -> void:
	if effect == null or not effect is EffectData:
		return

	var entry = {
		"effect": effect,
		"context": context,
		"ability": source_ability,
		"priority": priority
	}

	if priority > 0:
		# Insert by priority (higher priority first)
		var inserted = false
		for i in range(_queue.size()):
			if _queue[i]["priority"] < priority:
				_queue.insert(i, entry)
				inserted = true
				break
		if not inserted:
			_queue.append(entry)
	else:
		_queue.append(entry)

	effect_queued.emit(effect, context)


## Resolves all pending effects synchronously in a single frame (great for unit tests & AI simulation)
func resolve_all_sync() -> void:
	while _queue.size() > 0:
		_resolve_step()
	queue_empty.emit()


## Resolves pending effects asynchronously with an optional tween/timer delay between steps
func process_queue_async(step_delay: float = -1.0) -> void:
	if is_resolving:
		return
	is_resolving = true
	var delay = step_delay if step_delay >= 0.0 else default_step_delay

	while _queue.size() > 0:
		_resolve_step()
		if delay > 0.0 and is_inside_tree():
			await get_tree().create_timer(delay).timeout

	is_resolving = false
	queue_empty.emit()


## Resolves a single effect item from the front of the queue
func _resolve_step() -> void:
	if _queue.is_empty():
		return

	var entry = _queue.pop_front()
	var effect: EffectData = entry["effect"]
	var context: EffectContext = entry["context"]

	effect_started.emit(effect, context)

	# 1. Resolve targets
	var targets = _resolve_targets(effect.target_scope, context)

	# 2. Execute effect on each target
	for target in targets:
		var result = _execute_effect_on_target(effect, context, target)
		effect_applied.emit(effect, target, result)


## Resolves target array based on TargetScope
func _resolve_targets(scope: EffectData.TargetScope, context: EffectContext) -> Array:
	if custom_target_resolver.is_valid():
		var custom_res = custom_target_resolver.call(scope, context)
		if custom_res is Array:
			return custom_res

	# Default target resolution logic
	match scope:
		EffectData.TargetScope.SELF:
			if context.source != null:
				return [context.source]
			elif not context.targets.is_empty():
				return [context.targets[0]]
			return []

		EffectData.TargetScope.TARGET_SINGLE:
			if not context.targets.is_empty():
				return [context.targets[0]]
			return []

		EffectData.TargetScope.ALL_FRIENDLY:
			# 1. Explicit friendly list in context variables
			var friendly_list = context.get_var("friendly_units")
			if friendly_list is Array:
				return friendly_list.duplicate()

			# 2. Board Grid provider
			var grid = context.get_var("board_grid", context.get_var("board"))
			if grid != null and grid.has_method("get_occupied_slots"):
				var slots = grid.get_occupied_slots(context.source_side)
				var units: Array = []
				for s in slots:
					units.append(s.slot_data.primary_occupant if s.slot_data and s.slot_data.has_primary() else s)
				return units

			# 3. Filter targets pool by friendly side
			var matched: Array = []
			for t in context.targets:
				if _get_entity_side(t, context.source_side) == context.source_side:
					matched.append(t)
			if not matched.is_empty():
				return matched
			return context.targets.duplicate()

		EffectData.TargetScope.ALL_ENEMY:
			# 1. Explicit enemy list in context variables
			var enemy_list = context.get_var("enemy_units")
			if enemy_list is Array:
				return enemy_list.duplicate()

			# 2. Board Grid provider
			var grid = context.get_var("board_grid", context.get_var("board"))
			if grid != null and grid.has_method("get_occupied_slots"):
				var slots = grid.get_occupied_slots(-1)
				var units: Array = []
				for s in slots:
					if s.slot_data and s.slot_data.side != context.source_side:
						units.append(s.slot_data.primary_occupant if s.slot_data.has_primary() else s)
				return units

			# 3. Filter targets pool by opposing side
			var matched: Array = []
			for t in context.targets:
				if _get_entity_side(t, -1) != -1 and _get_entity_side(t) != context.source_side:
					matched.append(t)
			if not matched.is_empty():
				return matched
			return context.targets.duplicate()

		EffectData.TargetScope.ADJACENT_FRIENDLY:
			# 1. Universal Spatial Topology Protocol on board
			var board = context.get_var("board", context.get_var("board_grid"))
			if board != null and board.has_method("get_adjacent_units"):
				var origin = context.source if context.source != null else context.get_coordinate()
				var adj_units = board.get_adjacent_units(origin)
				var filtered: Array = []
				for u in adj_units:
					if _get_entity_side(u, context.source_side) == context.source_side:
						filtered.append(u)
				return filtered
			elif board != null and board.has_method("get_slot"):
				var adj_units: Array = []
				for lane_offset in [-1, 1]:
					var adj_slot = board.get_slot(context.source_side, context.source_lane + lane_offset)
					if adj_slot != null and adj_slot.slot_data and not adj_slot.slot_data.is_empty():
						adj_units.append(adj_slot.slot_data.primary_occupant if adj_slot.slot_data.has_primary() else adj_slot)
				return adj_units

			# 2. Candidate pool filtering
			var adj_matched: Array = []
			for t in context.targets:
				if _get_entity_side(t, context.source_side) == context.source_side:
					if abs(_get_entity_lane(t) - context.source_lane) == 1:
						adj_matched.append(t)
			return adj_matched

		EffectData.TargetScope.OPPOSING_LANE:
			# 1. Universal Spatial Topology Protocol on board
			var board = context.get_var("board", context.get_var("board_grid"))
			if board != null and board.has_method("get_opposing_units"):
				var origin = context.source if context.source != null else context.get_coordinate()
				return board.get_opposing_units(origin)
			elif board != null and board.has_method("get_opposing_slot"):
				var cur_slot = board.get_slot(context.source_side, context.source_lane)
				if cur_slot != null:
					var opp_slot = board.get_opposing_slot(cur_slot)
					if opp_slot != null and opp_slot.slot_data and not opp_slot.slot_data.is_empty():
						return [opp_slot.slot_data.primary_occupant if opp_slot.slot_data.has_primary() else opp_slot]
			elif board != null and board.has_method("get_slot"):
				var opp_side = 1 - context.source_side if board.get("sides_count") == 2 else (context.source_side + 1)
				var opp_slot = board.get_slot(opp_side, context.source_lane)
				if opp_slot != null and opp_slot.slot_data and not opp_slot.slot_data.is_empty():
					return [opp_slot.slot_data.primary_occupant if opp_slot.slot_data.has_primary() else opp_slot]

			# 2. Candidate pool filtering
			for t in context.targets:
				if _get_entity_side(t, -1) != context.source_side and _get_entity_lane(t) == context.source_lane:
					return [t]
			return []

		EffectData.TargetScope.RANDOM_ENEMY:
			var enemies = _resolve_targets(EffectData.TargetScope.ALL_ENEMY, context)
			if enemies.is_empty():
				return []
			var count = int(context.get_var("random_count", 1))
			var shuffled = enemies.duplicate()
			shuffled.shuffle()
			return shuffled.slice(0, count)

		EffectData.TargetScope.ALL_UNITS:
			var grid = context.get_var("board_grid", context.get_var("board"))
			if grid != null and grid.has_method("get_occupied_slots"):
				var slots = grid.get_occupied_slots(-1)
				var units: Array = []
				for s in slots:
					units.append(s.slot_data.primary_occupant if s.slot_data and s.slot_data.has_primary() else s)
				return units

			# Combine friendly and enemy or use targets
			var all_pool: Array = []
			var f_units = context.get_var("friendly_units")
			if f_units is Array:
				all_pool.append_array(f_units)
			var e_units = context.get_var("enemy_units")
			if e_units is Array:
				all_pool.append_array(e_units)
			if not all_pool.is_empty():
				return all_pool
			return context.targets.duplicate()

		_:
			return context.targets.duplicate()


func _get_entity_side(entity: Variant, default_side: int = 0) -> int:
	if entity is Dictionary:
		return int(entity.get("side", entity.get("team", default_side)))
	if entity is Object:
		if "slot_data" in entity and entity.slot_data != null:
			return entity.slot_data.side
		if "side" in entity:
			return int(entity.get("side"))
		if "team" in entity:
			return int(entity.get("team"))
		if "is_player" in entity:
			return 0 if entity.is_player else 1
	return default_side


func _get_entity_lane(entity: Variant, default_lane: int = 0) -> int:
	if entity is Dictionary:
		return int(entity.get("lane", entity.get("lane_index", default_lane)))
	if entity is Object:
		if "slot_data" in entity and entity.slot_data != null:
			return entity.slot_data.lane_index
		if "lane_index" in entity:
			return int(entity.get("lane_index"))
		if "lane" in entity:
			return int(entity.get("lane"))
	return default_lane


## Helper to unpack primary occupant from a BoardSlot / slot-like target
func _unpack_target(target: Variant) -> Variant:
	if target is Object and "slot_data" in target and target.slot_data != null and target.slot_data.has_primary():
		return target.slot_data.primary_occupant
	return target


## Applies the concrete effect logic to a single target
func _execute_effect_on_target(
	effect: EffectData,
	context: EffectContext,
	target: Variant
) -> int:
	if custom_effect_handler.is_valid():
		return custom_effect_handler.call(effect, context, target)

	var actual_target = _unpack_target(target)
	var applied_val: int = 0

	match effect.type:
		EffectData.EffectType.DAMAGE:
			applied_val = _apply_damage(actual_target, effect.amount)
		EffectData.EffectType.HEAL:
			applied_val = _apply_heal(actual_target, effect.amount)
		EffectData.EffectType.BUFF_STAT:
			applied_val = _apply_buff(actual_target, effect.stat_name, effect.amount)
		EffectData.EffectType.GAIN_RESOURCE:
			applied_val = _apply_resource(actual_target, effect.amount)
		EffectData.EffectType.DRAW_CARD:
			applied_val = _apply_draw(actual_target, effect.amount)
		EffectData.EffectType.DISCARD_CARD:
			applied_val = _apply_discard(actual_target, effect.amount, effect.metadata)
		EffectData.EffectType.DESTROY:
			applied_val = _apply_destroy(actual_target)
		EffectData.EffectType.SWAP_STATS:
			applied_val = _apply_swap_stats(actual_target, effect.stat_name, effect.metadata.get("stat_b", "def"))
		_:
			applied_val = effect.amount

	return applied_val


func _apply_damage(target: Variant, amount: int) -> int:
	if target == null:
		return 0

	# 1. Method call take_damage or apply_damage
	if target is Object:
		if target.has_method("take_damage"):
			return target.take_damage(amount)
		if target.has_method("apply_damage"):
			var res = target.apply_damage(amount)
			return amount if res is bool else int(res)

	# 2. Dictionary target
	if target is Dictionary:
		var cur_def = target.get("def", target.get("hp", target.get("current_def", 0)))
		var new_def = max(0, cur_def - amount)
		if mutate_targets_in_place:
			if target.has("def"):
				target["def"] = new_def
			elif target.has("hp"):
				target["hp"] = new_def
			elif target.has("current_def"):
				target["current_def"] = new_def
			if new_def == 0:
				target["is_destroyed"] = true
		_record_delta(target, "damage", "def", cur_def, new_def, -amount)
		return amount

	# 3. Object properties
	if target is Object:
		for prop in ["current_def", "current_hp", "defense", "def", "hp"]:
			if prop in target:
				var current = target.get(prop)
				var new_val = max(0, current - amount)
				target.set(prop, new_val)
				return amount

	push_warning("[AbilityResolver] Cannot apply DAMAGE (%d) to target of type %s: target missing take_damage(), apply_damage(), or DEF/HP properties." % [amount, type_string(typeof(target))])
	return 0


func _apply_heal(target: Variant, amount: int) -> int:
	if target == null:
		return 0

	if target is Object:
		if target.has_method("heal"):
			return target.heal(amount)
		if target.has_method("heal_to_full"):
			target.heal_to_full()
			return amount

	if target is Dictionary:
		var cur_def = target.get("def", target.get("hp", target.get("current_def", 0)))
		var max_def = target.get("max_def", target.get("max_hp", 999999))
		var new_def = min(max_def, cur_def + amount)
		var actual_heal = new_def - cur_def
		if mutate_targets_in_place:
			if target.has("def"):
				target["def"] = new_def
			elif target.has("hp"):
				target["hp"] = new_def
			elif target.has("current_def"):
				target["current_def"] = new_def
		_record_delta(target, "heal", "def", cur_def, new_def, actual_heal)
		return actual_heal

	if target is Object:
		for prop in ["current_def", "current_hp", "defense", "def", "hp"]:
			if prop in target:
				var current = target.get(prop)
				target.set(prop, current + amount)
				return amount

	push_warning("[AbilityResolver] Cannot apply HEAL (%d) to target of type %s: target missing heal(), heal_to_full(), or DEF/HP properties." % [amount, type_string(typeof(target))])
	return 0


func _apply_buff(target: Variant, stat_name: String, amount: int) -> int:
	if target == null:
		return 0

	var key = stat_name.to_lower()
	if target is Object:
		if target.has_method("apply_buff"):
			return target.apply_buff(key, amount)
		if key == "atk" and target.has_method("modify_atk"):
			target.modify_atk(amount)
			return amount
		if key == "def" and target.has_method("modify_def"):
			target.modify_def(amount)
			return amount

	if target is Dictionary:
		if target.has(key) or target.has("current_" + key):
			var actual_key = key if target.has(key) else ("current_" + key)
			var cur_val = target.get(actual_key, 0)
			var new_val = cur_val + amount
			if mutate_targets_in_place:
				target[actual_key] = new_val
			_record_delta(target, "buff", actual_key, cur_val, new_val, amount)
			return amount

	if target is Object:
		for k in [key, "current_" + key]:
			if k in target:
				var current = target.get(k)
				target.set(k, current + amount)
				return amount

	push_warning("[AbilityResolver] Cannot apply BUFF_STAT (%s += %d) to target of type %s: stat '%s' not found on target." % [stat_name, amount, type_string(typeof(target)), key])
	return 0


func _apply_resource(target: Variant, amount: int) -> int:
	if target == null:
		return 0

	if target is Object and target.has_method("gain_resource"):
		return target.gain_resource(amount)

	if target is Dictionary:
		for prop in ["magic", "mana", "resource", "action_points", "mp"]:
			if target.has(prop):
				var cur = target.get(prop, 0)
				if mutate_targets_in_place:
					target[prop] = cur + amount
				_record_delta(target, "resource", prop, cur, cur + amount, amount)
				return amount
		var cur_m = target.get("magic", 0)
		if mutate_targets_in_place:
			target["magic"] = cur_m + amount
		_record_delta(target, "resource", "magic", cur_m, cur_m + amount, amount)
		return amount

	if target is Object:
		for prop in ["magic", "mana", "resource", "action_points", "mp", "player_mp"]:
			if prop in target:
				var cur = target.get(prop)
				target.set(prop, cur + amount)
				return amount

	push_warning("[AbilityResolver] Cannot apply GAIN_RESOURCE (%d) to target of type %s: target missing gain_resource() or resource property." % [amount, type_string(typeof(target))])
	return 0


func _apply_draw(target: Variant, count: int) -> int:
	if target == null:
		return 0

	if target is Object:
		if target.has_method("draw_cards"):
			return target.draw_cards(count)
		if target.has_method("draw_player_card"):
			for _i in range(count):
				target.draw_player_card()
			return count
		if target.has_method("draw"):
			return target.draw(count)

	if target is Dictionary:
		var cur = target.get("cards_drawn", 0)
		if mutate_targets_in_place:
			target["cards_drawn"] = cur + count
		_record_delta(target, "draw", "cards_drawn", cur, cur + count, count)
		return count

	push_warning("[AbilityResolver] Cannot apply DRAW_CARD (%d) to target of type %s: target missing draw_cards() or cards_drawn dictionary key." % [count, type_string(typeof(target))])
	return 0


func _apply_discard(target: Variant, count: int, _metadata: Dictionary = {}) -> int:
	if target == null:
		return 0

	if target is Object:
		if target.has_method("discard_cards"):
			return target.discard_cards(count)
		if target.has_method("discard"):
			return target.discard(count)

	if target is Dictionary:
		if target.has("hand") and target["hand"] is Array:
			var hand_arr: Array = target["hand"]
			var actual_discarded = min(count, hand_arr.size())
			var cur_disc = target.get("cards_discarded", 0)
			if mutate_targets_in_place:
				for _i in range(actual_discarded):
					hand_arr.pop_back()
				target["cards_discarded"] = cur_disc + actual_discarded
			_record_delta(target, "discard", "cards_discarded", cur_disc, cur_disc + actual_discarded, actual_discarded)
			return actual_discarded
		else:
			var cur_disc = target.get("cards_discarded", 0)
			if mutate_targets_in_place:
				target["cards_discarded"] = cur_disc + count
			_record_delta(target, "discard", "cards_discarded", cur_disc, cur_disc + count, count)
			return count

	if target is Array:
		var discarded = 0
		for _i in range(min(count, target.size())):
			target.pop_back()
			discarded += 1
		return discarded

	push_warning("[AbilityResolver] Cannot apply DISCARD_CARD (%d) to target of type %s: target missing discard_cards(), hand Array, or Array container." % [count, type_string(typeof(target))])
	return 0


func _apply_destroy(target: Variant) -> int:
	if target == null:
		return 0

	if target is Object and target.has_method("destroy"):
		target.destroy()
		return 1

	if target is Dictionary:
		if mutate_targets_in_place:
			target["is_destroyed"] = true
			target["def"] = 0
			target["hp"] = 0
		_record_delta(target, "destroy", "is_destroyed", false, true, 1)
		return 1

	if target is Object:
		if "is_destroyed" in target:
			target.set("is_destroyed", true)
			return 1
		if target.has_method("queue_free"):
			target.queue_free()
			return 1

	push_warning("[AbilityResolver] Cannot apply DESTROY to target of type %s: missing destroy() method, is_destroyed property, or queue_free." % type_string(typeof(target)))
	return 0


func _apply_swap_stats(target: Variant, stat_a: String, stat_b: String) -> int:
	if target == null:
		return 0

	var a_key = stat_a.to_lower()
	var b_key = stat_b.to_lower()
	if target is Dictionary:
		if target.has(a_key) and target.has(b_key):
			var val_a = target.get(a_key, 0)
			var val_b = target.get(b_key, 0)
			if mutate_targets_in_place:
				target[a_key] = val_b
				target[b_key] = val_a
			_record_delta(target, "swap", "%s<->%s" % [a_key, b_key], [val_a, val_b], [val_b, val_a], 0)
			return 1

	if target is Object and a_key in target and b_key in target:
		var val_a = target.get(a_key)
		var val_b = target.get(b_key)
		target.set(a_key, val_b)
		target.set(b_key, val_a)
		return 1

	push_warning("[AbilityResolver] Cannot apply SWAP_STATS (%s <-> %s) to target of type %s: stats not found on target." % [stat_a, stat_b, type_string(typeof(target))])
	return 0


## Trigger registration: registers an entity's passive/reactive ability
func register_trigger_listener(ability: Resource, entity: Variant, side: int = 0) -> void:
	if ability is AbilityDefinition:
		_registered_listeners.append({
			"ability": ability,
			"entity": entity,
			"side": side
		})


func unregister_entity_listeners(entity: Variant) -> void:
	var i = _registered_listeners.size() - 1
	while i >= 0:
		if _registered_listeners[i]["entity"] == entity:
			_registered_listeners.remove_at(i)
		i -= 1


## Dispatches a trigger event and enqueues all matching listener abilities
func dispatch_trigger(
	trigger_name: String,
	source_entity: Variant,
	context: RefCounted = null
) -> void:
	trigger_dispatched.emit(trigger_name, source_entity)

	for listener in _registered_listeners:
		var ab: AbilityDefinition = listener["ability"]
		if ab.trigger == trigger_name:
			# If listener entity matches source or triggers globally
			var ctx = context
			if ctx == null:
				ctx = EffectContext.create(listener["entity"], listener["side"])
			ctx.trigger_name = trigger_name
			enqueue_ability(ab, ctx)


## Returns the number of effects currently waiting in the queue
func get_queue_size() -> int:
	return _queue.size()


## Clears all pending effects in the queue
func clear_queue() -> void:
	_queue.clear()
	is_resolving = false
