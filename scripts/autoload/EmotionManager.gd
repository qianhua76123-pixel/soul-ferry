extends Node

## EmotionManager.gd - 五情系统核心管理器

signal emotion_changed(emotion: String, old_value: int, new_value: int)
signal dominant_changed(old_dominant: String, new_dominant: String)
signal disorder_triggered(emotion: String)
signal disorder_cleared(emotion: String)
signal emotions_reset()

const EMOTIONS = ["rage", "fear", "grief", "joy", "calm"]
const MAX_VALUE = 5
const MIN_VALUE = 0
const DISORDER_THRESHOLD = 4
const CALM_AMPLIFY_THRESHOLD = 3

var values: Dictionary = {"rage":0,"fear":0,"grief":0,"joy":0,"calm":0}
var dominant_emotion: String = ""
var disorders: Dictionary = {}

func _ready() -> void:
	for emotion in EMOTIONS:
		disorders[emotion] = false

func modify(emotion: String, delta: int) -> void:
	if emotion not in values: return
	var old_val = values[emotion]
	var new_val = clamp(old_val + delta, MIN_VALUE, MAX_VALUE)
	if old_val == new_val: return
	values[emotion] = new_val
	emotion_changed.emit(emotion, old_val, new_val)
	_check_disorder(emotion)
	if emotion != "calm":
		_update_dominant()

func reset_all() -> void:
	for emotion in EMOTIONS:
		values[emotion] = 0
		disorders[emotion] = false
	dominant_emotion = ""
	emotions_reset.emit()

func apply_shift(shift: Dictionary) -> void:
	if shift.get("clear_all", false):
		reset_all(); return
	for emotion in shift:
		if emotion in values:
			modify(emotion, shift[emotion])

func on_turn_end() -> void:
	for emotion in EMOTIONS:
		if emotion == "calm": continue
		if emotion != dominant_emotion and values[emotion] > 0:
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
	var tag = card.get("emotion_tag", "")
	var etype = card.get("effect_type", "")
	if disorders.get("rage", false):
		if tag == "calm" or etype == "shield": return false
	if disorders.get("grief", false):
		if etype in ["heal", "heal_all_buffs"]: return false
	return true

func is_disorder(emotion: String) -> bool:
	return disorders.get(emotion, false)

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
	var total = 0
	for e in EMOTIONS: total += values[e]
	return total

func _check_disorder(emotion: String) -> void:
	if emotion == "calm":
		disorders["calm"] = false; return
	var was = disorders.get(emotion, false)
	var now = values[emotion] >= DISORDER_THRESHOLD
	disorders[emotion] = now
	if not was and now:
		disorder_triggered.emit(emotion)
	elif was and not now:
		disorder_cleared.emit(emotion)

func _update_dominant() -> void:
	var max_val = -1
	var new_dom = ""
	for emotion in ["rage","fear","grief","joy"]:
		if values[emotion] > max_val:
			max_val = values[emotion]; new_dom = emotion
	if max_val == 0: new_dom = ""
	if new_dom == dominant_emotion: return
	var tied = []
	for emotion in ["rage","fear","grief","joy"]:
		if values[emotion] == max_val: tied.append(emotion)
	if len(tied) > 1 and dominant_emotion in tied: return
	var old = dominant_emotion
	dominant_emotion = new_dom
	dominant_changed.emit(old, new_dom)
