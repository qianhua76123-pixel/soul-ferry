extends Node2D

## BattleStateMachine.gd - 战斗状态机

signal battle_started(enemy_data: Dictionary)
signal player_turn_started(turn: int)
signal enemy_turn_started()
signal card_effect_applied(card: Dictionary, result: Dictionary)
signal battle_ended(result: String)
signal du_hua_available(condition: String)
signal du_hua_succeeded(enemy_id: String)

# 状态常量（替代 enum，避免外部引用问题）
const STATE_IDLE         = 0
const STATE_BATTLE_START = 1
const STATE_PLAYER_TURN  = 2
const STATE_RESOLVING    = 3
const STATE_ENEMY_TURN   = 4
const STATE_TURN_END     = 5
const STATE_BATTLE_END   = 6

var current_state: int = 0
var current_turn: int = 0

var enemy_data: Dictionary = {}
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_shield: int = 0
var player_shield: int = 0

var joy_cards_played_this_turn: int = 0
var du_hua_triggered: bool = false

func start_battle(enemy_id: String) -> void:
	var enemy = _load_enemy(enemy_id)
	if enemy.is_empty():
		push_error("BattleStateMachine: 未找到敌人 " + enemy_id)
		# 使用默认敌人数据防止崩溃
		enemy = {"id": enemy_id, "name": "亡魂", "hp": 50, "actions": [{"type":"attack","value":8,"weight":100}]}
	enemy_data = enemy
	enemy_hp = enemy.get("hp", 50)
	enemy_max_hp = enemy_hp
	enemy_shield = 0
	player_shield = 0
	current_turn = 0
	joy_cards_played_this_turn = 0
	du_hua_triggered = false
	current_state = STATE_BATTLE_START
	battle_started.emit(enemy_data)
	_begin_player_turn()

func _load_enemy(enemy_id: String) -> Dictionary:
	var file = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if not file:
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	file.close()
	for enemy in json.get_data().get("enemies", []):
		if enemy.get("id", "") == enemy_id:
			return enemy
	return {}

func _begin_player_turn() -> void:
	current_turn += 1
	joy_cards_played_this_turn = 0
	current_state = STATE_PLAYER_TURN
	DeckManager.on_turn_start()
	if EmotionManager.is_disorder("fear"):
		DeckManager.discard_random()
	player_turn_started.emit(current_turn)

func play_card(card: Dictionary) -> bool:
	if current_state != STATE_PLAYER_TURN:
		return false
	current_state = STATE_RESOLVING
	if not DeckManager.play_card(card):
		current_state = STATE_PLAYER_TURN
		return false
	var result = _apply_card_effect(card)
	card_effect_applied.emit(card, result)
	if card.get("emotion_tag", "") == "joy":
		joy_cards_played_this_turn += 1
	else:
		joy_cards_played_this_turn = 0
	_check_du_hua(card)
	current_state = STATE_PLAYER_TURN
	if enemy_hp <= 0:
		_end_battle("victory")
	return true

func end_player_turn() -> void:
	if current_state != STATE_PLAYER_TURN:
		return
	current_state = STATE_TURN_END
	DeckManager.on_turn_end()
	EmotionManager.on_turn_end()
	_begin_enemy_turn()

func _begin_enemy_turn() -> void:
	current_state = STATE_ENEMY_TURN
	enemy_turn_started.emit()
	var action = _choose_enemy_action()
	_execute_enemy_action(action)
	if GameState.hp > 0:
		_begin_player_turn()
	else:
		_end_battle("defeat")

func _apply_card_effect(card: Dictionary) -> Dictionary:
	var effect_type = card.get("effect_type", "")
	var base_val    = card.get("effect_value", 0)
	var bonus       = card.get("condition_bonus", 0) if _check_condition(card) else 0
	var result      = {"type": effect_type, "value": 0}

	match effect_type:
		"attack", "attack_all":
			var dmg = int((base_val + bonus) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg)
			result.value = dmg
		"shield":
			var sv = base_val + bonus
			player_shield += sv
			result.value = sv
		"heal", "heal_all_buffs":
			var hv = int((base_val + bonus) * EmotionManager.get_heal_multiplier())
			GameState.heal(hv)
			result.value = hv
		"draw":
			DeckManager.draw_cards(base_val)
			result.value = base_val
		"weaken":
			result["weaken_percent"] = base_val
		"reset_shield":
			var total = EmotionManager.get_total_value()
			var sv = total * base_val
			player_shield += sv
			result.value = sv
		"du_hua_trigger":
			result["du_hua_attempt"] = true
		_:
			pass
	return result

func _check_condition(card: Dictionary) -> bool:
	var cond = card.get("condition", null)
	if cond == null: return false
	match cond:
		"rage_dominant":  return EmotionManager.dominant_emotion == "rage"
		"fear_dominant":  return EmotionManager.dominant_emotion == "fear"
		"grief_dominant": return EmotionManager.dominant_emotion == "grief"
		"joy_dominant":   return EmotionManager.dominant_emotion == "joy"
		"calm >= 3":      return EmotionManager.values["calm"]  >= 3
		"grief >= 3":     return EmotionManager.values["grief"] >= 3
		"fear >= 3":      return EmotionManager.values["fear"]  >= 3
	return false

func _check_du_hua(played_card: Dictionary) -> void:
	if du_hua_triggered: return
	var cond = enemy_data.get("du_hua_condition", null)
	if not cond: return
	var emotion_req = cond.get("emotion_requirement", {})
	for emotion in emotion_req:
		if EmotionManager.values[emotion] < emotion_req[emotion]:
			return
	match cond.get("type", ""):
		"card_play":
			if played_card.get("id", "") == cond.get("card_id", ""):
				_trigger_du_hua()
		"consecutive_joy_cards":
			if joy_cards_played_this_turn >= cond.get("count", 3):
				_trigger_du_hua()

func _trigger_du_hua() -> void:
	du_hua_triggered = true
	var desc = enemy_data.get("du_hua_condition", {}).get("description", "渡化条件已满足")
	du_hua_available.emit(desc)

func confirm_du_hua() -> void:
	if not du_hua_triggered: return
	GameState.record_du_hua(enemy_data.get("id", ""))
	du_hua_succeeded.emit(enemy_data.get("id",""))
	_end_battle("du_hua")

func _choose_enemy_action() -> Dictionary:
	var actions = enemy_data.get("actions", [])
	if actions.is_empty(): return {}
	var total = 0
	for a in actions: total += a.get("weight", 1)
	var roll = randi() % total
	var cum  = 0
	for a in actions:
		cum += a.get("weight", 1)
		if roll < cum: return a
	return actions[0]

func _execute_enemy_action(action: Dictionary) -> void:
	if action.is_empty(): return
	var mul = EmotionManager.get_enemy_damage_multiplier()
	match action.get("type", ""):
		"attack":
			var dmg = int(action.get("value", 0) * mul)
			if player_shield > 0:
				var blocked = min(player_shield, dmg)
				player_shield -= blocked
				dmg -= blocked
			if dmg > 0:
				GameState.take_damage(dmg)
		"emotion_push":
			EmotionManager.modify(action.get("emotion", ""), action.get("value", 1))
		"dot", "dot_fire", "all_field_heat_dot":
			GameState.take_damage(action.get("value", 0))
		"shield":
			enemy_shield += action.get("value", 0)

func _deal_damage_to_enemy(amount: int) -> void:
	if enemy_shield > 0:
		var blocked = min(enemy_shield, amount)
		enemy_shield -= blocked
		amount -= blocked
	enemy_hp = max(0, enemy_hp - amount)

func _end_battle(result: String) -> void:
	current_state = STATE_BATTLE_END
	if result == "victory":
		GameState.record_zhen_ya(enemy_data.get("id", ""))
	battle_ended.emit(result)
