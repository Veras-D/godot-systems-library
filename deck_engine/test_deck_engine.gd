extends SceneTree

const CardData = preload("CardData.gd")
const Deck = preload("Deck.gd")
const HandManager = preload("HandManager.gd")
const GenericCardView = preload("GenericCardView.gd")

func _init() -> void:
	print("==> Running DeckEngine Unit & Regression Tests...")

	# 1. Test CardData
	var card_a = CardData.create("c_01", "Flame Golem", 3, "Creature", "Fire", 6, 8, "Ignites enemy")
	assert(card_a.id == "c_01", "Card ID should match")
	assert(card_a.cost == 3, "Card cost should match")
	assert(card_a.attack == 6, "Card attack should match")
	assert(card_a.defense == 8, "Card defense should match")
	print("CardData model verified.")

	# 2. Test Deck Operations
	var deck = Deck.new()
	assert(deck.get_total_count() == 0, "Deck should start empty")

	var sample_cards: Array[CardData] = []
	for i in range(12):
		sample_cards.append(CardData.create("card_%02d" % i, "Test Card %d" % i, i % 4, "Creature", "Neutral", i, i * 2))

	deck.add_cards(sample_cards)
	assert(deck.get_draw_count() == 12, "Draw pile should contain 12 cards")

	# Test Draw
	var drawn_cards = deck.draw(4)
	assert(drawn_cards.size() == 4, "Should draw exactly 4 cards")
	assert(deck.get_draw_count() == 8, "Draw pile should now have 8 cards")

	# Test Discard
	for c in drawn_cards:
		deck.discard(c)
	assert(deck.get_discard_count() == 4, "Discard pile should have 4 cards")

	# Test Draw Pile Exhaustion & Discard Recycling
	var remaining = deck.draw(8)
	assert(deck.get_draw_count() == 0, "Draw pile should now be empty")

	# Drawing 2 more should automatically recycle the 4 discarded cards
	var recycled_draw = deck.draw(2, true)
	assert(recycled_draw.size() == 2, "Should draw 2 cards from recycled discard pile")
	assert(deck.get_draw_count() == 2, "Draw pile should have 2 cards remaining after recycling 4 and drawing 2")
	assert(deck.get_discard_count() == 0, "Discard pile should be empty after recycling")
	print("Deck draw, discard, and auto-recycle verified.")

	# 3. Test HandManager & Parabolic Arc Layout
	var hand_scene = load("res://deck_engine/HandManager.tscn")
	assert(hand_scene != null, "HandManager scene should load")

	var hand: HandManager = hand_scene.instantiate() as HandManager
	root.add_child(hand)
	hand.custom_minimum_size = Vector2(800, 220)

	# Add 5 cards to hand
	for i in range(5):
		hand.add_card(sample_cards[i])

	assert(hand.get_card_count() == 5, "Hand should have 5 cards")

	# Verify layout math
	var cards = hand.get_cards()
	# Card 0 (leftmost) should have negative rotation (tilted left)
	assert(cards[0].home_rotation < 0.0, "Leftmost card should tilt counter-clockwise")
	# Card 2 (center) should have near 0 rotation
	assert(abs(cards[2].home_rotation) < 0.05, "Center card should have near-zero rotation")
	# Card 4 (rightmost) should have positive rotation (tilted right)
	assert(cards[4].home_rotation > 0.0, "Rightmost card should tilt clockwise")

	# Verify parabolic arc: center card Y should be higher (smaller Y coordinate) than edge cards
	assert(cards[2].home_position.y < cards[0].home_position.y, "Center card should sit higher on screen than edge cards")
	assert(cards[2].home_position.y < cards[4].home_position.y, "Center card should sit higher on screen than edge cards")
	print("Parabolic arc & fan rotation verified.")

	# Test removing card
	var removed_card = cards[1]
	hand.remove_card(removed_card)
	assert(hand.get_card_count() == 4, "Hand should have 4 cards after removal")

	# Clean up
	hand.free()
	print("==> All DeckEngine Unit & Regression Tests PASSED!")
	quit(0)
