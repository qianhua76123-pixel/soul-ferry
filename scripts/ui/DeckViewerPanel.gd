extends Control
class_name DeckViewerPanel

## 卡组查看面板
## 显示当前牌库/手牌/弃牌堆的所有卡牌，支持筛选和滚动

const CardUINodeClass = preload("res://scripts/ui/CardUINode.gd")

var _visible_panel: Panel = null
var _scroll: ScrollContainer = null
var _grid: HFlowContainer = null
var _tab_btns: Array = []
var _cur_tab: String = "deck"   # deck / hand / discard

signal closed

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 必须用 FULL_RECT 以便遮罩覆盖全屏
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	hide()

func _build_ui() -> void:
	# 半透明遮罩
	var overlay: ColorRect = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 主面板：延迟到第一次显示时用视口尺寸居中
	_visible_panel = Panel.new()
	_visible_panel.custom_minimum_size = Vector2(860, 520)
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = Color(0.07, 0.05, 0.04, 0.97)
	ps.border_width_top    = 2; ps.border_width_bottom = 2
	ps.border_width_left   = 2; ps.border_width_right  = 2
	ps.border_color = Color(0.78, 0.60, 0.10, 0.8)
	ps.set_corner_radius_all(8)
	ps.content_margin_left   = 12; ps.content_margin_right  = 12
	ps.content_margin_top    = 12; ps.content_margin_bottom = 12
	_visible_panel.add_theme_stylebox_override("panel", ps)
	add_child(_visible_panel)

	# 标题行
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_row.offset_left  = 12; title_row.offset_right = -12
	title_row.offset_top   = 12; title_row.offset_bottom = 44
	_visible_panel.add_child(title_row)

	var title_lbl: Label = Label.new()
	title_lbl.text = "牌  组  查  看"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.78, 0.60, 0.10))
	title_row.add_child(title_lbl)

	# Tab 按钮
	var tabs: Array = [["deck","牌 库"], ["hand","手 牌"], ["discard","弃 牌"]]
	for tab_data in tabs:
		var tb: Button = Button.new()
		tb.text = tab_data[1]
		tb.custom_minimum_size = Vector2(80, 28)
		tb.add_theme_font_size_override("font_size", 13)
		var tab_id: String = tab_data[0]
		tb.pressed.connect(func(): _switch_tab(tab_id))
		title_row.add_child(tb)
		_tab_btns.append(tb)

	# 关闭按钮
	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 28)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(close_panel)
	title_row.add_child(close_btn)

	# 计数标签
	var count_lbl: Label = Label.new()
	count_lbl.name = "CountLabel"
	count_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	count_lbl.offset_left = 12; count_lbl.offset_right = -12
	count_lbl.offset_top  = 48; count_lbl.offset_bottom = 68
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	_visible_panel.add_child(count_lbl)

	# 滚动区 + 流式布局
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top    = 72
	_scroll.offset_bottom = -12
	_scroll.offset_left   = 12
	_scroll.offset_right  = -12
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_visible_panel.add_child(_scroll)

	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

## 打开面板
func open_panel() -> void:
	# 用视口实际尺寸计算居中位置（兼容 CanvasLayer）
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var panel_w: float = 860.0
	var panel_h: float = 520.0
	_visible_panel.size = Vector2(panel_w, panel_h)
	_visible_panel.position = Vector2(
		(vp.x - panel_w) * 0.5,
		(vp.y - panel_h) * 0.5
	)
	show()
	_switch_tab("deck")
	set_process_unhandled_key_input(true)

## 关闭面板
func close_panel() -> void:
	hide()
	set_process_unhandled_key_input(false)
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_D:
			close_panel()
			get_viewport().set_input_as_handled()

## 切换标签页
func _switch_tab(tab: String) -> void:
	_cur_tab = tab
	_refresh_cards()

## 刷新卡牌显示
func _refresh_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()

	var cards: Array = []
	match _cur_tab:
		"deck":    cards = DeckManager.deck.duplicate()
		"hand":    cards = DeckManager.hand.duplicate()
		"discard": cards = DeckManager.discard_pile.duplicate()

	var count_lbl: Node = _visible_panel.get_node_or_null("CountLabel")
	var tab_name: String = {"deck":"牌库","hand":"手牌","discard":"弃牌堆"}.get(_cur_tab,"")
	if count_lbl:
		count_lbl.set("text", "%s  共 %d 张" % [tab_name, cards.size()])

	for cd in cards:
		var card_node: Control = Control.new()
		card_node.custom_minimum_size = Vector2(100, 155)
		card_node.set_script(CardUINodeClass)
		_grid.add_child(card_node)
		if card_node.has_method("setup"):
			card_node.setup(cd)
		if card_node.has_method("set_playable"):
			card_node.set_playable(false)   # 查看模式不可打出

	# 更新 tab 按钮高亮
	var tab_names: Array = ["deck","hand","discard"]
	for i in _tab_btns.size():
		var tb: Button = _tab_btns[i]
		if i < tab_names.size() and tab_names[i] == _cur_tab:
			tb.add_theme_color_override("font_color", Color(0.78, 0.60, 0.10))
		else:
			tb.remove_theme_color_override("font_color")
