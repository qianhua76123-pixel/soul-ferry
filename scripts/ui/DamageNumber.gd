extends Node2D

## DamageNumber.gd - 战斗浮字组件
## 用法：从 BattleScene 实例化后调用 spawn(value, type, position)

@onready var _label: Label = $Label

func _color_for_type(type: String) -> Color:
	match type:
		"heal":
			return UIConstants.color_of("heal_flash")
		"emotion":
			return UIConstants.color_of("gold")
		"shield":
			return UIConstants.color_of("bei")
		"buff":
			return UIConstants.color_of("ju")
		_:
			return UIConstants.color_of("damage_flash")

func _prefix_for_type(type: String) -> String:
	match type:
		"damage":
			return "-"
		"heal", "shield":
			return "+"
		_:
			return ""

func _ready() -> void:
	_label.visible = false

## 主入口：设置内容、位置，然后播放动画
## value:    伤害/治疗数值（正整数）
## type:     "damage" / "heal" / "emotion" / "shield" / "buff"
## pos:      世界坐标（spawn 后立刻移动到这里）
## extra:    情绪类额外文字，如 "怒↑2"（type=emotion 时使用）
func spawn(value: int, type: String, pos: Vector2, extra: String = "") -> void:
	global_position = pos + Vector2(randf_range(-14.0, 14.0), 0.0)   # 轻微横向抖动

	var prefix = _prefix_for_type(type)

	if type == "emotion" and extra != "":
		_label.text = extra
	elif type == "damage" and value == 0:
		_label.text = "MISS"
	else:
		_label.text = "%s%d" % [prefix, value]

	_label.add_theme_color_override("font_color", _color_for_type(type))
	_label.modulate.a = 0.0
	_label.visible    = true

	# 三段 Tween 动画
	var tw: Tween = create_tween()

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
