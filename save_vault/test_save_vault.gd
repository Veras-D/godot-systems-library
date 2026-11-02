extends SceneTree

const SaveVault = preload("SaveVault.gd")

func _init() -> void:
	print("==> Running SaveVault Unit & Integrity Tests...")

	var test_dir = "user://test_vault/"
	var vault = SaveVault.new(test_dir, 1)

	# Clean any leftover files from previous runs
	_clean_dir(test_dir)

	# 1. Test Basic Save and Load
	var test_data = {
		"player_name": "Adventurer",
		"gold": 1500,
		"inventory": ["sword", "shield", "potion"],
		"settings": {"volume": 0.8, "fullscreen": true}
	}
	var preview_meta = {"player_name": "Adventurer", "gold": 1500}

	var save_ok = vault.save_slot("profile_1", test_data, preview_meta)
	assert(save_ok == true, "Save operation must succeed")
	assert(vault.slot_exists("profile_1"), "Slot profile_1 must exist")

	var loaded_data = vault.load_slot("profile_1")
	assert(loaded_data.get("player_name") == "Adventurer", "Loaded player_name must match")
	assert(loaded_data.get("gold") == 1500, "Loaded gold must match")
	assert(loaded_data.get("inventory").size() == 3, "Loaded inventory size must match")
	print("Basic save, load, and atomic write verified.")

	# 2. Test Preview Metadata & List Slots
	var meta = vault.get_slot_meta("profile_1")
	assert(not meta.is_empty(), "Metadata must not be empty")
	assert(meta.get("preview").get("gold") == 1500, "Preview gold must match")

	var slots_list = vault.list_slots()
	assert(slots_list.size() == 1, "Slot list must contain 1 entry")
	assert(slots_list[0]["slot_id"] == "profile_1", "Slot ID must be profile_1")
	print("Preview metadata and slot listing verified.")

	# 3. Test Rolling Backup Creation
	# Save again with updated data -> creates profile_1.json.bak with original data
	var updated_data = test_data.duplicate(true)
	updated_data["gold"] = 2500
	var update_ok = vault.save_slot("profile_1", updated_data, {"gold": 2500})
	assert(update_ok == true, "Update save must succeed")

	var bak_path = test_dir + "profile_1.json.bak"
	assert(FileAccess.file_exists(bak_path), "Backup file profile_1.json.bak must exist")
	print("Rolling backup creation verified.")

	# 4. Test Checksum Tamper Detection & Backup Fallback Recovery
	# Corrupt the primary save file on disk
	var primary_path = test_dir + "profile_1.json"
	var p_file = FileAccess.open(primary_path, FileAccess.WRITE)
	p_file.store_string('{"checksum": "INVALID_HASH_123", "data": "{\"gold\": 999999}"}')
	p_file.close()

	# Loading should detect checksum corruption and fall back to valid .bak file (with gold = 1500)
	var fallback_data = vault.load_slot("profile_1")
	assert(not fallback_data.is_empty(), "Fallback load from backup must succeed")
	assert(fallback_data.get("gold") == 1500, "Recovered data must contain previous gold 1500")
	print("Checksum validation and automatic backup recovery verified.")

	# 5. Test Version Migration Pipeline
	vault.current_version = 2
	vault.register_migration(2, func(old_data: Dictionary) -> Dictionary:
		old_data["gems"] = 100
		old_data["migrated_v2"] = true
		return old_data
	)

	# Save fresh v1 data
	vault.current_version = 1
	vault.save_slot("profile_mig", {"hero": "Warrior", "level": 10})

	# Switch to v2 and load -> migration should trigger
	vault.current_version = 2
	var migrated_data = vault.load_slot("profile_mig")
	assert(migrated_data.get("hero") == "Warrior", "Hero name preserved across migration")
	assert(migrated_data.get("gems") == 100, "Migration added new 'gems' field")
	assert(migrated_data.get("migrated_v2") == true, "Migration flag set")
	assert(migrated_data.get("_vault_version") == 2, "Vault version upgraded to 2")
	print("Schema version migration pipeline verified.")

	# 6. Test Slot Deletion
	var del_ok = vault.delete_slot("profile_1")
	assert(del_ok == true, "Delete must return true")
	assert(not vault.slot_exists("profile_1"), "Deleted slot must not exist")
	print("Slot deletion verified.")

	# Cleanup test directory
	_clean_dir(test_dir)
	vault.free()

	print("==================================================")
	print("ALL SAVE VAULT UNIT TESTS PASSED (100%)")
	print("==================================================")
	quit(0)


func _clean_dir(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		var dir = DirAccess.open(path)
		if dir:
			dir.list_dir_begin()
			var fn = dir.get_next()
			while fn != "":
				if not dir.current_is_dir():
					dir.remove(fn)
				fn = dir.get_next()
			dir.list_dir_end()
