class_name WheelConfig
extends RefCounted

# Universal Wheel Configuration
# Stores sectors, ratios, colors, multipliers, and rotation kinetics.

const ID_SUCCESS = "success"
const ID_PARTIAL = "partial"
const ID_FAILURE = "failure"

## Formal contract for wheel resolution outcomes
class WheelResult extends RefCounted:
	const KEY_ID = "id"
	const KEY_NAME = "name"
	const KEY_MULTIPLIER = "multiplier"
	const KEY_ANGLE = "angle_deg"
	const KEY_COLOR = "color"
	const KEY_IS_SUCCESS = "is_success"
	const KEY_QUICK_RESOLVED = "quick_resolved"

	var id: String = ID_SUCCESS
	var name: String = "SUCCESS"
	var multiplier: float = 1.0
	var angle_deg: float = 0.0
	var color: Color = Color.WHITE
	var is_success: bool = true
	var quick_resolved: bool = false

	static func from_dict(d: Dictionary) -> WheelResult:
		var r = WheelResult.new()
		r.id = d.get(KEY_ID, ID_SUCCESS)
		r.name = d.get(KEY_NAME, "SUCCESS")
		r.multiplier = float(d.get(KEY_MULTIPLIER, 1.0))
		r.angle_deg = float(d.get(KEY_ANGLE, 0.0))
		r.color = d.get(KEY_COLOR, Color.WHITE)
		r.is_success = d.get(KEY_IS_SUCCESS, true)
		r.quick_resolved = d.get(KEY_QUICK_RESOLVED, false)
		return r

	func to_dict() -> Dictionary:
		return {
			KEY_ID: id,
			KEY_NAME: name,
			KEY_MULTIPLIER: multiplier,
			KEY_ANGLE: angle_deg,
			KEY_COLOR: color,
			KEY_IS_SUCCESS: is_success,
			KEY_QUICK_RESOLVED: quick_resolved
		}

	func _get(property: StringName) -> Variant:
		match property:
			&"id": return id
			&"name": return name
			&"multiplier": return multiplier
			&"angle_deg": return angle_deg
			&"color": return color
			&"is_success": return is_success
			&"quick_resolved": return quick_resolved
		return null

var sectors: Array = []
var spin_speed_deg_sec: float = 1600.0
var min_spin_time: float = 0.25
var quick_resolve: bool = false
var clockwise: bool = true
var base_radius: float = 120.0

## Neutral 3-tier success/bonus/failure preset
static func create_tiered(success_ratio: float = 0.70, bonus_ratio: float = 0.10, speed: float = 1600.0) -> WheelConfig:
	var cfg = new()
	var fail_ratio = max(0.0, 1.0 - (success_ratio + bonus_ratio))
	cfg.sectors = [
		{
			"id": ID_PARTIAL,
			"name": "BONUS",
			"ratio": bonus_ratio,
			"color": Color(0.15, 0.9, 0.35, 1.0), # Vivid Green
			"multiplier": 2.0,
			"is_success": true
		},
		{
			"id": ID_SUCCESS,
			"name": "SUCCESS",
			"ratio": success_ratio,
			"color": Color(0.95, 0.85, 0.2, 1.0), # Gold/Yellow
			"multiplier": 1.0,
			"is_success": true
		},
		{
			"id": ID_FAILURE,
			"name": "FAILURE",
			"ratio": fail_ratio,
			"color": Color(0.85, 0.25, 0.25, 1.0), # Crimson
			"multiplier": 0.0,
			"is_success": false
		}
	]
	cfg.spin_speed_deg_sec = speed
	return cfg

## Neutral 50/50 binary choice preset (e.g. coin flip, heads/tails, yes/no)
static func create_coin_flip(ratio_a: float = 0.50, label_a: String = "HEADS", label_b: String = "TAILS", speed: float = 1400.0) -> WheelConfig:
	var cfg = new()
	var ratio_b = max(0.0, 1.0 - ratio_a)
	cfg.sectors = [
		{
			"id": "option_a",
			"name": label_a,
			"ratio": ratio_a,
			"color": Color(0.2, 0.65, 0.95, 1.0), # Azure
			"multiplier": 1.0,
			"is_success": true
		},
		{
			"id": "option_b",
			"name": label_b,
			"ratio": ratio_b,
			"color": Color(0.95, 0.55, 0.2, 1.0), # Orange
			"multiplier": 1.0,
			"is_success": true
		}
	]
	cfg.spin_speed_deg_sec = speed
	return cfg

## Neutral equal-distribution quadrant preset (4 equal sectors)
static func create_quadrants(labels: Array = ["A", "B", "C", "D"], speed: float = 1500.0) -> WheelConfig:
	var cfg = new()
	var default_colors = [
		Color(0.2, 0.65, 0.95, 1.0), # Blue
		Color(0.95, 0.85, 0.2, 1.0),  # Yellow
		Color(0.2, 0.85, 0.45, 1.0), # Green
		Color(0.85, 0.35, 0.85, 1.0)  # Magenta
	]
	var count = max(1, labels.size())
	var ratio_each = 1.0 / float(count)
	cfg.sectors = []
	for i in range(count):
		var lbl = str(labels[i])
		var col = default_colors[i % default_colors.size()]
		cfg.sectors.append({
			"id": "quad_%d" % i,
			"name": lbl,
			"ratio": ratio_each,
			"color": col,
			"multiplier": 1.0,
			"is_success": true
		})
	cfg.spin_speed_deg_sec = speed
	return cfg

## Fully customizable wheel preset
static func create_custom(p_sectors: Array, speed: float = 1600.0) -> WheelConfig:
	var cfg = new()
	cfg.sectors = p_sectors
	cfg.spin_speed_deg_sec = speed
	return cfg

## Returns the resolved sector at the given angle as a typed WheelResult.
func get_sector_at_angle(angle_deg: float) -> WheelResult:
	var norm_angle = fposmod(angle_deg, 360.0)
	var current_deg = 0.0
	for sector in sectors:
		var sector_span = sector.get("ratio", 0.0) * 360.0
		if norm_angle >= current_deg and norm_angle < (current_deg + sector_span):
			var res_dict = sector.duplicate()
			res_dict["angle_deg"] = norm_angle
			return WheelResult.from_dict(res_dict)
		current_deg += sector_span
	if not sectors.is_empty():
		var res_dict = sectors[-1].duplicate()
		res_dict["angle_deg"] = norm_angle
		return WheelResult.from_dict(res_dict)
	return WheelResult.new()

## Returns the resolved sector at the given angle as a dictionary.
func get_sector_at_angle_dict(angle_deg: float) -> Dictionary:
	return get_sector_at_angle(angle_deg).to_dict()

## Deterministically rolls a quick resolution outcome as a typed WheelResult.
func roll_quick_resolve() -> WheelResult:
	var roll = randf()
	var accum = 0.0
	for sector in sectors:
		accum += sector.get("ratio", 0.0)
		if roll <= accum:
			var res_dict = sector.duplicate()
			res_dict["angle_deg"] = accum * 360.0
			res_dict["quick_resolved"] = true
			return WheelResult.from_dict(res_dict)
	if not sectors.is_empty():
		var res_dict = sectors[-1].duplicate()
		res_dict["quick_resolved"] = true
		return WheelResult.from_dict(res_dict)
	return WheelResult.new()

## Deterministically rolls a quick resolution outcome as a dictionary.
func roll_quick_resolve_dict() -> Dictionary:
	return roll_quick_resolve().to_dict()
