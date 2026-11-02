extends Control

## Standalone Interactive Testbed for Universal Ability & Effect Engine
## Demonstrates:
## - Data-driven ability execution (Damage, Heal, Buff, Resource, Draw, Swap)
## - Queue-based resolution with step-by-step and async animation delays
## - Target scoping (Single target, All Friendly, All Enemy)
## - Dynamic reactions & trigger dispatching
## - Real-time battlefield stat updates and event log

const EffectData = preload("EffectData.gd")
const EffectContext = preload("EffectContext.gd")
const AbilityDefinition = preload("AbilityDefinition.gd")
const AbilityResolver = preload("AbilityResolver.gd")

@onready var resolver: AbilityResolver = $Resolver
@onready var log_label: RichTextLabel = $Layout/Sidebar/Scroll/VBox/LogSection/EventLog
@onready var queue_label: Label = $Layout/Sidebar/Scroll/VBox/QueueSection/QueueCountLabel

# Battlefield Mock Units UI
@onready var hero_card: PanelContainer = $Layout/MainArea/Battlefield/PlayerSide/HeroCard
@onready var knight_card: PanelContainer = $Layout/MainArea/Battlefield/PlayerSide/KnightCard
@onready var boss_card: PanelContainer = $Layout/MainArea/Battlefield/EnemySide/BossCard
@onready var minion_card: PanelContainer = $Layout/MainArea/Battlefield/EnemySide/MinionCard

# Data models for the entities
var entities: Dictionary = {
	"hero": {"name": "Hero", "hp": 25, "max_hp": 25, "mana": 3, "cards_drawn": 0, "side": 0},
	"knight": {"name": "Knight", "atk": 4, "def": 8, "max_def": 8, "side": 0},
	"boss": {"name": "Enemy Boss", "hp": 20, "max_hp": 20, "side": 1},
	"minion": {"name": "Enemy Minion", "atk": 2, "def": 5, "max_def": 5, "side": 1}
}

var selected_target_id: String = "minion"


func _ready() -> void:
	resolver.effect_queued.connect(_on_effect_queued)
	resolver.effect_started.connect(_on_effect_started)
	resolver.effect_applied.connect(_on_effect_applied)
	resolver.queue_empty.connect(_on_queue_empty)

	# Register Thorns reaction on Knight: when damaged, deals 2 damage back
	var thorns = AbilityDefinition.create("ab_thorns", "Thorns", "ON_DAMAGE_TAKEN", [
		EffectData.create_damage(2, EffectData.TargetScope.TARGET_SINGLE)
	])
	resolver.register_trigger_listener(thorns, entities["knight"], 0)

	_update_ui()
	_log("Ability Engine Testbed Ready. Knight has passive Thorns (deals 2 reaction damage when hit).")


func _update_ui() -> void:
	# Update Hero
	var h = entities["hero"]
	hero_card.get_node("VBox/Stats").text = "HP: %d/%d\nMana: %d | Hand: %d" % [h.hp, h.max_hp, h.mana, h.cards_drawn]

	# Update Knight
	var k = entities["knight"]
	knight_card.get_node("VBox/Stats").text = "ATK: %d | DEF: %d/%d" % [k.atk, k.def, k.max_def]

	# Update Boss
	var b = entities["boss"]
	boss_card.get_node("VBox/Stats").text = "HP: %d/%d" % [b.hp, b.max_hp]

	# Update Minion
	var m = entities["minion"]
	minion_card.get_node("VBox/Stats").text = "ATK: %d | DEF: %d/%d" % [m.atk, m.def, m.max_def]

	queue_label.text = "Pending in Queue: %d" % resolver.get_queue_size()


func _on_target_selected(entity_id: String) -> void:
	selected_target_id = entity_id
	_log("Target selected: %s" % entities[entity_id]["name"])


# --- ABILITY BUTTON ACTIONS ---

func _on_btn_fireball_pressed() -> void:
	var target = entities[selected_target_id]
	var dmg_eff = EffectData.create_damage(6, EffectData.TargetScope.TARGET_SINGLE)
	var ab = AbilityDefinition.create("ab_fireball", "🔥 Fireball", "ON_PLAY", [dmg_eff])
	var ctx = EffectContext.create(entities["hero"], 0, 0, [target])

	resolver.enqueue_ability(ab, ctx)
	_log("Queued 🔥 Fireball targeting %s (6 DMG)" % target["name"])
	_update_ui()


func _on_btn_divine_heal_pressed() -> void:
	var heal_eff = EffectData.create_heal(4, EffectData.TargetScope.TARGET_SINGLE)
	var ab = AbilityDefinition.create("ab_heal", "💚 Divine Heal", "ON_PLAY", [heal_eff])
	var friendly_targets = [entities["hero"], entities["knight"]]
	var ctx = EffectContext.create(entities["hero"], 0, 0, friendly_targets)

	resolver.enqueue_ability(ab, ctx)
	_log("Queued 💚 Divine Heal targeting All Friendly (4 HP)")
	_update_ui()


func _on_btn_battle_cry_pressed() -> void:
	var buff_eff = EffectData.create_buff("atk", 2, EffectData.TargetScope.TARGET_SINGLE)
	var ab = AbilityDefinition.create("ab_warcry", "⚔️ Battle Cry", "ON_PLAY", [buff_eff])
	var ctx = EffectContext.create(entities["hero"], 0, 0, [entities["knight"]])

	resolver.enqueue_ability(ab, ctx)
	_log("Queued ⚔️ Battle Cry targeting Knight (+2 ATK)")
	_update_ui()


func _on_btn_stat_swap_pressed() -> void:
	var swap_eff = EffectData.new()
	swap_eff.type = EffectData.EffectType.SWAP_STATS
	swap_eff.stat_name = "atk"
	swap_eff.metadata = {"stat_b": "def"}
	var ab = AbilityDefinition.create("ab_swap", "🔄 Stat Swap", "ON_PLAY", [swap_eff])
	var ctx = EffectContext.create(entities["hero"], 0, 0, [entities["knight"]])

	resolver.enqueue_ability(ab, ctx)
	_log("Queued 🔄 Stat Swap targeting Knight (Swap ATK & DEF)")
	_update_ui()


func _on_btn_arcane_surge_pressed() -> void:
	var res_eff = EffectData.create_resource_gain(2)
	var draw_eff = EffectData.create_draw(2)
	var ab = AbilityDefinition.create("ab_surge", "💎 Arcane Surge", "ON_PLAY", [res_eff, draw_eff])
	var ctx = EffectContext.create(entities["hero"], 0, 0, [entities["hero"]])

	resolver.enqueue_ability(ab, ctx)
	_log("Queued 💎 Arcane Surge (+2 Mana, +2 Cards)")
	_update_ui()


func _on_btn_chain_lightning_pressed() -> void:
	var dmg_eff = EffectData.create_damage(3, EffectData.TargetScope.TARGET_SINGLE)
	var ab = AbilityDefinition.create("ab_lightning", "⚡ Chain Lightning", "ON_PLAY", [dmg_eff])
	var enemy_targets = [entities["boss"], entities["minion"]]
	var ctx = EffectContext.create(entities["hero"], 0, 0, enemy_targets)

	resolver.enqueue_ability(ab, ctx)
	_log("Queued ⚡ Chain Lightning targeting All Enemies (3 DMG each)")
	_update_ui()


func _on_btn_enemy_hit_knight_pressed() -> void:
	# Enemy hits Knight -> triggers Thorns reaction
	var dmg = EffectData.create_damage(3, EffectData.TargetScope.TARGET_SINGLE)
	var ab = AbilityDefinition.create("ab_attack", "Enemy Strike", "ON_ATTACK", [dmg])
	var ctx = EffectContext.create(entities["minion"], 1, 0, [entities["knight"]])

	resolver.enqueue_ability(ab, ctx)
	_log("Enemy attacks Knight! (Will trigger Thorns reaction when resolved)")
	_update_ui()


# --- QUEUE RESOLUTION CONTROLS ---

func _on_btn_step_pressed() -> void:
	if resolver.get_queue_size() > 0:
		resolver._resolve_step()
		_update_ui()


func _on_btn_resolve_all_pressed() -> void:
	resolver.process_queue_async(0.25)


func _on_btn_reset_pressed() -> void:
	entities["hero"] = {"name": "Hero", "hp": 25, "max_hp": 25, "mana": 3, "cards_drawn": 0, "side": 0}
	entities["knight"] = {"name": "Knight", "atk": 4, "def": 8, "max_def": 8, "side": 0}
	entities["boss"] = {"name": "Enemy Boss", "hp": 20, "max_hp": 20, "side": 1}
	entities["minion"] = {"name": "Enemy Minion", "atk": 2, "def": 5, "max_def": 5, "side": 1}
	resolver.clear_queue()
	_update_ui()
	_log("Reset battlefield to original state.")


# --- RESOLVER SIGNAL HANDLERS ---

func _on_effect_queued(effect: Resource, _ctx: RefCounted) -> void:
	_update_ui()


func _on_effect_started(effect: Resource, _ctx: RefCounted) -> void:
	_update_ui()


func _on_effect_applied(effect: Resource, target: Variant, result_value: int) -> void:
	var t_name = target.get("name", "Target") if target is Dictionary else "Target"
	_log("✔ Applied %s to %s (Result: %d)" % [
		EffectData.EffectType.keys()[effect.type], t_name, result_value
	])

	# Check for reaction triggers
	if effect.type == EffectData.EffectType.DAMAGE and target == entities["knight"]:
		# Knight took damage -> trigger Thorns reaction
		_log("⚡ Knight's Thorns triggered! Enqueueing reaction...")
		var reaction_ctx = EffectContext.create(entities["knight"], 0, 0, [entities[selected_target_id]])
		resolver.dispatch_trigger("ON_DAMAGE_TAKEN", entities["knight"], reaction_ctx)

	_update_ui()


func _on_queue_empty() -> void:
	_log("🏁 Effect queue completed.")
	_update_ui()


func _log(msg: String) -> void:
	var time = Time.get_time_string_from_system()
	log_label.append_text("[%s] %s\n" % [time, msg])
