class_name WumianManager
extends Node

## WumianManager.gd - 无面人·空系统管理器（Autoload 单例）
## 注意：需在 Project Settings > Autoload 中注册为 "WumianManager"
## 职责：管理空度状态、空鸣触发、情绪转移规则、分段效果

signal emptiness_changed(old_val: int, new_val: int)
signal kongming_triggered(pre_emptiness: int)   # 空鸣触发信号
signal emotion_transferred(emotion: String, amount: int, direction: String)  # "from_enemy" | "to_enemy"

# ── 空度状态 ─────────────────────────────────────────
var emptiness: int = 0                       # 当前空度（0–10）
var _emptiness_stages_this_turn: Array = []  # 本回合经历的空度值（去重记录）
var _kongming_active: bool = false           # 镜·无我是否激活
var _kongming_turns_remaining: int = 0       # 镜·无我剩余回合数

# ── 角色状态 ─────────────────────────────────────────
var is_wumian_active: bool = false           # 无面人是否为当前角色

# ── 分段效果缓存 ─────────────────────────────────────
## current_tier 对应分段：
##   0 = 低（空度 0–2）：牌效果+10%，无法打出「清空」类牌
##   1 = 中（空度 3–5）：无加成无惩罚
##   2 = 高（空度 6–8）：每张牌费用-1
##   3 = 极高（空度 9–10）：所有牌费用0，但每回合开始 HP-5
var current_tier: int = 0

# ── 空鸣防重入标志 ───────────────────────────────────
var _kongming_fired_this_turn: bool = false  # 防止同一回合多次触发空鸣

# ════════════════════════════════════════════════════
#  初始化
# ════════════════════════════════════════════════════

func _ready() -> void:
	# 默认未激活，等待战斗系统调用 activate()
	is_wumian_active = false

# ════════════════════════════════════════════════════
#  公共 API - 激活/停用
# ════════════════════════════════════════════════════

## 激活无面人模式（战斗开始时由 BattleScene / BattleStateMachine 调用）
func activate() -> void:
	is_wumian_active = true
	emptiness = 0
	current_tier = 0
	_emptiness_stages_this_turn = [0]
	_kongming_active = false
	_kongming_turns_remaining = 0
	_kongming_fired_this_turn = false

## 停用无面人模式（战斗结束时调用）
func deactivate() -> void:
	is_wumian_active = false
	emptiness = 0
	current_tier = 0
	_emptiness_stages_this_turn = []
	_kongming_active = false
	_kongming_turns_remaining = 0
	_kongming_fired_this_turn = false

# ════════════════════════════════════════════════════
#  空度核心操作
# ════════════════════════════════════════════════════

## 修改空度：钳制到 [0,10]，记录经历值，更新分段，检查空鸣
func modify_emptiness(delta: int) -> void:
	if not is_wumian_active:
		return
	var old_val: int = emptiness
	emptiness = clampi(emptiness + delta, 0, 10)

	# 记录本回合经历的所有空度值
	if emptiness not in _emptiness_stages_this_turn:
		_emptiness_stages_this_turn.append(emptiness)

	# 更新分段缓存
	_update_tier()

	# 发射变化信号
	if emptiness != old_val:
		emptiness_changed.emit(old_val, emptiness)

	# 检查空鸣触发条件（仅检查，不重复触发）
	_check_kongming()

## 内部：更新分段缓存
func _update_tier() -> void:
	if emptiness <= 2:
		current_tier = 0
	elif emptiness <= 5:
		current_tier = 1
	elif emptiness <= 8:
		current_tier = 2
	else:
		current_tier = 3

## 内部：检查本回合是否经历了所有阶段，满足则触发空鸣
## 触发条件（简化）：本回合最小值=0 且 最大值=10
func _check_kongming() -> void:
	if _kongming_fired_this_turn:
		return
	if _emptiness_stages_this_turn.is_empty():
		return
	var min_val: int = _emptiness_stages_this_turn[0]
	var max_val: int = _emptiness_stages_this_turn[0]
	for v: int in _emptiness_stages_this_turn:
		if v < min_val:
			min_val = v
		if v > max_val:
			max_val = v
	if min_val == 0 and max_val == 10:
		_on_kongming()

## 强制触发空鸣（空溢/空鸣诀使用）
func trigger_kongming_forced() -> void:
	if not is_wumian_active:
		return
	_on_kongming()

## 内部：执行空鸣效果
func _on_kongming() -> void:
	if _kongming_fired_this_turn:
		return
	_kongming_fired_this_turn = true

	var pre_emptiness: int = emptiness

	# 1. 发射信号：BattleStateMachine 响应，处理敌人情绪失调和印记触发
	kongming_triggered.emit(pre_emptiness)

	# 2. 回复 HP = 归零前空度 × 2
	if pre_emptiness > 0:
		GameState.heal(pre_emptiness * 2)

	# 3. 空度归零
	emptiness = 0
	_update_tier()
	emptiness_changed.emit(pre_emptiness, 0)

	# 4. 激活镜·无我（持续 3 回合）
	_kongming_active = true
	_kongming_turns_remaining = 3

	# 5. 重置本回合空度记录（空鸣后从 0 开始新一轮记录）
	_emptiness_stages_this_turn = [0]

# ════════════════════════════════════════════════════
#  回合事件钩子
# ════════════════════════════════════════════════════

## 回合开始时调用
func on_turn_start() -> void:
	if not is_wumian_active:
		return

	# 重置空鸣防重入标志（新回合允许再次触发）
	_kongming_fired_this_turn = false

	# 重置本回合空度经历记录
	_emptiness_stages_this_turn = [emptiness]

	# 极高分段（9-10）：每回合开始 HP-5
	if current_tier == 3:
		GameState.take_damage(5)

	# 空度-2（最低0）
	modify_emptiness(-2)

	# 镜·无我倒计时
	if _kongming_turns_remaining > 0:
		_kongming_turns_remaining -= 1
		if _kongming_turns_remaining <= 0:
			_kongming_active = false
			_kongming_turns_remaining = 0

## 每次打出一张牌时调用（空度+1）
func on_card_played() -> void:
	if not is_wumian_active:
		return
	modify_emptiness(1)

## 受到伤害时调用；返回实际应扣除的伤害量（含减伤计算）
func on_damage_received(amount: int) -> int:
	if not is_wumian_active:
		return amount

	var actual: int = amount

	# 镜·无我激活时：50% 概率伤害减半
	if _kongming_active:
		if randi() % 2 == 0:
			actual = max(1, actual / 2)

	# 升级被动·空与形：空度≥6时受到伤害-20%
	if emptiness >= 6:
		actual = int(actual * 0.80)

	# 空度-1（最低0），受伤后修改
	modify_emptiness(-1)

	return actual

# ════════════════════════════════════════════════════
#  分段效果查询
# ════════════════════════════════════════════════════

## 根据当前分段返回费用修正值
## 返回 -999 表示「费用清零」（极高分段专用标志）
func get_card_cost_modifier() -> int:
	match current_tier:
		2:  # 空度 6–8：费用-1
			return -1
		3:  # 空度 9–10：所有牌费用为0
			return -999
		_:
			return 0

## 牌效果倍率：低分段+10%
func get_effect_multiplier() -> float:
	if current_tier == 0:
		return 1.10
	return 1.0

## 伤害修正倍率（升级被动·空与形）
## 空度≤2：造成伤害+20% = 1.20
## 空度≥6：受到伤害-20%（此处返回造成伤害方向，减伤由 on_damage_received 处理）
## 空度≤2 时造成伤害加成；其他情况返回 1.0
func get_damage_modifier() -> float:
	if emptiness <= 2:
		return 1.20  # 造成伤害+20%
	return 1.0

## 是否处于低分段（空度 0–2），用于限制「清空」类牌的打出
func is_low_tier() -> bool:
	return current_tier == 0

## 镜·无我是否激活
func is_kongming_mirror_active() -> bool:
	return _kongming_active

# ════════════════════════════════════════════════════
#  情绪转移
# ════════════════════════════════════════════════════

## 情绪转移：将敌人情绪转移给自己或消散
## absorb=true：敌人该情绪-amount，自身该情绪+amount（无面人唯一获取情绪的途径）
## absorb=false：直接消散（敌人-amount，自身不变）
func transfer_emotion_from_enemy(emotion: String, amount: int, absorb: bool) -> void:
	if not is_wumian_active:
		return
	# 无面人固有被动·无面之形：自身情绪不受失调惩罚，但积累本身有效
	if absorb:
		# 自身获取情绪（不触发失调，不累积超出值惩罚）
		EmotionManager.modify(emotion, amount)
		emotion_transferred.emit(emotion, amount, "from_enemy")
	else:
		# 直接消散：BattleScene / BattleStateMachine 负责对敌人情绪执行 -amount
		emotion_transferred.emit(emotion, amount, "dissipate")

## 情绪输出给敌人（情渡）
func transfer_emotion_to_enemy(emotion: String, amount: int) -> void:
	if not is_wumian_active:
		return
	# 自身情绪-amount（不能低于0）
	var actual: int = min(amount, EmotionManager.values.get(emotion, 0))
	if actual > 0:
		EmotionManager.modify(emotion, -actual)
	emotion_transferred.emit(emotion, actual, "to_enemy")

# ════════════════════════════════════════════════════
#  UI 辅助
# ════════════════════════════════════════════════════

## 返回当前空度分段的文字描述（用于 UI HUD 显示）
func get_emptiness_tier_description() -> String:
	match current_tier:
		0:
			return "虚（0–2）：牌效果+10%"
		1:
			return "平（3–5）：无加成"
		2:
			return "盈（6–8）：费用-1"
		3:
			return "溢（9–10）：费用归零 / 每回合HP-5"
		_:
			return "未知"

## 返回空度的简短状态字符串（用于 Debug 或浮字）
func get_emptiness_status_string() -> String:
	return "空度 %d/10 [%s]" % [emptiness, get_emptiness_tier_description()]
