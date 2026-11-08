extends SceneTree

## Automated Headless Unit Test Suite for SYS-13 (localization_engine)

const LocalizationParser = preload("LocalizationParser.gd")
const LocalizationManager = preload("LocalizationManager.gd")


func _init() -> void:
	print("\n========================================================")
	print("  RUNNING LOCALIZATION ENGINE SYSTEM TESTS (SYS-13)")
	print("========================================================\n")

	_test_xml_parser_and_entities()
	_test_locale_registration()
	_test_translations_and_switching()
	_test_fallback_translations()

	print("\n==> ALL Localization Engine Tests PASSED SUCCESSFULLY!")
	quit(0)


func _test_xml_parser_and_entities() -> void:
	print("Test 1: XML Entries Parser & Entity Unescaping...")
	var sample_xml = """<entries>
<entry name="!!CARD_NAME_PIG">The Pig</entry>
<entry name="!!CARD_DESC_PIG">Floop: Deal &lt;val1&gt; damage to opponent&apos;s creature.</entry>
<entry name="!!MENU_PLAY">&quot;Play Game&quot; &amp; Start</entry>
</entries>"""

	var parsed = LocalizationParser.parse_xml_entries(sample_xml)
	assert(parsed.size() == 3, "Expected 3 parsed entries, got %d" % parsed.size())
	assert(parsed["!!CARD_NAME_PIG"] == "The Pig", "Direct string mismatch")
	assert(parsed["!!CARD_DESC_PIG"] == "Floop: Deal <val1> damage to opponent's creature.", "Entities unescaping mismatch")
	assert(parsed["!!MENU_PLAY"] == "\"Play Game\" & Start", "Quotes and ampersand unescaping mismatch")
	print("  ✔ XML Parser and Entity unescaping passed")


func _test_locale_registration() -> void:
	print("Test 2: Locale Registration & Metadata...")
	var mgr = LocalizationManager.new()

	mgr.register_locale("en", "English", "English")
	mgr.register_locale("es", "Spanish", "Español")
	mgr.register_locale("fr", "French", "Français")

	var available = mgr.get_available_locales()
	assert(available.size() == 3, "Expected 3 registered locales, got %d" % available.size())
	assert(mgr.get_locale_display_name("es") == "Spanish", "Display name mismatch")

	mgr.free()
	print("  ✔ Locale registration passed")


func _test_translations_and_switching() -> void:
	print("Test 3: TranslationServer Integration & Dynamic Switching...")
	var mgr = LocalizationManager.new()

	mgr.register_locale("en", "English")
	mgr.register_locale("es", "Spanish")
	mgr.register_locale("fr", "French")

	# Add messages
	mgr.add_messages("en", {
		"HELLO": "Hello",
		"START_MATCH": "Start Match"
	})
	mgr.add_messages("es", {
		"HELLO": "Hola",
		"START_MATCH": "Comenzar Batalla"
	})
	mgr.add_messages("fr", {
		"HELLO": "Bonjour",
		"START_MATCH": "Commencer le Combat"
	})

	# Switch to English
	mgr.set_locale("en")
	assert(tr("HELLO") == "Hello", "English translation mismatch")
	assert(tr("START_MATCH") == "Start Match", "English START_MATCH mismatch")

	# Switch to Spanish dynamically
	var locale_fired = [false]
	mgr.locale_changed.connect(func(code, _name):
		if code == "es":
			locale_fired[0] = true
	)

	mgr.set_locale("es")
	assert(locale_fired[0] == true, "locale_changed signal should fire")
	assert(tr("HELLO") == "Hola", "Spanish translation mismatch after switch")
	assert(tr("START_MATCH") == "Comenzar Batalla", "Spanish START_MATCH mismatch")

	# Switch to French
	mgr.set_locale("fr")
	assert(tr("HELLO") == "Bonjour", "French translation mismatch")

	# Reset back to en
	mgr.set_locale("en")
	mgr.free()
	print("  ✔ TranslationServer and dynamic switching passed")


func _test_fallback_translations() -> void:
	print("Test 4: Fallback Translation Behavior...")
	var mgr = LocalizationManager.new()
	mgr.register_locale("en", "English")

	var fallback_result = mgr.translate_key("NON_EXISTENT_KEY", "Default Text")
	assert(fallback_result == "Default Text", "Fallback text was not returned for missing key")

	mgr.free()
	print("  ✔ Fallback translation passed")
