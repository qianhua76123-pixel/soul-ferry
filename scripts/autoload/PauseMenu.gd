extends CanvasLayer

## PauseMenu.gd - 全局暂停菜单（ESC 键呼出）
## 提供：音量调节 / 返回主菜单 / 继续游戏
## 战斗中暂停会保留战斗状态

const PAUSE_LAYER = 64

var _visible: bool = false
var _panel:   Control
var _bgm_slider:  HSlider
var _sfx_slider:  HSlider

func _ready() -> void:
	layer = PAUSE_LAYER
	_build_ui()
	visible = false
	# 注册全局输入监听
	set_process_unhandled_key_input(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	_visible = !_visible
	visible  = _visible
	get_tree().paused = _visible
	if _visible:
		_bgm_slider.value = SoundManager.bgm_volume * 100.0
		_sfx_slider.value = SoundManager.sfx_volume * 100.0

func _build_ui() -> void:
	# 半透明遮罩
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 主面板
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(340, 380)
	_panel.position = Vector2(-170, -190)

	var style = StyleBoxFlat.new()
	style.bg_color           = Color(0.06, 0.04, 0.03)
	style.border_color       = Color(0.55, 0.12, 0.08)
	style.border_width_left  = 2
	style.border_width_right = 2
	style.border_width_top   = 2
	style.border_width_bottom= 2
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 14)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",  24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top",   20)
	margin.add_theme_constant_override("margin_bottom",20)
	margin.add_child(vbox)
	_panel.add_child(margin)

	# 标题
	var title = Label.new()
	title.text = "— 暂停 —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.75, 0.20, 0.12))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# BGM 音量
	vbox.add_child(_make_label("🎵 背景音乐"))
	_bgm_slider = HSlider.new()
	_bgm_slider.min_value = 0
	_bgm_slider.max_value = 100
	_bgm_slider.step      = 1
	_bgm_slider.value     = SoundManager.bgm_volume * 100.0
	_bgm_slider.value_changed.connect(func(v): SoundManager.set_bgm_volume(v / 100.0))
	vbox.add_child(_bgm_slider)

	# SFX 音量
	vbox.add_child(_make_label("🔊 音效音量"))
	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0
	_sfx_slider.max_value = 100
	_sfx_slider.step      = 1
	_sfx_slider.value     = SoundManager.sfx_volume * 100.0
	_sfx_slider.value_changed.connect(func(v): SoundManager.set_sfx_volume(v / 100.0))
	vbox.add_child(_sfx_slider)

	vbox.add_child(HSeparator.new())

	# 当前状态信息
	var info = Label.new()
	info.name = "InfoLabel"
	info.text = _get_status_text()
	info.add_theme_color_override("font_color", Color(0.60, 0.56, 0.50))
	info.add_theme_font_size_override("font_size", 12)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	vbox.add_child(HSeparator.new())

	# 按钮区
	var continue_btn = _make_btn("继续游戏", Color(0.12, 0.40, 0.12))
	continue_btn.pressed.connect(func(): toggle())
	vbox.add_child(continue_btn)

	var menu_btn = _make_btn("返回主菜单", Color(0.40, 0.10, 0.08))
	menu_btn.pressed.connect(_on_return_to_menu)
	vbox.add_child(menu_btn)

func _make_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.70))
	lbl.add_theme_font_size_override("font_size", 14)
	return lbl

func _make_btn(text: String, bg: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", s)
	var sp = s.duplicate()
	sp.bg_color = bg.lightened(0.2)
	btn.add_theme_stylebox_override("hover", sp)
	btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	return btn

func _get_status_text() -> String:
	return "HP: %d/%d  |  金: %d  |  层: %d" % [
		GameState.hp, GameState.max_hp,
		GameState.gold, GameState.current_layer]

func _on_return_to_menu() -> void:
	get_tree().paused = false
	_visible = false
	visible  = false
	TransitionManager.change_scene("res://scenes/MainMenu.tscn")
