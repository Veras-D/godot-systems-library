# TestbedLocalization.gd
# Interactive testbed for SYS-13 (localization_engine).
extends Control

const LocalizationManagerClass = preload("LocalizationManager.gd")
const LocalizationParserClass = preload("LocalizationParser.gd")

@onready var manager: LocalizationManager = $LocalizationManager
@onready var lang_option: OptionButton = %LangOption
@onready var test_key_edit: LineEdit = %TestKeyEdit
@onready var translate_btn: Button = %TranslateBtn
@onready var result_label: Label = %ResultLabel

@onready var demo_title: Label = %DemoTitle
@onready var demo_play: Button = %DemoPlay
@onready var demo_settings: Button = %DemoSettings
@onready var demo_quit: Button = %DemoQuit


func _ready() -> void:
	_init_sample_locales()
	_populate_dropdown()
	lang_option.item_selected.connect(_on_lang_selected)
	translate_btn.pressed.connect(_on_translate_pressed)
	_update_demo_ui()


func _init_sample_locales() -> void:
	manager.register_locale("en", "English", "English")
	manager.register_locale("es", "Spanish", "Español")
	manager.register_locale("fr", "French", "Français")
	manager.register_locale("de", "German", "Deutsch")
	manager.register_locale("it", "Italian", "Italiano")
	manager.register_locale("pt", "Portuguese", "Português")

	# Add sample keys
	manager.add_messages("en", {
		"DEMO_TITLE": "Card Wars: Kingdom",
		"DEMO_PLAY": "Play Match",
		"DEMO_SETTINGS": "Settings",
		"DEMO_QUIT": "Quit Game"
	})
	manager.add_messages("es", {
		"DEMO_TITLE": "Guerra de Cartas: Reino",
		"DEMO_PLAY": "Jugar Partida",
		"DEMO_SETTINGS": "Opciones",
		"DEMO_QUIT": "Salir del Juego"
	})
	manager.add_messages("fr", {
		"DEMO_TITLE": "Guerre des Cartes",
		"DEMO_PLAY": "Jouer",
		"DEMO_SETTINGS": "Paramètres",
		"DEMO_QUIT": "Quitter"
	})
	manager.add_messages("de", {
		"DEMO_TITLE": "Kartenkriege",
		"DEMO_PLAY": "Spiel Starten",
		"DEMO_SETTINGS": "Einstellungen",
		"DEMO_QUIT": "Beenden"
	})
	manager.add_messages("it", {
		"DEMO_TITLE": "Guerra delle Carte",
		"DEMO_PLAY": "Gioca",
		"DEMO_SETTINGS": "Impostazioni",
		"DEMO_QUIT": "Esci"
	})
	manager.add_messages("pt", {
		"DEMO_TITLE": "Guerra de Cartas",
		"DEMO_PLAY": "Jogar Partida",
		"DEMO_SETTINGS": "Configurações",
		"DEMO_QUIT": "Sair"
	})


func _populate_dropdown() -> void:
	lang_option.clear()
	var locales = manager.get_available_locales()
	for i in range(locales.size()):
		var loc = locales[i]
		lang_option.add_item("%s (%s)" % [loc.display_name, loc.native_name], i)
		lang_option.set_item_metadata(i, loc.code)
	lang_option.selected = 0


func _on_lang_selected(idx: int) -> void:
	var code = str(lang_option.get_item_metadata(idx))
	manager.set_locale(code)
	_update_demo_ui()


func _on_translate_pressed() -> void:
	var key = test_key_edit.text.strip_edges()
	result_label.text = "Result: %s" % manager.translate_key(key, "[Key Not Found]")


func _update_demo_ui() -> void:
	demo_title.text = tr("DEMO_TITLE")
	demo_play.text = "⚔️ " + tr("DEMO_PLAY")
	demo_settings.text = "⚙️ " + tr("DEMO_SETTINGS")
	demo_quit.text = "🚪 " + tr("DEMO_QUIT")
