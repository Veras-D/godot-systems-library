class_name CardData
extends Resource

# Generic Card Data Model
# Stores card parameters decoupled from any specific game rules.

@export var id: String = ""
@export var name: String = "Unknown Card"
@export var cost: int = 0
@export var type: String = "Generic"
@export var category: String = "Standard"
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
	p_meta: Dictionary = {}
) -> Resource:
	var c = new()
	c.id = p_id
	c.name = p_name
	c.cost = p_cost
	c.type = p_type
	c.category = p_cat
	c.attack = p_atk
	c.defense = p_def
	c.description = p_desc
	c.metadata = p_meta
	return c
