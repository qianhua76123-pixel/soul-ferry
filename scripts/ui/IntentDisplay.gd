extends VBoxContainer

## IntentDisplay.gd - 敌人意图预告组件
## 由 BattleScene 在每次玩家回合开始时调用 show_intent(action_dict)

const INTENT_ICONS = {
	"attack":            "⚔",
	"attack_all":        "⚔⚔",
	"attack_all_triple": "⚔×3",
	"dot_fire":          "🔥",
	"dot":               "☠",
	"all_field_heat_dot":"🔥🌊",
	"shield":            "🛡",
	"emotion_push":      "〰",
	"summon_tide":       "🌊",
	"rage_card_storm":   "💢",
	"draw_player":       "👁",
	"status_seal":       "🔒",
	"weaken":            "↓",
	"unknown":           "？",
}

const INTENT_COLORS = {
	"attack":            Color(0.91, 0.30, 0.24),
	"attack_all":        Color(0.91, 0.20, 0.14),
	"attack_all_triple": Color(1.00, 0.10, 0.10),
	"dot_fire":          Color(0.90, 0.48, 0.13),
	"dot":               Color(0.56, 0.27, 0.68),
	"all_field_heat_dot":Color(0.90, 0.40, 0.10),
	"shield":            Color(0.20, 0.60, 0.86),
	"emotion_push":      Color(0.70, 0.70, 0.30),
	"summon_tide":       Color(0.15, 0.55, 0.80),
	"rage_card_storm":   Color(0.95, 0.20, 0.20),
	"draw_player":       Color(0.60, 0.20, 0.80),
	"unknown":           Color(0.55, 0.55, 0.55),
}

var _icon_label: Label
var _desc_label: Label
var _anim_tween: Tween = null

func _ready() -> void:
	custom_minimum_size = Vector2(220, 44)
	add_theme_constant_override("separation", 2)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", 18)
	_icon_label.custom_minimum_size = Vector2(28, 0)
	row.add_child(_icon_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(180, 0)
	row.add_child(_desc_label)

	show_intent({})

func show_intent(action: Dictionary) -> void:
	if action.is_empty():
		_icon_label.text = "？"
		_desc_label.text = "蓄势待发"
		_desc_label.add_theme_color_override("font_color", INTENT_COLORS["unknown"])
		return

	var atype = action.get("type", "unknown")
	_icon_label.text = INTENT_ICONS.get(atype, "？")
	_desc_label.text = _build_description(action)

	var color = INTENT_COLORS.get(atype, Color.GRAY)
	_desc_label.add_theme_color_override("font_color", color)
	_icon_label.add_theme_color_override("font_color", color)

	# 淡入
	modulate.a = 0.0
	if _anim_tween: _anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "modulate:a", 1.0, 0.3)

	# 攻击类：图标摇摆
	var atk_types = ["attack","attack_all","attack_all_triple","rage_card_storm","summon_tide"]
	if atype in atk_types:
		_play_icon_shake(int(action.get("value", 0)))

func _build_description(action: Dictionary) -> String:
	var val   = int(action.get("value", 0))
	var atype = action.get("type", "unknown")
	match atype:
		"attack":            return "造成 %d 点伤害" % int(val)
		"attack_all":        return "对全体造成 %d 伤害" % int(val)
		"attack_all_triple": return "三连击各 %d 伤害" % int(val)
		"dot_fire":          return "施加灼烧 ×%d（%d回合）" % [int(val), int(action.get("duration", 3))]
		"dot":               return "施加中毒 ×%d" % int(val)
		"all_field_heat_dot":return "全场灼烧 ×%d" % int(val)
		"shield":            return "获得 %d 护盾" % int(val)
		"emotion_push":
			var emo_cn = {"rage":"怒","fear":"惧","grief":"悲","joy":"喜","calm":"定"}
			var en = action.get("emotion", "")
			return "使你%s +%d" % [emo_cn.get(en, en), int(val)]
		"summon_tide":       return "召唤潮汐 %d×%d段" % [int(val), int(action.get("hits", 3))]
		"rage_card_storm":   return "狂暴（随手牌数增伤）"
		"draw_player":       return "强迫摸 %d 张牌" % int(val)
		"status_seal":       return "封印 %d 回合" % int(val)
		_:                   return "蓄势待发"

func _play_icon_shake(dmg_value: int) -> void:
	if dmg_value > 15:
		_desc_label.add_theme_font_size_override("font_size", 15)
	else:
		_desc_label.add_theme_font_size_override("font_size", 12)
	var orig_x = _icon_label.position.x
	var tw = _icon_label.create_tween()
	tw.tween_property(_icon_label, "position:x", orig_x + 4, 0.12)
	tw.tween_property(_icon_label, "position:x", orig_x - 4, 0.12)
	tw.tween_property(_icon_label, "position:x", orig_x + 2, 0.10)
	tw.tween_property(_icon_label, "position:x", orig_x,     0.08)
