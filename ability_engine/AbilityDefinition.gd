class_name AbilityDefinition
extends Resource

## Data contract for a full ability consisting of a trigger event and a sequence of effects.
## Used by cards, heroes, creatures, artifacts, and structures.

const EffectData = preload("EffectData.gd")

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var trigger: String = "ON_ACTIVATE"       # e.g. "ON_PLAY", "ON_SUMMON", "ON_DEATH", "ON_TURN_START", "ON_TURN_END", "ON_ATTACK", "ON_DAMAGE_TAKEN", "ON_ACTIVATE"
@export var effects: Array[Resource] = []         # Array of EffectData resources
@export var cost_resource: int = 0
@export var cooldown_turns: int = 0


static func create(
	p_id: String,
	p_name: String,
	p_trigger: String = "ON_ACTIVATE",
	p_effects: Array = [],
	p_desc: String = ""
) -> Resource:
	var ab = new()
	ab.id = p_id
	ab.name = p_name
	ab.trigger = p_trigger
	ab.description = p_desc
	for eff in p_effects:
		if eff is Resource:
			ab.effects.append(eff)
	return ab


func add_effect(effect: Resource) -> void:
	effects.append(effect)


func to_string_summary() -> String:
	var eff_summaries: Array[String] = []
	for e in effects:
		if e and e.has_method("to_string_summary"):
			eff_summaries.append(e.to_string_summary())
	return "[%s] Trigger: %s | Effects: %s" % [name, trigger, " -> ".join(eff_summaries)]
