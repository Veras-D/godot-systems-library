class_name SaveVault
extends Node

## Universal JSON Save Vault & State Serializer.
## Features:
## - Atomic file writes (writes to .tmp then atomic-renames to target)
## - SHA-256 Checksum validation for tamper and corruption detection
## - Rolling .bak backup fallback and automatic corruption recovery
## - Version tracking and automated data migration pipelines
## - Multi-slot management (list, query metadata, delete)

signal save_completed(slot_id: String, success: bool)
signal load_completed(slot_id: String, data: Dictionary, was_backup: bool)
signal corruption_detected(slot_id: String, details: String)
signal migration_applied(slot_id: String, from_version: int, to_version: int)

@export var base_dir: String = "user://saves/":
	set(val):
		base_dir = val if val.ends_with("/") else val + "/"

@export var current_version: int = 1
@export var enable_checksum: bool = true
@export var enable_backups: bool = true
@export var enforce_schema: bool = false

## Optional schema validator callback: func(data: Dictionary) -> Dictionary ({"valid": bool, "error": String})
var schema_validator: Callable = Callable()

# Registered migration callables: key = target_version (int), value = Callable(old_data: Dictionary) -> Dictionary
var _migrations: Dictionary = {}


func _init(p_base_dir: String = "user://saves/", p_version: int = 1) -> void:
	self.base_dir = p_base_dir
	self.current_version = p_version


## Registers a migration handler to upgrade data from (target_version - 1) to target_version
func register_migration(target_version: int, migration_callable: Callable) -> void:
	_migrations[target_version] = migration_callable


## Validates a save dictionary against Universal Schema v1 recommendations
static func validate_v1_schema(data: Dictionary) -> Dictionary:
	var valid_keys = ["game_data", "player_data", "system_states", "player", "inventory", "campaign", "settings", "meta"]
	for k in valid_keys:
		if data.has(k):
			return {"valid": true, "error": ""}
	return {"valid": false, "error": "Save payload must contain at least one state container ('player', 'inventory', 'campaign', 'settings', 'game_data', 'player_data', or 'system_states')"}


## Saves data into a specified slot atomically
func save_slot(slot_id: String, data: Dictionary, preview_meta: Dictionary = {}) -> bool:
	# Schema validation check (if enforced)
	if enforce_schema:
		var check_res = schema_validator.call(data) if schema_validator.is_valid() else validate_v1_schema(data)
		if not check_res.get("valid", true):
			var err_msg = check_res.get("error", "Schema validation failed")
			push_error("SaveVault: Schema validation failed for slot '%s': %s" % [slot_id, err_msg])
			save_completed.emit(slot_id, false)
			return false

	_ensure_directory()

	var save_path = _get_slot_path(slot_id)
	var temp_path = save_path + ".tmp"
	var backup_path = save_path + ".bak"

	# 1. Prepare payload with metadata
	var payload = data.duplicate(true)
	payload["_vault_version"] = current_version
	payload["_vault_timestamp"] = Time.get_datetime_string_from_system()
	if not preview_meta.is_empty():
		payload["_vault_preview"] = preview_meta

	var payload_json = JSON.stringify(payload, "\t")

	# 2. Build wrapper with checksum
	var wrapper = {
		"version": current_version,
		"timestamp": payload["_vault_timestamp"],
		"preview": preview_meta,
		"data": payload_json
	}
	if enable_checksum:
		wrapper["checksum"] = payload_json.sha256_text()

	var wrapper_json = JSON.stringify(wrapper, "\t")

	# 3. ATOMIC WRITE STEP 1: Write to .tmp file
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveVault: Failed to open temp file for writing: %s (Error: %d)" % [
			temp_path, FileAccess.get_open_error()
		])
		save_completed.emit(slot_id, false)
		return false

	file.store_string(wrapper_json)
	file.flush()
	file.close()

	# 4. ATOMIC WRITE STEP 2: Rotate existing save to .bak
	var dir = DirAccess.open(base_dir)
	if dir == null:
		push_error("SaveVault: Cannot access directory: %s" % base_dir)
		save_completed.emit(slot_id, false)
		return false

	var slot_file_name = _get_slot_filename(slot_id)
	var bak_file_name = slot_file_name + ".bak"
	var tmp_file_name = slot_file_name + ".tmp"

	if enable_backups and dir.file_exists(slot_file_name):
		if dir.file_exists(bak_file_name):
			dir.remove(bak_file_name)
		dir.rename(slot_file_name, bak_file_name)

	# 5. ATOMIC WRITE STEP 3: Rename .tmp to main slot file
	var rename_err = dir.rename(tmp_file_name, slot_file_name)
	if rename_err != OK:
		push_error("SaveVault: Failed to atomic-swap temp file to save file. Error: %d" % rename_err)
		# Attempt restore from backup if rename failed
		if dir.file_exists(bak_file_name):
			dir.rename(bak_file_name, slot_file_name)
		save_completed.emit(slot_id, false)
		return false

	save_completed.emit(slot_id, true)
	return true


## Loads data from slot with automatic checksum verification and backup fallback
func load_slot(slot_id: String) -> Dictionary:
	_ensure_directory()

	var save_path = _get_slot_path(slot_id)
	var backup_path = save_path + ".bak"

	# 1. Try reading primary save
	if FileAccess.file_exists(save_path):
		var primary_res = _try_read_and_verify(save_path, slot_id)
		if primary_res.success:
			var final_data = _apply_migrations_if_needed(slot_id, primary_res.data)
			load_completed.emit(slot_id, final_data, false)
			return final_data
		else:
			corruption_detected.emit(slot_id, "Primary save corrupted: %s" % primary_res.error)

	# 2. Primary failed or missing; try backup fallback
	if enable_backups and FileAccess.file_exists(backup_path):
		push_warning("SaveVault: Attempting recovery from backup file for slot '%s'..." % slot_id)
		var backup_res = _try_read_and_verify(backup_path, slot_id)
		if backup_res.success:
			push_warning("SaveVault: Successfully recovered slot '%s' from backup!" % slot_id)
			var final_data = _apply_migrations_if_needed(slot_id, backup_res.data)
			# Restore primary file from valid backup
			_restore_primary_from_backup(slot_id)
			load_completed.emit(slot_id, final_data, true)
			return final_data
		else:
			corruption_detected.emit(slot_id, "Backup also corrupted: %s" % backup_res.error)

	return {}


## Alias for save_slot (conforming to Universal SaveVault profile nomenclature)
func save_profile(profile_id: String, data: Dictionary, preview_meta: Dictionary = {}) -> bool:
	return save_slot(profile_id, data, preview_meta)


## Alias for load_slot (conforming to Universal SaveVault profile nomenclature)
func load_profile(profile_id: String) -> Dictionary:
	return load_slot(profile_id)


## Returns preview metadata for a slot without loading the full payload
func get_slot_meta(slot_id: String) -> Dictionary:
	var save_path = _get_slot_path(slot_id)
	if not FileAccess.file_exists(save_path):
		var backup_path = save_path + ".bak"
		if FileAccess.file_exists(backup_path):
			save_path = backup_path
		else:
			return {}

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		return {}

	var wrapper = json.data
	return {
		"slot_id": slot_id,
		"version": wrapper.get("version", 1),
		"timestamp": wrapper.get("timestamp", ""),
		"preview": wrapper.get("preview", {})
	}


## Lists all existing save slots with metadata
func list_slots() -> Array[Dictionary]:
	_ensure_directory()
	var results: Array[Dictionary] = []

	var dir = DirAccess.open(base_dir)
	if dir == null:
		return results

	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var slot_id = fname.get_basename()
			var meta = get_slot_meta(slot_id)
			if not meta.is_empty():
				results.append(meta)
		fname = dir.get_next()
	dir.list_dir_end()

	return results


## Checks if a slot exists (primary or backup)
func slot_exists(slot_id: String) -> bool:
	var path = _get_slot_path(slot_id)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## Deletes a slot including temp and backup files
func delete_slot(slot_id: String) -> bool:
	_ensure_directory()
	var dir = DirAccess.open(base_dir)
	if dir == null:
		return false

	var base_name = _get_slot_filename(slot_id)
	for ext in ["", ".tmp", ".bak"]:
		var target = base_name + ext
		if dir.file_exists(target):
			dir.remove(target)
	return true


# --- INTERNAL HELPERS ---

func _try_read_and_verify(file_path: String, _slot_id: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open file for reading"}

	var content = file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		return {"success": false, "error": "File is empty (0 bytes)"}

	var json = JSON.new()
	var parse_err = json.parse(content)
	if parse_err != OK:
		return {"success": false, "error": "Invalid wrapper JSON: %s (Line: %d)" % [json.get_error_message(), json.get_error_line()]}

	var wrapper = json.data
	if not wrapper is Dictionary or not wrapper.has("data"):
		return {"success": false, "error": "Wrapper missing 'data' field"}

	# Verify Checksum
	if enable_checksum and wrapper.has("checksum"):
		var stored_hash: String = wrapper["checksum"]
		var actual_hash: String = String(wrapper["data"]).sha256_text()
		if stored_hash != actual_hash:
			return {"success": false, "error": "Checksum mismatch! Stored: %s != Actual: %s" % [stored_hash, actual_hash]}

	# Parse inner payload
	var inner_json = JSON.new()
	var inner_err = inner_json.parse(wrapper["data"])
	if inner_err != OK or not inner_json.data is Dictionary:
		return {"success": false, "error": "Inner payload JSON parse failed"}

	return {"success": true, "data": inner_json.data}


func _apply_migrations_if_needed(slot_id: String, data: Dictionary) -> Dictionary:
	var ver: int = int(data.get("_vault_version", 1))
	var current_data = data

	while ver < current_version:
		var next_ver: int = ver + 1
		if _migrations.has(next_ver):
			var mig_func: Callable = _migrations[next_ver]
			current_data = mig_func.call(current_data)
			migration_applied.emit(slot_id, ver, next_ver)
		ver = next_ver

	current_data["_vault_version"] = current_version
	return current_data


func _restore_primary_from_backup(slot_id: String) -> void:
	var primary_path = _get_slot_path(slot_id)
	var backup_path = primary_path + ".bak"
	if FileAccess.file_exists(backup_path):
		DirAccess.copy_absolute(backup_path, primary_path)


func _ensure_directory() -> void:
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)


func _get_slot_path(slot_id: String) -> String:
	return base_dir + _get_slot_filename(slot_id)


func _get_slot_filename(slot_id: String) -> String:
	var clean_id = slot_id.replace("/", "_").replace("\\", "_")
	return clean_id + ".json"
