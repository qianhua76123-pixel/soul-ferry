extends CanvasLayer

## PauseMenu.gd - 全局暂停菜单（ESC 键呼出）
## 三个标签页：设置 / 成就 / 统计
## 战斗中暂停会保留战斗状态

const PAUSE_LAYER = 64
const UIC = preload("res://scripts/ui/UIConstants.gd")

var _visible_state: bool = false
var _panel:       Control = null
var _bgm_slider:  HSlider = null
var _sfx_slider:  HSlider = null

# 标签页
var _cur_tab:    String  = "settings"   # settings / achievements / stats
var _tab_bar:    HBoxContainer = null
var _page_stack: Control = null   # 当前显示的页 Control

func _ready() -> void:
	layer = PAUSE_LAYER
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
	_visible_state = !_visible_state
	visible = _visible_state
	get_tree().paused = _visible_state
	if _visible_state:
		if _bgm_slider: _bgm_slider.value = SoundManager.bgm_volume * 100.0
		if _sfx_slider: _sfx_slider.value = SoundManager.sfx_volume * 100.0
		_switch_tab(_cur_tab)  # 刷新数据

# ════════════════════════════════════════════════════════
#  UI 构建
# ════════════════════════════════════════════════════════

func _build_ui() -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = UIC.color_of("overlay_dim")
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(460, 500)
	_panel.add_theme_stylebox_override("panel", UIC.make_panel_style())
	add_child(_panel)

	# 面板居中（CanvasLayer 用绝对坐标）
	var vp: Vector2 = Vector2(1280, 720)   # 设计分辨率，_ready之后在toggle()里用实际值
	_panel.position = Vector2((vp.x - 460) * 0.5, (vp.y - 500) * 0.5)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.offset_left = 0; root_vbox.offset_right = 0
	root_vbox.offset_top = 0; root_vbox.offset_bottom = 0
	root_vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(root_vbox)

	# ── 顶部标题栏 ─────────────────────────────────────
	var title_bar: HBoxContainer = HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 48)
	title_bar.add_theme_constant_override("separation", 0)
	root_vbox.add_child(title_bar)

	var title_lbl: Label = Label.new()
	title_lbl.text = "  ⚙  暂停"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", UIC.color_of("gold"))
	title_bar.add_child(title_lbl)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.add_theme_color_override("font_color", UIC.color_of("ash"))
	close_btn.pressed.connect(func(): toggle())
	title_bar.add_child(close_btn)

	# ── Tab 选项卡 ─────────────────────────────────────
	_tab_bar = HBoxContainer.new()
	_tab_bar.custom_minimum_size = Vector2(0, 36)
	_tab_bar.add_theme_constant_override("separation", 2)
	root_vbox.add_child(_tab_bar)

	var sep_top: ColorRect = ColorRect.new()
	sep_top.custom_minimum_size = Vector2(0, 1)
	sep_top.color = UIC.color_of("gold_dim")
	root_vbox.add_child(sep_top)

	# ── 内容区（MarginContainer 包一层 padding）────────
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left",  20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_top",   16)
	content_margin.add_theme_constant_override("margin_bottom",14)
	root_vbox.add_child(content_margin)

	_page_stack = Control.new()
	_page_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(_page_stack)

	# ── 底部按钮 ───────────────────────────────────────
	var sep_bot: ColorRect = ColorRect.new()
	sep_bot.custom_minimum_size = Vector2(0, 1)
	sep_bot.color = UIC.color_of("gold_dim")
	root_vbox.add_child(sep_bot)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.custom_minimum_size = Vector2(0, 52)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	root_vbox.add_child(btn_row)

	var continue_btn: Button = _make_btn("▶ 继续游戏", "gold_dim")
	continue_btn.custom_minimum_size = Vector2(160, 38)
	continue_btn.pressed.connect(func(): toggle())
	btn_row.add_child(continue_btn)

	var menu_btn: Button = _make_btn("⏎ 返回主菜单", "nu")
	menu_btn.custom_minimum_size = Vector2(160, 38)
	menu_btn.pressed.connect(_on_return_to_menu)
	btn_row.add_child(menu_btn)

	# 构建 Tab 按钮并激活默认页
	_build_tab_btn("settings",     "⚙ 设置")
	_build_tab_btn("achievements", "🏆 成就")
	_build_tab_btn("stats",        "📊 统计")
	_switch_tab("settings")

func _build_tab_btn(tab_id: String, label: String) -> void:
	var btn: Button = Button.new()
	btn.name = "Tab_" + tab_id
	btn.text = label
	btn.custom_minimum_size = Vector2(100, 34)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func(): _switch_tab(tab_id))
	_tab_bar.add_child(btn)

func _switch_tab(tab_id: String) -> void:
	_cur_tab = tab_id
	# 高亮激活 tab
	var tab_ids: Array[String] = ["settings", "achievements", "stats"]
	for i in tab_ids.size():
		var tb: Button = _tab_bar.get_node_or_null("Tab_" + tab_ids[i])
		if not tb: continue
		if tab_ids[i] == tab_id:
			tb.add_theme_stylebox_override("normal", UIC.make_button_style("parch", "gold"))
			tb.add_theme_color_override("font_color", UIC.color_of("gold"))
		else:
			tb.add_theme_stylebox_override("normal", UIC.make_button_style("parch", "gold_dim"))
			tb.remove_theme_color_override("font_color")
	# 重建内容区
	for ch in _page_stack.get_children():
		ch.queue_free()
	await get_tree().process_frame
	match tab_id:
		"settings":     _build_settings_page()
		"achievements": _build_achievements_page()
		"stats":        _build_stats_page()

# ── 面板居中（toggle 调用时用实际 viewport 尺寸）─────
func _reposition_panel() -> void:
	if not _panel: return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = Vector2((vp.x - 460.0) * 0.5, (vp.y - 500.0) * 0.5)

# ════════════════════════════════════════════════════════
#  Page: 设置
# ════════════════════════════════════════════════════════

func _build_settings_page() -> void:
	_reposition_panel()
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	_page_stack.add_child(vbox)

	vbox.add_child(_make_label("🎵 背景音乐"))
	_bgm_slider = HSlider.new()
	_bgm_slider.min_value = 0; _bgm_slider.max_value = 100; _bgm_slider.step = 1
	_bgm_slider.value = SoundManager.bgm_volume * 100.0
	_bgm_slider.value_changed.connect(func(v): SoundManager.set_bgm_volume(v / 100.0))
	vbox.add_child(_bgm_slider)

	vbox.add_child(_make_label("🔊 音效音量"))
	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0; _sfx_slider.max_value = 100; _sfx_slider.step = 1
	_sfx_slider.value = SoundManager.sfx_volume * 100.0
	_sfx_slider.value_changed.connect(func(v): SoundManager.set_sfx_volume(v / 100.0))
	vbox.add_child(_sfx_slider)

	var sep: ColorRect = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = UIC.color_of("gold_dim")
	sep.modulate.a = 0.4
	vbox.add_child(sep)

	# 当前局状态
	var info: Label = Label.new()
	info.name = "InfoLabel"
	info.text = "❤ %d / %d   |   🪙 %d   |   第 %d 层" % [
		GameState.hp, GameState.max_hp, GameState.gold, GameState.current_layer]
	info.add_theme_color_override("font_color", UIC.color_of("text_secondary"))
	info.add_theme_font_size_override("font_size", UIC.font_size_of("body"))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	# 遗物
	var relics: Array = RelicManager.get_owned_relics()
	if relics.size() > 0:
		var relic_lbl: Label = Label.new()
		relic_lbl.text = "遗物：" + "  ".join(relics.map(func(r): return r.get("icon","?")))
		relic_lbl.add_theme_color_override("font_color", UIC.color_of("gold_dim"))
		relic_lbl.add_theme_font_size_override("font_size", UIC.font_size_of("body"))
		relic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		relic_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(relic_lbl)

# ════════════════════════════════════════════════════════
#  Page: 成就
# ════════════════════════════════════════════════════════

func _build_achievements_page() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_stack.add_child(scroll)

	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var ach_ids: Array = AchievementManager.ACHIEVEMENTS.keys()
	var unlocked_count: int = 0
	for ach_id: String in ach_ids:
		var info: Dictionary = AchievementManager.ACHIEVEMENTS[ach_id]
		var is_unlocked: bool = AchievementManager.stats["achievements"].has(ach_id)
		if is_unlocked: unlocked_count += 1

		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 38)
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)

		# 图标
		var icon_lbl: Label = Label.new()
		icon_lbl.text = info.get("icon","🏆") if is_unlocked else "▪"
		icon_lbl.custom_minimum_size = Vector2(28, 0)
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(icon_lbl)

		# 名称 + 描述
		var text_col: VBoxContainer = VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)

		var name_lbl: Label = Label.new()
		name_lbl.text = info.get("name", ach_id)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color",
			UIC.color_of("gold") if is_unlocked else UIC.color_of("ash"))
		text_col.add_child(name_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = info.get("desc","") if is_unlocked else "???"
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", UIC.color_of("text_secondary"))
		text_col.add_child(desc_lbl)

		# 解锁标记
		var badge: Label = Label.new()
		badge.text = "✔" if is_unlocked else "○"
		badge.add_theme_color_override("font_color",
			Color(0.5, 0.9, 0.4) if is_unlocked else UIC.color_of("gold_dim"))
		badge.add_theme_font_size_override("font_size", 14)
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(badge)

	# 进度摘要（顶部插入）
	var summary: Label = Label.new()
	summary.text = "🏆 已解锁 %d / %d" % [unlocked_count, ach_ids.size()]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 13)
	summary.add_theme_color_override("font_color", UIC.color_of("gold"))
	list.move_child(summary, 0)   # 但 summary 是 add_child 的，直接插到顶
	list.add_child(summary)
	list.move_child(summary, 0)

# ════════════════════════════════════════════════════════
#  Page: 统计
# ════════════════════════════════════════════════════════

func _build_stats_page() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_stack.add_child(scroll)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var s: Dictionary = AchievementManager.stats
	var stat_rows: Array[Array] = [
		["总游玩局数",    str(int(s.get("total_runs", 0)))],
		["累计渡化次数",  str(int(s.get("total_du_hua", 0)))],
		["累计镇压次数",  str(int(s.get("total_zhen_ya", 0)))],
		["通关次数",      str(int(s.get("total_victories", 0)))],
		["失败次数",      str(int(s.get("total_defeats", 0)))],
		["最高到达层数",  str(int(s.get("best_layer_reached", 0)))],
		["历史最高剩余HP",str(str(int(s.get("best_hp_remaining", 0))))],
		["累计出牌数",    str(int(s.get("total_cards_played", 0)))],
		["累计获得金币",  str(int(s.get("total_gold_earned", 0)))],
	]
	for row: Array in stat_rows:
		var key_lbl: Label = Label.new()
		key_lbl.text = str(row[0])
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", UIC.color_of("text_secondary"))
		grid.add_child(key_lbl)

		var val_lbl: Label = Label.new()
		val_lbl.text = str(row[1])
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", UIC.color_of("gold"))
		grid.add_child(val_lbl)

# ════════════════════════════════════════════════════════
#  工具
# ════════════════════════════════════════════════════════

func _make_label(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", UIC.color_of("text_secondary"))
	lbl.add_theme_font_size_override("font_size", UIC.font_size_of("body"))
	return lbl

func _make_btn(text: String, border_key: String = "gold_dim") -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.add_theme_stylebox_override("normal", UIC.make_button_style("parch", border_key))
	btn.add_theme_stylebox_override("hover",  UIC.make_button_style("parch", "gold"))
	btn.add_theme_color_override("font_color", UIC.color_of("text_primary"))
	btn.add_theme_font_size_override("font_size", UIC.font_size_of("body"))
	return btn

func _on_return_to_menu() -> void:
	get_tree().paused = false
	_visible_state = false
	visible = false
	TransitionManager.change_scene("res://scenes/MainMenu.tscn")
