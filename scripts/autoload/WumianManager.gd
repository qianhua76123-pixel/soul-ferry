extends Node
## WumianManager.gd - 无面人·空系统管理器（Autoload 单例）
## 精确空度状态机：分段效果 + 空鸣触发（同一回合经历0和10才触发）

signal emptiness_changed(old_val: int, new_val: int)
signal stage_changed(old_stage: int, new_stage: int)
signal kongming_triggered(pre_emptiness: int)
signal kongming_choice_required()                    # UI 处理玩家选择：渡化 or 穿甲
signal emotion_transferred(emotion: String, amount: int, direction: String)

# ── 空度核心状态 ─────────────────────────────────────
var emptiness: int = 0           # 当前空度（0–10）
var current_tier: int = 0        # 0=低(0-2) 1=中(3-5) 2=高(6-8) 3=极高(9-10)
var is_wumian_active: bool = false

# ── 空鸣精确触发：同一回合须经历0和10 ────────────────
var _this_turn_min_void: int = 10
var _this_turn_max_void: int = 0
var _kongming_fired_this_turn: bool = false

# ── 镜·无我 ──────────────────────────────────────────
var _kongming_active: bool = false
var _kongming_turns_remaining: int = 0

func _ready() -> void:
	is_wumian_active = false

# ════════════════════════════════════════════════════
#  激活/停用
# ════════════════════════════════════════════════════

func activate() -> void:
	is_wumian_active = true
	emptiness = 0
	current_tier = 0
	_reset_turn_tracking()
	_kongming_fired_this_turn = false
	_kongming_active = false
	_kongming_turns_remaining = 0

func deactivate() -> void:
	is_wumian_active = false
	emptiness = 0
	current_tier = 0

# ════════════════════════════════════════════════════
#  空度核心操作
# ════════════════════════════════════════════════════

func modify_emptiness(delta: int) -> void:
	if not is_wumian_active: return
	var old_val: int = emptiness
	emptiness = clampi(emptiness + delta, 0, 10)
	if emptiness == old_val: return

	# 更新本回合极值记录
	_this_turn_min_void = mini(_this_turn_min_void, emptiness)
	_this_turn_max_void = maxi(_this_turn_max_void, emptiness)

	# 分段检测
	var old_tier: int = current_tier
	_update_tier()
	if current_tier != old_tier:
		stage_changed.emit(old_tier, current_tier)

	emptiness_changed.emit(old_val, emptiness)

	# 空鸣检测（同一回合经历0-2 和 9-10）
	_check_kongming()

func _update_tier() -> void:
	if emptiness <= 2:      current_tier = 0
	elif emptiness <= 5:    current_tier = 1
	elif emptiness <= 8:    current_tier = 2
	else:                   current_tier = 3

func _check_kongming() -> void:
	if _kongming_fired_this_turn: return
	# 触发条件：本回合最小值≤2 且 最大值≥9
	if _this_turn_min_void <= 2 and _this_turn_max_void >= 9:
		_on_kongming()

# ── 空鸣执行 ─────────────────────────────────────────
func _on_kongming() -> void:
	if _kongming_fired_this_turn: return
	_kongming_fired_this_turn = true
	var pre_emptiness: int = emptiness

	# 发射信号（BattleStateMachine 响应）
	kongming_triggered.emit(pre_emptiness)

	# 回复HP = 归零前空度×2
	if pre_emptiness > 0:
		GameState.heal(pre_emptiness * 2)

	# 空度归零
	emptiness = 0
	_update_tier()
	emptiness_changed.emit(pre_emptiness, 0)

	# 激活镜·无我（持续3回合）
	_kongming_active = true
	_kongming_turns_remaining = 3

	# 重置本回合记录（从0开始新一轮）
	_this_turn_min_void = 0
	_this_turn_max_void = 0

	# 让玩家选择（渡化进度+25% 或 25点穿甲伤害）
	kongming_choice_required.emit()

func trigger_kongming_forced() -> void:
	if not is_wumian_active: return
	_on_kongming()

# ════════════════════════════════════════════════════
#  回合事件钩子
# ════════════════════════════════════════════════════

func on_turn_start() -> void:
	if not is_wumian_active: return
	_kongming_fired_this_turn = false
	_reset_turn_tracking()

	# 极高分段：每回合HP-5
	if current_tier == 3:
		GameState.take_damage(5)

	# 每回合开始空度-2（最低0）
	modify_emptiness(-2)

	# 镜·无我倒计时
	if _kongming_turns_remaining > 0:
		_kongming_turns_remaining -= 1
		if _kongming_turns_remaining <= 0:
			_kongming_active = false

func on_card_played() -> void:
	if not is_wumian_active: return
	modify_emptiness(1)

func on_damage_received(amount: int) -> int:
	if not is_wumian_active: return amount
	var actual: int = amount

	# 镜·无我：50%概率伤害减半
	if _kongming_active and randi() % 2 == 0:
		actual = maxi(1, actual / 2)

	# 高段（≥6）：受伤-20%
	if emptiness >= 6:
		actual = int(actual * 0.80)

	modify_emptiness(-1)
	return actual

func _reset_turn_tracking() -> void:
	_this_turn_min_void = emptiness
	_this_turn_max_void = emptiness

# ════════════════════════════════════════════════════
#  分段效果查询
# ════════════════════════════════════════════════════

func get_card_cost_modifier() -> int:
	match current_tier:
		2: return -1
		3: return -999   # 极高段：牌费归0
		_: return 0

func get_effect_multiplier() -> float:
	return 1.1 if current_tier == 0 else 1.0

func get_damage_modifier() -> float:
	return 1.2 if emptiness <= 2 else 1.0  # 低段：造成伤害+20%

func is_kongming_mirror_active() -> bool:
	return _kongming_active

func get_emptiness_tier_description() -> String:
	match current_tier:
		0: return "虚（0–2）：牌效果+10%"
		1: return "平（3–5）：无加成"
		2: return "盈（6–8）：费用-1"
		3: return "溢（9–10）：费用归零 / 每回合HP-5"
		_: return "未知"

func get_emptiness_status_string() -> String:
	return "空度 %d/10 [%s]" % [emptiness, get_emptiness_tier_description()]

# ════════════════════════════════════════════════════
#  情绪转移
# ════════════════════════════════════════════════════

func transfer_emotion_from_enemy(emotion: String, amount: int, absorb: bool) -> void:
	if not is_wumian_active: return
	if absorb:
		EmotionManager.modify(emotion, amount)
		emotion_transferred.emit(emotion, amount, "from_enemy")
	else:
		emotion_transferred.emit(emotion, amount, "dissipate")

func transfer_emotion_to_enemy(emotion: String, amount: int) -> void:
	if not is_wumian_active: return
	var actual: int = mini(amount, EmotionManager.values.get(emotion, 0))
	if actual > 0:
		EmotionManager.modify(emotion, -actual)
	emotion_transferred.emit(emotion, actual, "to_enemy")
