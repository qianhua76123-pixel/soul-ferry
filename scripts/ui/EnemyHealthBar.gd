extends VBoxContainer

class_name EnemyHealthBar

## EnemyHealthBar.gd - 敌人HP血条组件

var _real_bar:    ProgressBar
var _ghost_bar:   ProgressBar
var _info_label:  Label
var _hp_tween:    Tween = null

func _ready() -> void:
	_build()

func _build() -> void:
	custom_minimum_size = Vector2(220, 36)
	add_theme_constant_override("separation", 2)
	alignment = BoxContainer.ALIGNMENT_END   # 右对齐

	var bar_container = Control.new()
	bar_container.custom_minimum_size = Vector2(220, 16)
	add_child(bar_container)

	_ghost_bar = ProgressBar.new()
	_ghost_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ghost_bar.min_value = 0
	_ghost_bar.show_percentage = false
	var ghost_style = StyleBoxFlat.new()
	ghost_style.bg_color = Color(0.85, 0.65, 0.0, 0.7)
	_ghost_bar.add_theme_stylebox_override("fill", ghost_style)
	var ghost_bg = StyleBoxFlat.new()
	ghost_bg.bg_color = Color(0.08, 0.06, 0.05)
	_ghost_bar.add_theme_stylebox_override("background", ghost_bg)
	bar_container.add_child(_ghost_bar)

	_real_bar = ProgressBar.new()
	_real_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_real_bar.min_value = 0
	_real_bar.show_percentage = false
	var real_style = StyleBoxFlat.new()
	real_style.bg_color = Color(0.76, 0.20, 0.20)   # 敌人血条红色
	_real_bar.add_theme_stylebox_override("fill", real_style)
	var real_bg = StyleBoxFlat.new()
	real_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_real_bar.add_theme_stylebox_override("background", real_bg)
	bar_container.add_child(_real_bar)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.90, 0.86, 0.78))
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_info_label)

func set_hp(new_hp: int, max_hp: int) -> void:
	_real_bar.max_value  = max_hp
	_ghost_bar.max_value = max_hp
	_real_bar.value      = new_hp
	if _hp_tween: _hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_interval(0.3)
	_hp_tween.tween_property(_ghost_bar, "value", float(new_hp), 0.5)\
		.set_ease(Tween.EASE_OUT)
	var ratio = float(new_hp) / max(1, max_hp)
	var fill_style = StyleBoxFlat.new()
	if ratio > 0.5:
		fill_style.bg_color = Color(0.76, 0.20, 0.20)
	elif ratio > 0.25:
		fill_style.bg_color = Color(0.85, 0.45, 0.10)
	else:
		fill_style.bg_color = Color(0.95, 0.15, 0.10)
	_real_bar.add_theme_stylebox_override("fill", fill_style)
	_info_label.text = "%d / %d" % [int(new_hp), int(max_hp)]

func set_shield(shield: int) -> void:
	_info_label.text = "%d / %d   🛡 %d" % [
		int(_real_bar.value), int(_real_bar.max_value), shield]
