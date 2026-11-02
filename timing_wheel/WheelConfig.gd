class_name WheelConfig
extends RefCounted

# Universal Wheel Configuration
# Stores sectors, ratios, colors, multipliers, and rotation kinetics.

var sectors: Array = []
var spin_speed_deg_sec: float = 1600.0
var min_spin_time: float = 0.25
var quick_resolve: bool = false
var clockwise: bool = true
var base_radius: float = 120.0

static func create_card_wars_attacker(hit_ratio: float = 0.80, crit_ratio: float = 0.07) -> WheelConfig:
	var cfg = new()
	var miss_ratio = max(0.0, 1.0 - (hit_ratio + crit_ratio))
	cfg.sectors = [
		{
			"id": "crit",
			"name": "CRITICAL HIT!",
			"ratio": crit_ratio,
			"color": Color(0.1, 1.0, 0.3, 1.0), # Neon Green
			"multiplier": 2.0,
			"is_success": true
		},
		{
			"id": "hit",
			"name": "HIT",
			"ratio": hit_ratio,
			"color": Color(0.95, 0.85, 0.2, 1.0), # Gold/Yellow
			"multiplier": 1.0,
			"is_success": true
		},
		{
			"id": "miss",
			"name": "MISS",
			"ratio": miss_ratio,
			"color": Color(0.85, 0.2, 0.2, 1.0), # Crimson Red
			"multiplier": 0.0,
			"is_success": false
		}
	]
	cfg.spin_speed_deg_sec = 1600.0 # ~0.22s per full 360 rotation
	return cfg

static func create_card_wars_defender(hit_ratio: float = 0.15, crit_ratio: float = 0.05) -> WheelConfig:
	var cfg = new()
	var miss_ratio = max(0.0, 1.0 - (hit_ratio + crit_ratio))
	cfg.sectors = [
		{
			"id": "crit_block",
			"name": "PERFECT BLOCK!",
			"ratio": crit_ratio,
			"color": Color(0.2, 0.8, 1.0, 1.0), # Cyan
			"multiplier": 2.0,
			"is_success": true
		},
		{
			"id": "block",
			"name": "BLOCK",
			"ratio": hit_ratio,
			"color": Color(0.3, 0.6, 0.9, 1.0), # Blue
			"multiplier": 1.0,
			"is_success": true
		},
		{
			"id": "no_block",
			"name": "FAILED BLOCK",
			"ratio": miss_ratio,
			"color": Color(0.4, 0.4, 0.5, 1.0), # Slate Grey
			"multiplier": 0.0,
			"is_success": false
		}
	]
	cfg.spin_speed_deg_sec = 1750.0
	return cfg

static func create_custom(p_sectors: Array[Dictionary], speed: float = 1600.0) -> WheelConfig:
	var cfg = new()
	cfg.sectors = p_sectors
	cfg.spin_speed_deg_sec = speed
	return cfg

func get_sector_at_angle(angle_deg: float) -> Dictionary:
	var norm_angle = fposmod(angle_deg, 360.0)
	var current_deg = 0.0
	for sector in sectors:
		var sector_span = sector.get("ratio", 0.0) * 360.0
		if norm_angle >= current_deg and norm_angle < (current_deg + sector_span):
			var res = sector.duplicate()
			res["angle_deg"] = norm_angle
			return res
		current_deg += sector_span
	if not sectors.is_empty():
		var res = sectors[-1].duplicate()
		res["angle_deg"] = norm_angle
		return res
	return {}

func roll_quick_resolve() -> Dictionary:
	var roll = randf()
	var accum = 0.0
	for sector in sectors:
		accum += sector.get("ratio", 0.0)
		if roll <= accum:
			var res = sector.duplicate()
			res["angle_deg"] = accum * 360.0
			res["quick_resolved"] = true
			return res
	if not sectors.is_empty():
		return sectors[-1].duplicate()
	return {}
