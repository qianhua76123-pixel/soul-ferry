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
const BASE_DRAW_FIRST = 4   # 第一回合抽4张
const BASE_DRAW       = 3   # 后续每回合抽3张
const BASE_COST      = 3

var deck:         Array = []
var hand:         Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []
var current_cost: int  = 0
var max_cost:     int  = BASE_COST
var _is_first_turn: bool = true   # 标记是否第一回合

func _ready() -> void:
	pass

func init_deck(card_ids: Array) -> void:
	deck = []; hand = []; discard_pile = []; exhaust_pile = []
	_is_first_turn = true  # 重置第一回合标记（每次初始化牌组时确保正确）
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

func on_battle_start() -> void:
	## 每场战斗开始时重置牌堆状态
	## 注意：不重置 deck 本身（保留玩家构建的牌组）
	## 而是把所有牌（手牌+弃牌堆+消耗堆）归回抽牌堆
	for c in hand:
		deck.append(c)
	for c in discard_pile:
		deck.append(c)
	# exhaust_pile 不归还（已消耗的牌永久离场）
	hand.clear()
	discard_pile.clear()
	shuffle_deck()
	current_cost  = BASE_COST
	max_cost      = BASE_COST
	_is_first_turn = true
	# active_discard_used/limit 已随主动弃牌功能一同删除
	cost_changed.emit(current_cost)

func on_turn_start() -> void:
	max_cost = BASE_COST - EmotionManager.get_cost_reduction()
	current_cost = max_cost
	cost_changed.emit(current_cost)
	# reset_discard_limit() 已随主动弃牌功能删除
	# ── 抽卡数量计算（来源说明）──────────────────────────────────
	# 第一回合基础：BASE_DRAW_FIRST（4张）；后续每回合：BASE_DRAW（3张）
	# + EmotionManager.get_draw_bonus()：情绪奖励（如惧主导时返回+2，合计5张）
	# - 1：若惧失调则再减1
	# 最终保证至少抽1张（maxi 保底）
	var base_draw: int = BASE_DRAW_FIRST if _is_first_turn else BASE_DRAW
	var draw_bonus: int = EmotionManager.get_draw_bonus()  # 情绪加成（惧主导+2等）
	var draw_n: int = base_draw + draw_bonus
	if EmotionManager.is_disorder("fear"):
		draw_n -= 1  # 惧失调：减1张（但不低于最终保底）
	draw_cards(maxi(1, draw_n))
	_is_first_turn = false

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

## 主动弃牌功能已删除（保留被动弃牌：discard_from_hand / discard_random / card_discarded 信号）
## DiscardSystem 依赖 card_discarded 信号，不可删除

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

func remove_card(card: Dictionary) -> void:
	## 从完整牌组中永久移除一张牌（按 id 匹配，跨 deck/hand/discard_pile）
	var card_id: String = card.get("id", "")
	for arr: Array in [deck, hand, discard_pile, exhaust_pile]:
		for i: int in range(arr.size()):
			if arr[i].get("id", "") == card_id:
				arr.remove_at(i)
				return

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
