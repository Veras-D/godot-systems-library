class_name Deck
extends RefCounted

const CardData = preload("CardData.gd")

# Universal Deck Engine
# Manages draw pile, discard pile (graveyard), and banished pile with zero game coupling.

signal card_drawn(card: CardData)
signal card_discarded(card: CardData)
signal card_banished(card: CardData)
signal discard_recycled(count: int)
signal deck_shuffled

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var banish_pile: Array[CardData] = []

func add_card(card: CardData, to_top: bool = false) -> void:
	if card == null:
		return
	if to_top:
		draw_pile.push_front(card)
	else:
		draw_pile.append(card)

func add_cards(cards: Array[CardData], shuffle_after: bool = false) -> void:
	for c in cards:
		if c != null:
			draw_pile.append(c)
	if shuffle_after:
		shuffle()

func shuffle() -> void:
	# Fisher-Yates shuffle
	var n = draw_pile.size()
	for i in range(n - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = temp
	deck_shuffled.emit()

func draw_one(auto_recycle_discard: bool = true) -> CardData:
	if draw_pile.is_empty():
		if auto_recycle_discard and not discard_pile.is_empty():
			recycle_discard_into_draw(true)
		else:
			return null

	if draw_pile.is_empty():
		return null

	var card = draw_pile.pop_back()
	card_drawn.emit(card)
	return card

func draw(count: int, auto_recycle_discard: bool = true) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for _i in range(count):
		var card = draw_one(auto_recycle_discard)
		if card != null:
			drawn.append(card)
		else:
			break
	return drawn

func discard(card: CardData) -> void:
	if card == null:
		return
	discard_pile.append(card)
	card_discarded.emit(card)

func banish(card: CardData) -> void:
	if card == null:
		return
	banish_pile.append(card)
	card_banished.emit(card)

func recycle_discard_into_draw(shuffle_after: bool = true) -> void:
	if discard_pile.is_empty():
		return
	var recycled_count = discard_pile.size()
	for c in discard_pile:
		draw_pile.append(c)
	discard_pile.clear()

	if shuffle_after:
		shuffle()
	discard_recycled.emit(recycled_count)

func peek(count: int = 1) -> Array[CardData]:
	var peeked: Array[CardData] = []
	var limit = min(count, draw_pile.size())
	for i in range(draw_pile.size() - 1, draw_pile.size() - 1 - limit, -1):
		peeked.append(draw_pile[i])
	return peeked

func get_draw_count() -> int:
	return draw_pile.size()

func get_discard_count() -> int:
	return discard_pile.size()

func get_banish_count() -> int:
	return banish_pile.size()

func get_total_count() -> int:
	return draw_pile.size() + discard_pile.size() + banish_pile.size()

func clear() -> void:
	draw_pile.clear()
	discard_pile.clear()
	banish_pile.clear()
