class_name CardData
extends Resource

# Generic Card Data Model
# Stores card parameters decoupled from any specific game rules.

const UNIVERSAL_TAG: String = "Universal"

@export var id: String = ""
@export var name: String = "Unknown Card"
@export var cost: int = 0
@export var type: String = "Generic"          # Archetype (e.g. Creature, Spell, Building)
@export var category: String = "Standard"     # Subtype / Tribe (e.g. Knight, Dog, Scholar)
@export var affinity: String = UNIVERSAL_TAG   # Elemental/Faction/Terrain affinity tag
@export var attack: int = 0
@export var defense: int = 0
@export var description: String = ""
@export var metadata: Dictionary = {}

static func create(
	p_id: String,
	p_name: String,
	p_cost: int = 1,
	p_type: String = "Creature",
	p_affinity: String = UNIVERSAL_TAG,
	p_atk: int = 0,
	p_def: int = 0,
	p_desc: String = "",
	p_meta: Dictionary = {},
	p_cat: String = "Standard"
) -> Resource:
	var c = new()
	c.id = p_id
	c.name = p_name
	c.cost = p_cost
	c.type = p_type
	c.affinity = p_affinity if not p_affinity.is_empty() else UNIVERSAL_TAG
	c.attack = p_atk
	c.defense = p_def
	c.description = p_desc
	c.metadata = p_meta
	c.category = p_cat
	return c


## Returns the effective affinity tag for board placement validation.
## Returns 'affinity' directly with no fallback.
func get_affinity() -> String:
	return affinity
