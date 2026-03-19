extends Node

## GameState.gd - 游戏整体状态管理
## 存储当局游戏的所有持久数据：HP、金钱、遗物、地图进度、选择记录等


# ========== 信号 ==========
signal hp_changed(old_hp: int, new_hp: int)
signal max_hp_changed(old_max: int, new_max: int)
signal gold_changed(old_gold: int, new_gold: int)
signal relic_added(relic_id: String)
signal game_over()
signal run_completed(is_victory: bool, route: String)

# ========== 初始数值 ==========
const STARTING_HP = 80
const STARTING_MAX_HP = 80
const STARTING_GOLD = 100

# ========== 当局状态 ==========
var hp: int = STARTING_HP
var max_hp: int = STARTING_MAX_HP
var gold: int = STARTING_GOLD

var current_layer: int = 1       # 当前层（1-3）
var current_node: int = 0        # 当前节点
var map_path: Array = []         # 当前局选择的路径节点
var visited_nodes: Array = []    # 已访问节点

var relics: Array = []           # 持有的遗物ID列表
var choice_history: Array = []   # 道德选择记录（影响结局）
var du_hua_count: int = 0        # 渡化成功次数
var zhen_ya_count: int = 0       # 镇压次数

# 路线追踪（用于结局判定）
var route_tendency: String = ""  # "du_hua" | "zhen_ya" | "mixed"

# ========== 初始化 ==========
func _ready() -> void:
	pass

## 开始新的一局
func new_run() -> void:
	hp = STARTING_HP
	max_hp = STARTING_MAX_HP
	gold = STARTING_GOLD
	current_layer = 1
	current_node = 0
	map_path = []
	visited_nodes = []
	relics = []
	choice_history = []
	du_hua_count = 0
	zhen_ya_count = 0
	route_tendency = ""
	# 清除战斗传参 meta
	if has_meta("pending_enemy_id"):
		remove_meta("pending_enemy_id")
	# 初始遗物：三件随身之物（剧情固定）
	add_relic("tong_jing_sui")
	add_relic("wenlu_xiang")
	add_relic("duhun_ce")

# ========== HP 管理 ==========

## 受到伤害
func take_damage(amount: int) -> void:
	var actual = int(amount * EmotionManager.get_enemy_damage_multiplier())
	var old_hp = hp
	hp = max(0, hp - actual)
	emit_signal("hp_changed", old_hp, hp)
	
	if hp <= 0:
		emit_signal("game_over")

## 回复HP
func heal(amount: int) -> void:
	var actual = int(amount * EmotionManager.get_heal_multiplier())
	var old_hp = hp
	hp = min(max_hp, hp + actual)
	emit_signal("hp_changed", old_hp, hp)

## 增加最大HP
func increase_max_hp(amount: int) -> void:
	var old_max = max_hp
	max_hp += amount
	hp += amount  # 同时补充当前HP
	emit_signal("max_hp_changed", old_max, max_hp)

# ========== 金币管理 ==========

func gain_gold(amount: int) -> void:
	var old_gold = gold
	gold += amount
	emit_signal("gold_changed", old_gold, gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	var old_gold = gold
	gold -= amount
	emit_signal("gold_changed", old_gold, gold)
	return true

# ========== 遗物管理 ==========

func add_relic(relic_id: String) -> void:
	if not relic_id in relics:
		relics.append(relic_id)
		emit_signal("relic_added", relic_id)

func has_relic(relic_id: String) -> bool:
	return relic_id in relics

# ========== 选择记录 ==========

## 记录一次道德选择（影响结局分支）
func record_choice(choice_type: String, choice_value: String) -> void:
	choice_history.append({
		"type": choice_type,
		"value": choice_value,
		"layer": current_layer
	})

## 记录一次渡化成功
func record_du_hua(enemy_id: String) -> void:
	du_hua_count += 1
	record_choice("battle", "du_hua")
	
	# 渡魂册效果：渡化成功+3最大HP
	if has_relic("duhun_ce"):
		increase_max_hp(3)
	
	_update_route_tendency()

## 记录一次镇压
func record_zhen_ya(enemy_id: String) -> void:
	zhen_ya_count += 1
	record_choice("battle", "zhen_ya")
	_update_route_tendency()

## 更新路线倾向
func _update_route_tendency() -> void:
	if du_hua_count > zhen_ya_count * 2:
		route_tendency = "du_hua"
	elif zhen_ya_count > du_hua_count * 2:
		route_tendency = "zhen_ya"
	else:
		route_tendency = "mixed"

# ========== 地图进度 ==========

func advance_node(node_id: String) -> void:
	visited_nodes.append(node_id)
	current_node += 1

func advance_layer() -> void:
	current_layer += 1
	current_node = 0

# ========== 存档（简单JSON存档）==========

const SAVE_PATH = "user://save_data.json"

func save_game() -> void:
	var data = {
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"current_layer": current_layer,
		"current_node": current_node,
		"relics": relics,
		"choice_history": choice_history,
		"du_hua_count": du_hua_count,
		"zhen_ya_count": zhen_ya_count,
		"route_tendency": route_tendency,
		"deck": DeckManager.get_full_deck().map(func(c): return c.get("id", ""))
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	file.close()
	var data = json.get_data()
	hp = data.get("hp", STARTING_HP)
	max_hp = data.get("max_hp", STARTING_MAX_HP)
	gold = data.get("gold", STARTING_GOLD)
	current_layer = data.get("current_layer", 1)
	current_node = data.get("current_node", 0)
	relics = data.get("relics", [])
	choice_history = data.get("choice_history", [])
	du_hua_count = data.get("du_hua_count", 0)
	zhen_ya_count = data.get("zhen_ya_count", 0)
	route_tendency = data.get("route_tendency", "")
	return true
