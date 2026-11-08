class_name HotseatCurtain
extends Control

## HotseatCurtain: Fullscreen privacy curtain for turn-based pass-and-play matches.
## Obfuscates private hand information and tactical positions during device handoff.

const PlayerInputRouter = preload("PlayerInputRouter.gd")
const MatchRulesConfig = preload("MatchRulesConfig.gd")

signal handoff_started(next_player_slot: int, player_name: String)
signal unveil_confirmed(next_player_slot: int)
signal curtain_transition_finished(is_visible: bool)

enum CurtainState {
	INACTIVE,
	LOWERING,
	AWAITING_HANDOFF,
	RAISING
}

var current_state: CurtainState = CurtainState.INACTIVE
var target_player_slot: int = 0
var target_player_name: String = "Player 1"
var input_router: PlayerInputRouter

# UI Nodes created programmatically to be zero-dependency
var _bg_overlay: ColorRect
var _dialog_box: PanelContainer
var _prompt_title: Label
var _prompt_subtitle: Label
var _unveil_button: Button


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	anchors_preset = PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = GROW_DIRECTION_BOTH
	grow_vertical = GROW_DIRECTION_BOTH
	visible = false

	_build_ui()


func _build_ui() -> void:
	_bg_overlay = ColorRect.new()
	_bg_overlay.anchors_preset = PRESET_FULL_RECT
	_bg_overlay.anchor_right = 1.0
	_bg_overlay.anchor_bottom = 1.0
	_bg_overlay.color = Color(0.08, 0.09, 0.12, 0.98)
	add_child(_bg_overlay)

	var center = CenterContainer.new()
	center.anchors_preset = PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	_dialog_box = PanelContainer.new()
	_dialog_box.custom_minimum_size = Vector2(480, 240)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.22, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.85, 0.65, 0.2, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	_dialog_box.add_theme_stylebox_override("panel", style)
	center.add_child(_dialog_box)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.size_flags_vertical = SIZE_EXPAND_FILL
	_dialog_box.add_child(vbox)

	_prompt_title = Label.new()
	_prompt_title.text = "🔒 PASS THE DEVICE!"
	_prompt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_title.add_theme_font_size_override("font_size", 24)
	_prompt_title.modulate = Color(1.0, 0.85, 0.25)
	vbox.add_child(_prompt_title)

	_prompt_subtitle = Label.new()
	_prompt_subtitle.text = "Hand the screen to Player 2.\nKeep hands hidden from opposing eyes!"
	_prompt_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_subtitle.add_theme_font_size_override("font_size", 14)
	_prompt_subtitle.modulate = Color(0.8, 0.85, 0.9)
	vbox.add_child(_prompt_subtitle)

	_unveil_button = Button.new()
	_unveil_button.custom_minimum_size = Vector2(220, 48)
	_unveil_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	_unveil_button.text = "👀 I Am Ready (Unveil)"
	_unveil_button.pressed.connect(_on_unveil_pressed)
	vbox.add_child(_unveil_button)


## Triggers the curtain lowering transition to transfer turn to next player.
func start_handoff(next_player_slot: int, player_name: String, controller_type: int = MatchRulesConfig.ControllerType.KEYBOARD_MOUSE) -> void:
	target_player_slot = next_player_slot
	target_player_name = player_name
	current_state = CurtainState.LOWERING

	var glyph = PlayerInputRouter.get_action_glyph("confirm", controller_type)
	_prompt_title.text = "🔒 PASS TO %s!" % player_name.to_upper()
	_prompt_subtitle.text = "Turn handoff in progress.\nOnly %s should view the screen now!" % player_name
	_unveil_button.text = "👀 %s: Ready (%s)" % [player_name, glyph]

	visible = true
	modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		current_state = CurtainState.AWAITING_HANDOFF
		handoff_started.emit(target_player_slot, target_player_name)
		_unveil_button.grab_focus()
	)


func _on_unveil_pressed() -> void:
	if current_state != CurtainState.AWAITING_HANDOFF:
		return

	current_state = CurtainState.RAISING
	unveil_confirmed.emit(target_player_slot)

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		visible = false
		current_state = CurtainState.INACTIVE
		curtain_transition_finished.emit(false)
	)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or current_state != CurtainState.AWAITING_HANDOFF:
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.is_pressed()) or (event is InputEventKey and event.keycode == KEY_SPACE and event.is_pressed()):
		_on_unveil_pressed()
		get_viewport().set_input_as_handled()
