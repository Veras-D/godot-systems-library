# Audio Jukebox System (Standalone Godot 4 Module)

A completely decoupled, production-ready audio architecture for Godot 4 games.

Designed following the **Systems-First** architecture: zero game-specific coupling, self-contained testbeds, zero-allocation SFX recycling, and extraction-ready for any project.

---

## Features

- **Dual-Player BGM Crossfading**:
  - Two dedicated `AudioStreamPlayer` nodes (`BGM_A` and `BGM_B`) automatically alternate during track transitions.
  - Smooth volume fading via `Tween` with configurable duration (prevents pops, clicks, or jarring cuts).
  - Clean automatic disposal and stream unreferencing when inactive.
- **Zero-Allocation SFX Pooling**:
  - Pre-allocated pool of recycled `AudioStreamPlayer` nodes (default size 8).
  - Dynamic expansion by +4 nodes when simultaneous sound bursts exceed capacity.
  - Optional pitch variation (`play_sfx_with_variation()`) for organic, non-repetitive gameplay sounds.
- **Audio Bus Management & Volume Clamping**:
  - Automatically verifies and connects to `Master`, `Music`, and `SFX` buses (or safely creates them if missing).
  - True linear-to-decibel scaling (`linear_to_db` and `db_to_linear`).
  - Mute toggles and master volume control.
- **Procedural Audio Synthesizer**:
  - Includes `AudioManager.create_tone_stream()` to generate programmatic 8-bit PCM WAV beeps and tones on the fly.
  - Enables 100% headless automated testing with zero audio asset dependencies!
- **Standalone Interactive Testbed (`testbed_audio.tscn`)**:
  - Interactive UI with BGM track selector, crossfade duration slider, SFX burst spammers, bus mixer sliders, and real-time event log.

---

## Integration Guide

### 1. Instantiate or Autoload
In your scene or as an Autoload singleton (`AudioManager`):
```gdscript
var audio_mgr = AudioManager.new()
add_child(audio_mgr)
```

### 2. Play & Crossfade BGM
```gdscript
var battle_bgm = preload("res://assets/audio/battle_theme.ogg")

# Smoothly crossfade to battle theme over 1.5 seconds
audio_mgr.play_bgm(battle_bgm, 1.5)

# Stop BGM with a 1.0 second fade out
audio_mgr.stop_bgm(1.0)
```

### 3. Play Pooled SFX
```gdscript
var click_sfx = preload("res://assets/audio/click.wav")

# Play standard SFX
audio_mgr.play_sfx(click_sfx)

# Play with ±10% random pitch variation
audio_mgr.play_sfx_with_variation(click_sfx, 0.0, 0.10)
```

### 4. Adjust Bus Volumes (0.0 to 1.0 Linear)
```gdscript
audio_mgr.set_master_volume(0.8)
audio_mgr.set_music_volume(0.6)
audio_mgr.set_sfx_volume(1.0)
```

---

## Running the Isolated Testbed

Open and run `testbed_audio.tscn` directly in Godot:
```bash
godot audio_jukebox/testbed_audio.tscn
```
Or run the automated unit test headlessly:
```bash
godot --headless -s res://audio_jukebox/test_audio_manager.gd
```
