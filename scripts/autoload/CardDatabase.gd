extends Node

## CardDatabase.gd - 牌库数据，从 JSON 加载，运行时只读

const CARDS_DATA_PATH = "res://data/cards.json"

var _cards: Dictionary = {}
var _loaded: bool = false

func _ready() -> void:
	_load_cards()

func _load_cards() -> void:
	if _loaded: return
	var file = FileAccess.open(CARDS_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("CardDatabase: 无法打开 " + CARDS_DATA_PATH); return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("CardDatabase: JSON 解析失败"); file.close(); return
	file.close()
	for card in json.get_data().get("cards", []):
		_cards[card.get("id", "")] = card
	_loaded = true

func get_card(card_id: String) -> Dictionary:
	if not _loaded: _load_cards()
	return _cards.get(card_id, {}).duplicate(true)

func get_all_cards() -> Array:
	if not _loaded: _load_cards()
	return _cards.values()

func get_reward_cards(count: int = 3) -> Array:
	var pool = get_all_cards().filter(func(c): return not c.get("is_curse", false))
	pool.shuffle()
	# 保证稀有度分布：常见多，稀有少
	var weighted = []
	for c in pool:
		match c.get("rarity", "common"):
			"legendary": weighted.append_array([c])
			"rare":      weighted.append_array([c, c])
			_:           weighted.append_array([c, c, c, c])
	weighted.shuffle()
	var result = []
	var seen_ids = {}
	for c in weighted:
		if len(result) >= count: break
		if c.get("id","") not in seen_ids:
			result.append(c.duplicate(true))
			seen_ids[c.get("id","")] = true
	return result
