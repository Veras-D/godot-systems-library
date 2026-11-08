# SYS-13: Universal Localization Engine

Universal runtime internationalization and multilingual translation parser for Godot 4.x.

---

## 📦 Features

- **`LocalizationParser.gd`**:
  - High-performance XML entry stream parser (`<entry name="KEY">TEXT</entry>`).
  - Automatic unescaping of standard XML entities (`&apos;`, `&quot;`, `&amp;`, `&lt;`, `&gt;`).
  - Supports string buffers and file streaming.
- **`LocalizationManager.gd`**:
  - Integrates natively with Godot 4's global `TranslationServer`.
  - Populates and manages `Translation` resources with `add_message(key, val)`.
  - Real-time locale switching (`set_locale`) triggering automatic UI refresh and `locale_changed` signals.
  - Fallback translation support for missing keys.
- **Interactive Testbed (`testbed_localization.tscn`)**:
  - Live language switching demo across 6 languages with live key resolution.

---

## 🚀 Quick Integration

```gdscript
var manager = LocalizationManager.new()
add_child(manager)

# Register languages
manager.register_locale("en", "English")
manager.register_locale("es", "Español")

# Load translation dictionary
var es_data = LocalizationParser.parse_xml_file("res://languages/ES_Menu.bytes")
manager.add_messages("es", es_data)

# Switch language at runtime
manager.set_locale("es")

# Translate text
print(tr("!!BUTTON_PLAY"))
```

---

## 🧪 Testing

Run headless unit tests:
```bash
godot --headless -s localization_engine/test_localization.gd
```
