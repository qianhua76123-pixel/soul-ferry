extends Node

## GameState.gd - 游戏全局状态

signal hp_changed(old_hp: int, new_hp: int)
signal max_hp_changed(old_max: int, new_max: int)
signal gold_changed(old_gold: int, new_gold: int)
signal relic_added(relic_id: String)
signal game_saved()
signal game_loaded()
signal game_over()

const STARTING_HP     = 80
const STARTING_MAX_HP = 80
const STARTING_GOLD   = 100
const SAVE_PATH       = "user://save.json"

var hp:             int    = STARTING_HP
var max_hp:         int    = STARTING_MAX_HP
var gold:           int    = STARTING_GOLD
var current_layer:  int    = 1
var current_node:   int    = 0
var visited_nodes:  Array  = []
var relics:         Array  = []
var choice_history: Array  = []
var du_hua_count:   int    = 0
var zhen_ya_count:  int    = 0
var route_tendency: String = ""

func _ready() -> void:
	pass

# ════════════════════════════════════════════
#  存档系统
# ════════════════════════════════════════════

func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file: return false
	var content: String = file.get_as_text().strip_edges()
	file.close()
	return content.length() > 2

func save_to_file() -> void:
	# 序列化牌库（保留每张牌的 id + 升级等级）
	var deck_data: Array = []
	for card in DeckManager.get_full_deck():
		deck_data.append({
			"id":    card.get("id", ""),
			"level": card.get("level", 0),
		})

	var data: Dictionary = {
		"current_hp":    hp,
		"max_hp":        max_hp,
		"gold":          gold,
		"current_layer": current_layer,
		"current_node":  current_node,
		"visited_nodes": visited_nodes,
		"relics":        relics,
		"choice_history":choice_history,
		"du_hua_count":  du_hua_count,
		"zhen_ya_count": zhen_ya_count,
		"route_tendency":route_tendency,
		"deck":          deck_data,
		"emotion_values":EmotionManager.values.duplicate(),
		"map_state":     get_meta("map_data") if has_meta("map_data") else [],
		"save_version":  1,
		"save_time":     Time.get_unix_time_from_system(),
	}

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("GameState: 无法写入存档 " + SAVE_PATH); return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	game_saved.emit()

func load_from_file() -> bool:
	if not has_save(): return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file: return false
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		push_error("GameState: 存档解析失败"); return false
	file.close()

	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY: return false

	# ── 恢复 GameState ──
	var old_hp: int = hp
	hp             = data.get("current_hp",    STARTING_HP)
	max_hp         = data.get("max_hp",        STARTING_MAX_HP)
	gold           = data.get("gold",          STARTING_GOLD)
	current_layer  = data.get("current_layer", 1)
	current_node   = data.get("current_node",  0)
	visited_nodes  = data.get("visited_nodes", [])
	relics         = data.get("relics",        [])
	choice_history = data.get("choice_history",[])
	du_hua_count   = data.get("du_hua_count",  0)
	zhen_ya_count  = data.get("zhen_ya_count", 0)
	route_tendency = data.get("route_tendency","")

	hp_changed.emit(old_hp, hp)
	gold_changed.emit(0, gold)

	# ── 恢复地图数据 ──
	var map_state: Variant = data.get("map_state", [])
	if map_state is Array and not map_state.is_empty():
		set_meta("map_data", map_state)

	# ── 恢复情绪 ──
	var emotions: Dictionary = data.get("emotion_values", {})
	EmotionManager.reset_all()
	for emotion in emotions:
		EmotionManager.modify(emotion, int(emotions[emotion]))

	# ── 恢复遗物（通过 RelicManager）──
	if Engine.has_singleton("RelicManager"):
		RelicManager.active_relics = []
		RelicManager.nianhua_used_this_run = false
		RelicManager._wuqing_bonus_active  = false
		for rid in relics:
			RelicManager.add_relic(rid)

	# ── 恢复牌库 ──
	var deck_data: Array = data.get("deck", [])
	if not deck_data.is_empty():
		var card_ids: Array = []
		var upgrades: Dictionary = {}
		for entry in deck_data:
			var cid: String   = entry.get("id","")
			var level: int = entry.get("level", 0)
			card_ids.append(cid)
			if level > 0: upgrades[cid] = level
		DeckManager.init_deck(card_ids)
		# 应用升级等级
		for card in DeckManager.deck:
			var cid_2: String = card.get("id","")
			if cid_2 in upgrades:
				card["level"] = upgrades[cid_2]
				card["cost"]  = maxi(0, card.get("cost",1) - upgrades[cid_2])
	else:
		DeckManager.init_starter_deck()

	if Engine.has_singleton("BuffManager"):
		BuffManager.clear_all()

	game_loaded.emit()
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

# ════════════════════════════════════════════
#  游戏逻辑
# ════════════════════════════════════════════

func new_run() -> void:
	hp = STARTING_HP; max_hp = STARTING_MAX_HP; gold = STARTING_GOLD
	current_layer = 1; current_node = 0
	visited_nodes = []; relics = []; choice_history = []
	du_hua_count = 0; zhen_ya_count = 0; route_tendency = ""
	if has_meta("pending_enemy_id"): remove_meta("pending_enemy_id")
	if has_meta("map_data"):         remove_meta("map_data")
	EmotionManager.reset_all()
	if Engine.has_singleton("RelicManager"):
		RelicManager.active_relics         = []
		RelicManager.nianhua_used_this_run  = false
		RelicManager._wuqing_bonus_active   = false
	if Engine.has_singleton("BuffManager"):
		BuffManager.clear_all()
	add_relic("tong_jing_sui")
	add_relic("wenlu_xiang")
	add_relic("duhun_ce")

func take_damage(amount: int) -> void:
	var actual: int = int(amount * EmotionManager.get_enemy_damage_multiplier())
	var old_hp: int = hp
	hp = maxi(0, hp - actual)
	hp_changed.emit(old_hp, hp)
	if hp <= 0: game_over.emit()

func heal(amount: int) -> void:
	var actual: int = int(amount * EmotionManager.get_heal_multiplier())
	var old_hp: int = hp
	hp = minf(max_hp, hp + actual)
	hp_changed.emit(old_hp, hp)

func increase_max_hp(amount: int) -> void:
	var old_max: int = max_hp
	max_hp += amount; hp = minf(max_hp, hp + amount)
	max_hp_changed.emit(old_max, max_hp)

func gain_gold(amount: int) -> void:
	var old: int = gold; gold += amount; gold_changed.emit(old, gold)

func spend_gold(amount: int) -> bool:
	if gold < amount: return false
	var old: int = gold; gold -= amount; gold_changed.emit(old, gold); return true

func add_relic(relic_id: String) -> void:
	if relic_id not in relics:
		relics.append(relic_id); relic_added.emit(relic_id)

func has_relic(relic_id: String) -> bool:
	return relic_id in relics

func record_choice(choice_type: String, choice_value: String) -> void:
	choice_history.append({"type":choice_type,"value":choice_value,"layer":current_layer})

func record_du_hua(enemy_id: String) -> void:
	du_hua_count += 1; record_choice("battle","du_hua")
	if has_relic("duhun_ce"): increase_max_hp(3)
	_update_route()

func record_zhen_ya(_enemy_id: String) -> void:
	zhen_ya_count += 1; record_choice("battle","zhen_ya"); _update_route()

func _update_route() -> void:
	if du_hua_count > zhen_ya_count * 2: route_tendency = "du_hua"
	elif zhen_ya_count > du_hua_count * 2: route_tendency = "zhen_ya"
	else: route_tendency = "mixed"

func advance_node(node_id: String) -> void:
	visited_nodes.append(node_id); current_node += 1

func advance_layer() -> void:
	current_layer += 1; current_node = 0

func get_full_deck() -> Array:
	return DeckManager.get_full_deck()

# ════════════════════════════════════════════
#  结局触发
# ════════════════════════════════════════════

## 检查是否满足胜利条件（通关第三层 Boss）
## 在 MapScene 节点完成后调用
func check_victory_condition() -> bool:
	return current_layer > 3

## 触发结局场景
## ending_type: "success" / "defeat" / "lost"
func trigger_ending(ending_type: String) -> void:
	set_meta("ending_type",  ending_type)
	set_meta("du_hua_count", du_hua_count)
	set_meta("zhenya_count", zhen_ya_count)
	delete_save()
	# 成就：结局记录
	AchievementManager.on_ending(ending_type)
	TransitionManager.call_deferred("change_scene", "res://scenes/EndingScene.tscn")
