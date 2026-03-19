extends Node

## CardDatabase.gd - 从 JSON 加载所有牌卡，运行时只读缓存

const CARDS_DATA_PATH = "res://data/cards.json"
var _cards: Dictionary = {}

func _ready() -> void:
	_load_cards()

func _load_cards() -> void:
	var file = FileAccess.open(CARDS_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("CardDatabase: 无法加载 " + CARDS_DATA_PATH)
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("CardDatabase: JSON 解析错误")
		return
	file.close()
	for card in json.get_data().get("cards", []):
		_cards[card["id"]] = card
	print("CardDatabase: 加载 %d 张牌" % len(_cards))

func get_card(card_id: String) -> Dictionary:
	if card_id in _cards:
		return _cards[card_id].duplicate(true)
	push_warning("CardDatabase: 未找到牌卡 " + card_id)
	return {}

func get_all_cards() -> Array:
	return _cards.values().duplicate(true)

func get_cards_by_emotion(emotion_tag: String) -> Array:
	var result = []
	for card in _cards.values():
		if card.get("emotion_tag", "") == emotion_tag:
			result.append(card.duplicate(true))
	return result

func get_reward_cards(count: int = 3) -> Array:
	var pool = []
	for card in _cards.values():
		match card.get("rarity", "common"):
			"common":    for i in 5: pool.append(card)
			"rare":      for i in 2: pool.append(card)
			"legendary": pool.append(card)
	pool.shuffle()
	var result = []
	var seen = []
	for card in pool:
		if not card["id"] in seen:
			result.append(card.duplicate(true))
			seen.append(card["id"])
		if len(result) >= count:
			break
	return result
