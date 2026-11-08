# LocalizationManager.gd
# Universal Runtime Localization Manager for Godot 4.x.
# Integrates directly with Godot's native TranslationServer and provides dynamic runtime switching.
class_name LocalizationManager
extends Node

signal locale_changed(locale_code: String, display_name: String)

## Registered locales: code -> Dictionary { "display_name": String, "native_name": String, "translation": Translation }
var registered_locales: Dictionary = {}
var current_locale: String = "en"
var fallback_locale: String = "en"


func _ready() -> void:
	# Default base English locale registration
	if not registered_locales.has("en"):
		register_locale("en", "English", "English")


## Registers a supported locale in the system.
func register_locale(code: String, display_name: String, native_name: String = "") -> void:
	if native_name.is_empty():
		native_name = display_name

	var t_obj: Translation = null
	if registered_locales.has(code):
		t_obj = registered_locales[code].get("translation")
	else:
		t_obj = Translation.new()
		t_obj.locale = code
		TranslationServer.add_translation(t_obj)

	registered_locales[code] = {
		"code": code,
		"display_name": display_name,
		"native_name": native_name,
		"translation": t_obj
	}


## Adds a dictionary of key -> translated_text messages to a registered locale.
func add_messages(code: String, messages: Dictionary) -> void:
	if not registered_locales.has(code):
		register_locale(code, code.to_upper())

	var t_obj: Translation = registered_locales[code]["translation"]
	for k in messages.keys():
		t_obj.add_message(str(k), str(messages[k]))


## Changes the active locale globally across all UI and nodes via TranslationServer.
func set_locale(code: String) -> bool:
	if not registered_locales.has(code):
		push_warning("LocalizationManager: Locale '%s' is not registered." % code)
		return false

	current_locale = code
	TranslationServer.set_locale(code)
	var d_name = registered_locales[code]["display_name"]
	locale_changed.emit(code, d_name)
	return true


func get_current_locale() -> String:
	return current_locale


func get_locale_display_name(code: String) -> String:
	if registered_locales.has(code):
		return registered_locales[code]["display_name"]
	return code


func get_available_locales() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for c in registered_locales.keys():
		list.append({
			"code": c,
			"display_name": registered_locales[c]["display_name"],
			"native_name": registered_locales[c]["native_name"]
		})
	return list


## Translates a key using Godot's TranslationServer with an optional fallback.
func translate_key(key: String, fallback_text: String = "") -> String:
	var result = tr(key)
	if result == key and not fallback_text.is_empty():
		return fallback_text
	return result
