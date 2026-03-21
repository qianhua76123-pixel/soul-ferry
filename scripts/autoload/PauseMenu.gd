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
	# 暂停时自身仍需运行（处理输入和动画）
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
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
	var overlay: ColorRect = ColorRect.new()
	overlay.color = UIConstants.color_of("overlay_dim")
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 主面板
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(340, 380)
	_panel.position = Vector2(-170, -190)

	_panel.add_theme_stylebox_override("panel", UIConstants.make_panel_style())
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 14)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",  24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top",   20)
	margin.add_theme_constant_override("margin_bottom",20)
	margin.add_child(vbox)
	_panel.add_child(margin)

	# 标题
	var title: Label = Label.new()
	title.text = "— 暂停 —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	title.add_theme_font_size_override("font_size", UIConstants.font_size_of("heading"))
	vbox.add_child(title)

	var div: WaterInkDivider = WaterInkDivider.new()
	div.custom_minimum_size = Vector2(280, 8)
	div.ink_color = UIConstants.color_of("gold_dim")
	vbox.add_child(div)

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

	var div_mid: WaterInkDivider = WaterInkDivider.new()
	div_mid.custom_minimum_size = Vector2(280, 8)
	div_mid.ink_color = UIConstants.color_of("gold_dim")
	vbox.add_child(div_mid)

	# 当前状态信息
	var info: Label = Label.new()
	info.name = "InfoLabel"
	info.text = _get_status_text()
	info.add_theme_color_override("font_color", UIConstants.color_of("text_dim"))
	info.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	var div2: WaterInkDivider = WaterInkDivider.new()
	div2.custom_minimum_size = Vector2(280, 8)
	div2.ink_color = UIConstants.color_of("gold_dim")
	vbox.add_child(div2)

	# 按钮区
	var continue_btn: Button = _make_btn("继续游戏")
	continue_btn.pressed.connect(func(): toggle())
	vbox.add_child(continue_btn)

	var menu_btn: Button = _make_btn("返回主菜单")
	menu_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "nu"))
	menu_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	menu_btn.pressed.connect(_on_return_to_menu)
	vbox.add_child(menu_btn)

func _make_label(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", UIConstants.color_of("text_secondary"))
	lbl.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))
	return lbl

func _make_btn(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	btn.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	btn.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))
	return btn

func _get_status_text() -> String:
	return "%s %d/%d  |  %s %d  |  层: %d" % [
		UIConstants.ICONS["hp"], GameState.hp, GameState.max_hp,
		UIConstants.ICONS["coin"], GameState.gold,
		GameState.current_layer]

func _on_return_to_menu() -> void:
	get_tree().paused = false
	_visible = false
	visible  = false
	TransitionManager.change_scene("res://scenes/MainMenu.tscn")
