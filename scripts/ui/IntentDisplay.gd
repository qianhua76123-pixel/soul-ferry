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

## 攻击/高威胁意图：提高底对比度 + 金边闪烁（M-08 预警）
const THREAT_INTENT_TYPES: Array[String] = [
	"attack", "attack_all", "attack_all_triple",
	"rage_card_storm", "summon_tide", "all_field_heat_dot",
]

var _icon_label: Label
var _desc_label: Label
var _warn_caption: Label
var _anim_tween: Tween = null
var _border_tween: Tween = null
## 面板填充不透明度：常态略透，威胁时更实
var _fill_alpha: float = 0.72
## 边框/顶线闪烁强度（0.6～1.0 脉冲）
var _edge_flash: float = 1.0

func _ready() -> void:
	custom_minimum_size = Vector2(220, 44)
	add_theme_constant_override("separation", 2)

	var row: HBoxContainer = HBoxContainer.new()
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

	_warn_caption = Label.new()
	_warn_caption.visible = false
	_warn_caption.add_theme_font_size_override("font_size", UIConstants.font_size_of("micro"))
	_warn_caption.add_theme_color_override("font_color", UIConstants.color_of("nu"))
	_warn_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_warn_caption)

	show_intent({})

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	if rect.size.x < 8 or rect.size.y < 8:
		return
	var fill = UIConstants.color_of("parch")
	var border = UIConstants.color_of("gold_dim")
	var gl = UIConstants.color_of("gold")
	draw_rect(rect, Color(fill.r, fill.g, fill.b, _fill_alpha), true)
	var border_a: float = clampf(0.70 * _edge_flash, 0.35, 1.0)
	draw_rect(rect, Color(border.r, border.g, border.b, border_a), false, 1.0)
	var top_a: float = clampf(0.55 + 0.45 * (_edge_flash - 0.6) / 0.4, 0.45, 1.0)
	draw_line(Vector2(3, 1), Vector2(rect.size.x - 3, 1), Color(gl.r, gl.g, gl.b, top_a), 1.5)

func show_intent(action: Dictionary) -> void:
	if action.is_empty():
		_reset_threat_visuals()
		_icon_label.text = "？"
		_desc_label.text = "蓄势待发"
		_desc_label.add_theme_color_override("font_color", INTENT_COLORS["unknown"])
		_icon_label.add_theme_color_override("font_color", INTENT_COLORS["unknown"])
		_fade_in()
		return

	var atype: String = action.get("type", "unknown")
	_icon_label.text = INTENT_ICONS.get(atype, "？")
	_desc_label.text = _build_description(action)

	var color = INTENT_COLORS.get(atype, Color.GRAY)
	_desc_label.add_theme_color_override("font_color", color)
	_icon_label.add_theme_color_override("font_color", color)

	var is_threat: bool = atype in THREAT_INTENT_TYPES
	_apply_threat_visuals(is_threat, atype)

	_fade_in()

	# 攻击类：图标摇摆
	var atk_types: Array = ["attack", "attack_all", "attack_all_triple", "rage_card_storm", "summon_tide"]
	if atype in atk_types:
		_play_icon_shake(int(action.get("value", 0)))

func _build_description(action: Dictionary) -> String:
	var val   = int(action.get("value", 0))
	var atype: String = action.get("type", "unknown")
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
			var en: String = action.get("emotion", "")
			return "使你%s +%d" % [emo_cn.get(en, en), int(val)]
		"summon_tide":       return "召唤潮汐 %d×%d段" % [int(val), int(action.get("hits", 3))]
		"rage_card_storm":   return "狂暴（随手牌数增伤）"
		"draw_player":       return "强迫摸 %d 张牌" % int(val)
		"status_seal":       return "封印 %d 回合" % int(val)
		_:                   return "蓄势待发"

## 自定义一行意图（Boss 预告 / 问路香等），不走 action 字典解析
func show_intent_custom(icon: String, desc: String, rage_mode: bool = false) -> void:
	_reset_threat_visuals()
	_icon_label.text = icon if icon != "" else "?"
	_desc_label.text = desc
	var col: Color = INTENT_COLORS["rage_card_storm"] if rage_mode else UIConstants.color_of("text_secondary")
	_desc_label.add_theme_color_override("font_color", col)
	_icon_label.add_theme_color_override("font_color", col)
	_fade_in()

func _fade_in() -> void:
	modulate.a = 0.0
	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _reset_threat_visuals() -> void:
	_fill_alpha = 0.72
	_edge_flash = 1.0
	if _border_tween:
		_border_tween.kill()
		_border_tween = null
	if _warn_caption:
		_warn_caption.visible = false
		_warn_caption.text = ""
	queue_redraw()

func _apply_threat_visuals(is_threat: bool, atype: String) -> void:
	if not is_threat:
		_reset_threat_visuals()
		return
	_fill_alpha = 0.95
	_edge_flash = 0.6
	queue_redraw()
	if _border_tween:
		_border_tween.kill()
	_border_tween = create_tween()
	_border_tween.tween_method(_set_edge_flash, 0.6, 1.0, 0.15)
	_border_tween.tween_method(_set_edge_flash, 1.0, 0.6, 0.15)
	# 群体/多段/狂暴：额外一行微提示
	var big := atype in ["attack_all", "attack_all_triple", "rage_card_storm", "all_field_heat_dot", "summon_tide"]
	if big and _warn_caption:
		_warn_caption.text = "—— 杀招将启 ——"
		_warn_caption.visible = true
	elif _warn_caption:
		_warn_caption.visible = false
		_warn_caption.text = ""

func _set_edge_flash(v: float) -> void:
	_edge_flash = v
	queue_redraw()

func _play_icon_shake(dmg_value: int) -> void:
	if dmg_value > 15:
		_desc_label.add_theme_font_size_override("font_size", 15)
	else:
		_desc_label.add_theme_font_size_override("font_size", 12)
	var orig_x = _icon_label.position.x
	var tw: Tween = _icon_label.create_tween()
	tw.tween_property(_icon_label, "position:x", orig_x + 4, 0.12)
	tw.tween_property(_icon_label, "position:x", orig_x - 4, 0.12)
	tw.tween_property(_icon_label, "position:x", orig_x + 2, 0.10)
	tw.tween_property(_icon_label, "position:x", orig_x,     0.08)
