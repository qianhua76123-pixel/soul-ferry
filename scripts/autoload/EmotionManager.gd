extends Node

## EmotionManager.gd - 五情系统核心管理器
## 管理怒/惧/悲/喜/定五种情绪的值、失调检测、增幅计算
## 使用信号广播情绪变化，其他系统监听并响应


# ========== 信号 ==========
signal emotion_changed(emotion: String, old_value: int, new_value: int)
signal dominant_changed(old_dominant: String, new_dominant: String)
signal disorder_triggered(emotion: String)
signal disorder_cleared(emotion: String)
signal emotions_reset()

# ========== 常量 ==========
const EMOTIONS = ["rage", "fear", "grief", "joy", "calm"]
const MAX_VALUE = 5
const MIN_VALUE = 0
const DISORDER_THRESHOLD = 4  # 失调触发阈值
const CALM_AMPLIFY_THRESHOLD = 3  # 定系增幅阈值

# ========== 情绪状态 ==========
var values: Dictionary = {
	"rage": 0,
	"fear": 0,
	"grief": 0,
	"joy": 0,
	"calm": 0
}

var dominant_emotion: String = ""  # 当前主导情绪（同值时保持上一状态）
var disorders: Dictionary = {}  # 当前失调状态 { emotion: true/false }

# ========== 初始化 ==========
func _ready() -> void:
	for emotion in EMOTIONS:
		disorders[emotion] = false

# ========== 核心接口：修改情绪值 ==========

## 修改某情绪的值，自动触发失调检测和主导情绪更新
func modify(emotion: String, delta: int) -> void:
	if not emotion in values:
		push_error("EmotionManager: 未知情绪类型 " + emotion)
		return
	
	var old_value = values[emotion]
	var new_value = clamp(old_value + delta, MIN_VALUE, MAX_VALUE)
	
	if old_value == new_value:
		return
	
	values[emotion] = new_value
	emit_signal("emotion_changed", emotion, old_value, new_value)
	
	# 更新失调状态
	_check_disorder(emotion)
	
	# 更新主导情绪（定不参与主导竞争）
	if emotion != "calm":
		_update_dominant()

## 清零所有情绪（五情归一）
func reset_all() -> void:
	for emotion in EMOTIONS:
		values[emotion] = 0
		disorders[emotion] = false
	dominant_emotion = ""
	emit_signal("emotions_reset")

## 一次性应用多个情绪变化（如牌卡效果）
func apply_shift(shift: Dictionary) -> void:
	if shift.get("clear_all", false):
		reset_all()
		return
	for emotion in shift:
		if emotion in values:
			modify(emotion, shift[emotion])

# ========== 回合结束处理 ==========

## 每回合结束时，非主导情绪自然衰减-1
func on_turn_end() -> void:
	for emotion in EMOTIONS:
		if emotion == "calm":
			continue  # 定独立不衰减
		if emotion != dominant_emotion and values[emotion] > 0:
			modify(emotion, -1)

# ========== 增幅效果查询 ==========

## 获取攻击牌增幅倍率（怒主导时×1.3）
func get_attack_multiplier() -> float:
	if dominant_emotion == "rage":
		return 1.3
	return 1.0

## 获取恢复/增幅效果倍率（喜主导时×1.5）
func get_heal_multiplier() -> float:
	if dominant_emotion == "joy":
		return 1.5
	return 1.0

## 获取吸取效果倍率（悲主导时×1.5）
func get_absorb_multiplier() -> float:
	if dominant_emotion == "grief":
		return 1.5
	return 1.0

## 惧主导时摸牌额外加成
func get_draw_bonus() -> int:
	if dominant_emotion == "fear":
		return 2
	return 0

## 定≥3时费用减免
func get_cost_reduction() -> int:
	if values["calm"] >= CALM_AMPLIFY_THRESHOLD:
		return 1
	return 0

## 获取当前回合敌方伤害倍率（喜失调时×1.2）
func get_enemy_damage_multiplier() -> float:
	if disorders.get("joy", false):
		return 1.2
	return 1.0

# ========== 失调条件检测 ==========

## 检测是否可以打出某张牌（受失调限制）
func can_play_card(card: Dictionary) -> bool:
	var tag = card.get("emotion_tag", "")
	# 怒失调：无法打出防御/定类牌
	if disorders.get("rage", false):
		if tag == "calm" or card.get("effect_type", "") == "shield":
			return false
	# 悲失调：无法使用任何回复牌
	if disorders.get("grief", false):
		if card.get("effect_type", "") in ["heal", "heal_all_buffs"]:
			return false
	return true

## 检测某情绪是否处于失调
func is_disorder(emotion: String) -> bool:
	return disorders.get(emotion, false)

# ========== 内部方法 ==========

## 检测并更新失调状态
func _check_disorder(emotion: String) -> void:
	var was_disorder = disorders.get(emotion, false)
	var is_now_disorder = values[emotion] >= DISORDER_THRESHOLD
	
	if emotion == "calm":
		disorders["calm"] = false  # 定没有失调
		return
	
	disorders[emotion] = is_now_disorder
	
	if not was_disorder and is_now_disorder:
		emit_signal("disorder_triggered", emotion)
	elif was_disorder and not is_now_disorder:
		emit_signal("disorder_cleared", emotion)

## 更新主导情绪（定不参与竞争，同值保持上一状态）
func _update_dominant() -> void:
	var max_value = -1
	var new_dominant = ""
	
	for emotion in ["rage", "fear", "grief", "joy"]:  # 定不参与
		if values[emotion] > max_value:
			max_value = values[emotion]
			new_dominant = emotion
		# 同值时：保持当前主导不变
	
	if max_value == 0:
		new_dominant = ""
	
	# 如果有多个情绪并列最高，保持上一主导（如果上一主导在并列中则不变）
	if new_dominant != dominant_emotion:
		# 检查是否并列
		var tied = []
		for emotion in ["rage", "fear", "grief", "joy"]:
			if values[emotion] == max_value:
				tied.append(emotion)
		
		if len(tied) > 1 and dominant_emotion in tied:
			# 上一主导仍在并列中，保持不变
			return
		
		var old_dominant = dominant_emotion
		dominant_emotion = new_dominant
		emit_signal("dominant_changed", old_dominant, new_dominant)

# ========== 调试/UI 辅助 ==========

## 获取情绪颜色（用于UI）
func get_emotion_color(emotion: String) -> Color:
	match emotion:
		"rage": return Color("#8B1A1A")
		"fear": return Color("#4B0082")
		"grief": return Color("#1A3A6B")
		"joy": return Color("#B8860B")
		"calm": return Color("#E8E0D0")
	return Color.WHITE

## 获取情绪中文名
func get_emotion_name(emotion: String) -> String:
	match emotion:
		"rage": return "怒"
		"fear": return "惧"
		"grief": return "悲"
		"joy": return "喜"
		"calm": return "定"
	return "未知"

## 获取所有情绪总和（五情归一用）
func get_total_value() -> int:
	var total = 0
	for emotion in EMOTIONS:
		total += values[emotion]
	return total
