class_name DeckRulesValidator
extends RefCounted

## Universal Deck Construction & Constraint Validator
##
## Provides decoupled deck rules checking (min/max size, duplicate limits, ownership limits),
## cost/mana curve histogram calculation, and card collection querying/filtering.

var min_deck_size: int = 10
var max_deck_size: int = 25
var max_copies_per_card: int = 4

func _init(min_size: int = 10, max_size: int = 25, max_copies: int = 4) -> void:
	min_deck_size = min_size
	max_deck_size = max_size
	max_copies_per_card = max_copies


## Validates an array of card IDs (or card dictionaries/objects) against rules.
## Returns { "valid": bool, "errors": Array[String], "card_count": int, "counts_by_id": Dictionary }
func validate_deck(
	cards: Array,
	owned_counts: Dictionary = {},
	enforce_ownership: bool = false
) -> Dictionary:
	var errors: Array[String] = []
	var counts_by_id: Dictionary = {}

	for raw in cards:
		var cid = _extract_id(raw)
		if cid == "":
			continue
		counts_by_id[cid] = counts_by_id.get(cid, 0) + 1

	var total_cards = cards.size()
	if total_cards < min_deck_size:
		errors.append("Deck has %d cards (minimum is %d)." % [total_cards, min_deck_size])
	elif total_cards > max_deck_size:
		errors.append("Deck has %d cards (maximum is %d)." % [total_cards, max_deck_size])

	for cid in counts_by_id.keys():
		var count: int = counts_by_id[cid]
		if count > max_copies_per_card:
			errors.append("Too many copies of '%s' (%d/%d max)." % [cid, count, max_copies_per_card])
		if enforce_ownership and not owned_counts.is_empty():
			var owned = int(owned_counts.get(cid, 0))
			if count > owned:
				errors.append("Not enough owned copies of '%s' (%d in deck, %d owned)." % [cid, count, owned])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"card_count": total_cards,
		"counts_by_id": counts_by_id
	}


## Checks if a card can be added to an existing deck array.
## Returns { "can_add": bool, "reason": String }
func can_add_card(
	cards: Array,
	card_id: String,
	owned_counts: Dictionary = {},
	enforce_ownership: bool = false
) -> Dictionary:
	if cards.size() >= max_deck_size:
		return {
			"can_add": false,
			"reason": "Deck is full (%d/%d cards)." % [cards.size(), max_deck_size]
		}

	var current_copies: int = 0
	for raw in cards:
		if _extract_id(raw) == card_id:
			current_copies += 1

	if current_copies >= max_copies_per_card:
		return {
			"can_add": false,
			"reason": "Max %d copies reached (%d/%d)." % [max_copies_per_card, current_copies, max_copies_per_card]
		}

	if enforce_ownership and not owned_counts.is_empty():
		var owned = int(owned_counts.get(card_id, 0))
		if current_copies >= owned:
			return {
				"can_add": false,
				"reason": "All owned copies (%d) are already in deck." % owned
			}

	return {
		"can_add": true,
		"reason": ""
	}


## Computes a cost/mana curve histogram across card data entries.
## card_items can be Array of CardData, Dictionaries with "cost", or custom callables.
## max_bin defines the highest bucket (costs >= max_bin will be grouped).
## Returns Dictionary { 0: int, 1: int, ..., max_bin: int }
static func compute_cost_curve(card_items: Array, max_bin: int = 5) -> Dictionary:
	var curve: Dictionary = {}
	for b in range(max_bin + 1):
		curve[b] = 0

	for item in card_items:
		var cost = _extract_cost(item)
		var bin_key = mini(maxi(0, cost), max_bin)
		curve[bin_key] = curve.get(bin_key, 0) + 1

	return curve


## Filters a list of card items (Dictionaries or Objects) by criteria.
## filter_criteria:
## {
##   "search": String (matches name or ID),
##   "faction": String,
##   "type": String,
##   "cost": int (-1 for any),
##   "min_cost": int,
##   "max_cost": int
## }
static func filter_cards(card_items: Array, criteria: Dictionary) -> Array:
	var search_term = str(criteria.get("search", "")).strip_edges().to_lower()
	var faction = str(criteria.get("faction", "ALL")).to_upper()
	var card_type = str(criteria.get("type", "ALL")).to_upper()
	var target_cost = int(criteria.get("cost", -1))
	var min_cost = int(criteria.get("min_cost", -1))
	var max_cost = int(criteria.get("max_cost", -1))

	var filtered: Array = []
	for item in card_items:
		var cid = _extract_id(item).to_lower()
		var cname = _extract_field(item, "name", cid).to_lower()
		var cfaction = _extract_field(item, "faction", _extract_field(item, "landscape", "")).to_upper()
		var ctype = _extract_field(item, "type", "").to_upper()
		var ccost = _extract_cost(item)

		# Search text
		if search_term != "" and not (search_term in cid or search_term in cname):
			continue

		# Faction / Landscape
		if faction != "ALL" and faction != "" and cfaction != faction:
			continue

		# Type
		if card_type != "ALL" and card_type != "" and ctype != card_type:
			continue

		# Exact Cost
		if target_cost >= 0 and ccost != target_cost:
			continue

		# Cost Range
		if min_cost >= 0 and ccost < min_cost:
			continue
		if max_cost >= 0 and ccost > max_cost:
			continue

		filtered.append(item)

	return filtered


static func _extract_id(item: Variant) -> String:
	if typeof(item) == TYPE_STRING or typeof(item) == TYPE_STRING_NAME:
		return str(item).strip_edges()
	elif typeof(item) == TYPE_DICTIONARY:
		return str(item.get("id", item.get("card_id", ""))).strip_edges()
	elif item is Object:
		if "id" in item:
			return str(item.id).strip_edges()
	return ""


static func _extract_cost(item: Variant) -> int:
	if typeof(item) == TYPE_DICTIONARY:
		return int(item.get("cost", item.get("mp_cost", 0)))
	elif item is Object:
		if "cost" in item:
			return int(item.cost)
	return 0


static func _extract_field(item: Variant, field_name: String, default_val: String = "") -> String:
	if typeof(item) == TYPE_DICTIONARY:
		return str(item.get(field_name, default_val))
	elif item is Object:
		if field_name in item:
			return str(item.get(field_name))
	return default_val
