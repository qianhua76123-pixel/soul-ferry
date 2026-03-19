extends Node

## CardDatabase.gd - 牌卡数据库
## 从 JSON 文件加载所有牌卡数据，运行时只读缓存


const CARDS_DATA_PATH = "res://data/cards.json"

var _cards: Dictionary = {}  # id -> card data

func _ready() -> void:
	_load_cards()

## 从 JSON 加载牌卡数据
func _load_cards() -> void:
	var file = FileAccess.open(CARDS_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("CardDatabase: 无法加载牌卡数据文件 " + CARDS_DATA_PATH)
		return
	
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_str)
	if error != OK:
		push_error("CardDatabase: JSON 解析错误：" + json.get_error_message())
		return
	
	var data = json.get_data()
	for card in data.get("cards", []):
		_cards[card["id"]] = card
	
	print("CardDatabase: 已加载 %d 张牌卡" % len(_cards))

## 获取单张牌卡数据
func get_card(card_id: String) -> Dictionary:
	if card_id in _cards:
		return _cards[card_id].duplicate(true)
	push_warning("CardDatabase: 未找到牌卡 " + card_id)
	return {}

## 获取所有牌卡
func get_all_cards() -> Array:
	return _cards.values().duplicate(true)

## 按情绪标签获取牌卡
func get_cards_by_emotion(emotion_tag: String) -> Array:
	var result = []
	for card in _cards.values():
		if card.get("emotion_tag", "") == emotion_tag:
			result.append(card.duplicate(true))
	return result

## 按稀有度获取牌卡
func get_cards_by_rarity(rarity: String) -> Array:
	var result = []
	for card in _cards.values():
		if card.get("rarity", "") == rarity:
			result.append(card.duplicate(true))
	return result

## 获取战斗奖励牌卡（随机3选1，按稀有度加权）
func get_reward_cards(count: int = 3) -> Array:
	var pool = []
	# 普通：权重5，罕见：权重2，传说：权重0.3
	for card in _cards.values():
		match card.get("rarity", "common"):
			"common":
				for i in 5:
					pool.append(card)
			"rare":
				for i in 2:
					pool.append(card)
			"legendary":
				pool.append(card)
	
	pool.shuffle()
	var result = []
	var selected_ids = []
	for card in pool:
		if not card["id"] in selected_ids:
			result.append(card.duplicate(true))
			selected_ids.append(card["id"])
		if len(result) >= count:
			break
	return result
