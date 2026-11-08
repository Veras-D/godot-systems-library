extends SceneTree

const CurrencyWallet = preload("CurrencyWallet.gd")
const ProgressionTracker = preload("ProgressionTracker.gd")
const GachaRoller = preload("GachaRoller.gd")

func _init() -> void:
	print("==> Running ProgressionEngine Unit & Regression Tests...")

	# ==========================================================================
	# 1. CurrencyWallet Tests
	# ==========================================================================
	print("Test 1: CurrencyWallet Deposits, Withdrawals, Caps & Transfers...")
	var wallet_a = CurrencyWallet.new()
	var wallet_b = CurrencyWallet.new()

	wallet_a.register_currency("gold", 100, 1000)
	wallet_a.register_currency("gems", 5, 50)
	wallet_b.register_currency("gold", 0, -1)

	assert(wallet_a.get_balance("gold") == 100, "Initial gold should be 100")
	assert(wallet_a.get_balance("gems") == 5, "Initial gems should be 5")

	# Deposit within cap
	var bal1 = wallet_a.deposit("gold", 250)
	assert(bal1 == 350, "Gold balance should be 350")
	assert(wallet_a.get_balance("gold") == 350, "get_balance should reflect deposit")

	# Deposit exceeding cap
	wallet_a.deposit("gold", 800) # 350 + 800 = 1150, cap is 1000
	assert(wallet_a.get_balance("gold") == 1000, "Gold should cap at 1000")

	# Successful withdrawal
	var ok_withdraw = wallet_a.withdraw("gold", 400)
	assert(ok_withdraw == true, "Withdrawal of 400 should succeed")
	assert(wallet_a.get_balance("gold") == 600, "Gold should now be 600")

	# Overdraft prevention
	var fail_withdraw = wallet_a.withdraw("gold", 700) # 600 < 700
	assert(fail_withdraw == false, "Withdrawal exceeding balance should fail")
	assert(wallet_a.get_balance("gold") == 600, "Gold should remain 600")

	# Transfer between wallets
	var transfer_ok = wallet_a.transfer_to(wallet_b, "gold", 200)
	assert(transfer_ok == true, "Transfer of 200 should succeed")
	assert(wallet_a.get_balance("gold") == 400, "Sender should have 400")
	assert(wallet_b.get_balance("gold") == 200, "Recipient should have 200")

	# Serialization & Deserialization
	var saved_state = wallet_a.serialize()
	var restored_wallet = CurrencyWallet.new()
	restored_wallet.deserialize(saved_state)
	assert(restored_wallet.get_balance("gold") == 400, "Restored wallet gold should match")
	assert(restored_wallet.get_cap("gold") == 1000, "Restored wallet cap should match")
	print("  ✔ CurrencyWallet passed.")

	# ==========================================================================
	# 2. ProgressionTracker Tests
	# ==========================================================================
	print("Test 2: ProgressionTracker XP Curves, Multi-Level Jumps & Caps...")
	var tracker = ProgressionTracker.new(10, 100, 0.0) # Flat 100 XP per level, max level 10

	assert(tracker.current_level == 1, "Should start at level 1")
	assert(tracker.current_xp == 0, "Should start at 0 XP")

	# Single level up: grant 150 XP (needs 100 to level up to 2, 50 remainder)
	var res1 = tracker.add_xp(150)
	assert(res1["leveled_up"] == true, "Should report leveled_up = true")
	assert(tracker.current_level == 2, "Level should be 2")
	assert(tracker.current_xp == 50, "Remainder XP should be 50")
	assert(is_equal_approx(tracker.get_progress_ratio(), 0.5), "Progress ratio should be 0.5")

	# Multi-level jump: 50 + 275 = 325 XP.
	# Level 2 -> 3 (100 - 50 = 50 used, 225 left)
	# Level 3 -> 4 (100 used, 125 left)
	# Level 4 -> 5 (100 used, 25 left)
	var res2 = tracker.add_xp(275)
	assert(res2["leveled_up"] == true, "Should report leveled_up = true")
	assert(tracker.current_level == 5, "Level should advance to 5")
	assert(res2["levels_gained"] == 3, "Should have gained 3 levels")
	assert(tracker.current_xp == 25, "Remainder XP should be 25")

	# Custom XP table test
	var custom_tracker = ProgressionTracker.new()
	custom_tracker.set_custom_xp_table([100, 200, 400, 800])
	assert(custom_tracker.max_level == 5, "Custom table with 4 steps means max level 5")
	assert(custom_tracker.get_xp_for_level(1) == 100, "Level 1 needs 100")
	assert(custom_tracker.get_xp_for_level(2) == 200, "Level 2 needs 200")
	assert(custom_tracker.get_xp_for_level(3) == 400, "Level 3 needs 400")
	assert(custom_tracker.get_xp_for_level(4) == 800, "Level 4 needs 800")

	# Level cap test: grant massive XP to hit cap (max 10)
	var max_reached_signal = [false]
	tracker.max_level_reached.connect(func(): max_reached_signal[0] = true)

	tracker.add_xp(100000)
	assert(tracker.current_level == 10, "Level should cap at max_level 10")
	assert(tracker.is_max_level() == true, "is_max_level() should return true")
	assert(max_reached_signal[0] == true, "max_level_reached signal should have fired")
	assert(tracker.get_progress_ratio() == 1.0, "Progress ratio at max level should be 1.0")

	# Stat scaling calculation
	var base_hp = 100.0
	var hp_at_lvl_10 = tracker.calculate_scaled_stat(base_hp, 15.0)
	# Level 10 = base 100 + (10 - 1) * 15 = 100 + 135 = 235
	assert(hp_at_lvl_10 == 235.0, "Scaled stat should be 235.0 (got %f)" % hp_at_lvl_10)

	# Serialization
	var saved_prog = tracker.serialize()
	var restored_tracker = ProgressionTracker.new()
	restored_tracker.deserialize(saved_prog)
	assert(restored_tracker.current_level == 10, "Restored level should be 10")
	assert(restored_tracker.is_max_level() == true, "Restored tracker should be at max level")
	print("  ✔ ProgressionTracker passed.")

	# ==========================================================================
	# 3. GachaRoller Tests
	# ==========================================================================
	print("Test 3: GachaRoller Weighted Probabilities & Pity Guarantee...")
	var gacha = GachaRoller.new()

	var test_pool = [
		{ "id": "item_common", "weight": 90, "rarity": "Common" },
		{ "id": "item_rare", "weight": 9, "rarity": "Rare" },
		{ "id": "item_legendary", "weight": 1, "rarity": "Legendary" }
	]

	var registered_count = gacha.register_pool("standard_chest", test_pool)
	assert(registered_count == 3, "Should register 3 pool items")

	# Set pity rule: Guaranteed Legendary on 10th pull
	gacha.set_pity_rule("standard_chest", 10, "Legendary")

	# Deterministic RNG for predictable test
	var seeded_rng = RandomNumberGenerator.new()
	seeded_rng.seed = 12345

	# Roll 9 times with items that don't trigger legendary
	for i in range(9):
		var r = gacha.roll("standard_chest", seeded_rng)
		assert(r["ok"] == true, "Roll %d should succeed" % (i + 1))

	# 10th roll should trigger pity
	var pity_fired = [false]
	gacha.pity_triggered.connect(func(p, r): pity_fired[0] = true)

	var roll_10 = gacha.roll("standard_chest", seeded_rng)
	assert(roll_10["ok"] == true, "10th roll should succeed")
	assert(roll_10["is_pity"] == true, "10th roll must be pity roll")
	assert(roll_10["rarity"] == "Legendary", "Pity roll must return Legendary item")
	assert(roll_10["id"] == "item_legendary", "Pity roll must pick item_legendary")
	assert(pity_fired[0] == true, "pity_triggered signal must fire")
	assert(gacha.get_pity_count("standard_chest") == 0, "Pity counter must reset to 0 after pity roll")

	# Test Multi-Roll
	var multi_results = gacha.roll_multi("standard_chest", 5, seeded_rng)
	assert(multi_results.size() == 5, "Multi-roll should produce exactly 5 results")
	for res in multi_results:
		assert(res["ok"] == true, "Each multi-roll result must be valid")

	# Serialization
	var saved_pity = gacha.serialize_pity()
	var restored_gacha = GachaRoller.new()
	restored_gacha.deserialize_pity(saved_pity)
	assert(restored_gacha.get_pity_count("standard_chest") == gacha.get_pity_count("standard_chest"), "Pity count should match")
	print("  ✔ GachaRoller passed.")

	print("\nALL PROGRESSION ENGINE TESTS COMPLETED SUCCESSFULLY!")
	quit(0)
