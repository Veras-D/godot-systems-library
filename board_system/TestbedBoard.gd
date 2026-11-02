extends Control

## Standalone Interactive Testbed for Universal Board & Lane System
## Demonstrates:
## - 2-sided opposing grid with configurable lane counts
## - Affinity assignment and dynamic validation
## - Primary occupant & attachment placement
## - Lane-vs-lane combat simulation with damage shake animations
## - Full event logging of signals

const BoardGrid = preload("BoardGrid.gd")
const BoardSlot = preload("BoardSlot.gd")
const SlotData = preload("SlotData.gd")

@onready var grid: BoardGrid = $Layout/MainArea/GridContainer/BoardGrid
@onready var lane_count_spin: SpinBox = $Layout/Sidebar/Scroll/VBox/ConfigSection/LaneCountSpin
@onready var log_label: RichTextLabel = $Layout/Sidebar/Scroll/VBox/LogSection/EventLog
@onready var selected_info_label: Label = $Layout/Sidebar/Scroll/VBox/SelectionSection/SelectedInfo

var selected_slot: BoardSlot = null
var affinity_cycle: Array[String] = ["Grass", "Sand", "Swamp", "Plains", "Universal", ""]


func _ready() -> void:
	grid.slot_selected.connect(_on_slot_selected)
	grid.slot_hover_changed.connect(_on_slot_hover_changed)
	grid.occupant_dropped_on_slot.connect(_on_occupant_dropped)

	lane_count_spin.value = grid.lanes_per_side
	lane_count_spin.value_changed.connect(_on_lane_count_changed)

	_apply_default_affinities()
	_log("Board & Lane Testbed initialized with %d lanes per side." % grid.lanes_per_side)


func _on_slot_selected(slot: BoardSlot) -> void:
	selected_slot = slot
	var s_data = slot.slot_data
	var info = "Selected: Side %d, Lane %d\nAffinity: %s\nState: %s\nOccupant: %s\nAttachment: %s" % [
		s_data.side,
		s_data.lane_index,
		s_data.affinity if not s_data.affinity.is_empty() else "(None)",
		SlotData.SlotState.keys()[s_data.get_state()],
		"Yes" if s_data.has_primary() else "No",
		"Yes" if s_data.has_attachment() else "No"
	]
	selected_info_label.text = info
	_log("Selected Slot [Side %d, Lane %d]" % [s_data.side, s_data.lane_index])


func _on_slot_hover_changed(slot: BoardSlot, is_hovered: bool) -> void:
	if is_hovered and slot.slot_data:
		# Optionally highlight opposing slot
		var opp = grid.get_opposing_slot(slot)
		if opp and slot.current_highlight == BoardSlot.HighlightMode.HOVERED:
			# Just visual feedback
			pass


func _on_occupant_dropped(slot: BoardSlot, data: Variant) -> void:
	_log("Occupant dropped on [Side %d, Lane %d]: %s" % [
		slot.slot_data.side, slot.slot_data.lane_index, str(data)
	])


func _on_lane_count_changed(val: float) -> void:
	grid.lanes_per_side = int(val)
	_apply_default_affinities()
	_log("Rebuilt grid with %d lanes per side." % int(val))


func _apply_default_affinities() -> void:
	var side0_aff: Array[String] = ["Grass", "Sand", "Swamp", "Plains", "Universal"]
	var side1_aff: Array[String] = ["Sand", "Plains", "Grass", "Swamp", "Universal"]
	grid.set_side_affinities(0, side0_aff)
	grid.set_side_affinities(1, side1_aff)


func _on_btn_cycle_affinity_pressed() -> void:
	if selected_slot == null or selected_slot.slot_data == null:
		_log("⚠️ Select a slot first!")
		return
	var cur_aff = selected_slot.slot_data.affinity
	var idx = affinity_cycle.find(cur_aff)
	var next_aff = affinity_cycle[(idx + 1) % affinity_cycle.size()]
	selected_slot.slot_data.affinity = next_aff
	selected_slot._update_views()
	_on_slot_selected(selected_slot)
	_log("Slot [Side %d, Lane %d] affinity set to: '%s'" % [
		selected_slot.slot_data.side, selected_slot.slot_data.lane_index, next_aff
	])


func _on_btn_summon_unit_pressed(unit_affinity: String) -> void:
	if selected_slot == null:
		_log("⚠️ Select a slot first to summon!")
		return

	var s_data = selected_slot.slot_data
	var validation = grid.validate_placement(unit_affinity, s_data.side, s_data.lane_index)
	if not validation.allowed:
		_log("❌ Summon rejected: %s" % validation.reason)
		selected_slot.set_highlight(BoardSlot.HighlightMode.INVALID_TARGET)
		return

	# Create a simple visual mock unit node
	var unit_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.32, 0.95)
	style.set_corner_radius_all(6)
	unit_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	unit_panel.add_child(vbox)

	var icon_lbl = Label.new()
	icon_lbl.text = "👾 %s Unit" % unit_affinity
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(icon_lbl)

	var stats_lbl = Label.new()
	stats_lbl.text = "ATK: 4 | DEF: 7"
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 10)
	stats_lbl.modulate = Color(0.4, 0.9, 0.4)
	vbox.add_child(stats_lbl)

	selected_slot.set_primary_view(unit_panel)
	selected_slot.play_summon_pulse()
	_on_slot_selected(selected_slot)
	_log("✔ Summoned %s Unit into [Side %d, Lane %d]" % [
		unit_affinity, s_data.side, s_data.lane_index
	])


func _on_btn_attach_structure_pressed() -> void:
	if selected_slot == null:
		_log("⚠️ Select a slot first!")
		return
	var s_data = selected_slot.slot_data
	var val = grid.validate_placement("", s_data.side, s_data.lane_index, true)
	if not val.allowed:
		_log("❌ Structure rejected: %s" % val.reason)
		return

	var struct_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.22, 0.12, 0.9)
	style.set_corner_radius_all(4)
	struct_panel.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	lbl.text = "🏰 Fort (+2 ATK)"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	struct_panel.add_child(lbl)

	selected_slot.set_attachment_view(struct_panel)
	selected_slot.slot_data.set_modifier("atk", 2)
	_on_slot_selected(selected_slot)
	_log("✔ Attached Structure to [Side %d, Lane %d]" % [s_data.side, s_data.lane_index])


func _on_btn_remove_occupants_pressed() -> void:
	if selected_slot:
		selected_slot.clear_occupants()
		_on_slot_selected(selected_slot)
		_log("Cleared occupants from [Side %d, Lane %d]" % [
			selected_slot.slot_data.side, selected_slot.slot_data.lane_index
		])


func _on_btn_shake_pressed() -> void:
	if selected_slot:
		selected_slot.play_damage_shake(12.0, 0.4)
		_log("Played damage shake on [Side %d, Lane %d]" % [
			selected_slot.slot_data.side, selected_slot.slot_data.lane_index
		])


func _on_btn_simulate_clash_pressed() -> void:
	if selected_slot == null:
		_log("⚠️ Select an attacker slot first!")
		return
	var opp_slot = grid.get_opposing_slot(selected_slot)
	if opp_slot == null:
		_log("No opposing slot found!")
		return

	_log("⚔️ Simulating clash: [Side %d, Lane %d] attacks [Side %d, Lane %d]!" % [
		selected_slot.slot_data.side, selected_slot.slot_data.lane_index,
		opp_slot.slot_data.side, opp_slot.slot_data.lane_index
	])
	selected_slot.play_damage_shake(6.0, 0.2)
	opp_slot.play_damage_shake(14.0, 0.45)


func _on_btn_highlight_test_pressed() -> void:
	# Test highlighting valid slots for Grass on Side 0
	grid.highlight_valid_slots("Grass", 0)
	_log("Highlighted valid slots for 'Grass' on Side 0 (Green=Valid, Red=Invalid)")


func _on_btn_clear_highlights_pressed() -> void:
	grid.clear_all_highlights()
	_log("Cleared all highlights.")


func _on_btn_clear_all_pressed() -> void:
	grid.clear_all_slots()
	if selected_slot:
		_on_slot_selected(selected_slot)
	_log("Cleared all slots on the board.")


func _on_btn_serialize_pressed() -> void:
	var state = grid.serialize_grid()
	_log("Serialized board state: %d slots captured." % state.size())
	print("--- SERIALIZED BOARD STATE ---")
	print(JSON.stringify(state, "  "))


func _log(msg: String) -> void:
	var time = Time.get_time_string_from_system()
	log_label.append_text("[%s] %s\n" % [time, msg])
