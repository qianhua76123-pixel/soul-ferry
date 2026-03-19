extends Node

## DeckManager.gd - 牌库/手牌/弃牌堆管理

signal card_drawn(card: Dictionary)
signal card_played(card: Dictionary)
signal card_discarded(card: Dictionary)
signal hand_updated(hand: Array)
signal deck_shuffled()
signal hand_full()

const MAX_HAND_SIZE = 10
const BASE_DRAW_COUNT = 5
const BASE_COST_PER_TURN = 3

var deck: Array = []
var hand: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []
var current_cost: int = 0
var max_cost: int = BASE_COST_PER_TURN

func _ready() -> void:
	pass

func init_deck(card_ids: Array) -> void:
	deck = []
	hand = []
	discard_pile = []
	exhaust_pile = []
	for card_id in card_ids:
		var card = CardDatabase.get_card(card_id)
		if not card.is_empty():
			deck.append(card.duplicate(true))
	shuffle_deck()

func init_starter_deck() -> void:
	init_deck([
		"zhenhunfu", "zhenhunfu",
		"hun_po_lie", "hun_po_lie",
		"lei_shang",  "lei_shang",
		"podan",
		"jue_liao_ling",
		"hong_chen_yi_xiao",
		"ku_sha",
	])

func on_turn_start() -> void:
	max_cost = BASE_COST_PER_TURN - EmotionManager.get_cost_reduction()
	current_cost = max_cost
	var draw_count = BASE_DRAW_COUNT
	if EmotionManager.is_disorder("fear"):
		draw_count -= 1
	for i in draw_count:
		draw_card()

func on_turn_end() -> void:
	for card in hand.duplicate():
		discard_from_hand(card)

func draw_card() -> Dictionary:
	if len(hand) >= MAX_HAND_SIZE:
		emit_signal("hand_full")
		return {}
	if len(deck) == 0:
		if len(discard_pile) == 0:
			return {}
		reshuffle_discard()
	var card = deck.pop_back()
	hand.append(card)
	emit_signal("card_drawn", card)
	emit_signal("hand_updated", hand)
	return card

func draw_cards(count: int) -> void:
	var actual = count + EmotionManager.get_draw_bonus()
	for i in actual:
		draw_card()

func play_card(card: Dictionary) -> bool:
	if not card in hand:
		return false
	var cost = max(0, card.get("cost", 0) - EmotionManager.get_cost_reduction())
	if current_cost < cost:
		return false
	if not EmotionManager.can_play_card(card):
		return false
	current_cost -= cost
	hand.erase(card)
	EmotionManager.apply_shift(card.get("emotion_shift", {}))
	if card.get("rarity", "") == "legendary":
		exhaust_pile.append(card)
	else:
		discard_pile.append(card)
	emit_signal("card_played", card)
	emit_signal("hand_updated", hand)
	return true

func discard_from_hand(card: Dictionary) -> void:
	if card in hand:
		hand.erase(card)
		discard_pile.append(card)
		emit_signal("card_discarded", card)
		emit_signal("hand_updated", hand)

func discard_random() -> void:
	if len(hand) == 0:
		return
	discard_from_hand(hand[randi() % len(hand)])

func shuffle_deck() -> void:
	deck.shuffle()
	emit_signal("deck_shuffled")

func reshuffle_discard() -> void:
	deck = discard_pile.duplicate()
	discard_pile = []
	shuffle_deck()

func add_card_to_deck(card: Dictionary) -> void:
	deck.insert(0, card)

func add_card_to_hand(card: Dictionary) -> void:
	if len(hand) < MAX_HAND_SIZE:
		hand.append(card)
		emit_signal("hand_updated", hand)

func remove_card_from_deck(card_id: String) -> bool:
	for i in len(deck):
		if deck[i].get("id", "") == card_id:
			deck.remove_at(i)
			return true
	for i in len(discard_pile):
		if discard_pile[i].get("id", "") == card_id:
			discard_pile.remove_at(i)
			return true
	return false

func get_full_deck() -> Array:
	return deck + discard_pile + hand

func get_total_card_count() -> int:
	return len(deck) + len(discard_pile) + len(hand)
