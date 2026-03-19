extends Node

## GameState.gd - 游戏全局状态

signal hp_changed(old_hp: int, new_hp: int)
signal max_hp_changed(old_max: int, new_max: int)
signal gold_changed(old_gold: int, new_gold: int)
signal relic_added(relic_id: String)
signal game_over()

const STARTING_HP     = 80
const STARTING_MAX_HP = 80
const STARTING_GOLD   = 100

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

func new_run() -> void:
	hp = STARTING_HP; max_hp = STARTING_MAX_HP; gold = STARTING_GOLD
	current_layer = 1; current_node = 0
	visited_nodes = []; relics = []; choice_history = []
	du_hua_count = 0; zhen_ya_count = 0; route_tendency = ""
	if has_meta("pending_enemy_id"): remove_meta("pending_enemy_id")
	EmotionManager.reset_all()
	add_relic("tong_jing_sui")
	add_relic("wenlu_xiang")
	add_relic("duhun_ce")

func take_damage(amount: int) -> void:
	var actual = int(amount * EmotionManager.get_enemy_damage_multiplier())
	var old_hp = hp
	hp = max(0, hp - actual)
	hp_changed.emit(old_hp, hp)
	if hp <= 0: game_over.emit()

func heal(amount: int) -> void:
	var actual = int(amount * EmotionManager.get_heal_multiplier())
	var old_hp = hp
	hp = min(max_hp, hp + actual)
	hp_changed.emit(old_hp, hp)

func increase_max_hp(amount: int) -> void:
	var old_max = max_hp
	max_hp += amount; hp = min(max_hp, hp + amount)
	max_hp_changed.emit(old_max, max_hp)

func gain_gold(amount: int) -> void:
	var old = gold; gold += amount; gold_changed.emit(old, gold)

func spend_gold(amount: int) -> bool:
	if gold < amount: return false
	var old = gold; gold -= amount; gold_changed.emit(old, gold); return true

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
