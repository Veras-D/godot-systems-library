extends SceneTree

const WheelConfig = preload("WheelConfig.gd")

func _init() -> void:
	print("==> Running Timing Wheel Unit & Math Tests...")

	# 1. Test Tiered Configuration (70% Success, 10% Bonus, 20% Failure)
	var cfg = WheelConfig.create_tiered(0.70, 0.10)
	assert(cfg.sectors.size() == 3, "Should have 3 sectors")
	assert(cfg.sectors[0].id == WheelConfig.ID_PARTIAL, "First sector should be partial/bonus")
	assert(cfg.sectors[1].id == WheelConfig.ID_SUCCESS, "Second sector should be success")
	assert(cfg.sectors[2].id == WheelConfig.ID_FAILURE, "Third sector should be failure")

	# Check exact angles:
	# Bonus: 0.10 * 360 = 36.0° (0° to 36°)
	# Success: 36.0° to 36.0 + 252.0 = 288.0°
	# Failure: 288.0° to 360°
	var s_bonus = cfg.get_sector_at_angle(10.0)
	assert(s_bonus is WheelConfig.WheelResult, "get_sector_at_angle should return typed WheelResult")
	assert(s_bonus.id == WheelConfig.ID_PARTIAL, "10° should be in bonus sector")
	print("10° check: ", s_bonus.name, " multiplier: ", s_bonus.multiplier)

	var s_success = cfg.get_sector_at_angle(100.0)
	assert(s_success.id == WheelConfig.ID_SUCCESS, "100° should be in success sector")
	print("100° check: ", s_success.name, " multiplier: ", s_success.multiplier)

	var s_failure = cfg.get_sector_at_angle(340.0)
	assert(s_failure.id == WheelConfig.ID_FAILURE, "340° should be in failure sector")
	print("340° check: ", s_failure.name, " multiplier: ", s_failure.multiplier)

	# 2. Test Monte Carlo 5,000 rolls
	var rolls = 5000
	var counts = { WheelConfig.ID_PARTIAL: 0, WheelConfig.ID_SUCCESS: 0, WheelConfig.ID_FAILURE: 0 }
	for _i in range(rolls):
		var r = cfg.roll_quick_resolve()
		assert(r is WheelConfig.WheelResult, "roll_quick_resolve must return typed WheelResult")
		counts[r.id] += 1

	var bonus_pct = (float(counts[WheelConfig.ID_PARTIAL]) / float(rolls)) * 100.0
	var success_pct = (float(counts[WheelConfig.ID_SUCCESS]) / float(rolls)) * 100.0
	var fail_pct = (float(counts[WheelConfig.ID_FAILURE]) / float(rolls)) * 100.0
	print("5,000 rolls distribution:")
	print("  Bonus:   %.2f%% (Target 10.0%%)" % bonus_pct)
	print("  Success: %.2f%% (Target 70.0%%)" % success_pct)
	print("  Failure: %.2f%% (Target 20.0%%)" % fail_pct)

	assert(bonus_pct >= 7.0 and bonus_pct <= 13.0, "Bonus within margin")
	assert(success_pct >= 66.0 and success_pct <= 74.0, "Success within margin")
	assert(fail_pct >= 16.0 and fail_pct <= 24.0, "Failure within margin")

	# 3. Test Neutral Factory Presets
	var coin_cfg = WheelConfig.create_coin_flip()
	assert(coin_cfg.sectors.size() == 2, "Coin flip should have 2 sectors")
	assert(coin_cfg.sectors[0].name == "HEADS" and coin_cfg.sectors[1].name == "TAILS", "Coin flip names valid")

	var quad_cfg = WheelConfig.create_quadrants(["North", "East", "South", "West"])
	assert(quad_cfg.sectors.size() == 4, "Quadrants should have 4 sectors")
	assert(is_equal_approx(quad_cfg.sectors[0].ratio, 0.25), "Quadrants ratio should be 0.25 each")

	var custom_cfg = WheelConfig.create_custom([
		{"id": "speed_boost", "name": "Speed Boost", "ratio": 0.6, "multiplier": 1.5, "is_success": true},
		{"id": "oil_slick", "name": "Oil Slick", "ratio": 0.4, "multiplier": 0.0, "is_success": false}
	])
	assert(custom_cfg.sectors.size() == 2, "Custom config should accept arbitrary sectors")

	# 4. Test WheelResult Contract Class
	var mock_dict = {"id": WheelConfig.ID_PARTIAL, "name": "Bonus", "multiplier": 2.0, "angle_deg": 120.0, "is_success": true}
	var res_obj = WheelConfig.WheelResult.from_dict(mock_dict)
	assert(res_obj.id == WheelConfig.ID_PARTIAL, "WheelResult ID must match ID_PARTIAL")
	assert(res_obj.multiplier == 2.0, "WheelResult multiplier must match")
	var back_to_dict = res_obj.to_dict()
	assert(back_to_dict[WheelConfig.WheelResult.KEY_MULTIPLIER] == 2.0, "to_dict() must round-trip")
	print("WheelResult contract verified.")

	print("==> All Timing Wheel Unit Tests PASSED!")
	quit(0)
