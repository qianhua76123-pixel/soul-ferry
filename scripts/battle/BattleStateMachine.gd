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
signal wu_wei_mark_applied(emotion: String, count: int, turns_left: int)
signal wu_wei_ended_with_duhua()
signal chain_applied(total_chains: int)  # 锁链施加后通知 HUD 刷新
signal marks_changed(marks: Dictionary)  # 印记层数变化通知 UI
signal card_blocked_by_disorder(card: Dictionary, reason: String)  # 失控限制：牌无法打出
signal du_hua_state_updated(frequency: int, interrupts: int, stage: int)  # 渡化频率/中断/阶段状态变化

# ── 渡化窗口系统变量 ──────────────────────────────────
var du_hua_frequency: int = 0          # 渡化频率（0-100）
var du_hua_interrupts: int = 0         # 本场渡化中断次数
var du_hua_stage: int = 0              # 渡化阶段（0/1/2/完成）
var du_hua_window_open: bool = false   # 渡化窗口是否开放
var du_hua_emotion_sync_count: int = 0 # 本场情绪同步完成次数（用于quality判断）
var _stage_turn_counter: int = 0       # 阶段内回合计数（阶段1→2有3回合时间窗口）
var purification_quality: String = ""  # "minimal"/"stable"/"perfect"

# ── 执念计数器 ──────────────────────────────────────
var enemy_obsession: int = 0           # 执念层数（0-5）
var _obsession_burst_active: bool = false  # 执念爆发：本回合敌人行动效果×2

# ── 渡化出牌统计 ──────────────────────────────────────
var _cards_played_this_turn_by_emotion: Dictionary = {}  # 本回合各情绪出牌计数

# ── 护盾保留标记 ──────────────────────────────────────
var _shield_no_expire_flag: bool = false  # true时本回合末护盾不减半

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

# ── 铁壁流新增：铁甲系统 ──────────────────────────
var player_armor: int = 0          # 铁甲：固定减伤（每次受到伤害先消耗铁甲）
var _armor_to_attack_bonus: int = 0  # 「定而无极」临时攻击加成（本回合）
var _shield_regen_rate: float = 0.0  # 万夫莫开：护盾损失回复比例
var _damage_taken_this_turn: int = 0  # 百炼成钢：本回合受伤总计
var _reflect_charges: int = 0      # 盾反/山岳反甲：反弹次数
var _reflect_ratio: float = 0.0    # 当前反弹比例
var _persistent_shield_turns: int = 0  # 静若磐石剩余回合
var _persistent_shield_per_turn: int = 0  # 静若磐石每回合盾值

# ── 光愈流新增 ──────────────────────────────────
var _last_resonance_triggered: String = ""  # 镜花：记录上一次共鸣
var _next_card_free: bool = false           # 花开效果：下一张牌免费
var _enemy_marks: Dictionary = {}          # 敌人身上的印记层数 {emotion: count}
var _wu_wei_turns_remaining: int = 0       # 无为持续回合
var _wu_wei_marks_per_turn: Dictionary = {}

# ── 沈铁钧新增 ──────────────────────────────────
var enemy_chains: int = 0           # 锁链层数（主目标）
var _total_chains_this_battle: int = 0  # 千斤锁检测
var _skip_next_action: bool = false  # 锁链镇压/fear共鸣：标记跳过敌人下一次行动

var joy_cards_played_this_turn: int = 0
var du_hua_triggered: bool = false

func start_battle(enemy_id: String) -> void:
	var enemy: Dictionary = _load_enemy(enemy_id)
	if enemy.is_empty():
		push_error("BattleStateMachine: 未找到敌人 " + enemy_id)
		enemy = {"id": enemy_id, "name": "亡魂", "hp": 50, "actions": [{"type":"attack","value":8,"weight":100}]}
	enemy_data = enemy
	enemy_hp = enemy.get("hp", 50)
	enemy_max_hp = enemy_hp
	enemy_shield = 0
	player_shield = 0
	player_armor  = 0
	enemy_chains  = 0
	_total_chains_this_battle = 0
	_skip_next_action = false  # 重置锁链跳过标记
	_damage_taken_this_turn = 0
	_reflect_charges = 0
	_reflect_ratio   = 0.0
	_persistent_shield_turns = 0
	_enemy_marks = {}
	marks_changed.emit({})
	_wu_wei_turns_remaining = 0
	current_turn = 0
	joy_cards_played_this_turn = 0
	du_hua_triggered = false

	# 重置渡化系统
	du_hua_frequency = 0
	du_hua_interrupts = 0
	du_hua_stage = 0
	du_hua_window_open = false
	du_hua_emotion_sync_count = 0
	_stage_turn_counter = 0
	purification_quality = ""
	du_hua_triggered = false

	# 重置执念计数器
	enemy_obsession = enemy_data.get("obsession_init", 0)
	_obsession_burst_active = false

	# 重置出牌统计
	_cards_played_this_turn_by_emotion = {}
	_shield_no_expire_flag = false

	# ── 重置所有 Autoload 系统 ──────────────────────────
	# 情绪全部归零
	EmotionManager.reset_all()
	# 应用情绪余韵（上一场战斗的跨战斗情绪延续）
	var lingering: String = str(GameState.get_meta("lingering_emotion", ""))
	if lingering != "":
		EmotionManager.modify(lingering, int(GameState.get_meta("lingering_value", 0)))
		GameState.remove_meta("lingering_emotion")
		GameState.remove_meta("lingering_value")
	# 牌堆归位（手牌/弃牌堆→抽牌堆，重新洗牌）
	DeckManager.on_battle_start()
	# 清空所有 Buff
	BuffManager.clear_all()
	# 碎片清零已删除（碎片系统下线）
	# DiscardSystem.clear_run_shards()
	# 无名激活状态
	var char_id: String = str(GameState.get_meta("selected_character", ""))
	if char_id == "wumian":
		WumianManager.activate()
	else:
		WumianManager.deactivate()

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
	var file: FileAccess = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if not file:
		return {}
	var json: JSON = JSON.new()
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
	_cards_played_this_turn_by_emotion = {}  # 重置本回合各情绪出牌计数
	_obsession_burst_active = false           # 重置执念爆发标记
	current_state = STATE_PLAYER_TURN
	# 执念计数器：每回合开始+1
	_on_turn_start_obsession()
	# Buff 系统：回合开始处理
	BuffManager.process_turn_start(BuffManager.TARGET_PLAYER)
	DeckManager.on_turn_start()
	if EmotionManager.is_disorder("fear"):
		DeckManager.discard_random()
	player_turn_started.emit(current_turn)
	intent_updated.emit(next_intent)
	# 无为：持续施印倒计时
	_process_wu_wei_tick()
	# 回合开始时也检查渡化条件（emotion_threshold 型不依赖出牌）
	_check_du_hua({})

func play_card(card: Dictionary) -> bool:
	if current_state != STATE_PLAYER_TURN:
		return false
	# ── 失控限制检查 ──────────────────────────────────
	if not EmotionManager.can_play_card(card):
		card_blocked_by_disorder.emit(card, _get_blocked_reason(card))
		return false
	# ─────────────────────────────────────────────────
	current_state = STATE_RESOLVING
	if not DeckManager.play_card(card):
		current_state = STATE_PLAYER_TURN
		return false
	var result: Dictionary = _apply_card_effect(card)
	card_effect_applied.emit(card, result)
	if card.get("emotion_tag", "") == "joy":
		joy_cards_played_this_turn += 1
	else:
		joy_cards_played_this_turn = 0
	# 统计本回合各情绪出牌数
	var ctag: String = card.get("emotion_tag", "")
	if ctag != "":
		_cards_played_this_turn_by_emotion[ctag] = _cards_played_this_turn_by_emotion.get(ctag, 0) + 1
	# 渡化类牌：降低执念
	if card.get("effect_type", "") in ["du_hua_progress", "du_hua_trigger", "heal_and_purify_and_mark", "wumian_ferry_token"]:
		_on_purification_card_played()
	_check_du_hua(card)
	current_state = STATE_PLAYER_TURN
	if enemy_hp <= 0:
		_end_battle("victory")
	return true

func _get_blocked_reason(card: Dictionary) -> String:
	## 根据当前失控状态返回阻止打牌的原因文字
	var tag: String = card.get("emotion_tag", "")
	var etype: String = card.get("effect_type", "")
	var cost: int = card.get("cost", 1)
	if EmotionManager.is_disorder("rage"):
		if tag == "calm": return "怒失控：无法打出定系牌"
		if etype == "shield": return "怒失控：无法打出护盾牌"
	if EmotionManager.is_disorder("grief"):
		if etype in ["heal", "heal_all_buffs"]: return "悲失控：无法打出治疗牌"
	if EmotionManager.is_deep_disorder("fear"):
		if cost == 0: return "惧深度失调：无法打出费用0的牌"
	return "失控限制"

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
	# 锁链自然衰减：每回合结束 -1 层（最低 0）
	if enemy_chains > 0:
		enemy_chains = maxi(0, enemy_chains - 1)
		chain_applied.emit(enemy_chains)
	# 渡化频率自然衰减（每回合末-10，最低0）
	du_hua_frequency = maxi(0, du_hua_frequency - 10)
	du_hua_state_updated.emit(du_hua_frequency, du_hua_interrupts, du_hua_stage)

	# 渡化超时中断：条件已触发但玩家超过5回合没有确认渡化
	if du_hua_triggered and du_hua_stage != -1:
		_stage_turn_counter += 1
		if _stage_turn_counter > 5:
			_handle_du_hua_interrupt()
	# 护盾减半处理（替代原来的清零）
	if not _shield_no_expire_flag:
		player_shield = player_shield / 2  # 向下取整（GDScript 整数除法）
	_shield_no_expire_flag = false
	_begin_enemy_turn()

## Boss 当前阶段（1=正常, 2=愤怒），由 BossUI.boss_phase_changed 信号更新
var boss_phase: int = 1

func _begin_enemy_turn() -> void:
	current_state = STATE_ENEMY_TURN
	enemy_turn_started.emit()
	var action: Dictionary = _choose_enemy_action()
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
	var effect_type: String = card.get("effect_type", "")
	var base_val: int    = card.get("effect_value", 0)
	var bonus: int       = card.get("condition_bonus", 0) if _check_condition(card) else 0
	var result: Dictionary = {"type": effect_type, "value": 0}

	match effect_type:
		"attack", "attack_all":
			var dmg: int = int((base_val + bonus) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg)
			result.value = dmg

		"attack_all_triple":
			# 三次多段伤害
			var dmg_each: int = int((base_val + bonus) * EmotionManager.get_attack_multiplier())
			var total: int = 0
			for _i in 3:
				_deal_damage_to_enemy(dmg_each)
				total += dmg_each
			result.value = total

		"attack_lifesteal":
			var dmg_2: int = int((base_val + bonus) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg_2)
			GameState.heal(dmg_2)
			result.value = dmg_2
			result["healed"] = dmg_2

		"attack_dot":
			var dmg_2_2: int = int((base_val + bonus) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg_2_2)
			BuffManager.add_buff(BuffManager.TARGET_ENEMY, "dot_fire", 4, 3)
			result.value = dmg_2_2

		"attack_scaling_rage":
			# 伤害 = base_val × 当前怒值
			var rage_val: int = EmotionManager.values.get("rage", 0)
			var dmg_2_2_2: int = int((base_val * maxi(1, rage_val)) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg_2_2_2)
			result.value = dmg_2_2_2

		"attack_and_weaken_all":
			var dmg_2_2_2_2: int = int((base_val + bonus) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg_2_2_2_2)
			result["weaken_percent"] = 50
			result["defense_break"]  = 50
			result.value = dmg_2_2_2_2

		"shield":
			var sv: int = base_val + bonus
			player_shield += sv
			result.value = sv

		"shield_attack":
			# 护盾 + 造成等量伤害
			var sv_2: int = base_val + bonus
			player_shield += sv_2
			_deal_damage_to_enemy(sv_2)
			result.value = sv_2

		"shield_and_draw":
			var sv_2_2: int = base_val + bonus
			player_shield += sv_2_2
			DeckManager.draw_cards(2)
			result.value = sv_2_2

		"heal", "heal_all_buffs":
			var hv: int = int((base_val + bonus) * EmotionManager.get_heal_multiplier())
			GameState.heal(hv)
			result.value = hv

		"heal_and_draw":
			var hv_2: int = int((base_val + bonus) * EmotionManager.get_heal_multiplier())
			GameState.heal(hv_2)
			DeckManager.draw_cards(2)
			result.value = hv_2

		"heal_scale_grief":
			# 回复 = base_val × 悲情绪值
			var grief_val: int = EmotionManager.values.get("grief", 0)
			var hv_2_2: int = int(base_val * maxi(1, grief_val) * EmotionManager.get_heal_multiplier())
			GameState.heal(hv_2_2)
			result.value = hv_2_2

		"mass_heal_shield":
			var hv_2_2_2: int = int(base_val * EmotionManager.get_heal_multiplier())
			GameState.heal(hv_2_2_2)
			player_shield += base_val
			result.value = base_val
			result["healed"] = hv_2_2_2

		"draw":
			DeckManager.draw_cards(base_val)
			result.value = base_val

		"draw_shield":
			DeckManager.draw_cards(base_val)
			var sv_2_2_2: int = bonus if bonus > 0 else 5
			player_shield += sv_2_2_2
			result.value = sv_2_2_2

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
			var dmg_2_2_2_2_2: int = int(base_val * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg_2_2_2_2_2)
			result.value = dmg_2_2_2_2_2

		"remove_enemy_shield":
			# 清除敌人护盾并转化为伤害
			var removed: int = enemy_shield
			enemy_shield = 0
			if removed > 0:
				_deal_damage_to_enemy(removed)
			result.value = removed

		"reset_shield":
			# 五情归一：护盾 = 五情总值 × base_val
			var total_2: float = EmotionManager.get_total_value()
			var sv_2_2_2_2: int = total_2 * base_val
			player_shield += sv_2_2_2_2
			result.value = sv_2_2_2_2

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
			var vals: Dictionary = EmotionManager.values
			var avg = 0.0
			for k in vals: avg += vals[k]
			avg /= float(vals.size())
			for k in vals:
				var diff: int = vals[k] - int(avg)
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

		# ── 光愈流新卡牌效果 ──────────────────────────────
		"apply_mark_and_heal":
			# 喜祷：施加喜印+治疗
			var mark_count: int = base_val  # effect_value=2（印记数）
			var heal_val: int   = card.get("effect_value", 5)
			var has_existing: bool = _enemy_marks.get("joy", 0) > 0
			_apply_mark("joy", mark_count if not _check_condition(card) else mark_count)
			var actual_heal: int = (8 + bonus) if has_existing else (5 + bonus)
			GameState.heal(int(actual_heal * EmotionManager.get_heal_multiplier()))
			result.value = actual_heal

		"emotion_and_mark":
			# 定澄：定+情绪，同时施印
			var emo_shift: Dictionary = card.get("emotion_shift", {})
			for e: String in emo_shift:
				EmotionManager.modify(e, int(emo_shift[e]))
			var marks: Dictionary = card.get("marks_to_apply", {})
			var calm_bonus: int = 1 if _check_condition(card) else 0
			for e: String in marks:
				_apply_mark(e, int(marks[e]) + calm_bonus)
			_check_resonances()
			result.value = 0

		"trigger_resonance_if_marks":
			# 花开：满足印记条件时触发喜共鸣
			var req_marks: Dictionary = card.get("marks_required", {})
			var can_trigger: bool = true
			for e: String in req_marks:
				if _enemy_marks.get(e, 0) < int(req_marks[e]):
					can_trigger = false
			if can_trigger:
				_trigger_resonance("joy")
				_next_card_free = true
				result["resonance_triggered"] = "joy"
				result["next_card_free"] = true
			result.value = 0

		"shield_and_mark":
			# 定心结界：护盾+施印+触发定共鸣
			var sv: int = base_val + bonus
			player_shield += sv
			var marks2: Dictionary = card.get("marks_to_apply", {})
			for e: String in marks2:
				_apply_mark(e, int(marks2[e]))
			_check_resonances()
			result.value = sv

		"multiply_marks_and_heal":
			# 喜溢：喜印×2+回血
			var cap: int = card.get("mark_cap", 10)
			var old_count: int = _enemy_marks.get("joy", 0)
			var new_count: int = mini(old_count * 2, cap)
			_enemy_marks["joy"] = new_count
			var hv3: int = int(new_count * EmotionManager.get_heal_multiplier())
			GameState.heal(hv3)
			result.value = hv3

		"shield_equal_to_emotion":
			# 空灵护体：护盾=定×N
			var emo: String = card.get("shield_base_emotion", "calm")
			var mul: int    = base_val
			var sv3: int    = EmotionManager.values.get(emo, 0) * mul
			player_shield += sv3
			var emo_shift2: Dictionary = card.get("emotion_shift", {})
			for e: String in emo_shift2:
				EmotionManager.modify(e, int(emo_shift2[e]))
			result.value = sv3

		"multi_mark_and_trigger":
			# 双印汇流：同时施加两种印记，满足条件触发两次共鸣
			var marks3: Dictionary = card.get("marks_to_apply", {})
			for e: String in marks3:
				_apply_mark(e, int(marks3[e]))
			var trigger_cond: Dictionary = card.get("trigger_condition", {})
			var total_joy_calm: int = _enemy_marks.get("joy", 0) + _enemy_marks.get("calm", 0)
			if total_joy_calm >= trigger_cond.get("total_joy_calm_marks", 6):
				_trigger_resonance("joy")
				_trigger_resonance("calm")
				result["both_resonance"] = true
			result.value = 0

		"emotion_and_heal":
			# 喜泉：定情绪+回血，每回合限次
			var emo_s: Dictionary = card.get("emotion_shift", {})
			for e: String in emo_s:
				EmotionManager.modify(e, int(emo_s[e]))
			if _check_condition(card):
				var hv4: int = int(2 * EmotionManager.get_heal_multiplier())
				GameState.heal(hv4)
				result.value = hv4

		"heal_by_marks_and_draw":
			# 愈灵诀：回血=喜印+定印总数，抽牌
			var mark_types: Array = card.get("heal_from_marks", ["joy", "calm"])
			var total_marks: int = 0
			for e: String in mark_types:
				total_marks += _enemy_marks.get(e, 0)
			var min_heal: int = card.get("effect_value", 4)
			var max_heal: int = card.get("heal_cap", 15)
			var hv5: int = int(clampi(total_marks, min_heal, max_heal) * EmotionManager.get_heal_multiplier())
			GameState.heal(hv5)
			DeckManager.draw_cards(card.get("draw", 1))
			result.value = hv5

		"mark_and_delay":
			# 定念封印：施印+延迟敌人行动
			var marks4: Dictionary = card.get("marks_to_apply", {})
			for e: String in marks4:
				_apply_mark(e, int(marks4[e]))
			result["enemy_action_delay"] = 1
			result.value = 0

		"convert_marks_and_resonate":
			# 喜定同流：定印→喜印，触发共鸣
			var old_calm_marks: int = _enemy_marks.get("calm", 0)
			if old_calm_marks > 0:
				_enemy_marks["calm"] = 0
				_apply_mark("joy", old_calm_marks)
			_trigger_resonance("joy")
			result["resonance_triggered"] = "joy"
			result.value = 0

		"heal_and_purify_and_mark":
			# 光与愈：回血+渡化进度+施印
			var hv6: int = int(base_val * EmotionManager.get_heal_multiplier())
			GameState.heal(hv6)
			var purif_base: float = card.get("purification_bonus", 0.20)
			var purif_extra: float = card.get("condition_bonus_purification", 0.0) if _check_condition(card) else 0.0
			result["du_hua_progress"] = purif_base + purif_extra
			var marks5: Dictionary = card.get("marks_to_apply", {})
			for e: String in marks5:
				_apply_mark(e, int(marks5[e]))
			result.value = hv6

		"repeat_last_resonance":
			# 镜花：重复上一次共鸣
			if _last_resonance_triggered != "":
				_trigger_resonance(_last_resonance_triggered)
				result["repeated_resonance"] = _last_resonance_triggered
			result.value = 0

		"persistent_mark_and_purify":
			# 无为：开启持续施印+回血
			_wu_wei_turns_remaining = card.get("duration_turns", 3)
			_wu_wei_marks_per_turn  = card.get("per_turn_marks", {"joy": 1, "calm": 1})
			result["wu_wei_started"] = true
			result.value = 0

		# ── 铁壁流新卡牌效果 ──────────────────────────────
		"shield_and_emotion":
			# 铁躯：护盾+定
			var sv4: int = base_val + bonus
			player_shield += sv4
			var emo_s4: Dictionary = card.get("emotion_shift", {})
			for e: String in emo_s4:
				EmotionManager.modify(e, int(emo_s4[e]))
			result.value = sv4

		"emotion_and_shield_by_emotion":
			# 定心如山：定+护盾=定×N
			var emo_s5: Dictionary = card.get("emotion_shift", {})
			for e: String in emo_s5:
				EmotionManager.modify(e, int(emo_s5[e]))
			var mul2: int   = base_val
			var sv5: int    = EmotionManager.values.get("calm", 0) * mul2
			player_shield += sv5
			result.value = sv5

		"reflect_next_damage":
			# 盾反：下次伤害反弹N%
			_reflect_charges = 1
			_reflect_ratio   = float(base_val)
			result["reflect_active"] = true
			result.value = 0

		"convert_shield_to_armor":
			# 铁甲覆体：护盾转铁甲
			var ratio: float = float(base_val)
			var converted: int = int(player_shield * ratio)
			player_armor += converted
			# 护盾本回合不清零：通过 shield_no_expire_this_turn 标记
			result["armor_gained"] = converted
			result.value = converted

		"emotion_and_crowd_control":
			# 定阵：定+群控
			var emo_s6: Dictionary = card.get("emotion_shift", {})
			for e: String in emo_s6:
				EmotionManager.modify(e, int(emo_s6[e]))
			result["all_enemies_static"] = 1
			result.value = 0

		"shield_and_reflect_buff":
			# 山岳：护盾+反甲Buff
			player_shield += base_val
			_reflect_charges = card.get("reflect_max_times", 3)
			_reflect_ratio   = card.get("reflect_ratio", 0.40)
			result["mountain_reflect"] = true
			result.value = base_val

		"attack_by_armor":
			# 以柔克刚：伤害=铁甲×N
			var dmg3: int = int((player_armor * float(base_val) + card.get("base_damage", 5)) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg3)
			result.value = dmg3

		"attack_by_shield":
			# 铁壁突刺：伤害=护盾×%
			if player_shield <= 0:
				result.value = 0
			else:
				var dmg4: int = int(player_shield * float(base_val) * EmotionManager.get_attack_multiplier())
				_deal_damage_to_enemy(dmg4)
				result.value = dmg4

		"emotion_with_condition_bonus":
			# 凝定：定+条件奖励（满足条件时实际施加锁链）
			var emo_s7: Dictionary = card.get("emotion_shift", {})
			for e: String in emo_s7:
				EmotionManager.modify(e, int(emo_s7[e]))
			if _check_condition(card):
				result["bonus_energy_next_turn"] = card.get("condition_bonus_energy", 1)
				var chain_bonus: int = card.get("condition_bonus_chain", 1)
				result["bonus_chain"] = chain_bonus
				# 实际施加锁链（之前只写 result 但未执行效果）
				_apply_chain(chain_bonus)
			result.value = 0

		"convert_damage_taken_to_armor":
			# 百炼成钢：本回合受伤→铁甲
			var armor_gained: int = int(_damage_taken_this_turn * float(base_val))
			player_armor += armor_gained
			player_shield = 0  # 护盾清零
			result["armor_gained"] = armor_gained
			result.value = armor_gained

		"chain_and_shield":
			# 守土：施锁+护盾
			_apply_chain(card.get("chain_to_apply", 1))
			var sv6: int = base_val + bonus
			player_shield += sv6
			result.value = sv6

		"emotion_and_immune_debuff":
			# 无动于衷：定+免疫状态
			var emo_s8: Dictionary = card.get("emotion_shift", {})
			for e: String in emo_s8:
				EmotionManager.modify(e, int(emo_s8[e]))
			_dodge_charges += card.get("immune_next_debuff", 1)  # 复用 dodge 系统
			result["immune_debuff"] = true
			result.value = 0

		"shield_regen_on_hit":
			# 万夫莫开：护盾损失回复
			_shield_regen_rate = float(base_val)
			result["shield_regen_active"] = true
			result.value = 0

		"persistent_shield":
			# 静若磐石：持续回合护盾
			_persistent_shield_turns    = card.get("duration_turns", 3)
			_persistent_shield_per_turn = EmotionManager.values.get("calm", 0) * base_val
			player_shield += _persistent_shield_per_turn
			result["persistent_shield_started"] = true
			result.value = _persistent_shield_per_turn

		"armor_to_attack_bonus":
			# 定而无极：铁甲→攻击加成
			_armor_to_attack_bonus = player_armor * base_val
			player_armor = 0
			var emo_s9: Dictionary = card.get("emotion_shift", {})
			for e: String in emo_s9:
				EmotionManager.modify(e, int(emo_s9[e]))
			result["attack_bonus_this_turn"] = _armor_to_attack_bonus
			result.value = _armor_to_attack_bonus

		# ── 无面人·空系统卡牌效果 ──────────────────────────────
		"wumian_attack_emptiness":
			# 空手道：伤害8+空度效果倍率，分段变化时抽牌
			var old_tier: int = WumianManager.current_tier
			var dmg: int = int(base_val * WumianManager.get_effect_multiplier() * WumianManager.get_damage_modifier() * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg)
			WumianManager.on_card_played()  # 空度+1（通用打牌+1）
			WumianManager.modify_emptiness(1)  # 空手道额外+1（共+2）
			if WumianManager.current_tier != old_tier:
				DeckManager.draw_cards(1)
			result.value = dmg

		"wumian_set_emptiness_5":
			# 无为：空度强制归5
			var was_above: bool = WumianManager.emptiness > 5
			WumianManager.modify_emptiness(5 - WumianManager.emptiness)
			if was_above:
				DeckManager.current_cost = mini(DeckManager.current_cost + 1, DeckManager.max_cost)
			else:
				GameState.heal(4)
			result.value = 5

		"wumian_invert_emptiness":
			# 虚实互换：空度变为(10-空度)
			var new_e: int = 10 - WumianManager.emptiness
			WumianManager.modify_emptiness(new_e - WumianManager.emptiness)
			result.value = WumianManager.emptiness

		"wumian_emptiness_surge":
			# 空溢：空度+3，到10立即触发空鸣
			WumianManager.modify_emptiness(3)
			if WumianManager.emptiness >= 10:
				WumianManager.trigger_kongming_forced()
			result.value = WumianManager.emptiness

		"wumian_emptiness_absorb":
			# 空收：空度-3，护盾=减少量×4
			var reduce: int = mini(3, WumianManager.emptiness)
			WumianManager.modify_emptiness(-reduce)
			var sv: int = reduce * 4
			player_shield += sv
			result.value = sv

		"wumian_force_kongming":
			# 空鸣诀：直接触发空鸣
			WumianManager.trigger_kongming_forced()
			result.value = 0

		"wumian_float_sink":
			# 浮沉：≤5时+3；>5时-3；无论如何抽1张
			if WumianManager.emptiness <= 5:
				WumianManager.modify_emptiness(3)
			else:
				WumianManager.modify_emptiness(-3)
			DeckManager.draw_cards(1)
			result.value = WumianManager.emptiness

		"wumian_borrow_emotion":
			# 借情：目标最高情绪-2，可选转移或消散（BattleScene 处理玩家选择）
			result["borrow_emotion"] = true
			result["amount"] = 2
			result.value = 2

		"wumian_transfer_emotion_to_enemy":
			# 情渡：自身任意情绪→敌人（BattleScene 处理情绪选择）
			result["transfer_to_enemy"] = true
			result["max_amount"] = 3
			result.value = 0

		"wumian_mirror_emotions":
			# 情镜：BattleScene 处理双目标选择
			result["mirror_emotions"] = true
			result.value = 0

		"wumian_borrow_power":
			# 借力打力：穿甲伤害=目标最高情绪×5，该情绪归零
			var top_e: String = "grief"
			var top_v: int = 0
			for e: String in EmotionManager.EMOTIONS:
				var ev: int = EmotionManager.values.get(e, 0)
				if ev > top_v:
					top_v = ev
					top_e = e
			var dmg2: int = int(top_v * 5 * WumianManager.get_effect_multiplier() * WumianManager.get_damage_modifier())
			_deal_damage_to_enemy(dmg2)
			EmotionManager.modify(top_e, -top_v)
			result["emotion_cleared"] = top_e
			result.value = dmg2

		"wumian_emotion_debt":
			# 情债：对敌人施加标记（BattleScene 处理 Buff 应用）
			result["apply_emotion_debt"] = true
			result.value = 0

		"wumian_swap_emotions":
			# 移情别恋：BattleScene 处理三种情绪选择
			result["swap_emotions"] = true
			result.value = 0

		"wumian_void_emotions":
			# 空情：目标所有情绪归零，空度-1；清除≥5点时穿甲伤15
			var total_cleared: int = 0
			for e: String in EmotionManager.EMOTIONS:
				total_cleared += EmotionManager.values.get(e, 0)
				EmotionManager.modify(e, -EmotionManager.values.get(e, 0))
			WumianManager.modify_emptiness(-1)
			if total_cleared >= 5:
				_deal_damage_to_enemy(15)
				result.value = 15
			result["cleared_total"] = total_cleared

		"wumian_attack_by_emptiness":
			# 虚无掌：伤害=5+空度×2
			var dmg3: int = int((5 + WumianManager.emptiness * 2) * WumianManager.get_effect_multiplier() * WumianManager.get_damage_modifier() * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg3)
			result.value = dmg3

		"wumian_attack_all_disorder":
			# 空中劈：全体伤害6，失调敌人额外+超出量×4
			var base_dmg: int = int(6 * WumianManager.get_effect_multiplier() * WumianManager.get_damage_modifier() * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(base_dmg)
			result.value = base_dmg

		"wumian_attack_void_solid":
			# 以空击实：空度≥7时穿甲15+强制失调；否则伤害6
			if WumianManager.emptiness >= 7:
				var dmg4: int = int(15 * WumianManager.get_effect_multiplier())
				_deal_damage_to_enemy(dmg4)
				result["force_disorder"] = true
				result.value = dmg4
			else:
				var dmg5: int = int(6 * WumianManager.get_effect_multiplier() * WumianManager.get_damage_modifier() * EmotionManager.get_attack_multiplier())
				_deal_damage_to_enemy(dmg5)
				result.value = dmg5

		"wumian_emotion_burst":
			# 情绪炸裂：触发所有≥3情绪失调效果，每个+10点伤害
			var total_dmg: int = 0
			for e: String in EmotionManager.EMOTIONS:
				if EmotionManager.values.get(e, 0) >= 3:
					_deal_damage_to_enemy(10)
					total_dmg += 10
			result.value = total_dmg

		"wumian_counter_damage":
			# 空手还魂：伤害=本回合已受伤害，空度减少=受伤/4
			var counter_dmg: int = _damage_taken_this_turn
			if counter_dmg > 0:
				_deal_damage_to_enemy(counter_dmg)
				WumianManager.modify_emptiness(-(counter_dmg / 4))
			result["counter_damage"] = counter_dmg
			result.value = counter_dmg

		"wumian_void_shield":
			# 空盾：空度-2，护盾=6-当前空度（最低2，最高6）
			var reduce2: int = mini(2, WumianManager.emptiness)
			WumianManager.modify_emptiness(-reduce2)
			var sv2: int = clampi(6 - WumianManager.emptiness, 2, 6)
			player_shield += sv2
			result.value = sv2

		"wumian_mirror_shield":
			# 镜面护：护盾8，受伤30%反弹为情绪转移
			player_shield += 8
			result["mirror_reflect_ratio"] = 0.30
			result.value = 8

		"wumian_etherealize":
			# 虚化：免疫下一次攻击，空度+3
			_dodge_charges += 1
			WumianManager.modify_emptiness(3)
			result.value = 0

		"wumian_omnipresent":
			# 无处不在：每次受伤自动空度-1，积累护盾=触发次数×2（BattleScene 监听处理）
			result["omnipresent_active"] = true
			result.value = 0

		"wumian_explore":
			# 空·探：抽2张，空度+1
			DeckManager.draw_cards(2)
			WumianManager.modify_emptiness(1)
			result.value = 2

		"wumian_observe":
			# 观形：揭示敌人全部情绪/Buff/3回合意图，空度-1
			WumianManager.modify_emptiness(-1)
			result["reveal_enemy_full"] = true
			result["reveal_turns_ahead"] = 3
			result.value = 0

		"wumian_one_thought":
			# 一念：弃全部手牌，抽同等数量+1张，空度+弃牌数
			var discard_count: int = DeckManager.hand.size()
			DeckManager.discard_hand()
			WumianManager.modify_emptiness(discard_count)
			DeckManager.draw_cards(discard_count + 1)
			result.value = discard_count

		"wumian_ferry_token":
			# 渡口令：渡化进度+15%，空鸣后额外追加+20%
			result["du_hua_progress"] = 0.15
			result["kongming_bonus_progress"] = 0.20
			result.value = 0

		"wumian_set_emptiness_custom":
			# 调息：BattleScene 处理玩家选择0-10的空度值
			result["set_emptiness_custom"] = true
			result.value = 0

		_:
			pass
	return result

func _check_condition(card: Dictionary) -> bool:
	var cond: Variant = card.get("condition", null)
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
	## 渡化条件检查 — 以 du_hua_condition 为主要门槛，frequency 决定品质
	if du_hua_triggered: return
	if du_hua_stage == -1: return   # 永久关闭（第3次中断惩罚）

	var cond: Variant = enemy_data.get("du_hua_condition", null)
	if not cond: return

	var ctype: String = str(cond.get("type", "emotion_threshold"))
	var emotion_req: Dictionary = cond.get("emotion_requirement", {})

	# ── Step 1：检查情绪门槛（所有类型共享）─────────────────
	for emotion: String in emotion_req:
		if EmotionManager.values.get(emotion, 0) < int(emotion_req[emotion]):
			return   # 任一情绪未达标，直接退出

	# ── Step 2：按条件类型做附加检查 ─────────────────────────
	match ctype:
		"emotion_threshold":
			pass   # 情绪门槛已在 Step 1 完成，直接触发

		"card_play":
			if played_card.get("id", "") != str(cond.get("card_id", "")):
				return

		"consecutive_joy_cards":
			if joy_cards_played_this_turn < int(cond.get("count", 3)):
				return

		"emotion_and_low_hp":
			# 情绪达标 + 玩家 HP ≤ 50%
			var hp_ratio: float = float(GameState.hp) / float(maxi(1, GameState.max_hp))
			if hp_ratio > 0.5: return

		_:
			pass   # 未知类型：情绪门槛满足即触发

	# ── Step 3：记录情绪同步品质（frequency 越高品质越好）────
	du_hua_emotion_sync_count += 1
	# frequency 基于情绪共振程度动态计算品质
	var enemy_dom: String = str(enemy_data.get("dominant_emotion", ""))
	var player_dom: String = EmotionManager.dominant_emotion
	if enemy_dom != "" and player_dom == enemy_dom:
		du_hua_frequency = mini(du_hua_frequency + 30, 100)

	_trigger_du_hua()

func _handle_du_hua_interrupt() -> void:
	## 渡化中断惩罚系统（回合超时 or 条件丢失触发）
	du_hua_triggered = false  # 允许重新触发
	_stage_turn_counter = 0
	du_hua_interrupts += 1
	match du_hua_interrupts:
		1:
			# 第1次：敌人攻击+3持续2回合
			BuffManager.add_buff(BuffManager.TARGET_ENEMY, "attack_bonus_3", 3, 2)
		2:
			# 第2次：敌人回血15%，频率积累速率减半
			var heal_15: int = int(enemy_max_hp * 0.15)
			enemy_hp = mini(int(enemy_hp) + heal_15, enemy_max_hp)
			du_hua_frequency = du_hua_frequency / 2
		3:
			# 第3次：渡化永久关闭
			du_hua_stage = -1   # 特殊标记：永久关闭
	du_hua_state_updated.emit(du_hua_frequency, du_hua_interrupts, du_hua_stage)

## 渡化频率增加（敌人情绪施压后调用）
func _on_enemy_emotion_push_action() -> void:
	var gain: int = enemy_data.get("purification_window_gain", 20)
	du_hua_frequency = mini(du_hua_frequency + gain, 100)
	du_hua_state_updated.emit(du_hua_frequency, du_hua_interrupts, du_hua_stage)

## 执念计数器：每回合开始+1，达5时爆发
func _on_turn_start_obsession() -> void:
	enemy_obsession = mini(enemy_obsession + 1, 5)
	if enemy_obsession >= 5:
		_obsession_burst_active = true
		enemy_obsession -= 3

## 玩家打出渡化类牌时降低执念
func _on_purification_card_played() -> void:
	enemy_obsession = maxi(0, enemy_obsession - 1)

## 计算渡化品质
func _calculate_purification_quality() -> String:
	if du_hua_interrupts == 0 and du_hua_emotion_sync_count >= 3:
		return "perfect"
	elif du_hua_interrupts <= 1 and du_hua_emotion_sync_count >= 2:
		return "stable"
	else:
		return "minimal"

func _trigger_du_hua() -> void:
	if du_hua_triggered: return   # 防重入
	du_hua_triggered = true
	purification_quality = _calculate_purification_quality()
	var desc: String = str(
		enemy_data.get("du_hua_condition", {}).get("description", "渡化条件已满足"))
	du_hua_available.emit(desc)
	du_hua_state_updated.emit(du_hua_frequency, du_hua_interrupts, du_hua_stage)

func confirm_du_hua() -> void:
	if not du_hua_triggered: return
	GameState.record_du_hua(enemy_data.get("id", ""))
	du_hua_succeeded.emit(enemy_data.get("id",""))
	_end_battle("du_hua")

func _choose_enemy_action() -> Dictionary:
	var actions: Array = enemy_data.get("actions", [])
	if actions.is_empty(): return {}

	# Boss Phase 2：若存在 phase_2_actions，完全替换行动池
	if boss_phase == 2 and enemy_data.has("phase_2_actions"):
		var phase2_pool: Array = enemy_data.get("phase_2_actions", [])
		if not phase2_pool.is_empty():
			actions = phase2_pool
	elif boss_phase == 2:
		# 无 phase_2_actions 时使用原有权重调整逻辑
		var weighted: Array = actions.duplicate(true)
		for a in weighted:
			var t: String = a.get("type", "")
			if t in ["attack", "attack_all", "dot_fire", "dot", "all_field_heat_dot",
					 "summon_tide", "rage_card_storm"]:
				a["weight"] = int(a.get("weight", 1) * 2.5)
			elif t in ["shield", "heal"]:
				a["weight"] = maxi(1, int(a.get("weight", 1) * 0.3))
		actions = weighted

	var total: int = 0
	for a in actions:
		total += int(a.get("weight", 1))
	if total <= 0:
		return actions[0]
	var roll: int = randi() % total
	var cum: int = 0
	for a in actions:
		cum += int(a.get("weight", 1))
		if roll < cum:
			return a
	return actions[0]

func _execute_enemy_action(action: Dictionary) -> void:
	if action.is_empty(): return
	# 锁链镇压/fear共鸣：跳过本次行动（使用独立标记，避免与 next_intent 混淆）
	if _skip_next_action:
		_skip_next_action = false
		return
	var mul: float = EmotionManager.get_enemy_damage_multiplier()
	# 愤怒阶段：敌人伤害额外×1.3（仅在无 phase_2_actions 时）
	if boss_phase == 2 and not enemy_data.has("phase_2_actions"):
		mul *= 1.3
	# 执念爆发：本回合敌人行动效果×2
	if _obsession_burst_active:
		mul *= 2.0
	# 锁链削弱：每层锁链降低10%攻击力，最高降低50%
	if enemy_chains > 0:
		var chain_penalty: float = minf(float(enemy_chains) * 0.1, 0.5)
		mul *= (1.0 - chain_penalty)
	var atype: String = action.get("type", "")
	match atype:
		"attack", "attack_all":
			# 先检查玩家闪避
			if _dodge_charges > 0:
				_dodge_charges -= 1
				# 闪避成功，不扣血，播放浮字由 BattleScene 通过 hp_changed 无变化判断
			else:
				var raw: int = int(action.get("value", 0) * mul)
				var dmg: int = BuffManager.absorb_damage(BuffManager.TARGET_PLAYER, raw)
				if player_shield > 0:
					var blocked: int = mini(player_shield, dmg)
					player_shield -= blocked
					dmg -= blocked
				if dmg > 0:
					GameState.take_damage(dmg)
			# 处理 side_effect（Phase2行动的附加效果）
			var side: Dictionary = action.get("side_effect", {})
			if side.has("emotion_push"):
				EmotionManager.modify(str(side["emotion_push"]), int(side.get("value", 1)))
				_on_enemy_emotion_push_action()

		"emotion_push":
			EmotionManager.modify(action.get("emotion", ""), action.get("value", 1))
			# 情绪施压类行动：增加渡化频率
			_on_enemy_emotion_push_action()

		"dot", "dot_fire", "all_field_heat_dot":
			BuffManager.parse_dot_action(action)

		"shield":
			enemy_shield += action.get("value", 0)

		"draw_player":
			# 摄魅眼：强迫玩家摸牌（手牌超上限会被迫弃牌，陷阱效果）
			var draw_count: int = action.get("value", 2)
			DeckManager.draw_cards(draw_count)
			# 若手牌数超过上限(7)，强制弃置最新摸的牌
			var max_hand = 7
			while len(DeckManager.hand) > max_hand:
				DeckManager.discard_from_hand(DeckManager.hand[-1])

		"summon_tide":
			# 水鬼·望归：召唤潮汐连击（连续造成多次小伤害，每次固定值）
			var hit_count: int = action.get("hits", 3)
			var hit_val   = action.get("value", 8)
			for _i in hit_count:
				var raw_2  = int(hit_val * mul)
				var dmg_2  = BuffManager.absorb_damage(BuffManager.TARGET_PLAYER, raw_2)
				if player_shield > 0:
					var blocked_2: int = mini(player_shield, dmg_2)
					player_shield -= blocked_2
					dmg_2 -= blocked_2
				if dmg_2 > 0:
					GameState.take_damage(dmg_2)
				if GameState.hp <= 0: break
			# 潮汐附带：玩家情绪「悲」+1
			EmotionManager.modify("grief", 1)

		"rage_card_storm":
			# 鬼新娘·素锦：狂暴连击（伤害随玩家手牌数量递增）
			var base_dmg  = action.get("value", 5)
			var hand_size: int = len(DeckManager.hand)
			# 每张手牌+2额外伤害，模拟"花嫁之怒吞噬一切"
			var total_dmg: int = int((base_dmg + hand_size * 2) * mul)
			var dmg_2_2: int = BuffManager.absorb_damage(BuffManager.TARGET_PLAYER, total_dmg)
			if player_shield > 0:
				var blocked_2_2: int = mini(player_shield, dmg_2_2)
				player_shield -= blocked_2_2
				dmg_2_2 -= blocked_2_2
			if dmg_2_2 > 0:
				GameState.take_damage(dmg_2_2)
			# 狂暴风暴附带：让玩家「惧」「悲」各+1
			EmotionManager.modify("fear", 1)
			EmotionManager.modify("grief", 1)

		# ── Boss 专属行动 ──────────────────────────────────
		"heal_self":
			# Boss 自愈（水中沉潜等）
			var heal_val: int = int(action.get("value", 0))
			enemy_hp = minf(enemy_hp + heal_val, enemy_max_hp)

		"shield_self":
			# Boss 自盾
			var shield_val: int = int(action.get("value", 0))
			# 府衙封条遗物：敌人防御行动时锁链+1
			if RelicManager.has_relic("fu_ya_feng_tiao") or RelicManager.has_relic("fu_ya_feng_tiao_upgraded"):
				enemy_chains = mini(enemy_chains + 1, RelicManager.get_chain_stack_cap())
			enemy_shield += shield_val

		"drain_emotion":
			# Boss 吸取情绪（沈素锦：情感真空）
			var drain_count: int = action.get("drain_emotion_count", 1)
			var emotions: Array = ["grief", "fear", "rage", "joy", "calm"]
			for _i in drain_count:
				var rand_emo: String = emotions[randi() % emotions.size()]
				if EmotionManager.values.get(rand_emo, 0) > 0:
					EmotionManager.modify(rand_emo, -int(action.get("value", 1)))

		# ── Phase2 新增行动类型 ──────────────────────────────────

		"attack_armor_piercing":
			# 穿甲攻击（绕过护盾直接造成伤害）
			if _dodge_charges > 0:
				_dodge_charges -= 1
			else:
				var raw_ap: int = int(action.get("value", 0) * mul)
				var dmg_ap: int = BuffManager.absorb_damage(BuffManager.TARGET_PLAYER, raw_ap)
				# 穿甲：不扣护盾
				if dmg_ap > 0:
					GameState.take_damage(dmg_ap)
			# 处理 side_effect
			var se: Dictionary = action.get("side_effect", {})
			if se.has("emotion_push"):
				EmotionManager.modify(str(se["emotion_push"]), int(se.get("value", 1)))
				_on_enemy_emotion_push_action()

		"special_drown_memory":
			# 溺水记忆：手牌中情绪最多系变无效（由BattleScene响应，这里只记录状态）
			# 找出手牌中最多的情绪系
			var emotion_counts_h: Dictionary = {}
			for c: Dictionary in DeckManager.hand:
				var etag: String = c.get("emotion_tag", "")
				if etag != "":
					emotion_counts_h[etag] = emotion_counts_h.get(etag, 0) + 1
			var top_etag: String = ""
			var top_ecount: int = 0
			for etag: String in emotion_counts_h:
				if emotion_counts_h[etag] > top_ecount:
					top_ecount = emotion_counts_h[etag]
					top_etag = etag
			if top_etag != "":
				# 通过 meta 传递给 BattleScene 处理
				enemy_data["_drown_memory_tag"] = top_etag

		"shield_self_and_suppress_duhua":
			# 护盾+渡化频率-20
			var shield_val_s: int = int(action.get("value", 0))
			enemy_shield += shield_val_s
			var suppress: int = action.get("suppress", 20)
			du_hua_frequency = maxi(0, du_hua_frequency - suppress)
			du_hua_window_open = du_hua_frequency >= 60

		"apply_debuff":
			# Boss 施加 debuff（Phase2 扩展：支持新 debuff 类型）
			var debuff_type_2: String = str(action.get("value", ""))
			match debuff_type_2:
				"grief_aura":
					EmotionManager.modify("grief", 1)
					_on_enemy_emotion_push_action()
				"rage_aura":
					EmotionManager.modify("rage", 1)
					_on_enemy_emotion_push_action()
				"joy_drain":
					EmotionManager.modify("joy", -1)
				"jiao_gu":
					# 焦骨蔓延：2回合内每打牌受1DOT，通过 BuffManager 处理
					BuffManager.add_buff(BuffManager.TARGET_PLAYER, "jiao_gu_dot", 1, 2)
				_:
					pass

		"remove_shield_and_heal":
			# 旱地长叹：清除玩家护盾+自回血
			player_shield = 0
			var heal_a: int = int(action.get("value", 0))
			enemy_hp = mini(int(enemy_hp) + heal_a, enemy_max_hp)

		"shield_self_double":
			# 执念加冕：自盾+2回合减伤50%
			var ssd_val: int = int(action.get("value", 0))
			enemy_shield += ssd_val
			BuffManager.add_buff(BuffManager.TARGET_ENEMY, "damage_reduce_50", 1, 2)

		"drain_all_emotions":
			# 情感真空强化：所有情绪-2
			var drain_v: int = int(action.get("value", 2))
			for emo: String in EmotionManager.EMOTIONS:
				EmotionManager.modify(emo, -drain_v)

func _deal_damage_to_enemy(amount: int) -> void:
	# 五彩香灰：多印记类型加伤
	var mark_type_count: int = 0
	for e: String in _enemy_marks:
		if _enemy_marks[e] > 0:
			mark_type_count += 1
	var mark_bonus: float = RelicManager.get_multi_mark_damage_bonus(mark_type_count)
	if mark_bonus > 0.0:
		amount = int(amount * (1.0 + mark_bonus))

	# 定而无极：攻击加成
	if _armor_to_attack_bonus > 0:
		amount += _armor_to_attack_bonus

	if enemy_shield > 0:
		var blocked: int = mini(enemy_shield, amount)
		enemy_shield -= blocked
		amount -= blocked
	enemy_hp = maxf(0, enemy_hp - amount)

# ── 印记系统辅助方法 ──────────────────────────────────

func _process_wu_wei_tick() -> void:
	## 无为·持续施印：每回合开始触发，倒计时归零时自动渡化判定
	if _wu_wei_turns_remaining <= 0: return
	# 施印
	for emotion: String in _wu_wei_marks_per_turn:
		var cnt: int = int(_wu_wei_marks_per_turn[emotion])
		_apply_mark(emotion, cnt)
		wu_wei_mark_applied.emit(emotion, cnt, _wu_wei_turns_remaining)
	# 每回合回血3点
	GameState.heal(3)
	_wu_wei_turns_remaining -= 1
	# 最后一回合结束：若渡化条件满足，自动触发渡化判定
	if _wu_wei_turns_remaining <= 0:
		_check_du_hua({})
		wu_wei_ended_with_duhua.emit()

func _apply_mark(emotion: String, count: int) -> void:
	## 对敌人施加印记，并检查遗物触发
	if count <= 0: return
	_enemy_marks[emotion] = _enemy_marks.get(emotion, 0) + count
	# 通知遗物（旧铜铃：施印牌触发亲和效果）
	RelicManager.on_seal_card_played_ruyue(emotion)
	# 县志一卷：施加锁链时揭示意图（印记不触发，但复用接口）
	marks_changed.emit(_enemy_marks.duplicate())
	_check_resonances()

func _apply_chain(count: int) -> void:
	## 对敌人施加锁链，同时应用减攻/行动抑制效果
	var cap: int = RelicManager.get_chain_stack_cap()
	enemy_chains = mini(enemy_chains + count, cap)
	_total_chains_this_battle += count
	# 千斤锁：检查总锁链阈值
	RelicManager.on_chain_total_changed_tiejun(enemy_chains)
	# 锁链≥5层：下回合敌人跳过行动（镇压效果，类似 fear 共鸣）
	if enemy_chains >= 5:
		_skip_next_action = true
	# 通知 BattleScene 刷新锁链 HUD
	chain_applied.emit(enemy_chains)

func _check_resonances() -> void:
	## 检查所有印记是否满足共鸣条件
	for emotion: String in EmotionManager.EMOTIONS:
		var threshold: int = RelicManager.get_resonance_threshold_override(emotion)
		if _enemy_marks.get(emotion, 0) >= threshold:
			_trigger_resonance(emotion)

func _trigger_resonance(emotion: String) -> void:
	## 触发印记共鸣
	_last_resonance_triggered = emotion
	var power_bonus: float = RelicManager.get_resonance_power_bonus(emotion)
	# 消耗印记（神像碎块：不清零）
	if not RelicManager.should_keep_marks_after_five_resonance():
		_enemy_marks[emotion] = 0

	match emotion:
		"grief":
			var dmg: int = int(8.0 * (1.0 + power_bonus) * EmotionManager.get_attack_multiplier())
			_deal_damage_to_enemy(dmg)
		"fear":
			# 跳过敌人下一次行动：设独立标记（避免与 next_intent 混淆）
			_skip_next_action = true
		"rage":
			var pen_dmg: int = int(15.0 * (1.0 + power_bonus))
			_deal_damage_to_enemy(pen_dmg)  # 穿甲伤害
		"joy":
			var heal_v: int = int(8.0 * (1.0 + power_bonus) * EmotionManager.get_heal_multiplier())
			GameState.heal(heal_v)
		"calm":
			DeckManager.current_cost = mini(DeckManager.current_cost + 1, DeckManager.max_cost)

	# 遗物回调
	RelicManager.on_resonance_triggered_ruyue(emotion)
	RelicManager.on_resonance_triggered_canxiang(self)
	RelicManager.on_resonance_mirror_to_self(emotion)

	# 检查五情共鸣（五种印记是否都有）
	var all_present: bool = true
	for e: String in EmotionManager.EMOTIONS:
		if _enemy_marks.get(e, 0) <= 0:
			all_present = false; break
	if all_present:
		_trigger_five_resonance()

func _trigger_five_resonance() -> void:
	## 触发五情共鸣
	var purif_bonus: float = RelicManager.get_five_resonance_purification_bonus()
	# 伤害：对敌人造成20点穿甲
	_deal_damage_to_enemy(20)
	# 渡化进度
	# (由 BattleScene 响应 card_effect_applied 中的 du_hua_progress 处理)
	# 碎镜片：记录
	RelicManager.on_five_resonance_triggered_ruyue()
	# 清除印记（神像碎块保留）
	if not RelicManager.should_keep_marks_after_five_resonance():
		for e: String in EmotionManager.EMOTIONS:
			_enemy_marks[e] = 0

func _end_battle(result: String) -> void:
	current_state = STATE_BATTLE_END
	if result == "victory":
		GameState.record_zhen_ya(enemy_data.get("id", ""))
	# 情绪余韵：战斗结束时记录主导情绪（供下一场战斗开始时使用）
	var dominant: String = EmotionManager.dominant_emotion
	if EmotionManager.values.get(dominant, 0) >= 3:
		GameState.set_meta("lingering_emotion", dominant)
		GameState.set_meta("lingering_value", 1)
		GameState.set_meta("lingering_type", result)  # "du_hua" or "victory"
	battle_ended.emit(result)
