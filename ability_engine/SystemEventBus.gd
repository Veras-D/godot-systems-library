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


## Automatically bridges a BoardGrid's signals to this bus
func bind_board_grid(grid: Node) -> void:
	if grid == null:
		return

	if grid.has_signal("slot_dropped"):
		grid.connect("slot_dropped", func(slot, data):
			var side = slot.slot_data.side if slot and "slot_data" in slot and slot.slot_data else 0
			var lane = slot.slot_data.lane_index if slot and "slot_data" in slot and slot.slot_data else 0
			unit_summoned.emit(data, side, lane)
		)

	if grid.has_signal("slot_damage_shaken"):
		grid.connect("slot_damage_shaken", func(slot, intensity):
			damage_dealt.emit(null, slot, int(intensity))
		)


## Automatically bridges a HandManager's signals to this bus
func bind_hand_manager(hand: Node, player_side: int = 0) -> void:
	if hand == null:
		return

	if hand.has_signal("card_played"):
		hand.connect("card_played", func(card):
			card_played.emit(card, player_side, -1)
		)

	if hand.has_signal("card_drawn"):
		hand.connect("card_drawn", func(card):
			card_drawn.emit(card, player_side)
		)
