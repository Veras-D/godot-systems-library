extends SceneTree

const CardData = preload("CardData.gd")
const Deck = preload("Deck.gd")
const HandManager = preload("HandManager.gd")
const HandManagerScene = preload("HandManager.tscn")
const GenericCardView = preload("GenericCardView.gd")
const SlotData = preload("res://board_system/SlotData.gd")

func _init() -> void:
	print("==> Running DeckEngine Unit & Regression Tests...")

	# 1. Test CardData
	var card_a = CardData.create("c_01", "Flame Golem", 3, "Creature", "Fire", 6, 8, "Ignites enemy")
	assert(card_a.id == "c_01", "Card ID should match")
	assert(card_a.cost == 3, "Card cost should match")
	assert(card_a.attack == 6, "Card attack should match")
	assert(card_a.defense == 8, "Card defense should match")
	assert(card_a.get_affinity() == "Fire", "CardData get_affinity() should return affinity")
	print("CardData model verified.")

	# 2. Test Deck Operations
	var deck = Deck.new()
	assert(deck.get_total_count() == 0, "Deck should start empty")

	var sample_cards: Array[CardData] = []
	for i in range(12):
		sample_cards.append(CardData.create("card_%02d" % i, "Test Card %d" % i, i % 4, "Creature", "Universal", i, i * 2))

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
	var _remaining = deck.draw(8)
	assert(deck.get_draw_count() == 0, "Draw pile should now be empty")

	# Drawing 2 more should automatically recycle the 4 discarded cards
	var recycled_draw = deck.draw(2, true)
	assert(recycled_draw.size() == 2, "Should draw 2 cards from recycled discard pile")
	assert(deck.get_draw_count() == 2, "Draw pile should have 2 cards remaining after recycling 4 and drawing 2")
	assert(deck.get_discard_count() == 0, "Discard pile should be empty after recycling")
	print("Deck draw, discard, and auto-recycle verified.")

	# 3. Test HandManager & Parabolic Arc Layout
	var hand: HandManager = HandManagerScene.instantiate() as HandManager
	assert(hand != null, "HandManager should instantiate successfully")
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
	hand.queue_free()

	# 4. Test CardData Affinity & Slot Interoperability (Universal Tag & No Magic Fallback)
	var test_card = CardData.create("card_test", "Affinity Test", 1, "Creature", "Fire", 2, 3, "Test", {}, "Dragon")
	assert(test_card.affinity == "Fire", "Affinity should be Fire")
	assert(test_card.get_affinity() == "Fire", "get_affinity() should return Fire")
	assert(test_card.category == "Dragon", "Category should be Dragon")

	# Category must NOT leak into affinity or get_affinity()
	test_card.affinity = ""
	assert(test_card.get_affinity() == "", "get_affinity() must return affinity directly without falling back to category")

	# Test Default Universal Tag on creation
	var default_card = CardData.create("card_def", "Default Card", 1)
	assert(default_card.affinity == CardData.UNIVERSAL_TAG, "Default affinity must be UNIVERSAL_TAG (Universal)")
	assert(default_card.get_affinity() == "Universal", "get_affinity() must return Universal")

	# Test Interoperability with SlotData
	var forest_slot = SlotData.create(0, 0, "Forest")
	assert(forest_slot.can_accept_affinity(default_card.get_affinity()), "Universal card must be accepted on Forest slot")

	var fire_slot = SlotData.create(0, 1, "Fire")
	test_card.affinity = "Fire"
	assert(fire_slot.can_accept_affinity(test_card.get_affinity()), "Fire card must be accepted on Fire slot")
	assert(not forest_slot.can_accept_affinity(test_card.get_affinity()), "Fire card must be rejected on Forest slot")

	var univ_slot = SlotData.create(0, 2, "Universal")
	assert(univ_slot.can_accept_affinity(test_card.get_affinity()), "Universal slot must accept Fire card")
	print("CardData affinity and SlotData interoperability verified.")

	# 5. Test GenericCardView.card_data Setter UI Re-rendering
	var card_view_scene = load("res://deck_engine/GenericCardView.tscn")
	var test_view = card_view_scene.instantiate()
	root.add_child(test_view)

	var card_alpha = CardData.create("c_alpha", "Alpha Wolf", 2, "Creature", "Beast", 3, 2, "Prowls in pack")
	test_view.card_data = card_alpha
	assert(test_view.name_lbl.text == "Alpha Wolf", "Name label must reflect card_alpha name")
	assert(test_view.cost_lbl.text == "2", "Cost label must reflect card_alpha cost")
	assert(test_view.atk_lbl.text == "3", "Atk label must reflect card_alpha atk")
	assert(test_view.def_lbl.text == "2", "Def label must reflect card_alpha def")

	# Reassign card_data after ready and verify instant re-render
	var card_omega = CardData.create("c_omega", "Omega Dragon", 7, "Creature", "Fire", 10, 12, "Scorches sky")
	test_view.card_data = card_omega
	assert(test_view.name_lbl.text == "Omega Dragon", "Name label must re-render immediately on card_data reassignment")
	assert(test_view.cost_lbl.text == "7", "Cost label must re-render immediately on card_data reassignment")
	assert(test_view.atk_lbl.text == "10", "Atk label must re-render immediately on card_data reassignment")
	assert(test_view.def_lbl.text == "12", "Def label must re-render immediately on card_data reassignment")

	# Null card_data clears labels
	test_view.card_data = null
	assert(test_view.name_lbl.text == "", "Name label should be cleared when card_data is set to null")
	test_view.queue_free()
	print("GenericCardView card_data setter UI re-rendering verified.")

	# 6. Test DeckRulesValidator
	var DeckRulesValidator = preload("DeckRulesValidator.gd")
	var validator = DeckRulesValidator.new(10, 25, 4)

	# Test Deck validation (too small)
	var small_deck = ["c1", "c2", "c3"]
	var v_small = validator.validate_deck(small_deck)
	assert(not v_small["valid"], "Deck under 10 cards must be invalid")

	# Test Duplicate limit
	var dup_deck = ["c1", "c1", "c1", "c1", "c1", "c2", "c3", "c4", "c5", "c6"]
	var v_dup = validator.validate_deck(dup_deck)
	assert(not v_dup["valid"], "Deck with > 4 copies must be invalid")

	# Test Valid deck
	var legal_deck = []
	for i in range(15):
		legal_deck.append("card_%d" % i)
	var v_legal = validator.validate_deck(legal_deck)
	assert(v_legal["valid"], "Deck of 15 unique cards must be valid")

	# Test Mana curve histogram
	var curve_cards = [
		{ "cost": 0 }, { "cost": 1 }, { "cost": 1 }, { "cost": 2 },
		{ "cost": 3 }, { "cost": 5 }, { "cost": 8 }
	]
	var curve = DeckRulesValidator.compute_cost_curve(curve_cards, 5)
	assert(curve[0] == 1, "Cost 0 count should be 1")
	assert(curve[1] == 2, "Cost 1 count should be 2")
	assert(curve[2] == 1, "Cost 2 count should be 1")
	assert(curve[5] == 2, "Cost 5+ (5 and 8) grouped into bucket 5 should be 2")

	# Test Card filtering
	var all_cards = [
		{ "id": "card_01", "name": "Fire Imp", "faction": "Fire", "type": "Creature", "cost": 1 },
		{ "id": "card_02", "name": "Water Elemental", "faction": "Water", "type": "Creature", "cost": 3 },
		{ "id": "card_03", "name": "Fireball", "faction": "Fire", "type": "Spell", "cost": 2 }
	]
	var fire_cards = DeckRulesValidator.filter_cards(all_cards, { "faction": "FIRE" })
	assert(fire_cards.size() == 2, "Filtering by faction Fire should return 2 cards")
	var spell_cards = DeckRulesValidator.filter_cards(all_cards, { "type": "SPELL" })
	assert(spell_cards.size() == 1, "Filtering by type Spell should return 1 card")
	print("DeckRulesValidator constraints, curve, and filtering verified.")

	print("==> All DeckEngine Unit & Regression Tests PASSED!")
	quit(0)
