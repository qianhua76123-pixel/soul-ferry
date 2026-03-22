extends Node

## DeckManager.gd - 牌库/手牌/弃牌堆管理

signal card_drawn(card: Dictionary)
signal card_played(card: Dictionary)
signal card_discarded(card: Dictionary, is_forced: bool)  # is_forced=false 主动, true 被动/强制
signal hand_updated(hand: Array)
signal deck_shuffled()
signal hand_full()
signal cost_changed(new_cost: int)   # 费用变化（供 EnergyDisplay 使用）

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
		var c: Dictionary = CardDatabase.get_card(cid)
		if not c.is_empty(): deck.append(c)
	shuffle_deck()

func init_starter_deck() -> void:
	var char_id: String = str(GameState.get_meta("selected_character", "ruan_ruyue"))
	match char_id:
		"ruan_ruyue":
			init_deck([
				"zhenhunfu","zhenhunfu",
				"hun_po_lie","hun_po_lie",
				"lei_shang","lei_shang",
				"podan","jue_liao_ling",
				"hong_chen_yi_xiao","ku_sha",
			])
		"shen_tiejun":
			init_deck([
				"tie_qu","tie_qu",
				"tiejia_futi","tiejia_futi",
				"hun_po_lie","hun_po_lie",
				"lei_shang","lei_shang",
				"jue_liao_ling","ku_sha",
			])
		"wumian":
			init_deck([
				"kong_shou","kong_shou",
				"wu_wei","wu_wei",
				"jie_qing","jie_qing",
				"xu_shi_hu_huan","xu_shi_hu_huan",
				"hun_po_lie","lei_shang",
			])
		_:
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
	var c: Dictionary = deck.pop_back()
	hand.append(c)
	card_drawn.emit(c)
	hand_updated.emit(hand)

func draw_cards(count: int) -> void:
	for _i in count: draw_card()

func on_turn_start() -> void:
	max_cost = BASE_COST - EmotionManager.get_cost_reduction()
	current_cost = max_cost
	cost_changed.emit(current_cost)
	reset_discard_limit()
	var draw_n: int = BASE_DRAW + EmotionManager.get_draw_bonus()
	if EmotionManager.is_disorder("fear"): draw_n -= 1
	draw_cards(maxi(1, draw_n))

func on_turn_end() -> void:
	for c in hand.duplicate():
		discard_from_hand(c, true)  # 回合结束自动弃牌=强制

func play_card(card: Dictionary) -> bool:
	var idx: int = -1
	for i in len(hand):
		if hand[i].get("id","") == card.get("id",""):
			idx = i; break
	if idx < 0: return false
	var cost: int = maxi(0, card.get("cost", 0) - EmotionManager.get_cost_reduction())
	if current_cost < cost: return false
	if not EmotionManager.can_play_card(card): return false
	hand.remove_at(idx)
	current_cost -= cost
	cost_changed.emit(current_cost)   # 更新费用圆点
	# 应用情绪偏移
	var shift: Dictionary = card.get("emotion_shift", {})
	if not shift.is_empty():
		EmotionManager.apply_shift(shift)
	if card.get("exhaust", false):
		exhaust_pile.append(card)
	else:
		discard_pile.append(card)
	card_played.emit(card)
	hand_updated.emit(hand)
	return true

## 每回合可主动弃牌次数（遗物/牌效可修改）
var active_discard_limit: int = 1
var active_discard_used:  int = 0

func reset_discard_limit() -> void:
	active_discard_used = 0

func can_active_discard() -> bool:
	return active_discard_used < active_discard_limit

func active_discard(card: Dictionary) -> void:
	## 主动弃牌（玩家手动点击「弃牌」按钮），每回合有次数限制
	if not can_active_discard(): return
	active_discard_used += 1
	discard_from_hand(card, false)  # is_forced=false

func discard_from_hand(card: Dictionary, is_forced: bool = true) -> void:
	var idx: int = hand.find(card)
	if idx >= 0:
		hand.remove_at(idx)
		discard_pile.append(card)
		card_discarded.emit(card, is_forced)
	hand_updated.emit(hand)

func discard_random() -> void:
	if hand.is_empty(): return
	discard_from_hand(hand[randi() % len(hand)], true)  # 被动弃牌=强制

func discard_hand() -> void:
	## 整手弃牌（一念牌等）
	for card in hand.duplicate():
		discard_from_hand(card, true)

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

func replace_card(card_id: String, new_card: Dictionary) -> void:
	## 用新卡数据替换牌组中第一张匹配的牌（升级/锻造后更新）
	for arr in [deck, hand, discard_pile, exhaust_pile]:
		for i in arr.size():
			if arr[i].get("id", "") == card_id:
				arr[i] = new_card.duplicate(true)
				if arr == hand:
					hand_updated.emit(hand)
				return
