extends Node

## DeckManager.gd - 牌库/手牌/弃牌堆管理器
## 管理牌库的洗牌、摸牌、出牌、弃牌全流程

class_name DeckManager

# ========== 信号 ==========
signal card_drawn(card: Dictionary)
signal card_played(card: Dictionary)
signal card_discarded(card: Dictionary)
signal hand_updated(hand: Array)
signal deck_shuffled()
signal hand_full()

# ========== 常量 ==========
const MAX_HAND_SIZE = 10
const BASE_DRAW_COUNT = 5  # 每回合起手牌数
const BASE_COST_PER_TURN = 3  # 每回合费用

# ========== 牌库状态 ==========
var deck: Array = []       # 牌库（未抽）
var hand: Array = []       # 手牌
var discard_pile: Array = []  # 弃牌堆
var exhaust_pile: Array = []  # 消耗堆（不会重新进入牌库）

var current_cost: int = 0  # 本回合剩余费用
var max_cost: int = BASE_COST_PER_TURN  # 本回合最大费用

# ========== 初始化 ==========
func _ready() -> void:
	pass

## 用初始牌库初始化（游戏开始）
func init_deck(card_ids: Array) -> void:
	deck = []
	hand = []
	discard_pile = []
	exhaust_pile = []
	
	for card_id in card_ids:
		var card = CardDatabase.get_card(card_id)
		if card:
			deck.append(card.duplicate(true))
	
	shuffle_deck()

## 初始化默认起始牌库
func init_starter_deck() -> void:
	var starter_ids = [
		"zhenhunfu",      # 镇魂符 x2
		"zhenhunfu",
		"hun_po_lie",     # 魂魄裂 x2（混情攻击）
		"hun_po_lie",
		"lei_shang",      # 泪伤 x2（混情攻击）
		"lei_shang",
		"podan",          # 破胆（混情攻击）
		"jue_liao_ling",  # 觉了铃（基础符咒）
		"hong_chen_yi_xiao",  # 红尘一笑（基础符咒）
		"ku_sha",         # 枯煞（基础符咒）
		"yin_lu_ling",    # 阴路灵（基础符咒）
	]
	init_deck(starter_ids)

# ========== 回合管理 ==========

## 回合开始：重置费用，摸牌
func on_turn_start() -> void:
	# 计算本回合费用（考虑定系减免）
	max_cost = BASE_COST_PER_TURN - EmotionManager.get_cost_reduction()
	current_cost = max_cost
	
	# 计算摸牌数（惧失调时随机-1）
	var draw_count = BASE_DRAW_COUNT
	if EmotionManager.is_disorder("fear"):
		draw_count -= 1  # 惧失调：少摸一张
	
	# 摸牌
	for i in draw_count:
		draw_card()

## 回合结束：弃置手牌
func on_turn_end() -> void:
	# 将所有手牌移至弃牌堆
	for card in hand.duplicate():
		discard_from_hand(card)

# ========== 摸牌 ==========

## 摸一张牌
func draw_card() -> Dictionary:
	if len(hand) >= MAX_HAND_SIZE:
		emit_signal("hand_full")
		return {}
	
	# 牌库空时，将弃牌堆洗回
	if len(deck) == 0:
		if len(discard_pile) == 0:
			return {}  # 真的没牌了
		reshuffle_discard()
	
	var card = deck.pop_back()
	hand.append(card)
	emit_signal("card_drawn", card)
	emit_signal("hand_updated", hand)
	return card

## 额外摸N张牌（惧主导加成等）
func draw_cards(count: int) -> void:
	var actual_count = count + EmotionManager.get_draw_bonus()
	for i in actual_count:
		draw_card()

# ========== 出牌 ==========

## 尝试出牌，返回是否成功
func play_card(card: Dictionary) -> bool:
	if not card in hand:
		return false
	
	# 检查费用
	var cost = card.get("cost", 0) - EmotionManager.get_cost_reduction()
	cost = max(0, cost)
	if current_cost < cost:
		return false
	
	# 检查失调限制
	if not EmotionManager.can_play_card(card):
		return false
	
	# 扣除费用
	current_cost -= cost
	
	# 从手牌移除
	hand.erase(card)
	
	# 应用情绪偏移
	var shift = card.get("emotion_shift", {})
	EmotionManager.apply_shift(shift)
	
	# 加入弃牌堆（传说牌考虑消耗机制）
	if card.get("rarity", "") == "legendary":
		exhaust_pile.append(card)
	else:
		discard_pile.append(card)
	
	emit_signal("card_played", card)
	emit_signal("hand_updated", hand)
	return true

# ========== 弃牌 ==========

## 从手牌弃置
func discard_from_hand(card: Dictionary) -> void:
	if card in hand:
		hand.erase(card)
		discard_pile.append(card)
		emit_signal("card_discarded", card)
		emit_signal("hand_updated", hand)

## 随机弃置一张手牌（惧失调触发）
func discard_random() -> void:
	if len(hand) == 0:
		return
	var idx = randi() % len(hand)
	discard_from_hand(hand[idx])

# ========== 牌库操作 ==========

## 洗牌
func shuffle_deck() -> void:
	deck.shuffle()
	emit_signal("deck_shuffled")

## 将弃牌堆洗回牌库
func reshuffle_discard() -> void:
	deck = discard_pile.duplicate()
	discard_pile = []
	shuffle_deck()

## 向牌库添加一张牌
func add_card_to_deck(card: Dictionary) -> void:
	deck.insert(0, card)  # 加到最底部

## 向手牌添加一张牌（不通过摸牌流程）
func add_card_to_hand(card: Dictionary) -> void:
	if len(hand) < MAX_HAND_SIZE:
		hand.append(card)
		emit_signal("hand_updated", hand)

## 从牌库永久移除一张牌（商店移除功能）
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

# ========== 查询 ==========

## 获取整个牌库（牌库+弃牌堆+手牌）
func get_full_deck() -> Array:
	return deck + discard_pile + hand

## 获取牌库总数
func get_total_card_count() -> int:
	return len(deck) + len(discard_pile) + len(hand)
