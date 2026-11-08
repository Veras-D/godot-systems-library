extends Control

const CurrencyWallet = preload("CurrencyWallet.gd")
const ProgressionTracker = preload("ProgressionTracker.gd")
const GachaRoller = preload("GachaRoller.gd")

var wallet: CurrencyWallet
var tracker: ProgressionTracker
var gacha: GachaRoller

@onready var gold_lbl: Label = $Layout/MainArea/Content/Left/WalletPanel/Margin/VBox/GoldRow/Value
@onready var gems_lbl: Label = $Layout/MainArea/Content/Left/WalletPanel/Margin/VBox/GemsRow/Value
@onready var energy_lbl: Label = $Layout/MainArea/Content/Left/WalletPanel/Margin/VBox/EnergyRow/Value

@onready var level_lbl: Label = $Layout/MainArea/Content/Left/ProgressionPanel/Margin/VBox/LevelHeader/LevelValue
@onready var xp_bar: ProgressBar = $Layout/MainArea/Content/Left/ProgressionPanel/Margin/VBox/XPBar
@onready var xp_text_lbl: Label = $Layout/MainArea/Content/Left/ProgressionPanel/Margin/VBox/XPText
@onready var level_status: Label = $Layout/MainArea/Content/Left/ProgressionPanel/Margin/VBox/LevelStatus

@onready var pool_option: OptionButton = $Layout/MainArea/Content/Right/GachaPanel/Margin/VBox/PoolPicker
@onready var pity_lbl: Label = $Layout/MainArea/Content/Right/GachaPanel/Margin/VBox/PityLabel
@onready var gacha_results: ItemList = $Layout/MainArea/Content/Right/GachaPanel/Margin/VBox/ResultsList
@onready var gacha_status: Label = $Layout/MainArea/Content/Right/GachaPanel/Margin/VBox/GachaStatus

func _ready() -> void:
	# 1. Setup Wallet
	wallet = CurrencyWallet.new()
	wallet.register_currency("gold", 500, 100000)
	wallet.register_currency("gems", 15, 1000)
	wallet.register_currency("energy", 50, 100)

	wallet.balance_changed.connect(func(_cid, _old_v, _new_v): _update_wallet_ui())
	wallet.insufficient_funds.connect(func(cid, req, curr):
		gacha_status.text = "Insufficient %s! Need %d, have %d." % [cid.to_upper(), req, curr]
		gacha_status.modulate = Color(1.0, 0.3, 0.3)
	)

	# 2. Setup Progression Tracker
	tracker = ProgressionTracker.new(50, 100, 1.15)
	tracker.level_up.connect(func(old_lvl, new_lvl):
		level_status.text = "★ LEVEL UP! Advanced from %d to %d!" % [old_lvl, new_lvl]
		level_status.modulate = Color(0.3, 1.0, 0.3)
	)
	tracker.max_level_reached.connect(func():
		level_status.text = "🏆 MAXIMUM LEVEL (50) ACHIEVED!"
		level_status.modulate = Color(1.0, 0.85, 0.2)
	)

	# 3. Setup Gacha Roller
	gacha = GachaRoller.new()

	var normal_chest_pool = [
		{ "id": "Common Wooden Shield", "weight": 60, "rarity": "Common" },
		{ "id": "Common Shortsword", "weight": 60, "rarity": "Common" },
		{ "id": "Uncommon Iron Helm", "weight": 25, "rarity": "Uncommon" },
		{ "id": "Rare Silver Halberd", "weight": 10, "rarity": "Rare" },
		{ "id": "Epic Dragon Ring", "weight": 3, "rarity": "Epic" }
	]

	var premium_chest_pool = [
		{ "id": "Rare Mythril Blade", "weight": 50, "rarity": "Rare" },
		{ "id": "Epic Sunfire Robes", "weight": 35, "rarity": "Epic" },
		{ "id": "Legendary Void Sovereign", "weight": 10, "rarity": "Legendary" },
		{ "id": "Mythic Astral Phoenix", "weight": 2, "rarity": "Mythic" }
	]

	gacha.register_pool("normal_chest", normal_chest_pool)
	gacha.register_pool("premium_chest", premium_chest_pool)

	gacha.set_pity_rule("normal_chest", 10, "Rare")
	gacha.set_pity_rule("premium_chest", 10, "Legendary")

	gacha.pity_triggered.connect(func(pool, rarity):
		gacha_status.text = "✨ PITY ACTIVATED! Guaranteed %s Pulled!" % rarity
		gacha_status.modulate = Color(1.0, 0.8, 0.2)
	)

	# Setup UI
	pool_option.clear()
	pool_option.add_item("Cool Chest (Cost: 100 Gold)", 0)
	pool_option.set_item_metadata(0, { "pool": "normal_chest", "currency": "gold", "cost": 100 })
	pool_option.add_item("Algebraic Chest (Cost: 5 Gems)", 1)
	pool_option.set_item_metadata(1, { "pool": "premium_chest", "currency": "gems", "cost": 5 })
	pool_option.item_selected.connect(func(_idx): _update_gacha_ui())

	_update_wallet_ui()
	_update_progression_ui()
	_update_gacha_ui()


func _update_wallet_ui() -> void:
	gold_lbl.text = "%d G" % wallet.get_balance("gold")
	gems_lbl.text = "%d 💎" % wallet.get_balance("gems")
	energy_lbl.text = "%d / %d ⚡" % [wallet.get_balance("energy"), wallet.get_cap("energy")]


func _update_progression_ui() -> void:
	level_lbl.text = "Level %d / %d" % [tracker.current_level, tracker.max_level]
	var needed = tracker.get_xp_for_next_level()
	var ratio = tracker.get_progress_ratio()
	xp_bar.value = ratio * 100.0

	if tracker.is_max_level():
		xp_text_lbl.text = "MAX LEVEL REACHED"
	else:
		xp_text_lbl.text = "XP: %d / %d (%d%%)" % [tracker.current_xp, needed, int(ratio * 100.0)]


func _update_gacha_ui() -> void:
	var sel_idx = pool_option.selected
	if sel_idx < 0:
		return
	var meta = pool_option.get_item_metadata(sel_idx)
	var pool_name = meta["pool"]
	var pity_count = gacha.get_pity_count(pool_name)
	pity_lbl.text = "Pity Progress: %d / 10 (Guaranteed High Rarity at 10)" % pity_count


# ==============================================================================
# UI ACTION HANDLERS
# ==============================================================================

func _on_deposit_gold(amount: int) -> void:
	wallet.deposit("gold", amount)


func _on_deposit_gems(amount: int) -> void:
	wallet.deposit("gems", amount)


func _on_add_xp(amount: int) -> void:
	tracker.add_xp(amount)
	_update_progression_ui()


func _on_roll_gacha(multi_count: int = 1) -> void:
	var sel_idx = pool_option.selected
	if sel_idx < 0:
		return
	var meta = pool_option.get_item_metadata(sel_idx)
	var pool_name = meta["pool"]
	var curr_id = meta["currency"]
	var cost_per_roll = int(meta["cost"])
	var total_cost = cost_per_roll * multi_count

	if not wallet.withdraw(curr_id, total_cost):
		return

	gacha_results.clear()
	var rolls = gacha.roll_multi(pool_name, multi_count)
	for r in rolls:
		var prefix = "✨ [PITY] " if r.get("is_pity", false) else ""
		var text = "%s%s (%s)" % [prefix, r["id"], r["rarity"]]
		gacha_results.add_item(text)

	if not rolls.is_empty() and not rolls[rolls.size() - 1].get("is_pity", false):
		gacha_status.text = "Pulled %d items!" % rolls.size()
		gacha_status.modulate = Color(0.4, 0.9, 0.4)

	_update_wallet_ui()
	_update_gacha_ui()
