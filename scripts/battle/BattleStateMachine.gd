extends Node

## BattleStateMachine.gd - 战斗状态机
## 管理战斗的完整流程：开始→玩家回合→打牌→结算→敌方回合→循环

class_name BattleStateMachine

# ========== 信号 ==========
signal state_changed(new_state: State)
signal battle_started(enemy_data: Dictionary)
signal player_turn_started(turn: int)
signal enemy_turn_started()
signal card_effect_applied(card: Dictionary, result: Dictionary)
signal battle_ended(result: String)  # "victory" | "defeat" | "du_hua"
signal du_hua_available(condition: String)
signal du_hua_succeeded(enemy_id: String)

# ========== 状态枚举 ==========
enum State {
	IDLE,
	BATTLE_START,
	PLAYER_TURN,
	RESOLVING_CARD,
	ENEMY_TURN,
	RESOLVING_ENEMY,
	TURN_END,
	BATTLE_END
}

var current_state: State = State.IDLE
var current_turn: int = 0

# ========== 当前战斗数据 ==========
var enemy_data: Dictionary = {}
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_shield: int = 0
var player_shield: int = 0

# 渡化追踪
var joy_cards_played_this_turn: int = 0  # 喜类牌连续打出计数（素锦渡化用）
var du_hua_triggered: bool = false

# ========== 初始化战斗 ==========
func start_battle(enemy_id: String) -> void:
	var enemy = _load_enemy(enemy_id)
	if enemy.is_empty():
		push_error("BattleStateMachine: 未找到敌人 " + enemy_id)
		return
	
	enemy_data = enemy
	enemy_hp = enemy.get("hp", 50)
	enemy_max_hp = enemy_hp
	enemy_shield = 0
	player_shield = 0
	current_turn = 0
	joy_cards_played_this_turn = 0
	du_hua_triggered = false
	
	emit_signal("battle_started", enemy_data)
	_set_state(State.BATTLE_START)
	_begin_player_turn()

## 加载敌人数据
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

# ========== 回合流程 ==========

## 开始玩家回合
func _begin_player_turn() -> void:
	current_turn += 1
	joy_cards_played_this_turn = 0
	_set_state(State.PLAYER_TURN)
	
	# 回合开始效果
	DeckManager.on_turn_start()
	
	# 惧失调：回合开始随机弃1张
	if EmotionManager.is_disorder("fear"):
		DeckManager.discard_random()
	
	emit_signal("player_turn_started", current_turn)

## 玩家出牌
func play_card(card: Dictionary) -> bool:
	if current_state != State.PLAYER_TURN:
		return false
	
	_set_state(State.RESOLVING_CARD)
	
	if not DeckManager.play_card(card):
		_set_state(State.PLAYER_TURN)
		return false
	
	# 应用牌卡效果
	var result = _apply_card_effect(card)
	emit_signal("card_effect_applied", card, result)
	
	# 追踪喜类牌（素锦渡化条件）
	if card.get("emotion_tag", "") == "joy":
		joy_cards_played_this_turn += 1
	else:
		joy_cards_played_this_turn = 0  # 连续计数被中断
	
	# 检测渡化条件
	_check_du_hua_condition(card)
	
	_set_state(State.PLAYER_TURN)
	
	# 检测战斗结束
	if enemy_hp <= 0:
		_end_battle("victory")
	
	return true

## 结束玩家回合
func end_player_turn() -> void:
	if current_state != State.PLAYER_TURN:
		return
	
	_set_state(State.TURN_END)
	
	# 回合结束：弃置手牌
	DeckManager.on_turn_end()
	
	# 情绪自然衰减
	EmotionManager.on_turn_end()
	
	# 进入敌方回合
	_begin_enemy_turn()

## 敌方回合
func _begin_enemy_turn() -> void:
	_set_state(State.ENEMY_TURN)
	emit_signal("enemy_turn_started")
	
	# 执行敌人行动
	var action = _choose_enemy_action()
	_execute_enemy_action(action)
	
	# 敌方回合结束后重新开始玩家回合
	_begin_player_turn()

# ========== 牌卡效果处理 ==========

func _apply_card_effect(card: Dictionary) -> Dictionary:
	var effect_type = card.get("effect_type", "")
	var base_value = card.get("effect_value", 0)
	var result = {"type": effect_type, "value": 0}
	
	# 检查条件触发
	var bonus = 0
	if _check_card_condition(card):
		bonus = card.get("condition_bonus", 0)
	
	match effect_type:
		"attack":
			var dmg = int((base_value + bonus) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg)
			result.value = dmg
		
		"attack_all":
			var dmg = int((base_value + bonus) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg)  # 当前只有单敌人，待扩展
			result.value = dmg
		
		"shield":
			var shield_val = base_value + bonus
			player_shield += shield_val
			result.value = shield_val
		
		"heal":
			var heal_val = int((base_value + bonus) * EmotionManager.get_heal_multiplier())
			GameState.heal(heal_val)
			result.value = heal_val
		
		"draw":
			DeckManager.draw_cards(base_value)
			result.value = base_value
		
		"weaken":
			# 施加削弱状态（百分比）
			result["weaken_percent"] = base_value
		
		"reset_shield":
			# 五情归一：获得情绪总和×倍率的护盾
			var total = EmotionManager.get_total_value()
			var shield_val = total * base_value  # base_value=3 即×3
			# 注：情绪清零已在 apply_shift 中处理
			player_shield += shield_val
			result.value = shield_val
		
		"du_hua_trigger":
			result["du_hua_attempt"] = true
		
		"du_hua_progress":
			result["du_hua_progress"] = 1
	
	return result

## 检查牌卡条件是否满足
func _check_card_condition(card: Dictionary) -> bool:
	var condition = card.get("condition", null)
	if condition == null:
		return false
	
	match condition:
		"rage_dominant": return EmotionManager.dominant_emotion == "rage"
		"fear_dominant": return EmotionManager.dominant_emotion == "fear"
		"grief_dominant": return EmotionManager.dominant_emotion == "grief"
		"joy_dominant": return EmotionManager.dominant_emotion == "joy"
		"calm >= 3": return EmotionManager.values["calm"] >= 3
		"grief >= 3": return EmotionManager.values["grief"] >= 3
		"fear >= 3": return EmotionManager.values["fear"] >= 3
		_: return false

# ========== 渡化系统 ==========

## 检测渡化条件
func _check_du_hua_condition(played_card: Dictionary) -> void:
	if du_hua_triggered:
		return
	
	var condition = enemy_data.get("du_hua_condition", null)
	if not condition:
		return
	
	var cond_type = condition.get("type", "")
	var emotion_req = condition.get("emotion_requirement", {})
	
	# 检查情绪前提
	for emotion in emotion_req:
		if EmotionManager.values[emotion] < emotion_req[emotion]:
			return
	
	match cond_type:
		"card_play":
			if played_card.get("id", "") == condition.get("card_id", ""):
				_trigger_du_hua()
		
		"consecutive_joy_cards":
			if joy_cards_played_this_turn >= condition.get("count", 3):
				_trigger_du_hua()

## 触发渡化
func _trigger_du_hua() -> void:
	du_hua_triggered = true
	emit_signal("du_hua_available", enemy_data.get("du_hua_condition", {}).get("description", ""))

## 完成渡化（UI确认后调用）
func confirm_du_hua() -> void:
	if not du_hua_triggered:
		return
	GameState.record_du_hua(enemy_data.get("id", ""))
	emit_signal("du_hua_succeeded", enemy_data.get("id", ""))
	_end_battle("du_hua")

# ========== 敌人行动 ==========

func _choose_enemy_action() -> Dictionary:
	var actions = enemy_data.get("actions", [])
	if actions.is_empty():
		return {}
	
	# 根据权重随机选择行动
	var total_weight = 0
	for action in actions:
		total_weight += action.get("weight", 1)
	
	var roll = randi() % total_weight
	var cumulative = 0
	for action in actions:
		cumulative += action.get("weight", 1)
		if roll < cumulative:
			return action
	
	return actions[0]

func _execute_enemy_action(action: Dictionary) -> void:
	if action.is_empty():
		return
	
	var action_type = action.get("type", "")
	var dmg_multiplier = EmotionManager.get_enemy_damage_multiplier()
	
	match action_type:
		"attack":
			var dmg = int(action.get("value", 0) * dmg_multiplier)
			# 先扣护盾
			if player_shield > 0:
				var blocked = min(player_shield, dmg)
				player_shield -= blocked
				dmg -= blocked
			if dmg > 0:
				GameState.take_damage(dmg)
		
		"emotion_push":
			var emotion = action.get("emotion", "")
			var value = action.get("value", 1)
			EmotionManager.modify(emotion, value)
		
		"dot":
			# 持续伤害（简化：直接造成伤害）
			GameState.take_damage(action.get("value", 0))
		
		"dot_fire":
			GameState.take_damage(action.get("value", 0))
		
		"all_field_heat_dot":
			GameState.take_damage(action.get("value", 0))
		
		"shield":
			enemy_shield += action.get("value", 0)

# ========== 战斗结束 ==========

func _deal_damage_to_enemy(amount: int) -> void:
	# 先扣护盾
	if enemy_shield > 0:
		var blocked = min(enemy_shield, amount)
		enemy_shield -= blocked
		amount -= blocked
	enemy_hp = max(0, enemy_hp - amount)

func _end_battle(result: String) -> void:
	_set_state(State.BATTLE_END)
	
	if result == "victory":
		GameState.record_zhen_ya(enemy_data.get("id", ""))
	
	emit_signal("battle_ended", result)

func _set_state(new_state: State) -> void:
	current_state = new_state
	emit_signal("state_changed", new_state)
