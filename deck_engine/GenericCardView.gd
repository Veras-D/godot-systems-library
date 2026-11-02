class_name GenericCardView
extends Control

const CardData = preload("CardData.gd")

signal card_clicked(card_view: GenericCardView)
signal card_hovered(card_view: GenericCardView)
signal card_unhovered(card_view: GenericCardView)

@export var card_data: CardData

@onready var panel: Panel = $Panel
@onready var cost_lbl: Label = $Panel/CostBadge/Label
@onready var name_lbl: Label = $Panel/NameLabel
@onready var type_lbl: Label = $Panel/TypeLabel
@onready var desc_lbl: Label = $Panel/DescLabel
@onready var atk_lbl: Label = $Panel/StatsRow/AtkBadge/Label
@onready var def_lbl: Label = $Panel/StatsRow/DefBadge/Label

var is_hovered: bool = false
var is_selected: bool = false
var home_position: Vector2 = Vector2.ZERO
var home_rotation: float = 0.0
var home_z_index: int = 0

func _ready() -> void:
	custom_minimum_size = Vector2(130, 180)
	size = Vector2(130, 180)
	# Critical for card fanning: pivot must be at bottom-center!
	pivot_offset = Vector2(size.x / 2.0, size.y)
	mouse_filter = MOUSE_FILTER_PASS

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	if card_data != null:
		render_card(card_data)

func render_card(p_data: CardData) -> void:
	card_data = p_data
	if not is_inside_tree():
		return

	name_lbl.text = p_data.name
	cost_lbl.text = str(p_data.cost)
	type_lbl.text = "%s • %s" % [p_data.type.to_upper(), p_data.category]
	desc_lbl.text = p_data.description
	atk_lbl.text = str(p_data.attack)
	def_lbl.text = str(p_data.defense)

func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_style()

func _update_style() -> void:
	if is_selected:
		modulate = Color(1.2, 1.2, 0.7, 1.0)
	elif is_hovered:
		modulate = Color(1.1, 1.1, 1.1, 1.0)
	else:
		modulate = Color.WHITE

func _on_mouse_entered() -> void:
	is_hovered = true
	_update_style()
	card_hovered.emit(self)

func _on_mouse_exited() -> void:
	is_hovered = false
	_update_style()
	card_unhovered.emit(self)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)


## Native Godot Drag-and-Drop integration for board placement
func _get_drag_data(_at_position: Vector2) -> Variant:
	if card_data == null:
		return null

	var preview = Control.new()
	var preview_card = duplicate() as Control
	preview_card.position = -size / 2.0
	preview_card.modulate = Color(1.0, 1.0, 1.0, 0.85)
	preview.add_child(preview_card)
	set_drag_preview(preview)

	return {
		"type": "card",
		"card_data": card_data,
		"source_view": self
	}
