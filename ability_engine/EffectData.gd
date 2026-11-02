class_name EffectData
extends Resource

## Data contract for a single discrete effect or action.
## Decoupled: specifies what should happen and to whom, not the game-specific visuals.

enum EffectType {
	DAMAGE,          # Deals damage to target DEF / HP
	HEAL,            # Restores HP / DEF
	BUFF_STAT,       # Adds or subtracts from an attribute (ATK, DEF, ARMOR, SPEED)
	GAIN_RESOURCE,   # Adds player resource (Magic, Mana, Energy, Gold)
	DRAW_CARD,       # Draws N cards into hand
	DISCARD_CARD,    # Discards N cards from hand
	DESTROY,         # Instantly destroys target entity
	SWAP_STATS,      # Swaps two stats (e.g. ATK and DEF)
	CUSTOM           # Delegates to a custom Callable / script handler
}

enum TargetScope {
	SELF,                # The entity casting or triggering the ability
	TARGET_SINGLE,       # A single chosen target
	ALL_FRIENDLY,        # All friendly units on the caster's side
	ALL_ENEMY,           # All enemy units on the opposing side
	ADJACENT_FRIENDLY,   # Left and right neighboring units
	OPPOSING_LANE,       # The directly opposite enemy lane
	RANDOM_ENEMY,        # N random enemy targets
	ALL_UNITS            # Every unit on the board
}

@export var type: EffectType = EffectType.DAMAGE
@export var target_scope: TargetScope = TargetScope.TARGET_SINGLE
@export var amount: int = 0
@export var stat_name: String = ""             # Target stat for BUFF_STAT / SWAP_STATS (e.g. "atk", "def")
@export var duration_turns: int = 0           # 0 = permanent / instant, >0 = temporary turns
@export var metadata: Dictionary = {}          # Arbitrary custom parameters
@export var custom_handler_id: String = ""    # For CUSTOM type handlers


static func create_damage(p_amount: int, p_target: TargetScope = TargetScope.TARGET_SINGLE) -> Resource:
	var eff = new()
	eff.type = EffectType.DAMAGE
	eff.amount = p_amount
	eff.target_scope = p_target
	return eff


static func create_heal(p_amount: int, p_target: TargetScope = TargetScope.SELF) -> Resource:
	var eff = new()
	eff.type = EffectType.HEAL
	eff.amount = p_amount
	eff.target_scope = p_target
	return eff


static func create_buff(
	p_stat: String,
	p_amount: int,
	p_target: TargetScope = TargetScope.SELF,
	p_duration: int = 0
) -> Resource:
	var eff = new()
	eff.type = EffectType.BUFF_STAT
	eff.stat_name = p_stat
	eff.amount = p_amount
	eff.target_scope = p_target
	eff.duration_turns = p_duration
	return eff


static func create_resource_gain(p_amount: int) -> Resource:
	var eff = new()
	eff.type = EffectType.GAIN_RESOURCE
	eff.amount = p_amount
	eff.target_scope = TargetScope.SELF
	return eff


static func create_draw(p_count: int) -> Resource:
	var eff = new()
	eff.type = EffectType.DRAW_CARD
	eff.amount = p_count
	eff.target_scope = TargetScope.SELF
	return eff


static func create_discard(p_count: int, p_target: TargetScope = TargetScope.SELF) -> Resource:
	var eff = new()
	eff.type = EffectType.DISCARD_CARD
	eff.amount = p_count
	eff.target_scope = p_target
	return eff


func to_string_summary() -> String:
	match type:
		EffectType.DAMAGE:
			return "Deal %d Damage to %s" % [amount, TargetScope.keys()[target_scope]]
		EffectType.HEAL:
			return "Heal %d to %s" % [amount, TargetScope.keys()[target_scope]]
		EffectType.BUFF_STAT:
			var prefix = "+" if amount > 0 else ""
			return "%s%d %s to %s" % [prefix, amount, stat_name.to_upper(), TargetScope.keys()[target_scope]]
		EffectType.GAIN_RESOURCE:
			return "Gain %d Resource" % amount
		EffectType.DRAW_CARD:
			return "Draw %d Cards" % amount
		EffectType.DISCARD_CARD:
			return "Discard %d Cards from %s" % [amount, TargetScope.keys()[target_scope]]
		EffectType.DESTROY:
			return "Destroy %s" % TargetScope.keys()[target_scope]
		_:
			return "%s (Amount: %d)" % [EffectType.keys()[type], amount]
