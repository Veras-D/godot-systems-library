class_name SystemEventBus
extends Node

## Universal Decoupled Event Bus for Turn-Based & Card Games.
## Serves as the central broadcaster for gameplay events, allowing UI, audio,
## and ability systems to react without tightly coupling to one another.

signal turn_started(side: int)
signal turn_ended(side: int)
signal phase_changed(phase_name: String)
signal card_drawn(card: Variant, side: int)
signal card_played(card: Variant, side: int, lane: int)
signal unit_summoned(unit: Variant, side: int, lane: int)
signal damage_dealt(source: Variant, target: Variant, amount: int)
signal unit_defeated(unit: Variant, side: int, lane: int)


## Automatically connects standard event signals to an AbilityResolver instance,
## translating game events into ability triggers.
func connect_resolver(resolver: Node) -> void:
	if resolver == null or not resolver.has_method("dispatch_trigger"):
		return

	card_played.connect(func(card: Variant, _side: int, _lane: int):
		resolver.dispatch_trigger("ON_PLAY", card)
	)

	unit_summoned.connect(func(unit: Variant, _side: int, _lane: int):
		resolver.dispatch_trigger("ON_SUMMON", unit)
	)

	turn_started.connect(func(side: int):
		resolver.dispatch_trigger("ON_TURN_START", side)
	)

	turn_ended.connect(func(side: int):
		resolver.dispatch_trigger("ON_TURN_END", side)
	)

	damage_dealt.connect(func(_source: Variant, target: Variant, _amount: int):
		resolver.dispatch_trigger("ON_DAMAGE_TAKEN", target)
	)

	unit_defeated.connect(func(unit: Variant, _side: int, _lane: int):
		resolver.dispatch_trigger("ON_DEATH", unit)
	)
