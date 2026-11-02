class_name HandManager
extends Control

const CardData = preload("CardData.gd")
const GenericCardView = preload("GenericCardView.gd")

signal card_clicked(card_view: GenericCardView)
signal card_added(card_view: GenericCardView)
signal card_removed(card_view: GenericCardView)
signal card_hovered(card_view: GenericCardView)
signal card_unhovered(card_view: GenericCardView)
signal card_drawn(card: Variant)
signal card_played(card: Variant)

@export var card_scene: PackedScene = preload("GenericCardView.tscn")
@export var max_hand_width: float = 650.0
@export var max_card_spacing: float = 120.0
@export var arc_height: float = 35.0
@export var max_angle_spread_deg: float = 28.0
@export var max_hand_size: int = 10
@export var hover_lift_px: float = 40.0
@export var hover_scale: float = 1.15

var _card_views: Array[GenericCardView] = []
var _hovered_card: GenericCardView = null

func _ready() -> void:
	custom_minimum_size = Vector2(max_hand_width, 220)

func add_card(card_data: CardData) -> GenericCardView:
	if card_data == null:
		return null

	if _card_views.size() >= max_hand_size:
		return null

	var view: GenericCardView = card_scene.instantiate() as GenericCardView
	add_child(view)
	view.render_card(card_data)

	_card_views.append(view)

	view.card_clicked.connect(_on_card_clicked.bind(view))
	view.card_hovered.connect(_on_card_hovered.bind(view))
	view.card_unhovered.connect(_on_card_unhovered.bind(view))

	update_hand_layout(true)
	card_added.emit(view)
	card_drawn.emit(card_data)
	return view

func play_card(card_view: GenericCardView) -> void:
	if card_view == null or not card_view in _card_views:
		return
	var c_data = card_view.card_data
	remove_card(card_view)
	card_played.emit(c_data)

func remove_card(card_view: GenericCardView) -> void:
	if card_view == null or not card_view in _card_views:
		return

	if _hovered_card == card_view:
		_hovered_card = null

	_card_views.erase(card_view)
	card_removed.emit(card_view)
	card_view.queue_free()
	update_hand_layout(true)

func clear_hand() -> void:
	_hovered_card = null
	for c in _card_views:
		c.queue_free()
	_card_views.clear()

func update_hand_layout(animate: bool = true) -> void:
	var n = _card_views.size()
	if n == 0:
		return

	# Dynamic spacing: compress cards if hand count exceeds max width
	var spacing = minf(max_card_spacing, max_hand_width / max(1, n - 1))
	var center_x = size.x / 2.0
	var base_y = size.y - 190.0

	for i in range(n):
		var card = _card_views[i]
		# Normalize: -0.5 (leftmost) to +0.5 (rightmost)
		var norm = 0.0 if n == 1 else (float(i) / float(n - 1)) - 0.5

		# 1. Horizontal distribution
		var target_x = center_x + (norm * spacing * (n - 1)) - (card.size.x / 2.0)

		# 2. Parabolic arc drop: edges sink downward
		var target_y = base_y + (norm * norm) * arc_height * 4.0

		# 3. Angular fan rotation
		var target_rot = norm * deg_to_rad(max_angle_spread_deg)

		card.home_position = Vector2(target_x, target_y)
		card.home_rotation = target_rot
		card.home_z_index = i

		# If this card is currently hovered, don't overwrite its lifted transform
		if card == _hovered_card:
			continue

		card.z_index = i

		if animate:
			var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "position", card.home_position, 0.22)
			tw.tween_property(card, "rotation", card.home_rotation, 0.22)
			tw.tween_property(card, "scale", Vector2.ONE, 0.15)
		else:
			card.position = card.home_position
			card.rotation = card.home_rotation
			card.scale = Vector2.ONE

func _on_card_hovered(card: GenericCardView) -> void:
	_hovered_card = card
	card.z_index = 100

	var lift_target = Vector2(card.home_position.x, card.home_position.y - hover_lift_px)
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "position", lift_target, 0.18)
	tw.tween_property(card, "rotation", 0.0, 0.18)
	tw.tween_property(card, "scale", Vector2(hover_scale, hover_scale), 0.18)

	card_hovered.emit(card)

func _on_card_unhovered(card: GenericCardView) -> void:
	if _hovered_card == card:
		_hovered_card = null

	card.z_index = card.home_z_index
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "position", card.home_position, 0.2)
	tw.tween_property(card, "rotation", card.home_rotation, 0.2)
	tw.tween_property(card, "scale", Vector2.ONE, 0.18)

	card_unhovered.emit(card)

func _on_card_clicked(card: GenericCardView) -> void:
	card_clicked.emit(card)

func get_cards() -> Array[GenericCardView]:
	return _card_views

func get_card_count() -> int:
	return _card_views.size()
