extends VBoxContainer

class_name PlayerHealthBar

## PlayerHealthBar.gd - 玩家HP血条组件（双层残影血条）

var _real_bar:   ProgressBar
var _ghost_bar:  ProgressBar
var _info_label: Label
var _buff_label: Label
var _hp_tween:   Tween = null

func _ready() -> void:
	_build()

func _build() -> void:
	custom_minimum_size = Vector2(220, 42)
	add_theme_constant_override("separation", 2)

	# 双层血条容器
	var bar_container = Control.new()
	bar_container.custom_minimum_size = Vector2(220, 16)
	add_child(bar_container)

	# 残影层（底层，黄色）
	_ghost_bar = ProgressBar.new()
	_ghost_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ghost_bar.min_value = 0
	_ghost_bar.show_percentage = false
	var ghost_style = StyleBoxFlat.new()
	ghost_style.bg_color = Color(0.85, 0.65, 0.0, 0.7)
	_ghost_bar.add_theme_stylebox_override("fill", ghost_style)
	var ghost_bg = StyleBoxFlat.new()
	ghost_bg.bg_color = UIConstants.color_of("card_face")
	_ghost_bar.add_theme_stylebox_override("background", ghost_bg)
	bar_container.add_child(_ghost_bar)

	# 实际HP层（上层）
	_real_bar = ProgressBar.new()
	_real_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_real_bar.min_value = 0
	_real_bar.show_percentage = false
	var real_style = StyleBoxFlat.new()
	real_style.bg_color = Color(0.30, 0.68, 0.31)
	_real_bar.add_theme_stylebox_override("fill", real_style)
	var real_bg = StyleBoxFlat.new()
	real_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_real_bar.add_theme_stylebox_override("background", real_bg)
	bar_container.add_child(_real_bar)

	# HP 数值 + 护盾同行
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	add_child(_info_label)

	# Buff 行
	_buff_label = Label.new()
	_buff_label.add_theme_font_size_override("font_size", 11)
	_buff_label.add_theme_color_override("font_color", UIConstants.color_of("text_muted"))
	add_child(_buff_label)

func set_hp(new_hp: int, max_hp: int) -> void:
	_real_bar.max_value  = max_hp
	_ghost_bar.max_value = max_hp
	_real_bar.value      = new_hp
	# 残影延迟跟随
	if _hp_tween: _hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_interval(0.3)
	_hp_tween.tween_property(_ghost_bar, "value", float(new_hp), 0.5)\
		.set_ease(Tween.EASE_OUT)
	# 颜色
	var ratio = float(new_hp) / max(1, max_hp)
	var fill_style = StyleBoxFlat.new()
	if ratio > 0.6:
		fill_style.bg_color = Color(0.30, 0.68, 0.31)   # 绿
	elif ratio > 0.3:
		fill_style.bg_color = Color(1.0,  0.76, 0.03)   # 黄
	else:
		fill_style.bg_color = Color(0.96, 0.26, 0.21)   # 红
	_real_bar.add_theme_stylebox_override("fill", fill_style)
	if ratio <= 0.3:
		_start_pulse()

func set_shield(shield: int) -> void:
	_info_label.text = "%d / %d   🛡 %d" % [
		int(_real_bar.value), int(_real_bar.max_value), shield]

func set_buffs(buff_text: String) -> void:
	_buff_label.text = buff_text

func _start_pulse() -> void:
	if _real_bar.get_meta("_pulsing", false): return
	_real_bar.set_meta("_pulsing", true)
	var tw = _real_bar.create_tween().set_loops()
	tw.tween_property(_real_bar, "modulate:a", 0.45, 0.75)
	tw.tween_property(_real_bar, "modulate:a", 1.0,  0.75)
