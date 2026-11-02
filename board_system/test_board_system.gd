extends SceneTree

const SlotData = preload("SlotData.gd")
const BoardSlot = preload("BoardSlot.gd")
const BoardGrid = preload("BoardGrid.gd")
const BoardGridScene = preload("BoardGrid.tscn")

func _init() -> void:
	print("==> Running Board & Lane System Tests...")

	# 1. Test SlotData Initialization & Coordinate
	var s_data = SlotData.create(0, 2, "Grass")
	assert(s_data.side == 0, "SlotData side should be 0")
	assert(s_data.lane_index == 2, "SlotData lane_index should be 2")
	assert(s_data.affinity == "Grass", "SlotData affinity should be Grass")
	assert(s_data.get_coordinate() == Vector2i(0, 2), "Coordinate should be Vector2i(0, 2)")
	assert(s_data.get_state() == SlotData.SlotState.EMPTY, "Default state should be EMPTY")
	assert(s_data.is_empty(), "Slot should report is_empty() == true")
	print("SlotData initialization & coordinates verified.")

	# 2. Test SlotData Occupants & States
	var dummy_unit = {"id": "unit_01", "name": "Forest Wolf"}
	var dummy_building = {"id": "bld_01", "name": "Watchtower"}

	s_data.primary_occupant = dummy_unit
	assert(not s_data.is_empty(), "Occupied slot should not be empty")
	assert(s_data.has_primary(), "Should have primary occupant")
	assert(s_data.get_state() == SlotData.SlotState.OCCUPIED, "State should be OCCUPIED")

	s_data.attached_occupant = dummy_building
	assert(s_data.has_attachment(), "Should have attachment occupant")

	# Test clear
	s_data.clear()
	assert(s_data.is_empty(), "Slot should be empty after clear()")
	assert(not s_data.has_primary(), "Primary occupant should be null after clear")
	assert(not s_data.has_attachment(), "Attachment should be null after clear")
	print("SlotData occupancy & clearing verified.")

	# 3. Test Affinity Validation Rules
	var grass_slot = SlotData.create(0, 0, "Grass")
	assert(grass_slot.can_accept_affinity("Grass"), "Matching affinity should be accepted")
	assert(not grass_slot.can_accept_affinity("Fire"), "Mismatched affinity should be rejected")
	assert(grass_slot.can_accept_affinity("Universal"), "Universal occupant should be accepted on Grass")

	var universal_slot = SlotData.create(0, 1, "Universal")
	assert(universal_slot.can_accept_affinity("Grass"), "Grass occupant accepted on Universal slot")
	assert(universal_slot.can_accept_affinity("Water"), "Water occupant accepted on Universal slot")

	var blank_slot = SlotData.create(0, 2, "")
	assert(blank_slot.can_accept_affinity("Darkness"), "Empty affinity slot accepts any occupant")

	grass_slot.is_locked = true
	assert(not grass_slot.can_accept_affinity("Grass"), "Locked slot must reject all occupants")
	print("Affinity validation rules verified.")

	# 4. Test Modifiers
	var mod_slot = SlotData.create(0, 0, "Grass")
	mod_slot.set_modifier("atk_aura", 3)
	mod_slot.set_modifier("armor", 1)
	assert(mod_slot.get_modifier("atk_aura") == 3, "Modifier atk_aura should be 3")
	assert(mod_slot.get_modifier("armor") == 1, "Modifier armor should be 1")
	assert(mod_slot.get_modifier("speed", 0) == 0, "Fallback default modifier should return 0")

	mod_slot.remove_modifier("armor")
	assert(mod_slot.get_modifier("armor", null) == null, "Removed modifier should be absent")
	print("Slot modifiers verified.")

	# 5. Test BoardGrid Scene Instantiation & Sizing
	var grid_inst: BoardGrid = BoardGridScene.instantiate()
	self.root.add_child(grid_inst)
	grid_inst.sides_count = 2
	grid_inst.lanes_per_side = 4
	grid_inst.rebuild_grid()

	var all_slots = grid_inst.get_all_slots()
	assert(all_slots.size() == 8, "2 sides * 4 lanes should yield 8 total slots")

	var side0_slots = grid_inst.get_all_slots(0)
	assert(side0_slots.size() == 4, "Side 0 should contain 4 slots")

	var side1_slots = grid_inst.get_all_slots(1)
	assert(side1_slots.size() == 4, "Side 1 should contain 4 slots")
	print("BoardGrid sizing & child construction verified.")

	# 6. Test Opposing Slot Resolution (Side 0 vs Side 1)
	var s0_l2 = grid_inst.get_slot(0, 2)
	assert(s0_l2 != null, "Slot (0, 2) must exist")
	assert(s0_l2.slot_data.side == 0 and s0_l2.slot_data.lane_index == 2, "Slot coordinates must match")

	var opp_slot = grid_inst.get_opposing_slot(s0_l2)
	assert(opp_slot != null, "Opposing slot must exist for (0, 2)")
	assert(opp_slot.slot_data.side == 1 and opp_slot.slot_data.lane_index == 2, "Opposing slot must be (1, 2)")

	var s1_l0 = grid_inst.get_slot(1, 0)
	var opp_s1_l0 = grid_inst.get_opposing_slot(s1_l0)
	assert(opp_s1_l0.slot_data.side == 0 and opp_s1_l0.slot_data.lane_index == 0, "Opposing slot for (1, 0) must be (0, 0)")
	print("Opposing lane lookup verified.")

	# 7. Test Affinity Assignment & Queries
	grid_inst.set_slot_affinity(0, 0, "Sand")
	grid_inst.set_slot_affinity(0, 1, "Swamp")
	grid_inst.set_slot_affinity(0, 2, "Sand")
	grid_inst.set_slot_affinity(0, 3, "Plains")

	var sand_slots = grid_inst.get_slots_by_affinity("Sand", 0)
	assert(sand_slots.size() == 2, "Side 0 should have 2 Sand slots")
	assert(sand_slots[0].slot_data.lane_index == 0, "First Sand slot at lane 0")
	assert(sand_slots[1].slot_data.lane_index == 2, "Second Sand slot at lane 2")
	print("Affinity assignment & filtering verified.")

	# 8. Test Grid Placement Validation
	var val_valid = grid_inst.validate_placement("Sand", 0, 0)
	assert(val_valid.allowed == true, "Sand unit on Sand slot should be allowed")

	var val_mismatch = grid_inst.validate_placement("Grass", 0, 0)
	assert(val_mismatch.allowed == false, "Grass unit on Sand slot should be rejected")

	var val_universal = grid_inst.validate_placement("Universal", 0, 0)
	assert(val_universal.allowed == true, "Universal unit on Sand slot should be allowed")

	# Place unit and test re-placement rejection
	s0_l2.slot_data.primary_occupant = dummy_unit
	var val_occupied = grid_inst.validate_placement("Sand", 0, 2)
	assert(val_occupied.allowed == false, "Placement in occupied slot should be rejected")

	# Structure placement on occupied unit slot should be allowed
	var val_struct = grid_inst.validate_placement("", 0, 2, true)
	assert(val_struct.allowed == true, "Structure should be allowed on unit slot with no existing structure")
	print("Grid placement validation rules verified.")

	# 9. Test Serialization
	var serialized = grid_inst.serialize_grid()
	assert(serialized.size() == 8, "Serialized data should contain 8 slot states")
	assert(serialized[0].has("side"), "Serialized dictionary must contain 'side'")
	assert(serialized[0].has("lane_index"), "Serialized dictionary must contain 'lane_index'")
	assert(serialized[0].has("affinity"), "Serialized dictionary must contain 'affinity'")
	print("BoardGrid serialization verified.")

	# 10. Test Animation Signals & Custom Validator
	var event_box = {"shaken": false}
	grid_inst.slot_damage_shaken.connect(func(_slot, _intensity): event_box["shaken"] = true)
	s0_l2.play_damage_shake(10.0, 0.1)
	assert(event_box["shaken"] == true, "slot_damage_shaken signal must bubble up to BoardGrid")

	grid_inst.custom_affinity_validator = func(card_aff: String, slot_aff: String) -> bool:
		return card_aff == "Wildcard" or card_aff == slot_aff
	var val_custom = grid_inst.validate_placement("Wildcard", 0, 0)
	assert(val_custom.allowed == true, "Custom affinity validator should accept Wildcard")
	print("Board animation signals & custom validator verified.")

	# 11. Test Drag-and-Drop Drop Rules (N2 & N3)
	var test_slot = grid_inst.get_slot(0, 0) # Slot (0, 0) affinity is Sand
	assert(not test_slot._can_drop_data(Vector2.ZERO, null), "Drop check must reject null data")
	assert(not test_slot._can_drop_data(Vector2.ZERO, {"type": "unknown"}), "Drop check must reject unknown payload")
	assert(not test_slot._can_drop_data(Vector2.ZERO, {"type": "card", "card_data": null}), "Drop check must reject malformed card payload with null card_data")
	assert(not test_slot._can_drop_data(Vector2.ZERO, {"type": "card", "card_data": "invalid"}), "Drop check must reject card payload without affinity")

	# Affinity mismatch via drag-drop
	var grass_card = {"affinity": "Grass"}
	assert(not test_slot._can_drop_data(Vector2.ZERO, {"type": "card", "card_data": grass_card}), "Drag-drop must reject Grass card on Sand slot")

	# Affinity match via drag-drop
	var sand_card = {"affinity": "Sand"}
	assert(test_slot._can_drop_data(Vector2.ZERO, {"type": "card", "card_data": sand_card}), "Drag-drop must accept Sand card on Sand slot")

	# Custom validator via drag-drop (N3)
	var wildcard_card = {"affinity": "Wildcard"}
	assert(test_slot._can_drop_data(Vector2.ZERO, {"type": "card", "card_data": wildcard_card}), "Drag-drop must respect custom affinity validator for Wildcard")
	print("Drag-and-drop validation & custom validator (N2/N3) verified.")

	grid_inst.free()
	print("==================================================")
	print("ALL BOARD & LANE SYSTEM UNIT TESTS PASSED (100%)")
	print("==================================================")
	quit(0)
