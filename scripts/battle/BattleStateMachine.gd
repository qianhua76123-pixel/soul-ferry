extends Node

## BattleStateMachine.gd - 战斗状态机

signal battle_started(enemy_data: Dictionary)
signal player_turn_started(turn: int)
signal enemy_turn_started()
signal card_effect_applied(card: Dictionary, result: Dictionary)
signal battle_ended(result: String)
signal du_hua_available(condition: String)
signal du_hua_succeeded(enemy_id: String)
signal intent_updated(intent: Dictionary)

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
var next_intent: Dictionary = {}   # 下一回合敌人意图（供 UI 读取）

var enemy_data: Dictionary = {}
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_shield: int = 0
var player_shield: int = 0
var _dodge_charges: int = 0   # 下次受击无效次数（dodge_next 牌效果）

var joy_cards_played_this_turn: int = 0
var du_hua_triggered: bool = false

func start_battle(enemy_id: String) -> void:
	var enemy = _load_enemy(enemy_id)
	if enemy.is_empty():
		push_error("BattleStateMachine: 未找到敌人 " + enemy_id)
		enemy = {"id": enemy_id, "name": "亡魂", "hp": 50, "actions": [{"type":"attack","value":8,"weight":100}]}
	enemy_data = enemy
	enemy_hp = enemy.get("hp", 50)
	enemy_max_hp = enemy_hp
	enemy_shield = 0
	player_shield = 0
	current_turn = 0
	joy_cards_played_this_turn = 0
	du_hua_triggered = false
	# 清空上一场战斗遗留 Buff
	BuffManager.clear_all()
	# 接收 BuffManager 对敌人的 Buff 伤害
	if not BuffManager.buff_damage_to_enemy.is_connected(_on_buff_damage_to_enemy):
		BuffManager.buff_damage_to_enemy.connect(_on_buff_damage_to_enemy)
	current_state = STATE_BATTLE_START
	battle_started.emit(enemy_data)
	_begin_player_turn()

func _on_buff_damage_to_enemy(amount: int) -> void:
	_deal_damage_to_enemy(amount)
	if enemy_hp <= 0:
		_end_battle("victory")

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
	# Buff 系统：回合开始处理
	BuffManager.process_turn_start(BuffManager.TARGET_PLAYER)
	DeckManager.on_turn_start()
	if EmotionManager.is_disorder("fear"):
		DeckManager.discard_random()
	player_turn_started.emit(current_turn)
	intent_updated.emit(next_intent)
	# 回合开始时也检查渡化条件（emotion_threshold 型不依赖出牌）
	_check_du_hua({})

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
	# 执念：若激活，跳过情绪自然衰减
	if not BuffManager.obsession_active:
		EmotionManager.on_turn_end()
	# Buff 系统：回合结束处理（灼烧/中毒伤害、层数衰减）
	BuffManager.process_turn_end(BuffManager.TARGET_PLAYER)
	BuffManager.process_turn_end(BuffManager.TARGET_ENEMY)
	_begin_enemy_turn()

## Boss 当前阶段（1=正常, 2=愤怒），由 BossUI.boss_phase_changed 信号更新
var boss_phase: int = 1

func _begin_enemy_turn() -> void:
	current_state = STATE_ENEMY_TURN
	enemy_turn_started.emit()
	var action = _choose_enemy_action()
	# 记录行动类型供 BattleScene UI 读取
	enemy_data["_last_action_type"] = action.get("type", "")
	_execute_enemy_action(action)
	# 预告下一回合意图（选完本轮动作后，再预选下轮）
	next_intent = _choose_enemy_action()
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

		"attack_all_triple":
			# 三次多段伤害
			var dmg_each = int((base_val + bonus) * EmotionManager.get_attack_multiplier())
			var total = 0
			for _i in 3:
				_deal_damage_to_enemy(dmg_each)
				total += dmg_each
			result.value = total

		"attack_lifesteal":
			var dmg = int((base_val + bonus) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg)
			GameState.heal(dmg)
			result.value = dmg
			result["healed"] = dmg

		"attack_dot":
			var dmg = int((base_val + bonus) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg)
			BuffManager.add_buff(BuffManager.TARGET_ENEMY, "dot_fire", 4, 3)
			result.value = dmg

		"attack_scaling_rage":
			# 伤害 = base_val × 当前怒值
			var rage_val = EmotionManager.values.get("rage", 0)
			var dmg = int((base_val * max(1, rage_val)) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg)
			result.value = dmg

		"attack_and_weaken_all":
			var dmg = int((base_val + bonus) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg)
			result["weaken_percent"] = 50
			result["defense_break"]  = 50
			result.value = dmg

		"shield":
			var sv = base_val + bonus
			player_shield += sv
			result.value = sv

		"shield_attack":
			# 护盾 + 造成等量伤害
			var sv = base_val + bonus
			player_shield += sv
			_deal_damage_to_enemy(sv)
			result.value = sv

		"shield_and_draw":
			var sv = base_val + bonus
			player_shield += sv
			DeckManager.draw_cards(2)
			result.value = sv

		"heal", "heal_all_buffs":
			var hv = int((base_val + bonus) * EmotionManager.get_heal_multiplier())
			GameState.heal(hv)
			result.value = hv

		"heal_and_draw":
			var hv = int((base_val + bonus) * EmotionManager.get_heal_multiplier())
			GameState.heal(hv)
			DeckManager.draw_cards(2)
			result.value = hv

		"heal_scale_grief":
			# 回复 = base_val × 悲情绪值
			var grief_val = EmotionManager.values.get("grief", 0)
			var hv = int(base_val * max(1, grief_val) * EmotionManager.get_heal_multiplier())
			GameState.heal(hv)
			result.value = hv

		"mass_heal_shield":
			var hv = int(base_val * EmotionManager.get_heal_multiplier())
			GameState.heal(hv)
			player_shield += base_val
			result.value = base_val
			result["healed"] = hv

		"draw":
			DeckManager.draw_cards(base_val)
			result.value = base_val

		"draw_shield":
			DeckManager.draw_cards(base_val)
			var sv = bonus if bonus > 0 else 5
			player_shield += sv
			result.value = sv

		"weaken":
			result["weaken_percent"] = base_val

		"weaken_fear":
			result["weaken_percent"] = base_val
			result["weaken_duration"] = 2

		"weaken_and_draw":
			result["weaken_percent"] = base_val
			DeckManager.draw_cards(1)
			result.value = 1

		"dodge_next":
			# 标记下次受击无效（BattleScene 处理浮字，状态机存标记）
			_dodge_charges += (base_val + bonus)
			result.value = _dodge_charges

		"dodge_attack":
			# 格挡并反击
			_dodge_charges += 1
			var dmg = int(base_val * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg)
			result.value = dmg

		"remove_enemy_shield":
			# 清除敌人护盾并转化为伤害
			var removed = enemy_shield
			enemy_shield = 0
			if removed > 0:
				_deal_damage_to_enemy(removed)
			result.value = removed

		"reset_shield":
			# 五情归一：护盾 = 五情总值 × base_val
			var total = EmotionManager.get_total_value()
			var sv = total * base_val
			player_shield += sv
			result.value = sv

		"status_fear_all":
			EmotionManager.modify("fear", base_val)
			result.value = base_val

		"dot_and_weaken":
			BuffManager.add_buff(BuffManager.TARGET_ENEMY, "dot", base_val, 3)
			result["weaken_percent"] = base_val * 5

		"status_seal":
			result["sealed_turns"] = base_val

		"balance_emotions":
			# 将所有情绪值向均值靠拢（差值缩小 base_val）
			var vals = EmotionManager.values
			var avg = 0.0
			for k in vals: avg += vals[k]
			avg /= float(vals.size())
			for k in vals:
				var diff = vals[k] - int(avg)
				if abs(diff) > base_val:
					EmotionManager.modify(k, -sign(diff) * base_val)
			player_shield += 10
			result.value = 10

		"du_hua_progress":
			result["du_hua_progress"] = base_val + bonus

		"du_hua_trigger":
			result["du_hua_attempt"] = true

		"reduce_enemy_emotion":
			result["reduce_emotion"] = base_val

		"buff_all_cards":
			result["buff_all"] = base_val

		"draw_discard_enemy":
			DeckManager.draw_cards(base_val)
			result.value = base_val

		"peek_enemy":
			result["peek"] = true

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
		"calm_dominant":  return EmotionManager.dominant_emotion == "calm"
		"rage >= 3":      return EmotionManager.values.get("rage",  0) >= 3
		"calm >= 3":      return EmotionManager.values.get("calm",  0) >= 3
		"grief >= 3":     return EmotionManager.values.get("grief", 0) >= 3
		"grief >= 2":     return EmotionManager.values.get("grief", 0) >= 2
		"fear >= 3":      return EmotionManager.values.get("fear",  0) >= 3
		"fear >= 2":      return EmotionManager.values.get("fear",  0) >= 2
		"joy >= 3":       return EmotionManager.values.get("joy",   0) >= 3
	return false

func _check_du_hua(played_card: Dictionary) -> void:
	if du_hua_triggered: return
	var cond = enemy_data.get("du_hua_condition", null)
	if not cond: return
	var emotion_req = cond.get("emotion_requirement", {})
	for emotion in emotion_req:
		if EmotionManager.values.get(emotion, 0) < emotion_req[emotion]:
			return
	# 情绪条件已满足，按 type 进一步检查
	match cond.get("type", ""):
		"emotion_threshold":
			# 纯情绪阈值型：情绪条件满足即触发
			_trigger_du_hua()
		"card_play":
			if played_card.get("id", "") == cond.get("card_id", ""):
				_trigger_du_hua()
		"consecutive_joy_cards":
			if joy_cards_played_this_turn >= cond.get("count", 3):
				_trigger_du_hua()
		_:
			# 未知类型：情绪条件满足即触发（宽容处理）
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

	# 愤怒阶段（Boss HP≤50%）：提升攻击/dot权重，降低辅助权重
	var weighted = actions.duplicate(true)
	if boss_phase == 2:
		for a in weighted:
			var t = a.get("type", "")
			if t in ["attack", "attack_all", "dot_fire", "dot", "all_field_heat_dot",
					 "summon_tide", "rage_card_storm"]:
				a["weight"] = int(a.get("weight", 1) * 2.5)   # 攻击性行动权重×2.5
			elif t in ["shield", "heal"]:
				a["weight"] = max(1, int(a.get("weight", 1) * 0.3))  # 防御性行动权重×0.3

	var total = 0
	for a in weighted: total += a.get("weight", 1)
	var roll = randi() % total
	var cum  = 0
	for a in weighted:
		cum += a.get("weight", 1)
		if roll < cum: return a
	return weighted[0]

func _execute_enemy_action(action: Dictionary) -> void:
	if action.is_empty(): return
	var mul   = EmotionManager.get_enemy_damage_multiplier()
	# 愤怒阶段：敌人伤害额外×1.3
	if boss_phase == 2:
		mul *= 1.3
	var atype = action.get("type", "")
	match atype:
		"attack":
			# 先检查玩家闪避
			if _dodge_charges > 0:
				_dodge_charges -= 1
				# 闪避成功，不扣血，播放浮字由 BattleScene 通过 hp_changed 无变化判断
			else:
				var raw = int(action.get("value", 0) * mul)
				var dmg = BuffManager.absorb_damage(BuffManager.TARGET_PLAYER, raw)
				if player_shield > 0:
					var blocked = min(player_shield, dmg)
					player_shield -= blocked
					dmg -= blocked
				if dmg > 0:
					GameState.take_damage(dmg)

		"emotion_push":
			EmotionManager.modify(action.get("emotion", ""), action.get("value", 1))

		"dot", "dot_fire", "all_field_heat_dot":
			BuffManager.parse_dot_action(action)

		"shield":
			enemy_shield += action.get("value", 0)

		"draw_player":
			# 摄魅眼：强迫玩家摸牌（手牌超上限会被迫弃牌，陷阱效果）
			var draw_count = action.get("value", 2)
			DeckManager.draw_cards(draw_count)
			# 若手牌数超过上限(7)，强制弃置最新摸的牌
			var max_hand = 7
			while len(DeckManager.hand) > max_hand:
				DeckManager.discard_from_hand(DeckManager.hand[-1])

		"summon_tide":
			# 水鬼·望归：召唤潮汐连击（连续造成多次小伤害，每次固定值）
			var hit_count = action.get("hits", 3)
			var hit_val   = action.get("value", 8)
			for _i in hit_count:
				var raw  = int(hit_val * mul)
				var dmg  = BuffManager.absorb_damage(BuffManager.TARGET_PLAYER, raw)
				if player_shield > 0:
					var blocked = min(player_shield, dmg)
					player_shield -= blocked
					dmg -= blocked
				if dmg > 0:
					GameState.take_damage(dmg)
				if GameState.hp <= 0: break
			# 潮汐附带：玩家情绪「悲」+1
			EmotionManager.modify("grief", 1)

		"rage_card_storm":
			# 鬼新娘·素锦：狂暴连击（伤害随玩家手牌数量递增）
			var base_dmg  = action.get("value", 5)
			var hand_size = len(DeckManager.hand)
			# 每张手牌+2额外伤害，模拟"花嫁之怒吞噬一切"
			var total_dmg = int((base_dmg + hand_size * 2) * mul)
			var dmg = BuffManager.absorb_damage(BuffManager.TARGET_PLAYER, total_dmg)
			if player_shield > 0:
				var blocked = min(player_shield, dmg)
				player_shield -= blocked
				dmg -= blocked
			if dmg > 0:
				GameState.take_damage(dmg)
			# 狂暴风暴附带：让玩家「惧」「悲」各+1
			EmotionManager.modify("fear", 1)
			EmotionManager.modify("grief", 1)

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
