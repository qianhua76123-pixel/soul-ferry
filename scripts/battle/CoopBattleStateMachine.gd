class_name CoopBattleStateMachine
extends Node
## 双角色协作模式状态机
## 实现「同行渡魂」双人协作战斗的核心逻辑
## ruan = 阮如月（印记系），shen = 沈铁钧（锁链系）

# ── 信号 ─────────────────────────────────────────────────
signal coop_battle_started
signal turn_changed(character: String)          ## "ruan" | "shen" | "enemy"
signal coop_resonance_triggered(bonus_type: String)
signal coop_five_resonance_triggered
signal battle_ended(result: String)
signal du_hua_available(description: String)
signal du_hua_succeeded(enemy_id: String)

# ── 状态常量 ──────────────────────────────────────────────
const TURN_RUAN: String  = "ruan"
const TURN_SHEN: String  = "shen"
const TURN_ENEMY: String = "enemy"

# ── 当前回合角色 ──────────────────────────────────────────
var current_character: String = TURN_RUAN  ## "ruan" | "shen" | "enemy"

# ── 阮如月状态 ────────────────────────────────────────────
var ruan_hp: int              = 80
var ruan_max_hp: int          = 80
var ruan_shield: int          = 0
var ruan_hand: Array          = []
var ruan_energy: int          = 3
var ruan_max_energy: int      = 3
## 本回合已向敌人施加的印记 {emotion: count}
var ruan_marks_applied_this_turn: Dictionary = {}
## 本回合已触发的共鸣列表 ["grief", "rage", ...]
var ruan_resonance_triggered: Array          = []

# ── 沈铁钧状态 ────────────────────────────────────────────
var shen_hp: int               = 100
var shen_max_hp: int           = 100
var shen_shield: int           = 0
var shen_hand: Array           = []
var shen_energy: int           = 3
var shen_max_energy: int       = 3
## 印记引爆加成：阮如月对锁链敌人施印后累积的锁链伤害加成
var shen_chain_damage_bonus: float     = 0.0
## 阮如月触发怒共鸣后，沈铁钧本回合怒爆倍率加成
var shen_fury_burst_bonus: float       = 0.0
## 阮如月触发悲共鸣后，沈铁钧下次锁链溅射伤害翻倍标记
var shen_next_splash_double: bool      = false
## 本回合锁链溅射比例加成（五情共鸣协同爆发时+0.30）
var shen_splash_bonus_this_turn: float = 0.0

# ── 共享资源 ──────────────────────────────────────────────
## 敌人印记（两人共享施印结果）{emotion: count}
var shared_enemy_marks: Dictionary     = {}
## 渡化进度（0.0 ~ 1.0）
var shared_purification_progress: float = 0.0
## 敌人锁链层数
var enemy_chains: int                  = 0

# ── 敌人状态 ──────────────────────────────────────────────
var enemy_data: Dictionary = {}
var enemy_hp: int          = 0
var enemy_max_hp: int      = 0
var enemy_shield: int      = 0

# ── 协同状态计数（渡魂二人券） ────────────────────────────
## 本回合阮如月已向沈铁钧提供的能量次数
var coop_ruan_gave_bonus_this_turn: int = 0
## 本回合沈铁钧已向阮如月提供的能量次数
var coop_shen_gave_bonus_this_turn: int = 0

# ── 五情共鸣完成标记（并肩渡魂传说遗物） ─────────────────
var ruan_five_resonance_done: bool = false
var shen_five_resonance_done: bool = false

# ── 渡化触发标记 ─────────────────────────────────────────
var du_hua_triggered: bool = false

# ── 当前回合计数 ─────────────────────────────────────────
var current_round: int = 0

# ────────────────────────────────────────────────────────
# 公开方法
# ────────────────────────────────────────────────────────

func start_coop_battle(enemy_id: String) -> void:
	## 启动双人协作战斗
	var enemy: Dictionary = _load_enemy(enemy_id)
	if enemy.is_empty():
		push_error("CoopBattleStateMachine: 未找到敌人 " + enemy_id)
		enemy = {
			"id": enemy_id,
			"name": "亡魂",
			"hp": 80,
			"actions": [{"type": "attack", "value": 8, "weight": 100}]
		}
	enemy_data = enemy
	enemy_hp       = enemy.get("hp", 80)
	enemy_max_hp   = enemy_hp
	enemy_shield   = 0
	enemy_chains   = 0

	# 重置双人状态
	_reset_character_states()
	# 协同状态清零
	coop_ruan_gave_bonus_this_turn = 0
	coop_shen_gave_bonus_this_turn = 0
	ruan_five_resonance_done       = false
	shen_five_resonance_done       = false
	shared_enemy_marks             = {}
	shared_purification_progress   = 0.0
	du_hua_triggered               = false
	current_round                  = 0

	current_character = TURN_RUAN
	coop_battle_started.emit()
	_begin_character_turn(TURN_RUAN)


func end_character_turn() -> void:
	## 结束当前角色回合，切换到下一个角色或进入敌人回合
	match current_character:
		TURN_RUAN:
			# 阮如月回合结束：检查协同效果，再切换到沈铁钧
			_check_coop_synergies()
			_begin_character_turn(TURN_SHEN)
		TURN_SHEN:
			# 沈铁钧回合结束：检查五情共鸣，再进入敌人回合
			_check_coop_five_resonance()
			_begin_character_turn(TURN_ENEMY)
		TURN_ENEMY:
			# 敌人回合结束：进入下一轮阮如月回合
			current_round += 1
			_reset_turn_state()
			_begin_character_turn(TURN_RUAN)
		_:
			push_warning("CoopBattleStateMachine: 未知角色回合 " + current_character)


func play_card_ruan(card: Dictionary) -> void:
	## 阮如月出牌（只能在阮如月回合调用）
	if current_character != TURN_RUAN:
		push_warning("CoopBattleStateMachine: 当前不是阮如月回合")
		return

	var cost: int = card.get("cost", 1)
	# 检查铁印同心：印记总层数>15时印记牌降费（此处通过 CoopManager 获取）
	if CoopManager.has_coop_relic("tie_yin_tongxin"):
		var total_marks: int = _count_total_marks()
		if total_marks > 15:
			cost = max(0, cost - 1)
	# 沈铁钧定共鸣后阮如月印记牌降费
	cost = max(0, cost - CoopManager.ruan_card_cost_reduction)

	if ruan_energy < cost:
		push_warning("CoopBattleStateMachine: 阮如月能量不足")
		return
	ruan_energy -= cost

	var effect_type: String = card.get("effect_type", "")

	# 处理印记效果
	if effect_type in ["apply_mark", "apply_mark_and_heal", "emotion_and_mark",
					   "mark_and_delay", "multi_mark_and_trigger"]:
		var marks: Dictionary = card.get("marks_to_apply", {})
		# 沈铁钧施锁后阮如月印记牌效率+1层
		var efficiency_bonus: int = CoopManager.ruan_mark_efficiency_bonus
		for emotion: String in marks:
			var count: int = int(marks[emotion]) + efficiency_bonus
			_apply_mark_ruan(emotion, count)

	# 检查共鸣触发
	_check_resonances_ruan()

	# 铁印同心：锁链总层数>10时阮如月印记共鸣+20%（通过信号通知UI）
	if CoopManager.has_coop_relic("tie_yin_tongxin") and enemy_chains > 10:
		coop_resonance_triggered.emit("tie_yin_ruan_bonus")


func play_card_shen(card: Dictionary) -> void:
	## 沈铁钧出牌（只能在沈铁钧回合调用）
	if current_character != TURN_SHEN:
		push_warning("CoopBattleStateMachine: 当前不是沈铁钧回合")
		return

	var cost: int = card.get("cost", 1)
	if shen_energy < cost:
		push_warning("CoopBattleStateMachine: 沈铁钧能量不足")
		return
	shen_energy -= cost

	var effect_type: String = card.get("effect_type", "")
	var base_val: int       = card.get("effect_value", 0)

	match effect_type:
		"chain_attack":
			# 锁链攻击：应用印记引爆加成
			var dmg: float = float(base_val) * (1.0 + shen_chain_damage_bonus)
			if shen_fury_burst_bonus > 0.0:
				dmg *= (1.0 + shen_fury_burst_bonus)
			var splash_ratio: float = card.get("splash_ratio", 0.3) + shen_splash_bonus_this_turn
			if shen_next_splash_double:
				splash_ratio *= 2.0
				shen_next_splash_double = false
			_deal_damage_to_enemy(int(dmg))
			# 铁印同心：印记总层数>15时锁链溅射+15%
			if CoopManager.has_coop_relic("tie_yin_tongxin"):
				var total_marks: int = _count_total_marks()
				if total_marks > 15:
					splash_ratio += 0.15

		"apply_chain":
			# 施加锁链
			var chain_count: int = base_val
			enemy_chains += chain_count
			# 沈铁钧施锁 → 阮如月本回合印记牌效率+1层
			CoopManager.ruan_mark_efficiency_bonus += 1
			# 渡魂二人券：阮如月获得+1能量
			_try_give_energy_bonus(TURN_SHEN, TURN_RUAN)

		"fury_burst":
			# 怒爆：使用 shen_fury_burst_bonus 加成
			var dmg: float = float(base_val) * (1.0 + shen_fury_burst_bonus)
			_deal_damage_to_enemy(int(dmg))
			# 沈铁钧怒爆 → 阮如月本回合所有印记牌费用-1
			CoopManager.ruan_card_cost_reduction += 1
			# 渡魂二人券：阮如月获得+1能量
			_try_give_energy_bonus(TURN_SHEN, TURN_RUAN)

		_:
			# 通用攻击
			if base_val > 0:
				_deal_damage_to_enemy(base_val)

	# 检查沈铁钧定共鸣（阮如月抽1张牌）
	_check_resonances_shen(card)

	if enemy_hp <= 0:
		_end_battle("victory")


func confirm_du_hua() -> void:
	## 玩家确认执行渡化
	if not du_hua_triggered:
		return
	# 并肩渡魂传说遗物：两人各触发过五情共鸣且无人死亡 → 渡化进度填满
	if CoopManager.has_coop_relic("bingjian_duhun"):
		if ruan_five_resonance_done and shen_five_resonance_done:
			if ruan_hp > 0 and shen_hp > 0:
				shared_purification_progress = 1.0
				coop_five_resonance_triggered.emit()
	GameState.record_du_hua(enemy_data.get("id", ""))
	du_hua_succeeded.emit(enemy_data.get("id", ""))
	_end_battle("du_hua")


# ────────────────────────────────────────────────────────
# 内部：回合流程
# ────────────────────────────────────────────────────────

func _begin_character_turn(character: String) -> void:
	## 开始指定角色的回合
	current_character = character
	turn_changed.emit(character)

	match character:
		TURN_RUAN:
			# 阮如月回合开始：重置本回合印记/共鸣记录，恢复能量
			ruan_marks_applied_this_turn = {}
			ruan_resonance_triggered     = []
			ruan_energy                  = ruan_max_energy

		TURN_SHEN:
			# 沈铁钧回合开始：恢复能量
			shen_energy = shen_max_energy

		TURN_ENEMY:
			# 敌人回合
			_enemy_turn()


func _reset_character_states() -> void:
	## 战斗开始时重置所有角色状态
	ruan_hp                          = ruan_max_hp
	ruan_shield                      = 0
	ruan_energy                      = ruan_max_energy
	ruan_hand                        = []
	ruan_marks_applied_this_turn     = {}
	ruan_resonance_triggered         = []

	shen_hp                          = shen_max_hp
	shen_shield                      = 0
	shen_energy                      = shen_max_energy
	shen_hand                        = []
	shen_chain_damage_bonus          = 0.0
	shen_fury_burst_bonus            = 0.0
	shen_next_splash_double          = false
	shen_splash_bonus_this_turn      = 0.0


func _reset_turn_state() -> void:
	## 每轮（敌人回合结束后）重置临时加成
	# 重置协同计数器
	coop_ruan_gave_bonus_this_turn   = 0
	coop_shen_gave_bonus_this_turn   = 0
	# 重置沈铁钧临时加成（部分加成只持续到本回合）
	shen_chain_damage_bonus          = 0.0
	shen_fury_burst_bonus            = 0.0
	shen_splash_bonus_this_turn      = 0.0
	# 重置 CoopManager 的回合级加成
	CoopManager.reset_turn_bonuses()


# ────────────────────────────────────────────────────────
# 内部：协同效果检查
# ────────────────────────────────────────────────────────

func _check_coop_synergies() -> void:
	## 阮如月回合结束时检查并触发协同效果
	## 决定沈铁钧回合的加成

	# 印记引爆：阮如月本回合施加过印记且敌人有锁链 → 沈铁钧锁链伤害+15%
	var applied_any_mark: bool = not ruan_marks_applied_this_turn.is_empty()
	if applied_any_mark and enemy_chains > 0:
		shen_chain_damage_bonus += 0.15
		coop_resonance_triggered.emit("mark_explosion_chain")

	# 阮如月触发了悲共鸣 → 沈铁钧下次锁链溅射伤害翻倍
	if "grief" in ruan_resonance_triggered:
		shen_next_splash_double = true
		CoopManager.shen_next_splash_double = true
		coop_resonance_triggered.emit("grief_splash_double")

	# 阮如月触发了怒共鸣 → 沈铁钧本回合怒爆倍率+0.2
	if "rage" in ruan_resonance_triggered:
		shen_fury_burst_bonus += 0.2
		coop_resonance_triggered.emit("rage_fury_burst_bonus")

	# 同步加成到 CoopManager 供外部读取
	CoopManager.shen_chain_damage_bonus = shen_chain_damage_bonus


func _check_coop_five_resonance() -> void:
	## 沈铁钧回合结束时检查两人合并情绪总值是否达到协同五情共鸣条件
	## 简化实现：以 EmotionManager 单例为共享，检测五情总值 ≥ 10

	var total_emotion: int = EmotionManager.get_total_value()
	if total_emotion < 10:
		return

	# 触发协同五情共鸣
	# 渡化进度+40%
	shared_purification_progress += 0.40
	shared_purification_progress  = min(shared_purification_progress, 1.0)

	# 沈铁钧本回合所有锁链溅射比例+30%
	shen_splash_bonus_this_turn += 0.30

	# 对所有敌人触发两人合并印记的共鸣效果
	_trigger_combined_mark_resonance()

	coop_five_resonance_triggered.emit()

	# 检查渡化条件
	if shared_purification_progress >= 1.0 and not du_hua_triggered:
		du_hua_triggered = true
		var desc: String = enemy_data.get("du_hua_condition", {}).get(
			"description", "五情同鸣，渡化时机已至"
		)
		du_hua_available.emit(desc)


func _trigger_combined_mark_resonance() -> void:
	## 对所有敌人触发两人合并印记的共鸣效果各一次
	for emotion: String in shared_enemy_marks:
		if shared_enemy_marks[emotion] > 0:
			_trigger_resonance_effect(emotion)


func _check_resonances_ruan() -> void:
	## 检查阮如月施印后是否触发印记共鸣
	for emotion: String in shared_enemy_marks:
		var threshold: int = 3  ## 默认共鸣阈值
		if shared_enemy_marks.get(emotion, 0) >= threshold:
			if emotion not in ruan_resonance_triggered:
				ruan_resonance_triggered.append(emotion)
				_trigger_resonance_effect(emotion)
				# 渡魂二人券：沈铁钧获得+1能量
				_try_give_energy_bonus(TURN_RUAN, TURN_SHEN)
				# 清除触发的印记
				shared_enemy_marks[emotion] = 0


func _check_resonances_shen(card: Dictionary) -> void:
	## 检查沈铁钧是否触发定共鸣（让阮如月抽1张牌）
	var effect_type: String = card.get("effect_type", "")
	## 若沈铁钧打出定情绪牌触发定共鸣
	if effect_type in ["emotion_and_shield_by_emotion", "persistent_shield"] or \
	   card.get("emotion_tag", "") == "calm":
		# 沈铁钧定共鸣 → 阮如月抽1张牌
		DeckManager.draw_cards(1)
		# 渡魂二人券：阮如月获得+1能量
		_try_give_energy_bonus(TURN_SHEN, TURN_RUAN)
		coop_resonance_triggered.emit("calm_draw_ruan")


# ────────────────────────────────────────────────────────
# 内部：敌人回合
# ────────────────────────────────────────────────────────

func _enemy_turn() -> void:
	## 敌人回合：优先攻击HP百分比更低的角色，攻击值-20%
	var action: Dictionary = _choose_enemy_action()
	if action.is_empty():
		end_character_turn()
		return

	var atype: String = action.get("type", "")
	var base_damage: int = action.get("value", 0)
	# 双人模式：攻击值乘以0.8（-20%）
	var reduced_damage: int = int(base_damage * 0.8)

	match atype:
		"attack":
			var target: String = _choose_attack_target()
			_apply_damage_to_character(target, reduced_damage)
		"attack_all":
			# 群攻：双人各受伤害
			_apply_damage_to_character(TURN_RUAN, reduced_damage)
			_apply_damage_to_character(TURN_SHEN, reduced_damage)
		"emotion_push":
			EmotionManager.modify(action.get("emotion", ""), action.get("value", 1))
		"shield":
			enemy_shield += action.get("value", 0)
		_:
			# 其他行动沿用单人逻辑
			pass

	# 检查战斗结束（两人均阵亡）
	if ruan_hp <= 0 and shen_hp <= 0:
		_end_battle("defeat")
		return

	end_character_turn()


func _choose_attack_target() -> String:
	## 选择攻击目标：优先攻击HP百分比更低的角色
	var ruan_pct: float = float(ruan_hp) / float(ruan_max_hp)
	var shen_pct: float = float(shen_hp) / float(shen_max_hp)
	if ruan_pct <= shen_pct:
		return TURN_RUAN
	return TURN_SHEN


func _apply_damage_to_character(character: String, damage: int) -> void:
	## 对指定角色造成伤害（先扣护盾，再扣HP）
	var actual: int = damage
	match character:
		TURN_RUAN:
			if ruan_shield > 0:
				var blocked: int = min(ruan_shield, actual)
				ruan_shield -= blocked
				actual      -= blocked
			if actual > 0:
				ruan_hp = max(0, ruan_hp - actual)
		TURN_SHEN:
			if shen_shield > 0:
				var blocked: int = min(shen_shield, actual)
				shen_shield -= blocked
				actual      -= blocked
			if actual > 0:
				shen_hp = max(0, shen_hp - actual)


# ────────────────────────────────────────────────────────
# 内部：印记 & 共鸣
# ────────────────────────────────────────────────────────

func _apply_mark_ruan(emotion: String, count: int) -> void:
	## 阮如月施加印记到共享印记池
	if count <= 0:
		return
	shared_enemy_marks[emotion] = shared_enemy_marks.get(emotion, 0) + count
	# 记录本回合施印（用于协同效果检查）
	ruan_marks_applied_this_turn[emotion] = \
		ruan_marks_applied_this_turn.get(emotion, 0) + count


func _trigger_resonance_effect(emotion: String) -> void:
	## 触发印记共鸣效果
	match emotion:
		"grief":
			# 悲共鸣：对敌人造成伤害
			_deal_damage_to_enemy(8)
		"fear":
			# 惧共鸣：跳过敌人下一次行动
			enemy_data["_skip_next_action"] = true
		"rage":
			# 怒共鸣：穿甲伤害
			_deal_damage_to_enemy(15)
		"joy":
			# 喜共鸣：回复阮如月HP
			var heal_val: int = 8
			ruan_hp = min(ruan_max_hp, ruan_hp + heal_val)
		"calm":
			# 定共鸣：回复能量
			ruan_energy = min(ruan_max_energy, ruan_energy + 1)
	# 检查五情共鸣（五种印记是否都触发过）
	_check_five_resonance_completion()


func _check_five_resonance_completion() -> void:
	## 检查阮如月本回合是否触发了五情共鸣
	var all_emotions: Array[String] = ["grief", "fear", "rage", "joy", "calm"]
	var all_present: bool = true
	for e: String in all_emotions:
		if e not in ruan_resonance_triggered:
			all_present = false
			break
	if all_present and not ruan_five_resonance_done:
		ruan_five_resonance_done = true


func _count_total_marks() -> int:
	## 统计当前敌人身上的印记总层数
	var total: int = 0
	for e: String in shared_enemy_marks:
		total += int(shared_enemy_marks[e])
	return total


# ────────────────────────────────────────────────────────
# 内部：渡魂二人券能量赠送
# ────────────────────────────────────────────────────────

func _try_give_energy_bonus(from_character: String, to_character: String) -> void:
	## 渡魂二人券：触发共鸣时给另一人+1能量（每回合各最多3次）
	if not CoopManager.has_coop_relic("duohun_erjuan"):
		return
	const MAX_BONUS: int = 3
	match from_character:
		TURN_RUAN:
			if coop_ruan_gave_bonus_this_turn < MAX_BONUS:
				coop_ruan_gave_bonus_this_turn += 1
				shen_energy = min(shen_max_energy, shen_energy + 1)
		TURN_SHEN:
			if coop_shen_gave_bonus_this_turn < MAX_BONUS:
				coop_shen_gave_bonus_this_turn += 1
				ruan_energy = min(ruan_max_energy, ruan_energy + 1)


# ────────────────────────────────────────────────────────
# 内部：伤害 & 敌人行动
# ────────────────────────────────────────────────────────

func _deal_damage_to_enemy(amount: int) -> void:
	## 对敌人造成伤害（先扣护盾）
	if enemy_shield > 0:
		var blocked: int = min(enemy_shield, amount)
		enemy_shield -= blocked
		amount       -= blocked
	enemy_hp = max(0, enemy_hp - amount)


func _choose_enemy_action() -> Dictionary:
	## 随机权重选择敌人行动
	var actions: Array = enemy_data.get("actions", [])
	if actions.is_empty():
		return {}
	var total: int = 0
	for a: Dictionary in actions:
		total += int(a.get("weight", 1))
	if total <= 0:
		return actions[0]
	var roll: int = randi() % total
	var cum: int  = 0
	for a: Dictionary in actions:
		cum += int(a.get("weight", 1))
		if roll < cum:
			return a
	return actions[0]


# ────────────────────────────────────────────────────────
# 内部：战斗结束 & 数据加载
# ────────────────────────────────────────────────────────

func _end_battle(result: String) -> void:
	## 结束战斗，发出信号
	if result == "victory":
		GameState.record_zhen_ya(enemy_data.get("id", ""))
	battle_ended.emit(result)


func _load_enemy(enemy_id: String) -> Dictionary:
	## 从 enemies.json 加载敌人数据
	var file: FileAccess = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	for enemy: Dictionary in json.get_data().get("enemies", []):
		if enemy.get("id", "") == enemy_id:
			return enemy
	return {}
