extends Node2D

## DamageNumber.gd - 战斗浮字组件
## 用法：从 BattleScene 实例化后调用 spawn(value, type, position)

@onready var _label: Label = $Label

# type → 颜色 + 前缀格式
const TYPE_CONFIG = {
	"damage":  {"color": Color(1.0, 0.22, 0.18, 1.0), "prefix": "-"},
	"heal":    {"color": Color(0.28, 0.88, 0.28, 1.0), "prefix": "+"},
	"emotion": {"color": Color(0.95, 0.78, 0.12, 1.0), "prefix": ""},
	"shield":  {"color": Color(0.45, 0.65, 1.00, 1.0), "prefix": "+"},
	"buff":    {"color": Color(0.80, 0.45, 1.00, 1.0), "prefix": ""},
}

func _ready() -> void:
	_label.visible = false

## 主入口：设置内容、位置，然后播放动画
## value:    伤害/治疗数值（正整数）
## type:     "damage" / "heal" / "emotion" / "shield" / "buff"
## pos:      世界坐标（spawn 后立刻移动到这里）
## extra:    情绪类额外文字，如 "怒↑2"（type=emotion 时使用）
func spawn(value: int, type: String, pos: Vector2, extra: String = "") -> void:
	global_position = pos + Vector2(randf_range(-14.0, 14.0), 0.0)   # 轻微横向抖动

	var cfg    = TYPE_CONFIG.get(type, TYPE_CONFIG["damage"])
	var prefix = cfg["prefix"]

	if type == "emotion" and extra != "":
		_label.text = extra
	elif type == "damage" and value == 0:
		_label.text = "MISS"
	else:
		_label.text = "%s%d" % [prefix, value]

	_label.add_theme_color_override("font_color", cfg["color"])
	_label.modulate.a = 0.0
	_label.visible    = true

	# 三段 Tween 动画
	var tw = create_tween()

	# 0 ~ 0.25s：向上 40px + 淡入
	tw.tween_property(self, "position:y", position.y - 40.0, 0.25) \
	  .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(_label, "modulate:a", 1.0, 0.20)

	# 0.25 ~ 0.55s：继续上移 20px + 保持可见（短暂停留）
	tw.tween_property(self, "position:y", position.y - 60.0, 0.18) \
	  .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

	# 0.55 ~ 0.80s：淡出
	tw.tween_property(_label, "modulate:a", 0.0, 0.25)

	# 完成后自毁
	tw.tween_callback(queue_free)
