extends Control

## Standalone Interactive Testbed for Universal Save Vault
## Demonstrates:
## - Atomic file saving with SHA-256 checksums
## - Real-time slot management (list, save, load, delete)
## - Chaos testing: intentionally corrupting files to demonstrate automatic .bak recovery
## - Schema version migration testing (v1 to v2)

const SaveVault = preload("SaveVault.gd")

@onready var vault: SaveVault = $SaveVault
@onready var slot_option: OptionButton = $Layout/MainArea/SlotControls/SlotOption
@onready var slot_info_label: Label = $Layout/MainArea/SlotInfoPanel/SlotInfo
@onready var payload_text: TextEdit = $Layout/MainArea/PayloadEditor
@onready var log_label: RichTextLabel = $Layout/Sidebar/Scroll/VBox/LogSection/EventLog

var default_slot_ids: Array[String] = ["slot_1", "slot_2", "slot_3", "autosave", "quicksave"]


func _ready() -> void:
	vault.base_dir = "user://testbed_vault/"
	vault.current_version = 1

	vault.save_completed.connect(_on_save_completed)
	vault.load_completed.connect(_on_load_completed)
	vault.corruption_detected.connect(_on_corruption_detected)
	vault.migration_applied.connect(_on_migration_applied)

	# Register sample v1 -> v2 migration
	vault.register_migration(2, func(old_data: Dictionary) -> Dictionary:
		old_data["bonus_tokens"] = 500
		old_data["version_2_migrated"] = true
		return old_data
	)

	_populate_slot_options()
	_load_sample_payload()
	_refresh_slot_info()

	_log("Save Vault Testbed ready. Base path: %s" % vault.base_dir)


func _populate_slot_options() -> void:
	slot_option.clear()
	for s_id in default_slot_ids:
		var has_file = vault.slot_exists(s_id)
		var label = "%s %s" % ["💾" if has_file else "⚪", s_id]
		slot_option.add_item(label)


func _load_sample_payload() -> void:
	var sample = {
		"player_name": "Finn the Human",
		"level": 14,
		"coins": 3250,
		"inventory": ["Demon Sword", "Golden Harp", "Healing Potion"],
		"preferences": {
			"bgm_volume": 0.8,
			"sfx_volume": 1.0,
			"screen_shake": true
		}
	}
	payload_text.text = JSON.stringify(sample, "  ")


func _get_current_slot_id() -> String:
	var idx = slot_option.selected
	if idx >= 0 and idx < default_slot_ids.size():
		return default_slot_ids[idx]
	return "slot_1"


func _refresh_slot_info() -> void:
	var s_id = _get_current_slot_id()
	var meta = vault.get_slot_meta(s_id)
	if meta.is_empty():
		slot_info_label.text = "Slot '%s': [EMPTY / NOT FOUND]" % s_id
	else:
		slot_info_label.text = "Slot '%s' | Version: %d | Saved: %s" % [
			s_id, meta.get("version", 1), meta.get("timestamp", "N/A")
		]


# --- BUTTON ACTIONS ---

func _on_slot_option_item_selected(_index: int) -> void:
	_refresh_slot_info()


func _on_btn_save_pressed() -> void:
	var s_id = _get_current_slot_id()
	var json = JSON.new()
	if json.parse(payload_text.text) != OK or not json.data is Dictionary:
		_log("❌ Error: Invalid JSON in editor payload!")
		return

	var data: Dictionary = json.data
	var preview_meta = {
		"player_name": data.get("player_name", "Unknown"),
		"level": data.get("level", 1)
	}

	var ok = vault.save_slot(s_id, data, preview_meta)
	if ok:
		_log("✔ Successfully saved slot '%s' (Atomic write + SHA-256)" % s_id)
	else:
		_log("❌ Failed to save slot '%s'" % s_id)
	_populate_slot_options()
	_refresh_slot_info()


func _on_btn_load_pressed() -> void:
	var s_id = _get_current_slot_id()
	var data = vault.load_slot(s_id)
	if data.is_empty():
		_log("⚠️ Slot '%s' is empty or could not be loaded." % s_id)
	else:
		payload_text.text = JSON.stringify(data, "  ")
		_log("✔ Successfully loaded slot '%s'" % s_id)
	_refresh_slot_info()


func _on_btn_delete_pressed() -> void:
	var s_id = _get_current_slot_id()
	if vault.delete_slot(s_id):
		_log("🗑️ Deleted slot '%s' and its backup files." % s_id)
	else:
		_log("Failed to delete slot '%s'" % s_id)
	_populate_slot_options()
	_refresh_slot_info()


func _on_btn_corrupt_primary_pressed() -> void:
	var s_id = _get_current_slot_id()
	var path = vault._get_slot_path(s_id)
	if not FileAccess.file_exists(path):
		_log("⚠️ Save the slot at least twice first so a valid .bak exists before corrupting!")
		return

	# Corrupt the primary save file with bad checksum
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"checksum": "CORRUPTED_TAMPER_HASH", "data": "{\"corrupted\": true}"}')
	file.close()

	_log("💥 Corrupted primary file '%s'! Now click 'Load Active Slot' to test backup recovery." % path)


func _on_btn_test_migration_pressed() -> void:
	var s_id = _get_current_slot_id()
	_log("Upgrading vault to schema Version 2...")
	vault.current_version = 2
	var data = vault.load_slot(s_id)
	if not data.is_empty():
		payload_text.text = JSON.stringify(data, "  ")
		_log("✔ Successfully migrated slot '%s' to Version 2! (Added bonus_tokens: 500)" % s_id)
	_refresh_slot_info()


func _on_btn_list_slots_pressed() -> void:
	var slots = vault.list_slots()
	_log("--- EXISTING SLOTS (%d FOUND) ---" % slots.size())
	for s in slots:
		_log("• %s (Version %d) - %s" % [s["slot_id"], s["version"], s["timestamp"]])


# --- VAULT SIGNAL HANDLERS ---

func _on_save_completed(slot_id: String, success: bool) -> void:
	_log("Signal: save_completed(slot='%s', success=%s)" % [slot_id, str(success)])


func _on_load_completed(slot_id: String, _data: Dictionary, was_backup: bool) -> void:
	_log("Signal: load_completed(slot='%s', was_backup=%s)" % [slot_id, str(was_backup)])


func _on_corruption_detected(slot_id: String, details: String) -> void:
	_log("⚠️ Signal: corruption_detected(slot='%s'): %s" % [slot_id, details])


func _on_migration_applied(slot_id: String, from_v: int, to_v: int) -> void:
	_log("🔄 Signal: migration_applied(slot='%s', from_v=%d, to_v=%d)" % [slot_id, from_v, to_v])


func _log(msg: String) -> void:
	var time = Time.get_time_string_from_system()
	log_label.append_text("[%s] %s\n" % [time, msg])
