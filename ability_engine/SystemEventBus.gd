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
func connect_resolver(resolver: Object) -> void:
	if resolver == null or not resolver.has_method("dispatch_trigger"):
		return

	card_played.connect(func(card: Variant, _side: int, _lane: int):
		resolver.dispatch_trigger("ON_PLAY", card)
	)

	card_drawn.connect(func(card: Variant, _side: int):
		resolver.dispatch_trigger("ON_DRAW", card)
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

	var on_slot_drop = func(slot, data):
		var side: int = 0
		var lane: int = 0
		if slot != null:
			if "slot_data" in slot and slot.slot_data != null:
				side = slot.slot_data.side
				lane = slot.slot_data.lane_index
			elif "side" in slot:
				side = slot.side
				lane = slot.lane if "lane" in slot else 0

		# Extract unit if data is wrapped in a drag-and-drop dictionary
		var unit = data
		if data is Dictionary and data.has("card_data"):
			unit = data.get("card_data")

		unit_summoned.emit(unit, side, lane)

	if grid.has_signal("occupant_dropped_on_slot"):
		grid.connect("occupant_dropped_on_slot", on_slot_drop)
	elif grid.has_signal("slot_dropped"):
		grid.connect("slot_dropped", on_slot_drop)

	if grid.has_signal("slot_damage_shaken"):
		grid.connect("slot_damage_shaken", func(slot, intensity):
			damage_dealt.emit(null, slot, int(intensity))
		)


## Automatically bridges a HandManager's signals to this bus
func bind_hand_manager(hand: Node, player_side: int = 0) -> void:
	if hand == null:
		return

	var unwrap = func(card_or_view: Variant) -> Variant:
		if card_or_view is Object and "card_data" in card_or_view and card_or_view.card_data != null:
			return card_or_view.card_data
		return card_or_view

	if hand.has_signal("card_played"):
		hand.connect("card_played", func(card):
			card_played.emit(unwrap.call(card), player_side, -1)
		)
	elif hand.has_signal("card_clicked"):
		hand.connect("card_clicked", func(card_view):
			card_played.emit(unwrap.call(card_view), player_side, -1)
		)

	if hand.has_signal("card_drawn"):
		hand.connect("card_drawn", func(card):
			card_drawn.emit(unwrap.call(card), player_side)
		)
	elif hand.has_signal("card_added"):
		hand.connect("card_added", func(card_view):
			card_drawn.emit(unwrap.call(card_view), player_side)
		)
