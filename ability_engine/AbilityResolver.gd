class_name AbilityResolver
extends Node

## Universal Data-Driven Ability & Effect Queue Resolver.
## Executes effects in a deterministic, FIFO queue with priority support.
## Completely decoupled: resolves effects against abstract targets (Nodes, Dictionaries, or Objects).

const EffectData = preload("EffectData.gd")
const EffectContext = preload("EffectContext.gd")
const AbilityDefinition = preload("AbilityDefinition.gd")

signal effect_queued(effect: Resource, context: RefCounted)
signal effect_started(effect: Resource, context: RefCounted)
signal effect_applied(effect: Resource, target: Variant, result_value: int)
signal trigger_dispatched(trigger_name: String, source: Variant)
signal queue_empty()

@export var default_step_delay: float = 0.0

var _queue: Array[Dictionary] = []
var _registered_listeners: Array[Dictionary] = [] # Array of {"ability": AbilityDefinition, "entity": Variant, "side": int}
var is_resolving: bool = false

## Optional custom target resolver callable: func(scope: EffectData.TargetScope, context: EffectContext) -> Array
var custom_target_resolver: Callable = Callable()

## Optional custom effect executor callable: func(effect: EffectData, context: EffectContext, target: Variant) -> int
var custom_effect_handler: Callable = Callable()


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
			return context.targets.duplicate()
		_:
			# If targets are explicitly populated in context, fall back to them
			return context.targets.duplicate()


## Applies the concrete effect logic to a single target
func _execute_effect_on_target(
	effect: EffectData,
	context: EffectContext,
	target: Variant
) -> int:
	if custom_effect_handler.is_valid():
		return custom_effect_handler.call(effect, context, target)

	var applied_val: int = 0

	match effect.type:
		EffectData.EffectType.DAMAGE:
			applied_val = _apply_damage(target, effect.amount)
		EffectData.EffectType.HEAL:
			applied_val = _apply_heal(target, effect.amount)
		EffectData.EffectType.BUFF_STAT:
			applied_val = _apply_buff(target, effect.stat_name, effect.amount)
		EffectData.EffectType.GAIN_RESOURCE:
			applied_val = _apply_resource(target, effect.amount)
		EffectData.EffectType.DRAW_CARD:
			applied_val = _apply_draw(target, effect.amount)
		EffectData.EffectType.DESTROY:
			applied_val = _apply_destroy(target)
		EffectData.EffectType.SWAP_STATS:
			applied_val = _apply_swap_stats(target, effect.stat_name, effect.metadata.get("stat_b", "def"))
		_:
			applied_val = effect.amount

	return applied_val


func _apply_damage(target: Variant, amount: int) -> int:
	if target == null:
		return 0

	# 1. Method call take_damage
	if target is Object and target.has_method("take_damage"):
		return target.take_damage(amount)

	# 2. Dictionary target
	if target is Dictionary:
		var cur_def = target.get("def", target.get("hp", 0))
		var new_def = max(0, cur_def - amount)
		if target.has("def"):
			target["def"] = new_def
		elif target.has("hp"):
			target["hp"] = new_def
		if new_def == 0:
			target["is_destroyed"] = true
		return amount

	# 3. Object properties
	if target is Object:
		for prop in ["current_def", "current_hp", "defense", "def", "hp"]:
			if prop in target:
				var current = target.get(prop)
				var new_val = max(0, current - amount)
				target.set(prop, new_val)
				return amount

	return 0


func _apply_heal(target: Variant, amount: int) -> int:
	if target == null:
		return 0

	if target is Object and target.has_method("heal"):
		return target.heal(amount)

	if target is Dictionary:
		var cur_def = target.get("def", target.get("hp", 0))
		var max_def = target.get("max_def", target.get("max_hp", 999999))
		var new_def = min(max_def, cur_def + amount)
		var actual_heal = new_def - cur_def
		if target.has("def"):
			target["def"] = new_def
		elif target.has("hp"):
			target["hp"] = new_def
		return actual_heal

	if target is Object:
		for prop in ["current_def", "current_hp", "defense", "def", "hp"]:
			if prop in target:
				var current = target.get(prop)
				target.set(prop, current + amount)
				return amount

	return 0


func _apply_buff(target: Variant, stat_name: String, amount: int) -> int:
	if target == null:
		return 0

	var key = stat_name.to_lower()
	if target is Object and target.has_method("apply_buff"):
		return target.apply_buff(key, amount)

	if target is Dictionary:
		var cur_val = target.get(key, 0)
		target[key] = cur_val + amount
		return amount

	if target is Object and key in target:
		var current = target.get(key)
		target.set(key, current + amount)
		return amount

	return 0


func _apply_resource(target: Variant, amount: int) -> int:
	if target is Object and target.has_method("gain_resource"):
		return target.gain_resource(amount)
	if target is Dictionary:
		var cur = target.get("magic", target.get("mana", target.get("resource", 0)))
		target["magic"] = cur + amount
		return amount
	return amount


func _apply_draw(target: Variant, count: int) -> int:
	if target is Object and target.has_method("draw_cards"):
		return target.draw_cards(count)
	if target is Dictionary:
		target["cards_drawn"] = target.get("cards_drawn", 0) + count
		return count
	return count


func _apply_destroy(target: Variant) -> int:
	if target is Object and target.has_method("destroy"):
		target.destroy()
		return 1
	if target is Dictionary:
		target["is_destroyed"] = true
		target["def"] = 0
		target["hp"] = 0
		return 1
	return 0


func _apply_swap_stats(target: Variant, stat_a: String, stat_b: String) -> int:
	var a_key = stat_a.to_lower()
	var b_key = stat_b.to_lower()
	if target is Dictionary:
		var val_a = target.get(a_key, 0)
		var val_b = target.get(b_key, 0)
		target[a_key] = val_b
		target[b_key] = val_a
		return 1
	if target is Object and a_key in target and b_key in target:
		var val_a = target.get(a_key)
		var val_b = target.get(b_key)
		target.set(a_key, val_b)
		target.set(b_key, val_a)
		return 1
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
