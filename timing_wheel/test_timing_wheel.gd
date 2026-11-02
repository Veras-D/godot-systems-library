extends SceneTree

const WheelConfig = preload("WheelConfig.gd")

func _init() -> void:
	print("==> Running Timing Wheel Unit & Math Tests...")

	# 1. Test Attacker Configuration
	var cfg = WheelConfig.create_card_wars_attacker(0.80, 0.07)
	assert(cfg.sectors.size() == 3, "Should have 3 sectors")
	assert(cfg.sectors[0].id == "crit", "First sector should be crit")
	assert(cfg.sectors[1].id == "hit", "Second sector should be hit")
	assert(cfg.sectors[2].id == "miss", "Third sector should be miss")

	# Check exact angles:
	# Crit: 0.07 * 360 = 25.2°
	# Hit: 25.2° to 25.2 + 288 = 313.2°
	# Miss: 313.2° to 360°
	var s_crit = cfg.get_sector_at_angle(10.0)
	assert(s_crit.id == "crit", "10° should be in crit sector")
	print("10° check: ", s_crit.name, " multiplier: ", s_crit.multiplier)

	var s_hit = cfg.get_sector_at_angle(100.0)
	assert(s_hit.id == "hit", "100° should be in hit sector")
	print("100° check: ", s_hit.name, " multiplier: ", s_hit.multiplier)

	var s_miss = cfg.get_sector_at_angle(340.0)
	assert(s_miss.id == "miss", "340° should be in miss sector")
	print("340° check: ", s_miss.name, " multiplier: ", s_miss.multiplier)

	# 2. Test Monte Carlo 5,000 rolls
	var rolls = 5000
	var counts = { "crit": 0, "hit": 0, "miss": 0 }
	for _i in range(rolls):
		var r = cfg.roll_quick_resolve()
		counts[r.id] += 1

	var crit_pct = (float(counts["crit"]) / float(rolls)) * 100.0
	var hit_pct = (float(counts["hit"]) / float(rolls)) * 100.0
	var miss_pct = (float(counts["miss"]) / float(rolls)) * 100.0
	print("5,000 rolls distribution:")
	print("  Crit: %.2f%% (Target 7.0%%)" % crit_pct)
	print("  Hit:  %.2f%% (Target 80.0%%)" % hit_pct)
	print("  Miss: %.2f%% (Target 13.0%%)" % miss_pct)

	assert(crit_pct >= 5.0 and crit_pct <= 9.0, "Crit within margin")
	assert(hit_pct >= 77.0 and hit_pct <= 83.0, "Hit within margin")
	assert(miss_pct >= 10.0 and miss_pct <= 16.0, "Miss within margin")

	print("==> All Timing Wheel Unit Tests PASSED!")
	quit(0)
