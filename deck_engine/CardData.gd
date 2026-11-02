class_name CardData
extends Resource

# Generic Card Data Model
# Stores card parameters decoupled from any specific game rules.

@export var id: String = ""
@export var name: String = "Unknown Card"
@export var cost: int = 0
@export var type: String = "Generic"          # Archetype (e.g. Creature, Spell, Building)
@export var category: String = "Standard"     # Subtype / Tribe (e.g. Knight, Dog, Scholar)
var _affinity: String = ""

@export var affinity: String:
	get:
		return _affinity
	set(val):
		_affinity = val

@export var faction: String:
	get:
		return _affinity
	set(val):
		_affinity = val
@export var attack: int = 0
@export var defense: int = 0
@export var description: String = ""
@export var metadata: Dictionary = {}

static func create(
	p_id: String,
	p_name: String,
	p_cost: int = 1,
	p_type: String = "Creature",
	p_cat: String = "Neutral",
	p_atk: int = 0,
	p_def: int = 0,
	p_desc: String = "",
	p_meta: Dictionary = {},
	p_faction: String = "",
	p_affinity: String = ""
) -> Resource:
	var c = new()
	c.id = p_id
	c.name = p_name
	c.cost = p_cost
	c.type = p_type
	c.category = p_cat
	var eff_aff = p_affinity if not p_affinity.is_empty() else (p_faction if not p_faction.is_empty() else p_cat)
	c.affinity = eff_aff
	c.attack = p_atk
	c.defense = p_def
	c.description = p_desc
	c.metadata = p_meta
	return c


## Returns the effective affinity tag for board placement validation
func get_affinity() -> String:
	if not affinity.is_empty():
		return affinity
	if not faction.is_empty():
		return faction
	return category
