extends Node

## CardDatabase.gd - 牌库数据，从 JSON 加载，运行时只读

const CARDS_DATA_PATH = "res://data/cards.json"

var _cards: Dictionary = {}
var _loaded: bool = false

func _ready() -> void:
	_load_cards()

func _load_cards() -> void:
	if _loaded: return
	var file: FileAccess = FileAccess.open(CARDS_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("CardDatabase: 无法打开 " + CARDS_DATA_PATH); return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("CardDatabase: JSON 解析失败"); file.close(); return
	file.close()
	for card in json.get_data().get("cards", []):
		card["cost"] = int(card.get("cost", 1))
		_cards[card.get("id", "")] = card
	_loaded = true

func get_card(card_id: String) -> Dictionary:
	if not _loaded: _load_cards()
	var card: Dictionary = _cards.get(card_id, {}).duplicate(true)
	# 动态注入 desc（始终反映真实数值，支持升级）
	if not card.is_empty():
		card["desc"] = get_desc(card_id, card.get("level", 0))
	return card

func get_all_cards() -> Array:
	if not _loaded: _load_cards()
	return _cards.values()

func get_reward_cards(count: int = 3) -> Array:
	var pool: Array = get_all_cards().filter(func(c): return not c.get("is_curse", false))
	pool.shuffle()
	var weighted: Array = []
	for c in pool:
		match c.get("rarity", "common"):
			"legendary": weighted.append_array([c])
			"rare":      weighted.append_array([c, c])
			_:           weighted.append_array([c, c, c, c])
	weighted.shuffle()
	var result: Array = []
	var seen_ids: Dictionary = {}
	for c in weighted:
		if len(result) >= count: break
		if c.get("id","") not in seen_ids:
			result.append(c.duplicate(true))
			seen_ids[c.get("id","")] = true
	return result

# ════════════════════════════════════════════════════════
#  get_desc() — 根据 JSON 数值动态拼接牌卡描述
#  level=0: 基础值; level=1: 升级值（×1.5取整 或 +1）
#  升级后变化的数值用金色 BBCode 标注
# ════════════════════════════════════════════════════════
func get_desc(card_id: String, level: int = 0) -> String:
	if not _loaded: _load_cards()
	var card: Dictionary = _cards.get(card_id, {})
	if card.is_empty(): return "???"

	var etype: String = card.get("effect_type", "")
	var base: int     = int(card.get("effect_value", 0))
	var bonus: Variant = card.get("condition_bonus", null)
	var cond: Variant  = card.get("condition", null)
	var shift: Dictionary = card.get("emotion_shift", {})
	var ename_cn: String = EmotionManager.get_emotion_name(card.get("emotion_tag", "calm"))

	# 升级值计算
	var upval  = int(base * 1.5) if base > 0 else base
	var bonus_int: int = bonus if bonus != null else 0
	var upbonus: int = bonus_int + 1 if bonus_int > 0 else bonus_int

	var val  = upval   if level > 0 and upval   != base       else base
	var bval: int = upbonus if level > 0 and upbonus != bonus_int  else bonus_int

	# 升级变化数值标金色
	var vs: String = str(int(val)) if (level == 0 or val == base) else ("[color=#f0c040]%d[/color]" % val)
	var bs: String = str(int(bval)) if (level == 0 or bval == bonus_int) else ("[color=#f0c040]%d[/color]" % bval)

	# 情绪偏移文字
	var shift_str = ""
	for emotion in shift:
		if emotion == "clear_all":
			shift_str += "所有情绪归零"
		else:
			var ev: int = int(shift[emotion])
			if ev > 0:
				shift_str += "+%s%d" % [EmotionManager.get_emotion_name(emotion), ev]

	var cond_str: String = _cond_text(cond)
	var desc     = _build_desc(etype, vs, bs, cond_str, card, ename_cn)

	if shift_str != "" and "归零" not in desc and "清零" not in desc:
		desc += "  " + shift_str

	return desc

func _cond_text(cond) -> String:
	if cond == null or str(cond) == "null" or str(cond) == "": return ""
	match str(cond):
		"calm >= 3":      return "定≥3时"
		"calm_dominant":  return "定主导时"
		"rage_dominant":  return "怒主导时"
		"fear_dominant":  return "惧主导时"
		"grief_dominant": return "悲主导时"
		"joy_dominant":   return "喜主导时"
		"rage >= 3":      return "怒≥3时"
		"fear >= 3":      return "惧≥3时"
		"grief >= 3":     return "悲≥3时"
		"joy >= 3":       return "喜≥3时"
	if " >= " in str(cond):
		var parts: PackedStringArray = str(cond).split(" >= ")
		return "%s≥%s时" % [EmotionManager.get_emotion_name(parts[0].strip_edges()), parts[1].strip_edges()]
	return str(cond)

func _build_desc(etype: String, vs: String, bs: String,
				 cond: String, card: Dictionary, _ename_cn: String) -> String:
	var cid: String = card.get("id", "")
	match etype:
		"attack":
			if cid == "fen_nu_bao":
				return "造成「当前怒值×4」点伤害"
			var d = "造成 %s 点伤害" % vs
			if cond != "" and bs != "0": d += "，%s额外+%s" % [cond, bs]
			return d
		"attack_all":
			var d_2 = "对所有敌人造成 %s 点伤害" % vs
			if cond != "" and bs != "0": d_2 += "，%s额外+%s" % [cond, bs]
			return d_2
		"attack_lifesteal":
			return "造成 %s 点伤害，吸取一半为HP" % vs
		"shield":
			var d_2_2 = "获得 %s 点护盾" % vs
			if cond != "" and bs != "0": d_2_2 += "，%s额外+%s" % [cond, bs]
			return d_2_2
		"shield_attack":
			return "获得 %s 点护盾并造成 %s 点伤害%s" % [vs, vs,
				"，%s效果翻倍" % cond if cond != "" else ""]
		"reset_shield":
			return "【传说】将所有情绪归零，获得情绪总和×%s的护盾" % vs
		"heal":
			var d_2_2_2 = "回复 %s HP" % vs
			if cond != "" and bs != "0": d_2_2_2 += "，%s额外+%s" % [cond, bs]
			elif cond != "" and card.get("condition_bonus_type","") != "":
				d_2_2_2 += "，%s额外效果" % cond
			return d_2_2_2
		"heal_all_buffs":
			var d_2_2_2_2 = "回复 %s HP" % vs
			if cond != "" and bs != "0": d_2_2_2_2 += "，%s额外+%s并施加祝福" % [cond, bs]
			return d_2_2_2_2
		"draw":
			var d_2_2_2_2_2 = "摸 %s 张牌" % vs
			if cond != "": d_2_2_2_2_2 += "，%s改为摸 %s 张" % [cond, bs if bs != "0" else "3"]
			return d_2_2_2_2_2
		"weaken":
			var d_2_2_2_2_2_2 = "目标下回合伤害-%s%%" % vs
			if card.get("condition_bonus_type","") != "":
				d_2_2_2_2_2_2 += "，%s施加执念" % cond
			return d_2_2_2_2_2_2
		"dodge_attack":
			var d_2_2_2_2_2_2_2 = "造成 %s 点伤害+获得闪避" % vs
			if cond != "" and bs != "0": d_2_2_2_2_2_2_2 += "，%s额外+%s" % [cond, bs]
			return d_2_2_2_2_2_2_2
		"dot_and_weaken":
			var d_2_2_2_2_2_2_2_2 = "【传说】对目标施加执念DOT %s 回合" % vs
			if cond != "" and bs != "0": d_2_2_2_2_2_2_2_2 += "，%s每回合+%s" % [cond, bs]
			return d_2_2_2_2_2_2_2_2
		"draw_discard_enemy":
			var d_2_2_2_2_2_2_2_2_2 = "令敌人弃置 %s 张意图" % vs
			if cond != "" and bs != "0": d_2_2_2_2_2_2_2_2_2 += "，%s额外+%s层执念" % [cond, bs]
			return d_2_2_2_2_2_2_2_2_2
		"buff_all_cards":
			var d_2_2_2_2_2_2_2_2_2_2 = "【传说】本回合所有牌效果+%s" % vs
			if cond != "": d_2_2_2_2_2_2_2_2_2_2 += "，%s翻倍" % cond
			return d_2_2_2_2_2_2_2_2_2_2
		"status_fear_all":
			var d_2_2_2_2_2_2_2_2_2_2_2 = "对所有敌人施加「恐惧」%s层" % vs
			if cond != "" and bs != "0": d_2_2_2_2_2_2_2_2_2_2_2 += "，%s持续+%s回合" % [cond, bs]
			return d_2_2_2_2_2_2_2_2_2_2_2
		"status_seal":
			return "对目标施加「封印」%s层" % vs
		"reduce_enemy_emotion":
			var d_2_2_2_2_2_2_2_2_2_2_2_2 = "降低目标情绪压力 %s 点" % vs
			if cond != "" and bs != "0": d_2_2_2_2_2_2_2_2_2_2_2_2 += "，%s额外-%s并回血" % [cond, bs]
			return d_2_2_2_2_2_2_2_2_2_2_2_2
		"peek_enemy":
			return "预览敌人下回合意图"
		"du_hua_progress":
			return "渡化进度+%s" % vs
		"du_hua_trigger":
			return "%s触发渡化判定" % cond
	return card.get("description", "???")
