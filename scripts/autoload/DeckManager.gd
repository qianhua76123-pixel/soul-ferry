extends Node

## DeckManager.gd - 牌库/手牌/弃牌堆管理

signal card_drawn(card: Dictionary)
signal card_played(card: Dictionary)
signal card_discarded(card: Dictionary)
signal hand_updated(hand: Array)
signal deck_shuffled()
signal hand_full()

const MAX_HAND_SIZE  = 10
const BASE_DRAW      = 5
const BASE_COST      = 3

var deck:         Array = []
var hand:         Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []
var current_cost: int  = 0
var max_cost:     int  = BASE_COST

func _ready() -> void:
	pass

func init_deck(card_ids: Array) -> void:
	deck = []; hand = []; discard_pile = []; exhaust_pile = []
	for cid in card_ids:
		var c = CardDatabase.get_card(cid)
		if not c.is_empty(): deck.append(c)
	shuffle_deck()

func init_starter_deck() -> void:
	init_deck([
		"zhenhunfu","zhenhunfu",
		"hun_po_lie","hun_po_lie",
		"lei_shang","lei_shang",
		"podan","jue_liao_ling",
		"hong_chen_yi_xiao","ku_sha",
	])

func get_total_card_count() -> int:
	return len(deck) + len(hand) + len(discard_pile) + len(exhaust_pile)

func get_full_deck() -> Array:
	var all = []
	all.append_array(deck); all.append_array(hand)
	all.append_array(discard_pile)
	return all

func shuffle_deck() -> void:
	deck.shuffle()
	deck_shuffled.emit()

func draw_card() -> void:
	if len(hand) >= MAX_HAND_SIZE:
		hand_full.emit(); return
	if deck.is_empty():
		if discard_pile.is_empty(): return
		deck = discard_pile.duplicate(); discard_pile = []; shuffle_deck()
	if deck.is_empty(): return
	var c = deck.pop_back()
	hand.append(c)
	card_drawn.emit(c)
	hand_updated.emit(hand)

func draw_cards(count: int) -> void:
	for _i in count: draw_card()

func on_turn_start() -> void:
	max_cost = BASE_COST - EmotionManager.get_cost_reduction()
	current_cost = max_cost
	var draw_n = BASE_DRAW + EmotionManager.get_draw_bonus()
	if EmotionManager.is_disorder("fear"): draw_n -= 1
	draw_cards(max(1, draw_n))

func on_turn_end() -> void:
	for c in hand.duplicate():
		discard_from_hand(c)

func play_card(card: Dictionary) -> bool:
	var idx = -1
	for i in len(hand):
		if hand[i].get("id","") == card.get("id",""):
			idx = i; break
	if idx < 0: return false
	var cost = max(0, card.get("cost", 0) - EmotionManager.get_cost_reduction())
	if current_cost < cost: return false
	if not EmotionManager.can_play_card(card): return false
	hand.remove_at(idx)
	current_cost -= cost
	# 应用情绪偏移
	var shift = card.get("emotion_shift", {})
	if not shift.is_empty():
		EmotionManager.apply_shift(shift)
	if card.get("exhaust", false):
		exhaust_pile.append(card)
	else:
		discard_pile.append(card)
	card_played.emit(card)
	hand_updated.emit(hand)
	return true

func discard_from_hand(card: Dictionary) -> void:
	var idx = hand.find(card)
	if idx >= 0:
		hand.remove_at(idx)
		discard_pile.append(card)
		card_discarded.emit(card)
	hand_updated.emit(hand)

func discard_random() -> void:
	if hand.is_empty(): return
	discard_from_hand(hand[randi() % len(hand)])

func add_card_to_deck(card: Dictionary) -> void:
	deck.append(card.duplicate(true))
	shuffle_deck()

func remove_card_from_deck(card_id: String) -> bool:
	for i in len(deck):
		if deck[i].get("id","") == card_id:
			deck.remove_at(i); return true
	for i in len(discard_pile):
		if discard_pile[i].get("id","") == card_id:
			discard_pile.remove_at(i); return true
	return false
