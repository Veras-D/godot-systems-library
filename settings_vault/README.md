# SYS-12: Settings Vault

Universal Audio Bus Volume, Display/Resolution Modes, V-Sync, FPS Limiter, and Input Remapping Manager for Godot 4.x.

---

## 📦 Features

- **`SettingsManager.gd`**:
  - **Audio Management**:
    - Converts linear slider values (`0.0` to `1.0`) to decibels with `linear_to_db` and clamps mute state under `0.001`.
    - Manages `Master`, `BGM`, `SFX`, and `VO` audio buses with independent mute toggles.
  - **Display & Graphics**:
    - Fullscreen, Exclusive Fullscreen, Maximized, and Windowed presentation modes.
    - Standard resolution switcher (`1280x720`, `1280x800` [Steam Deck], `1600x900`, `1920x1080`, `2560x1440`, `3840x2160`).
    - V-Sync modes: `Disabled`, `Enabled`, `Adaptive`, `Mailbox`.
    - Framerate capper (`30`, `60`, `120`, `144`, Unlimited).
    - UI Scale adjustment.
  - **Controls & Input Remapping**:
    - Dynamic remapping of keyboard (`InputEventKey`) and joypad buttons (`InputEventJoypadButton`).
    - Serializable to JSON with safe factory reset to initial project defaults.
  - **Persistence**:
    - Clean atomic JSON storage in `user://settings.json`.
- **Interactive Testbed (`testbed_settings.tscn`)**:
  - Live audio sliders, display resolution/vsync dropdowns, and save/load verification.

---

## 🚀 Quick Integration

```gdscript
var settings = SettingsManager.new()
add_child(settings)

# Load existing preferences
settings.load_settings()

# Adjust volume
settings.set_bus_volume("Master", 0.75)

# Set resolution for Steam Deck
settings.set_resolution(Vector2i(1280, 800))

# Save to disk
settings.save_settings()
```

---

## 🧪 Testing

Run headless unit tests:
```bash
godot --headless -s settings_vault/test_settings_vault.gd
```
