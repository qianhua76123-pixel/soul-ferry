extends Control

## CardUINode.gd - 单张牌卡 UI 节点
## 像素化/民俗剪纸风占位符渲染，_draw() 直接绘制卡面
## 支持点击出牌、悬停预览、灰显不可用状态


signal card_clicked(card_data: Dictionary)

# ========== 卡牌尺寸 ==========
const CARD_W = 90.0
const CARD_H = 130.0
const CORNER_R = 6.0

# ========== 颜色主题 ==========
# 稀有度边框色
const RARITY_COLORS = {
	"common":   Color(0.55, 0.52, 0.47),   # 灰边
	"rare":     Color(0.85, 0.72, 0.0),    # 金边
	"legendary": Color(0.85, 0.12, 0.12),  # 红边
}
const BG_COLOR    = Color(0.08, 0.06, 0.05)    # 卡面底色（近黑）
const TEXT_COLOR  = Color(0.92, 0.88, 0.80)    # 主文字色
const COST_BG     = Color(0.15, 0.12, 0.10)    # 费用圆底色
const HOVER_TINT  = Color(1.1, 1.1, 1.0)       # 悬停高亮

# ========== 数据 ==========
var card_data: Dictionary = {}
var is_playable: bool = true
var _hovered: bool = false
var _hover_offset: float = 0.0  # 悬停上浮量

# 预计算
var _emotion_color: Color = Color.WHITE
var _cost_text: String = "?"
var _rarity_color: Color = RARITY_COLORS["common"]

# ========== 初始化 ==========
func _ready() -> void:
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	mouse_entered.connect(func(): _hovered = true; _animate_hover(true))
	mouse_exited.connect(func(): _hovered = false; _animate_hover(false))

func setup(data: Dictionary) -> void:
	card_data = data
	var emotion = data.get("emotion_tag", "calm")
	_emotion_color = EmotionManager.get_emotion_color(emotion)
	var cost = data.get("cost", 0) - EmotionManager.get_cost_reduction()
	_cost_text = str(max(0, cost))
	_rarity_color = RARITY_COLORS.get(data.get("rarity", "common"), RARITY_COLORS["common"])
	queue_redraw()

func set_playable(playable: bool) -> void:
	is_playable = playable
	modulate = Color.WHITE if playable else Color(0.45, 0.45, 0.45, 0.75)

# ========== 绘制 ==========
func _draw() -> void:
	var offset = Vector2(0, -_hover_offset)

	# 1. 外框（稀有度颜色）
	draw_rect(Rect2(offset, Vector2(CARD_W, CARD_H)), _rarity_color)

	# 2. 内底色（缩进2px）
	draw_rect(Rect2(offset + Vector2(2, 2), Vector2(CARD_W - 4, CARD_H - 4)), BG_COLOR)

	# 3. 情绪色条（顶部横条，高8px）
	draw_rect(Rect2(offset + Vector2(2, 2), Vector2(CARD_W - 4, 8)), _emotion_color)

	# 4. 占位符插图区域（像素噪点风格）
	_draw_pixel_art_placeholder(offset + Vector2(2, 12), Vector2(CARD_W - 4, 55))

	# 5. 分割线
	draw_line(offset + Vector2(2, 68), offset + Vector2(CARD_W - 2, 68), _rarity_color, 1.0)

	# 6. 牌名（居中）
	var name_text = card_data.get("name", "???")
	draw_string(
		ThemeDB.fallback_font,
		offset + Vector2(CARD_W / 2.0 - 28, 82),
		name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_COLOR
	)

	# 7. 效果描述（小字，换行显示）
	_draw_desc_text(offset + Vector2(4, 94))

	# 8. 费用圆（左上角）
	draw_circle(offset + Vector2(14, 14), 11.0, COST_BG)
	draw_arc(offset + Vector2(14, 14), 11.0, 0, TAU, 32, _rarity_color, 1.5)
	draw_string(
		ThemeDB.fallback_font,
		offset + Vector2(10, 19),
		_cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT_COLOR
	)

	# 9. 情绪标签（右下角小图标）
	_draw_emotion_symbol(offset + Vector2(CARD_W - 18, CARD_H - 18))

## 像素化占位符插图：根据情绪绘制简单图形
func _draw_pixel_art_placeholder(pos: Vector2, size: Vector2) -> void:
	var emotion = card_data.get("emotion_tag", "calm")
	var bg = _emotion_color
	bg.a = 0.15
	draw_rect(Rect2(pos, size), bg)

	# 像素风格简图（8×8 格子内的抽象符号）
	var cx = pos.x + size.x / 2.0
	var cy = pos.y + size.y / 2.0
	var c = _emotion_color
	c.a = 0.7

	match emotion:
		"rage":   # 火焰形：三角形叠加
			var tri1 = PackedVector2Array([
				Vector2(cx, cy - 18), Vector2(cx - 14, cy + 14), Vector2(cx + 14, cy + 14)
			])
			draw_colored_polygon(tri1, c)
			c.a = 0.4
			var tri2 = PackedVector2Array([
				Vector2(cx, cy - 8), Vector2(cx - 8, cy + 10), Vector2(cx + 8, cy + 10)
			])
			draw_colored_polygon(tri2, Color(1.0, 0.6, 0.2, 0.8))

		"fear":   # 眼睛形：椭圆+瞳孔
			draw_arc(Vector2(cx, cy), 16.0, 0, TAU, 32, c, 2.0)
			draw_circle(Vector2(cx, cy), 7.0, c)
			draw_circle(Vector2(cx + 2, cy - 2), 3.0, Color.BLACK)

		"grief":  # 水滴形：圆+尖角
			draw_circle(Vector2(cx, cy + 4), 12.0, c)
			var drop = PackedVector2Array([
				Vector2(cx, cy - 18), Vector2(cx - 8, cy), Vector2(cx + 8, cy)
			])
			draw_colored_polygon(drop, c)

		"joy":    # 圆形光晕：同心圆
			for r in [18, 13, 8]:
				var cc = c
				cc.a = float(r) / 20.0
				draw_arc(Vector2(cx, cy), float(r), 0, TAU, 32, cc, 2.5)
			draw_circle(Vector2(cx, cy), 5.0, c)

		"calm":   # 八卦/印章：方形+内圆
			draw_rect(Rect2(cx - 14, cy - 14, 28, 28), c, false, 2.0)
			draw_circle(Vector2(cx, cy), 8.0, c, false, 2.0)
			draw_line(Vector2(cx - 14, cy), Vector2(cx + 14, cy), c, 1.5)
			draw_line(Vector2(cx, cy - 14), Vector2(cx, cy + 14), c, 1.5)

## 描述文字（最多2行，超出省略）
func _draw_desc_text(pos: Vector2) -> void:
	var desc = card_data.get("description", "")
	if desc.length() > 22:
		desc = desc.substr(0, 20) + "…"
	draw_string(
		ThemeDB.fallback_font,
		pos, desc, HORIZONTAL_ALIGNMENT_LEFT, int(CARD_W - 6), 10,
		Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 0.75)
	)

## 情绪标签小图标（右下角）
func _draw_emotion_symbol(pos: Vector2) -> void:
	var c = _emotion_color
	c.a = 0.85
	draw_circle(pos, 7.0, c)
	var emotion_initial = EmotionManager.get_emotion_name(card_data.get("emotion_tag", "calm"))
	draw_string(
		ThemeDB.fallback_font, pos - Vector2(5, -5),
		emotion_initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK
	)

# ========== 悬停动画 ==========
func _animate_hover(hovering: bool) -> void:
	var tween = create_tween()
	tween.tween_property(self, "_hover_offset", 16.0 if hovering else 0.0, 0.15)
	tween.connect("step_finished", func(_n): queue_redraw())

# ========== 输入 ==========
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_playable:
			emit_signal("card_clicked", card_data)
			# 点击反馈：快速缩放
			var tween = create_tween()
			tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.05)
			tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
