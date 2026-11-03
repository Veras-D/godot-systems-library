class_name BoardSlot
extends Control

## Visual component representing a single board lane slot.
## Completely decoupled: displays whatever occupant node or data is provided.
## Supports drag-and-drop, click-to-place, hover highlights, and feedback animations.

const SlotData = preload("SlotData.gd")

signal slot_clicked(slot: BoardSlot)
signal slot_hovered(slot: BoardSlot, is_hovered: bool)
signal slot_dropped(slot: BoardSlot, data: Variant)
signal occupant_cleared(slot: BoardSlot)
signal damage_shake_started(slot: BoardSlot, intensity: float)
signal summon_pulse_started(slot: BoardSlot)

enum HighlightMode {
	NONE,
	HOVERED,
	SELECTED,
	VALID_TARGET,
	INVALID_TARGET
}

@export var slot_data: Resource = null:
	set(val):
		if slot_data and slot_data.is_connected("occupant_changed", _on_data_occupant_changed):
			slot_data.disconnect("occupant_changed", _on_data_occupant_changed)
			slot_data.disconnect("affinity_changed", _on_data_affinity_changed)
			slot_data.disconnect("modifiers_changed", _on_data_modifiers_changed)
		slot_data = val
		if slot_data:
			slot_data.occupant_changed.connect(_on_data_occupant_changed)
			slot_data.affinity_changed.connect(_on_data_affinity_changed)
			slot_data.modifiers_changed.connect(_on_data_modifiers_changed)
			_update_views()

@export var custom_colors: Dictionary = {
	"Grass": Color(0.2, 0.65, 0.25, 0.4),
	"Swamp": Color(0.4, 0.25, 0.55, 0.4),
	"Sand": Color(0.85, 0.7, 0.2, 0.4),
	"Plains": Color(0.25, 0.6, 0.8, 0.4),
	"Universal": Color(0.7, 0.7, 0.75, 0.4),
	"Default": Color(0.12, 0.15, 0.22, 0.85)
}

## Optional reference to parent BoardGrid or custom validator for drop checks
var grid_owner: Node = null
var custom_affinity_validator: Callable = Callable()

@onready var background_panel: Panel = $Background
@onready var highlight_overlay: Panel = $HighlightOverlay
@onready var affinity_badge: Label = $Header/AffinityBadge
@onready var lane_coord_label: Label = $Header/CoordLabel
@onready var primary_container: Control = $Content/PrimaryContainer
@onready var attachment_container: Control = $Content/AttachmentContainer
@onready var modifier_label: Label = $Footer/ModifierLabel

var current_highlight: HighlightMode = HighlightMode.NONE
var is_mouse_inside: bool = false
var _shake_tween: Tween = null


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	if slot_data == null:
		slot_data = SlotData.create(0, 0, "")
	_update_views()
	set_highlight(HighlightMode.NONE)


## Setup slot with data programmatically
func setup(p_slot_data: Resource) -> void:
	self.slot_data = p_slot_data


## Set or clear occupant visually
func set_primary_view(view_node: Node) -> void:
	# Clear existing children
	for child in primary_container.get_children():
		child.queue_free()
	if view_node:
		primary_container.add_child(view_node)
		if slot_data:
			slot_data.primary_occupant = view_node


func set_attachment_view(view_node: Node) -> void:
	for child in attachment_container.get_children():
		child.queue_free()
	if view_node:
		attachment_container.add_child(view_node)
		if slot_data:
			slot_data.attached_occupant = view_node


func clear_occupants() -> void:
	for child in primary_container.get_children():
		child.queue_free()
	for child in attachment_container.get_children():
		child.queue_free()
	if slot_data:
		slot_data.clear()
	occupant_cleared.emit(self)


## Set highlight state with visual styling
func set_highlight(mode: HighlightMode) -> void:
	current_highlight = mode
	if not is_inside_tree() or highlight_overlay == null:
		return

	match mode:
		HighlightMode.NONE:
			highlight_overlay.visible = false
		HighlightMode.HOVERED:
			highlight_overlay.visible = true
			highlight_overlay.modulate = Color(1.0, 1.0, 1.0, 0.25)
		HighlightMode.SELECTED:
			highlight_overlay.visible = true
			highlight_overlay.modulate = Color(1.0, 0.85, 0.2, 0.5)
		HighlightMode.VALID_TARGET:
			highlight_overlay.visible = true
			highlight_overlay.modulate = Color(0.2, 1.0, 0.35, 0.5)
		HighlightMode.INVALID_TARGET:
			highlight_overlay.visible = true
			highlight_overlay.modulate = Color(1.0, 0.2, 0.2, 0.5)


## Play damage shake animation
func play_damage_shake(intensity: float = 8.0, duration: float = 0.35) -> void:
	damage_shake_started.emit(self, intensity)
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	var orig_pos = position
	_shake_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shake_tween.tween_property(self, "position", orig_pos + Vector2(intensity, 0), duration * 0.2)
	_shake_tween.tween_property(self, "position", orig_pos - Vector2(intensity * 0.8, 0), duration * 0.2)
	_shake_tween.tween_property(self, "position", orig_pos + Vector2(intensity * 0.4, 0), duration * 0.2)
	_shake_tween.tween_property(self, "position", orig_pos, duration * 0.4)


## Play summon pulse animation
func play_summon_pulse() -> void:
	summon_pulse_started.emit(self)
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale = Vector2(0.9, 0.9)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25)


## Drag and Drop Handlers (Godot Control native D&D)
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if slot_data == null or slot_data.is_locked or slot_data.is_disabled:
		return false
	if data == null or not (data is Dictionary):
		return false

	var payload_type = data.get("type", "")
	if payload_type == "card":
		var card = data.get("card_data")
		if card == null:
			return false # Malformed card payload

		var aff: String = ""
		if card is Object and card.has_method("get_affinity"):
			aff = card.get_affinity()
		elif card is Dictionary and card.has("affinity"):
			aff = str(card.get("affinity"))
		elif card is Object and "affinity" in card:
			aff = str(card.get("affinity"))
		else:
			return false # Malformed card with no affinity tag

		if grid_owner != null and grid_owner.has_method("validate_placement"):
			return grid_owner.validate_placement(aff, slot_data.side, slot_data.lane_index, false).get("allowed", false)
		elif custom_affinity_validator.is_valid():
			return slot_data.is_empty() and custom_affinity_validator.call(aff, slot_data.affinity)
		return slot_data.is_empty() and slot_data.can_accept_affinity(aff)

	elif payload_type == "attachment":
		if grid_owner != null and grid_owner.has_method("validate_placement"):
			return grid_owner.validate_placement("", slot_data.side, slot_data.lane_index, true).get("allowed", false)
		return slot_data.has_primary() and not slot_data.has_attachment()

	# Disallow any other malformed or unrecognized payload
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	slot_dropped.emit(self, data)


func _on_mouse_entered() -> void:
	is_mouse_inside = true
	if current_highlight == HighlightMode.NONE:
		set_highlight(HighlightMode.HOVERED)
	slot_hovered.emit(self, true)


func _on_mouse_exited() -> void:
	is_mouse_inside = false
	if current_highlight == HighlightMode.HOVERED:
		set_highlight(HighlightMode.NONE)
	slot_hovered.emit(self, false)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(self)


func _update_views() -> void:
	if not is_inside_tree() or background_panel == null:
		return

	if slot_data:
		affinity_badge.text = slot_data.affinity if not slot_data.affinity.is_empty() else "—"
		lane_coord_label.text = "S%d:L%d" % [slot_data.side, slot_data.lane_index]

		# Affinity color tint
		var bg_color = custom_colors.get(slot_data.affinity, custom_colors["Default"])
		background_panel.self_modulate = bg_color

		# Modifiers
		if slot_data.modifiers.is_empty():
			modifier_label.text = ""
		else:
			var mod_strings: Array[String] = []
			for k in slot_data.modifiers:
				var v = slot_data.modifiers[k]
				var sign_prefix = "+" if (v is int or v is float) and v > 0 else ""
				mod_strings.append("%s%s %s" % [sign_prefix, str(v), k.to_upper()])
			modifier_label.text = ", ".join(mod_strings)
	else:
		affinity_badge.text = "—"
		lane_coord_label.text = ""
		modifier_label.text = ""
		background_panel.self_modulate = custom_colors["Default"]


func _on_data_occupant_changed(_data: Resource) -> void:
	_update_views()


func _on_data_affinity_changed(_data: Resource, _new_affinity: String) -> void:
	_update_views()


func _on_data_modifiers_changed(_data: Resource) -> void:
	_update_views()
