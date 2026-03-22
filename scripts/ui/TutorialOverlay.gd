extends Control
class_name TutorialOverlay

## 新手引导覆盖层
## 第一次进入游戏时自动触发（检查 GameState.get_meta("tutorial_done", false)）

signal tutorial_finished

const PAGES: Array = [
	{
		"title": "欢迎来到渡魂录",
		"content": "你是一名[color=#c8a040]渡魂人[/color]，负责引导困于世间的魂魄离开。\n\n游戏流程：\n• [color=#c8a040]地图探索[/color] — 选择前进路线\n• [color=#c8a040]战斗[/color] — 打出卡牌，操控五情\n• [color=#c8a040]休息 / 商店[/color] — 强化自身",
		"icon": "⛩"
	},
	{
		"title": "五情系统",
		"content": "每张卡牌携带一种情绪标签：\n[color=#cc3333]怒[/color]  [color=#6633cc]惧[/color]  [color=#3366cc]悲[/color]  [color=#ccaa00]喜[/color]  [color=#33cc88]定[/color]\n\n打出卡牌会积累对应情绪值（0～5）。\n情绪越高，同类卡牌效果越强。\n\n当某情绪达到[color=#ff4444]满值（5）[/color]，轮盘端点出现脉冲特效，情绪进入溢出状态——爆发但有风险！",
		"icon": "🎭"
	},
	{
		"title": "渡化与镇压",
		"content": "击败敌人的方式有两种：\n\n[color=#ccaa00]⚔ 战斗胜利[/color] — 将敌人 HP 降至零\n[color=#33cc88]✨ 渡化[/color] — 满足特定情绪条件，引导魂魄安然离去\n\n渡化成功会获得额外奖励，是高难度核心玩法。",
		"icon": "✨"
	},
	{
		"title": "卡牌与能量",
		"content": "每回合有固定[color=#c8a040]行动点（能量）[/color]可用。\n打出卡牌需消耗对应费用。\n\n技巧：\n• 情绪值高时，对应牌费用降低\n• 某些遗物改变能量上限\n• 弃牌堆耗尽时，牌库自动重洗\n• 按 [color=#c8a040][D][/color] 键随时查看当前牌组",
		"icon": "🃏"
	},
	{
		"title": "遗物系统",
		"content": "战斗胜利或探索事件中获得[color=#c8a040]遗物[/color]。\n遗物提供持续被动效果，是强力套路的核心。\n\n[color=#888888]鼠标悬停在遗物图标上可查看效果说明。[/color]",
		"icon": "🪬"
	},
	{
		"title": "选择你的渡魂人",
		"content": "[color=#c8a040]阮如月[/color] — 庙祝，擅长渡化，情绪印记加成\n[color=#6699cc]沈铁钧[/color] — 老捕快，擅长镇压，铁链怒爆\n[color=#aaaaaa]无名[/color] — 无脸守护者，空度系统，情绪转移\n\n每位角色有独特牌池与胜利路线。\n准备好了吗？踏上旅途。",
		"icon": "🚢"
	},
]

var _cur_page: int = 0
var _panel: Panel = null
var _title_lbl: Label = null
var _content_lbl: RichTextLabel = null
var _icon_lbl: Label = null
var _progress_lbl: Label = null
var _next_btn: Button = null
var _skip_btn: Button = null
var _dot_row: HBoxContainer = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 必须同时设置全屏锚点 + grow，才能让子节点的 0.5 锚点相对于视口居中
	set_anchors_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical   = Control.GROW_DIRECTION_BOTH
	z_index = 500
	modulate.a = 0.0
	_build_ui()
	_show_page(0)
	# 淡入
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)

func _build_ui() -> void:
	# 半透明遮罩
	var overlay: ColorRect = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 主面板 —— 相对于整个视口居中
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(700, 430)
	# 使用 PRESET_CENTER 锚点后，需要同时把锚点参考从"父容器"改为视口尺寸
	# 这里直接用绝对居中：锚点全置 0.5，offset 再偏移半宽高
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left   = -350
	_panel.offset_right  =  350
	_panel.offset_top    = -215
	_panel.offset_bottom =  215
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.04, 0.03, 0.97)
	ps.border_width_top    = 2; ps.border_width_bottom = 2
	ps.border_width_left   = 2; ps.border_width_right  = 2
	ps.border_color = Color(0.78, 0.60, 0.10, 0.85)
	ps.set_corner_radius_all(10)
	ps.content_margin_left   = 30; ps.content_margin_right  = 30
	ps.content_margin_top    = 20; ps.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", ps)
	add_child(_panel)

	# 图标
	_icon_lbl = Label.new()
	_icon_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_icon_lbl.offset_top = 18; _icon_lbl.offset_bottom = 64
	_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_lbl.add_theme_font_size_override("font_size", 34)
	_panel.add_child(_icon_lbl)

	# 标题
	_title_lbl = Label.new()
	_title_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_lbl.offset_top = 68; _title_lbl.offset_bottom = 102
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 20)
	_title_lbl.add_theme_color_override("font_color", Color(0.78, 0.60, 0.10))
	_panel.add_child(_title_lbl)

	# 分割线
	var div: ColorRect = ColorRect.new()
	div.set_anchors_preset(Control.PRESET_TOP_WIDE)
	div.offset_left = 30; div.offset_right = -30
	div.offset_top = 108; div.offset_bottom = 110
	div.color = Color(0.78, 0.60, 0.10, 0.35)
	_panel.add_child(div)

	# 内容
	_content_lbl = RichTextLabel.new()
	_content_lbl.bbcode_enabled = true
	_content_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_content_lbl.offset_top    = 116
	_content_lbl.offset_bottom = 320
	_content_lbl.offset_left   = 20
	_content_lbl.offset_right  = -20
	_content_lbl.add_theme_font_size_override("normal_font_size", 15)
	_content_lbl.add_theme_color_override("default_color", Color(0.88, 0.84, 0.76))
	_panel.add_child(_content_lbl)

	# 进度圆点行
	_dot_row = HBoxContainer.new()
	_dot_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dot_row.offset_top = -60; _dot_row.offset_bottom = -38
	_dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dot_row.add_theme_constant_override("separation", 8)
	_panel.add_child(_dot_row)

	# 跳过按钮
	_skip_btn = Button.new()
	_skip_btn.text = "跳过引导"
	_skip_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_skip_btn.offset_left = 16; _skip_btn.offset_right = 120
	_skip_btn.offset_top  = -34; _skip_btn.offset_bottom = -6
	_skip_btn.flat = true
	_skip_btn.add_theme_font_size_override("font_size", 12)
	_skip_btn.add_theme_color_override("font_color", Color(0.5,0.45,0.38))
	_skip_btn.pressed.connect(_finish)
	_panel.add_child(_skip_btn)

	# 下一页/完成按钮
	_next_btn = Button.new()
	_next_btn.text = "下一页  →"
	_next_btn.custom_minimum_size = Vector2(140, 36)
	_next_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_next_btn.offset_left  = -156; _next_btn.offset_right  = -16
	_next_btn.offset_top   = -42;  _next_btn.offset_bottom = -6
	var btn_ps: StyleBoxFlat = StyleBoxFlat.new()
	btn_ps.bg_color = Color(0.14, 0.10, 0.06, 0.95)
	btn_ps.border_width_top    = 1; btn_ps.border_width_bottom = 1
	btn_ps.border_width_left   = 1; btn_ps.border_width_right  = 1
	btn_ps.border_color = Color(0.78, 0.60, 0.10, 0.8)
	btn_ps.set_corner_radius_all(5)
	_next_btn.add_theme_stylebox_override("normal", btn_ps)
	_next_btn.add_theme_font_size_override("font_size", 14)
	_next_btn.add_theme_color_override("font_color", Color(0.78, 0.60, 0.10))
	_next_btn.pressed.connect(_next_page)
	_panel.add_child(_next_btn)

func _show_page(idx: int) -> void:
	_cur_page = idx
	var page: Dictionary = PAGES[idx]
	_icon_lbl.text = page.get("icon", "")
	_title_lbl.text = page.get("title", "")
	_content_lbl.text = page.get("content", "")

	# 更新进度圆点
	for child: Node in _dot_row.get_children():
		child.queue_free()
	for i: int in PAGES.size():
		var dot: ColorRect = ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8) if i != idx else Vector2(20, 8)
		dot.color = Color(0.78,0.60,0.10,0.9) if i == idx else Color(0.4,0.35,0.25,0.5)
		_dot_row.add_child(dot)

	if idx >= PAGES.size() - 1:
		_next_btn.text = "确认，出发！"
	else:
		_next_btn.text = "下一页  →"

	# 内容淡入
	_content_lbl.modulate.a = 0.0
	_title_lbl.modulate.a   = 0.0
	_icon_lbl.modulate.a    = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_content_lbl, "modulate:a", 1.0, 0.25)
	tw.tween_property(_title_lbl,   "modulate:a", 1.0, 0.20)
	tw.tween_property(_icon_lbl,    "modulate:a", 1.0, 0.18)

func _next_page() -> void:
	if _cur_page >= PAGES.size() - 1:
		_finish()
	else:
		_show_page(_cur_page + 1)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE, KEY_ENTER: _next_page()
			KEY_ESCAPE:           _finish()
		get_viewport().set_input_as_handled()

func _finish() -> void:
	GameState.set_meta("tutorial_done", true)
	tutorial_finished.emit()
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
