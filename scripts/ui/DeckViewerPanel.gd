extends Control
class_name DeckViewerPanel

## DeckViewerPanel.gd - 卡组查看面板（完整版）
##
## 功能：
##   A. 全屏遮罩弹出面板（牌库 / 手牌 / 弃牌堆 三 Tab，卡牌图）
##   B. 常驻右下角迷你摘要栏（牌数 + 点击展开）
##   C. 右下角固定「📖 牌组」按钮（可由外部调用 install_fixed_btn 安装）
##   D. 键盘快捷键 [D] 切换开关

const CardUINodeClass = preload("res://scripts/ui/CardUINode.gd")

# ── 弹出面板 ────────────────────────────────────────────
var _panel:     Panel           = null
var _scroll:    ScrollContainer = null
var _grid:      HFlowContainer  = null
var _tab_btns:  Array           = []
var _cur_tab:   String          = "deck"
var _count_lbl: Label           = null

# ── 常驻迷你栏 ─────────────────────────────────────────
var _mini_bar:  Control         = null
var _mini_deck_lbl:  Label      = null
var _mini_hand_lbl:  Label      = null
var _mini_disc_lbl:  Label      = null

signal closed

# ════════════════════════════════════════════════════════
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_popup()
	_build_mini_bar()
	hide_popup()
	# 监听牌堆变化实时更新迷你栏
	DeckManager.hand_updated.connect(func(_h): _refresh_mini_bar())
	DeckManager.deck_shuffled.connect(func(): _refresh_mini_bar())
	DeckManager.card_discarded.connect(func(_c, _f): _refresh_mini_bar())

# ════════════════════════════════════════════════════════
#  弹出面板构建
# ════════════════════════════════════════════════════════
func _build_popup() -> void:
	# 遮罩（只在面板可见时拦截点击）
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	# 主面板
	_panel = Panel.new()
	_panel.name = "MainPanel"
	_panel.custom_minimum_size = Vector2(880, 540)
	_panel.visible = false
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color    = Color(0.06, 0.04, 0.03, 0.97)
	ps.border_color = Color(0.78, 0.60, 0.10, 0.85)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(8)
	ps.content_margin_left = 14; ps.content_margin_right  = 14
	ps.content_margin_top  = 14; ps.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", ps)
	add_child(_panel)

	# ── 标题行 ──────────────────────────────────────────
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_row.offset_left   = 14; title_row.offset_right  = -14
	title_row.offset_top    = 14; title_row.offset_bottom = 48
	title_row.add_theme_constant_override("separation", 8)
	_panel.add_child(title_row)

	var title_lbl: Label = Label.new()
	title_lbl.text = "📖  牌  组  查  看"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	title_row.add_child(title_lbl)

	# Tab 按钮
	var tabs: Array[Array] = [["deck","牌 库"], ["hand","手 牌"], ["discard","弃 牌"], ["exhaust","消 耗"]]
	for td: Array in tabs:
		var tb: Button = Button.new()
		tb.text = td[1]
		tb.custom_minimum_size = Vector2(72, 28)
		tb.add_theme_font_size_override("font_size", 12)
		tb.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
		tb.add_theme_stylebox_override("hover",  UIConstants.make_button_style("parch", "gold"))
		var tid: String = td[0]
		tb.pressed.connect(func(): _switch_tab(tid))
		title_row.add_child(tb)
		_tab_btns.append(tb)

	# 关闭按钮
	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 28)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", UIConstants.color_of("ash"))
	close_btn.pressed.connect(hide_popup)
	title_row.add_child(close_btn)

	# ── 副标题（张数 + 快捷键提示）───────────────────────
	_count_lbl = Label.new()
	_count_lbl.name = "CountLabel"
	_count_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_count_lbl.offset_left   = 14; _count_lbl.offset_right  = -14
	_count_lbl.offset_top    = 52; _count_lbl.offset_bottom = 72
	_count_lbl.add_theme_font_size_override("font_size", 11)
	_count_lbl.add_theme_color_override("font_color", UIConstants.color_of("ash"))
	_panel.add_child(_count_lbl)

	# ── 分隔线 ───────────────────────────────────────────
	var sep: ColorRect = ColorRect.new()
	sep.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sep.offset_left   = 14; sep.offset_right  = -14
	sep.offset_top    = 74; sep.offset_bottom = 75
	sep.color = UIConstants.color_of("gold_dim")
	sep.modulate.a = 0.5
	_panel.add_child(sep)

	# ── 卡牌滚动区 ───────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.name = "CardScroll"
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top    = 78
	_scroll.offset_bottom = -14
	_scroll.offset_left   = 14
	_scroll.offset_right  = -14
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)

	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

# ════════════════════════════════════════════════════════
#  常驻迷你摘要栏（右下角）
# ════════════════════════════════════════════════════════
func _build_mini_bar() -> void:
	_mini_bar = Control.new()
	_mini_bar.name = "MiniDeckBar"
	# 锚定右下角
	_mini_bar.anchor_left   = 1.0
	_mini_bar.anchor_top    = 1.0
	_mini_bar.anchor_right  = 1.0
	_mini_bar.anchor_bottom = 1.0
	_mini_bar.offset_left   = -170.0
	_mini_bar.offset_top    = -42.0
	_mini_bar.offset_right  = -4.0
	_mini_bar.offset_bottom = -4.0
	_mini_bar.layout_mode   = 1
	_mini_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_mini_bar)

	# 背景胶囊
	var bg: Panel = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bs: StyleBoxFlat = StyleBoxFlat.new()
	bs.bg_color    = Color(0.06, 0.04, 0.02, 0.88)
	bs.border_color = Color(UIConstants.color_of("gold_dim").r,
							UIConstants.color_of("gold_dim").g,
							UIConstants.color_of("gold_dim").b, 0.6)
	bs.set_border_width_all(1)
	bs.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", bs)
	_mini_bar.add_child(bg)

	# 内容行
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0; row.offset_right = -8.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_mini_bar.add_child(row)

	# 图标
	var icon: Label = Label.new()
	icon.text = "📖"
	icon.add_theme_font_size_override("font_size", 13)
	row.add_child(icon)

	# 牌库数
	_mini_deck_lbl = _make_mini_lbl("抽0", UIConstants.color_of("text_secondary"))
	row.add_child(_mini_deck_lbl)

	# 手牌数
	_mini_hand_lbl = _make_mini_lbl("手0", UIConstants.color_of("gold"))
	row.add_child(_mini_hand_lbl)

	# 弃牌数
	_mini_disc_lbl = _make_mini_lbl("弃0", UIConstants.color_of("ash"))
	row.add_child(_mini_disc_lbl)

	# 点击迷你栏展开面板
	var click_area: Button = Button.new()
	click_area.flat = true
	click_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_area.pressed.connect(toggle_popup)
	_mini_bar.add_child(click_area)

	_refresh_mini_bar()

func _make_mini_lbl(text: String, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _refresh_mini_bar() -> void:
	if not _mini_deck_lbl: return
	_mini_deck_lbl.text = "抽%d" % DeckManager.deck.size()
	_mini_hand_lbl.text = "手%d" % DeckManager.hand.size()
	_mini_disc_lbl.text = "弃%d" % DeckManager.discard_pile.size()

# ════════════════════════════════════════════════════════
#  公共 API
# ════════════════════════════════════════════════════════

## 安装固定「📖 牌组」按钮到指定父节点，用 anchor 定位
## battle_mode=true 时按钮放左上角 HUD 区，false 放右下角地图区
func install_fixed_btn(parent: Node, battle_mode: bool = false) -> Button:
	var btn: Button = Button.new()
	btn.name = "FixedDeckBtn"
	btn.text = "📖 牌组 [D]"
	btn.custom_minimum_size = Vector2(100, 30)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	btn.add_theme_stylebox_override("hover",  UIConstants.make_button_style("parch", "gold"))
	btn.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	btn.layout_mode = 1
	if battle_mode:
		# 战斗模式：右上角 HUD，不遮挡卡牌
		btn.anchor_left   = 1.0; btn.anchor_top    = 0.0
		btn.anchor_right  = 1.0; btn.anchor_bottom = 0.0
		btn.offset_left   = -108.0; btn.offset_right  = -4.0
		btn.offset_top    = 4.0;   btn.offset_bottom = 34.0
	else:
		# 地图模式：右上角固定
		btn.anchor_left   = 1.0; btn.anchor_top    = 0.0
		btn.anchor_right  = 1.0; btn.anchor_bottom = 0.0
		btn.offset_left   = -108.0; btn.offset_right  = -4.0
		btn.offset_top    = 4.0;   btn.offset_bottom = 34.0
	btn.pressed.connect(toggle_popup)
	parent.add_child(btn)
	return btn

func toggle_popup() -> void:
	if _panel.visible:
		hide_popup()
	else:
		show_popup()

func show_popup(tab: String = "deck") -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var pw: float = minf(880.0, vp.x - 40.0)
	var ph: float = minf(540.0, vp.y - 40.0)
	_panel.size = Vector2(pw, ph)
	_panel.position = Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	_panel.visible = true
	get_node_or_null("Overlay").visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_switch_tab(tab)
	set_process_unhandled_key_input(true)

## 兼容旧调用
func open_panel() -> void:
	show_popup()

func hide_popup() -> void:
	if _panel: _panel.visible = false
	var ov: Node = get_node_or_null("Overlay")
	if ov: ov.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_key_input(false)
	closed.emit()

func close_panel() -> void:
	hide_popup()

func is_open() -> bool:
	return _panel != null and _panel.visible

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ESCAPE, KEY_D]:
			hide_popup()
			get_viewport().set_input_as_handled()

# ════════════════════════════════════════════════════════
#  Tab 切换 & 卡牌刷新
# ════════════════════════════════════════════════════════

func _switch_tab(tab: String) -> void:
	_cur_tab = tab
	_refresh_cards()
	# 更新 tab 高亮
	var tab_ids: Array[String] = ["deck", "hand", "discard", "exhaust"]
	for i in _tab_btns.size():
		var tb: Button = _tab_btns[i]
		var active: bool = i < tab_ids.size() and tab_ids[i] == _cur_tab
		if active:
			tb.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold"))
			tb.add_theme_color_override("font_color", UIConstants.color_of("gold"))
		else:
			tb.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
			tb.remove_theme_color_override("font_color")

func _refresh_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()

	var cards: Array = []
	match _cur_tab:
		"deck":    cards = DeckManager.deck.duplicate()
		"hand":    cards = DeckManager.hand.duplicate()
		"discard": cards = DeckManager.discard_pile.duplicate()
		"exhaust": cards = DeckManager.exhaust_pile.duplicate()

	var tab_names: Dictionary = {
		"deck":"牌库（抽牌堆）",
		"hand":"当前手牌",
		"discard":"弃牌堆",
		"exhaust":"消耗堆"
	}
	if _count_lbl:
		_count_lbl.text = "%s  ·  共 %d 张   [D] 关闭" % [
			tab_names.get(_cur_tab, ""), cards.size()]

	if cards.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "（空）"
		empty_lbl.add_theme_color_override("font_color", UIConstants.color_of("ash"))
		empty_lbl.add_theme_font_size_override("font_size", 13)
		_grid.add_child(empty_lbl)
		return

	for cd: Dictionary in cards:
		var wrapper: Control = Control.new()
		wrapper.custom_minimum_size = Vector2(104, 162)
		wrapper.set_script(CardUINodeClass)
		_grid.add_child(wrapper)
		if wrapper.has_method("setup"):
			wrapper.setup(cd)
		if wrapper.has_method("set_playable"):
			wrapper.set_playable(false)
