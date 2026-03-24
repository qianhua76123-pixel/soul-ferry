extends Node

## EmotionManager.gd - 五情系统核心管理器

signal emotion_changed(emotion: String, old_value: int, new_value: int)
signal dominant_changed(old_dominant: String, new_dominant: String)
signal disorder_triggered(emotion: String)
signal disorder_cleared(emotion: String)
signal deep_disorder_triggered(emotion: String)  # 深度失调（≥5）
signal collapse_triggered(emotion: String)        # 崩溃（=6）
signal emotions_reset()
signal emotion_increased(emotion: String, amount: int)   # 新增：情绪增加时通知（悲慧被动用）

const EMOTIONS = ["rage", "fear", "grief", "joy", "calm"]
const MAX_VALUE = 6                  # 原5→6
const MIN_VALUE = 0
const DISORDER_THRESHOLD = 4
const DEEP_DISORDER_THRESHOLD = 5   # 深度失调阈值
const COLLAPSE_THRESHOLD = 6        # 崩溃阈值
const CALM_AMPLIFY_THRESHOLD = 3

var values: Dictionary = {"rage":0,"fear":0,"grief":0,"joy":0,"calm":0}
var dominant_emotion: String = ""
var disorders: Dictionary = {}
var deep_disorders: Dictionary = {}  # 深度失调状态
var collapses: Dictionary = {}       # 崩溃状态

# 情绪衰减计数器
var _dominant_turns: int = 0  # 主导情绪衰减计数（每2回合-1）
var _calm_turns: int = 0      # 定情绪衰减计数（每3回合-1）

func _ready() -> void:
	for emotion in EMOTIONS:
		disorders[emotion] = false
		deep_disorders[emotion] = false
		collapses[emotion] = false

func modify(emotion: String, delta: int) -> void:
	if emotion not in values: return
	var old_val: int = values[emotion]
	var new_val: int = clampi(old_val + delta, MIN_VALUE, MAX_VALUE)
	if old_val == new_val: return
	values[emotion] = new_val
	emotion_changed.emit(emotion, old_val, new_val)
	# 情绪增加时额外发射信号（悲慧被动/协作联动等监听）
	if new_val > old_val:
		emotion_increased.emit(emotion, new_val - old_val)
	_check_disorder(emotion)
	if emotion != "calm":
		_update_dominant()

func reset_all() -> void:
	for emotion in EMOTIONS:
		values[emotion] = 0
		disorders[emotion] = false
		deep_disorders[emotion] = false
		collapses[emotion] = false
	dominant_emotion = ""
	_dominant_turns = 0
	_calm_turns = 0
	emotions_reset.emit()

func apply_shift(shift: Dictionary) -> void:
	if shift.get("clear_all", false):
		reset_all(); return
	for emotion in shift:
		if emotion in values:
			modify(emotion, shift[emotion])

func on_turn_end() -> void:
	# 定深度失调效果：若定≥5，其他四情各+1
	if values["calm"] >= DEEP_DISORDER_THRESHOLD:
		for emotion in ["rage", "fear", "grief", "joy"]:
			modify(emotion, 1)

	# 情绪自然衰减（分情绪类型处理）
	# 1. 定情绪：每3回合-1
	_calm_turns += 1
	if _calm_turns >= 3:
		if values["calm"] > 0:
			modify("calm", -1)
			# 失调加速：失调中额外-1
			if disorders.get("calm", false) and values["calm"] > 0:
				modify("calm", -1)
		_calm_turns = 0

	# 2. 主导情绪：每2回合-1
	if dominant_emotion != "":
		_dominant_turns += 1
		if _dominant_turns >= 2:
			if values[dominant_emotion] > 0:
				modify(dominant_emotion, -1)
				# 失调加速：失调中额外-1
				if disorders.get(dominant_emotion, false) and values[dominant_emotion] > 0:
					modify(dominant_emotion, -1)
			_dominant_turns = 0

	# 3. 非主导、非定情绪：每回合-1（失调则额外-1）
	for emotion in ["rage", "fear", "grief", "joy"]:
		if emotion == dominant_emotion: continue  # 主导已处理
		if emotion == "calm": continue
		if values[emotion] > 0:
			modify(emotion, -1)
			# 失调加速：失调中额外-1
			if disorders.get(emotion, false) and values[emotion] > 0:
				modify(emotion, -1)

func get_attack_multiplier() -> float:
	return 1.3 if dominant_emotion == "rage" else 1.0

func get_heal_multiplier() -> float:
	return 1.5 if dominant_emotion == "joy" else 1.0

func get_absorb_multiplier() -> float:
	return 1.5 if dominant_emotion == "grief" else 1.0

func get_draw_bonus() -> int:
	return 2 if dominant_emotion == "fear" else 0

func get_cost_reduction() -> int:
	return 1 if values["calm"] >= CALM_AMPLIFY_THRESHOLD else 0

func get_enemy_damage_multiplier() -> float:
	return 1.2 if disorders.get("joy", false) else 1.0

func can_play_card(card: Dictionary) -> bool:
	var tag: String = card.get("emotion_tag", "")
	var etype: String = card.get("effect_type", "")
	var cost: int = card.get("cost", 1)

	# 原有失调限制
	if disorders.get("rage", false):
		if tag == "calm" or etype == "shield": return false
	if disorders.get("grief", false):
		if etype in ["heal", "heal_all_buffs"]: return false

	# 深度失调限制（≥5）
	# 惧深度失调：无法打出费用为0的牌
	if deep_disorders.get("fear", false):
		if cost == 0: return false
	# 悲深度失调：手牌上限-2（通过 get_hand_limit_modifier 查询，此处不阻止打牌）
	# 喜深度失调：无法使用遗物主动效果（通过 is_relic_active_blocked 查询）

	return true

## 手牌上限修正（悲深度失调-2）
func get_hand_limit_modifier() -> int:
	if deep_disorders.get("grief", false):
		return -2
	return 0

## 遗物主动效果是否被阻止（喜深度失调）
func is_relic_active_blocked() -> bool:
	return deep_disorders.get("joy", false)

## 是否处于深度失调状态
func is_deep_disorder(emotion: String) -> bool:
	return deep_disorders.get(emotion, false)

## 是否处于崩溃状态
func is_collapse(emotion: String) -> bool:
	return collapses.get(emotion, false)

func is_disorder(emotion: String) -> bool:
	return disorders.get(emotion, false)

## 主导情绪弱点查询（用于 BattleScene 显示）
func get_dominant_weakness() -> Dictionary:
	match dominant_emotion:
		"rage":
			return {
				"emotion": "rage",
				"weakness": "受定系攻击时伤害×1.5",
				"description": "怒为主导时，定系力量对你的伤害加深"
			}
		"fear":
			return {
				"emotion": "fear",
				"weakness": "深度失调时无法打出费用为0的牌",
				"description": "惧意过深，连本能反应都被压制"
			}
		"grief":
			return {
				"emotion": "grief",
				"weakness": "深度失调时手牌上限-2",
				"description": "悲伤蔓延，无法集中心神"
			}
		"joy":
			return {
				"emotion": "joy",
				"weakness": "深度失调时无法使用遗物主动效果",
				"description": "虚妄之喜，让你忘记了手边的工具"
			}
		"calm":
			return {
				"emotion": "calm",
				"weakness": "深度失调时其他四情各+1",
				"description": "定意过极，反而搅动其余四情"
			}
	return {}

## 主导情绪弱点效果查询：若主导为怒，受定系攻击时×1.5
func get_dominant_damage_multiplier_against_calm() -> float:
	if dominant_emotion == "rage":
		return 1.5
	return 1.0

func get_emotion_color(emotion: String) -> Color:
	match emotion:
		"rage":  return Color(0.545, 0.102, 0.102)
		"fear":  return Color(0.294, 0.0,   0.510)
		"grief": return Color(0.102, 0.227, 0.420)
		"joy":   return Color(0.722, 0.525, 0.043)
		"calm":  return Color(0.910, 0.878, 0.816)
	return Color.WHITE

func get_emotion_name(emotion: String) -> String:
	match emotion:
		"rage":  return "怒"
		"fear":  return "惧"
		"grief": return "悲"
		"joy":   return "喜"
		"calm":  return "定"
	return "?"

func get_total_value() -> int:
	var total: int = 0
	for e in EMOTIONS: total += values[e]
	return total

func _check_disorder(emotion: String) -> void:
	if emotion == "calm":
		disorders["calm"] = false
		deep_disorders["calm"] = false
		collapses["calm"] = false
		return

	var current_val: int = values[emotion]

	# ── 普通失调（≥4）──
	var was: bool = disorders.get(emotion, false)
	var now: bool = current_val >= DISORDER_THRESHOLD
	disorders[emotion] = now
	if not was and now:
		disorder_triggered.emit(emotion)
	elif was and not now:
		disorder_cleared.emit(emotion)

	# ── 深度失调（≥5）──
	var was_deep: bool = deep_disorders.get(emotion, false)
	var now_deep: bool = current_val >= DEEP_DISORDER_THRESHOLD
	deep_disorders[emotion] = now_deep
	if not was_deep and now_deep:
		deep_disorder_triggered.emit(emotion)

	# ── 崩溃（=6）──
	var was_collapse: bool = collapses.get(emotion, false)
	var now_collapse: bool = current_val >= COLLAPSE_THRESHOLD
	collapses[emotion] = now_collapse
	if not was_collapse and now_collapse:
		collapse_triggered.emit(emotion)

func _update_dominant() -> void:
	var max_val: int = -1
	var new_dom: String = ""
	for emotion in ["rage","fear","grief","joy"]:
		if values[emotion] > max_val:
			max_val = values[emotion]; new_dom = emotion
	if max_val == 0: new_dom = ""
	if new_dom == dominant_emotion: return
	var tied: Array = []
	for emotion in ["rage","fear","grief","joy"]:
		if values[emotion] == max_val: tied.append(emotion)
	if len(tied) > 1 and dominant_emotion in tied: return
	var old: String = dominant_emotion
	# 主导切换时重置计数器
	_dominant_turns = 0
	dominant_emotion = new_dom
	dominant_changed.emit(old, new_dom)
