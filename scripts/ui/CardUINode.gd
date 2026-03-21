extends Control

class_name CardUINode

## CardUINode.gd - 牌卡UI（_draw渲染，像素民俗风占位符）

signal card_clicked(card_data: Dictionary)

const CARD_W = 90.0
const CARD_H = 130.0

var card_data: Dictionary = {}
var is_playable: bool = true
var _emotion_color: Color = Color.WHITE
var _cost_text: String = "?"
var _rarity_color: Color = UIConstants.color_of("card_border_common")
var _hover_offset: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	mouse_entered.connect(func(): _animate_hover(true))
	mouse_exited.connect(func():  _animate_hover(false))

func setup(data: Dictionary) -> void:
	card_data = data
	_emotion_color = EmotionManager.get_emotion_color(data.get("emotion_tag", "calm"))
	var cost = data.get("cost", 0) - EmotionManager.get_cost_reduction()
	_cost_text = str(max(0, cost))
	_rarity_color = _rarity_border_color(data.get("rarity", "common"))
	queue_redraw()

func _rarity_border_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return UIConstants.color_of("card_border_rare")
		"legendary":
			return UIConstants.color_of("card_border_legendary")
		_:
			return UIConstants.color_of("card_border_common")

func set_playable(playable: bool) -> void:
	is_playable = playable
	if playable:
		modulate = Color.WHITE
	else:
		var a := UIConstants.color_of("ash")
		modulate = Color(a.r, a.g, a.b, 0.58)

func _draw() -> void:
	var ofs = Vector2(0, -_hover_offset)
	# 外框
	draw_rect(Rect2(ofs, Vector2(CARD_W, CARD_H)), _rarity_color)
	# 底色
	draw_rect(Rect2(ofs + Vector2(2,2), Vector2(CARD_W-4, CARD_H-4)), UIConstants.color_of("card_face"))
	# 情绪色条
	draw_rect(Rect2(ofs + Vector2(2,2), Vector2(CARD_W-4, 8)), _emotion_color)
	# 占位插图
	_draw_placeholder(ofs + Vector2(2,12), Vector2(CARD_W-4, 50))
	# 分割线
	draw_line(ofs+Vector2(2,63), ofs+Vector2(CARD_W-2,63), _rarity_color, 1.0)
	# 牌名
	var name: String = card_data.get("name","???")
	var tc := UIConstants.color_of("text_primary")
	draw_string(ThemeDB.fallback_font, ofs+Vector2(4,76), name,
		HORIZONTAL_ALIGNMENT_LEFT, int(CARD_W-8), 11, tc)
	# 描述
	var desc = card_data.get("desc", card_data.get("description",""))
	if desc.length() > 20: desc = desc.substr(0,18) + "…"
	draw_string(ThemeDB.fallback_font, ofs+Vector2(4,90), desc,
		HORIZONTAL_ALIGNMENT_LEFT, int(CARD_W-8), 9, UIConstants.color_of("text_muted"))
	# 费用圆
	var ink := UIConstants.color_of("ink")
	draw_circle(ofs+Vector2(14,14), 11.0, Color(ink.r * 1.2, ink.g * 1.2, ink.b * 1.2))
	draw_arc(ofs+Vector2(14,14), 11.0, 0, TAU, 32, _rarity_color, 1.5)
	draw_string(ThemeDB.fallback_font, ofs+Vector2(9,19), _cost_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tc)
	# 情绪图标
	var c = _emotion_color; c.a = 0.85
	draw_circle(ofs+Vector2(CARD_W-14, CARD_H-14), 7.0, c)
	draw_string(ThemeDB.fallback_font, ofs+Vector2(CARD_W-19, CARD_H-9),
		EmotionManager.get_emotion_name(card_data.get("emotion_tag","calm")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)

func _draw_placeholder(pos: Vector2, size: Vector2) -> void:
	# 底色
	var bg = _emotion_color; bg.a = 0.08
	draw_rect(Rect2(pos, size), bg)
	var cx = pos.x + size.x / 2.0
	var cy = pos.y + size.y / 2.0
	var c  = _emotion_color
	var cd = Color(c.r * 0.6, c.g * 0.6, c.b * 0.6, 0.9)  # 暗色
	var cl = Color(min(c.r+0.3,1.0), min(c.g+0.3,1.0), min(c.b+0.3,1.0), 0.5) # 亮色

	match card_data.get("emotion_tag", "calm"):

		"rage":
			# 烈焰：三层火舌+中心爆点
			var flame_c = [
				Color(0.95, 0.30, 0.05, 0.9),
				Color(0.98, 0.60, 0.05, 0.85),
				Color(1.00, 0.90, 0.20, 0.8),
			]
			for i in 3:
				var fw = 16.0 - i * 4.0
				var fh = 22.0 - i * 5.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx,           cy - fh),
					Vector2(cx - fw*0.4,  cy - fh*0.3),
					Vector2(cx - fw*0.6,  cy + fh*0.5),
					Vector2(cx,           cy + fh*0.2),
					Vector2(cx + fw*0.6,  cy + fh*0.5),
					Vector2(cx + fw*0.4,  cy - fh*0.3),
				]), flame_c[i])
			# 中心爆点
			draw_circle(Vector2(cx, cy + 4), 5.0, Color(1.0, 1.0, 0.6, 0.9))
			# 火星（4颗）
			for ang in [0.3, 1.2, 2.1, 4.5]:
				var sp = Vector2(cos(ang)*18, sin(ang)*12) + Vector2(cx, cy)
				draw_circle(sp, 1.5, Color(1.0, 0.7, 0.1, 0.7))
			# 底部烟灰
			draw_arc(Vector2(cx, cy + 18), 8.0, PI, TAU, 16, Color(0.3,0.1,0.05,0.4), 2.0)

		"fear":
			# 幽眼：同心圆+竖瞳+血丝
			draw_circle(Vector2(cx, cy), 18.0, Color(0.05, 0.02, 0.08, 0.9))
			draw_circle(Vector2(cx, cy), 15.0, Color(0.70, 0.68, 0.62, 0.9))  # 巩膜
			# 血丝
			for ang in [0.4, 1.8, 3.2, 4.8]:
				var ex = cx + cos(ang) * 14
				var ey = cy + sin(ang) * 11
				draw_line(Vector2(cx + cos(ang)*6, cy + sin(ang)*5),
					Vector2(ex, ey), Color(0.7, 0.1, 0.1, 0.5), 0.8)
			# 虹膜
			draw_circle(Vector2(cx, cy), 9.0, Color(0.30, 0.0, 0.50, 0.95))
			# 竖瞳
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx,     cy - 8),
				Vector2(cx - 3, cy),
				Vector2(cx,     cy + 8),
				Vector2(cx + 3, cy),
			]), Color(0.02, 0.01, 0.03, 1.0))
			# 高光
			draw_circle(Vector2(cx + 3, cy - 3), 2.5, Color(1.0, 1.0, 1.0, 0.85))
			# 外圈阴影晕
			draw_arc(Vector2(cx, cy), 18.0, 0, TAU, 32, Color(0.4, 0.0, 0.6, 0.4), 3.0)

		"grief":
			# 泪雨：水珠轮廓+下落泪滴+涟漪
			# 主泪珠
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx,      cy - 18),
				Vector2(cx - 10, cy + 2),
				Vector2(cx,      cy + 14),
				Vector2(cx + 10, cy + 2),
			]), Color(0.15, 0.40, 0.70, 0.85))
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx,      cy - 18),
				Vector2(cx - 10, cy + 2),
				Vector2(cx,      cy + 14),
				Vector2(cx + 10, cy + 2),
			]), Color(0.55, 0.75, 0.95, 0.4))
			# 涟漪（底部）
			for i in 3:
				draw_arc(Vector2(cx, cy + 18), float(4 + i*5), PI*0.2, PI*0.8,
					16, Color(0.20, 0.50, 0.80, 0.35 - i*0.1), 1.0)
			# 小泪珠（左右各一）
			draw_circle(Vector2(cx - 14, cy + 2), 4.0, Color(0.15, 0.40, 0.70, 0.6))
			draw_circle(Vector2(cx + 14, cy + 2), 3.0, Color(0.15, 0.40, 0.70, 0.5))
			# 高光
			draw_circle(Vector2(cx - 3, cy - 8), 2.5, Color(0.8, 0.9, 1.0, 0.7))

		"joy":
			# 双喜：八芒星光+旋转花瓣+中心喜字笔画
			# 光芒（8道）
			for i in 8:
				var a = i * PI / 4.0
				var inner = 6.0; var outer = 20.0
				draw_line(
					Vector2(cx + cos(a) * inner, cy + sin(a) * inner),
					Vector2(cx + cos(a) * outer, cy + sin(a) * outer),
					Color(0.98, 0.88, 0.20, 0.6 - i * 0.02), 1.5)
			# 花瓣（4片）
			for i in 4:
				var a_2 = i * PI / 2.0 + PI/4.0
				draw_circle(
					Vector2(cx + cos(a_2)*9, cy + sin(a_2)*9), 6.0,
					Color(0.95, 0.75, 0.10, 0.55))
			# 中心金圆
			draw_circle(Vector2(cx, cy), 7.0, Color(0.98, 0.88, 0.20, 0.95))
			draw_circle(Vector2(cx, cy), 4.0, Color(1.00, 0.98, 0.70, 0.9))
			# 光晕
			draw_arc(Vector2(cx, cy), 22.0, 0, TAU, 32,
				Color(0.98, 0.88, 0.20, 0.2), 4.0)

		"calm":
			# 八卦罗盘：外圆+八卦纹+中心太极
			# 外圆
			draw_arc(Vector2(cx, cy), 20.0, 0, TAU, 64, Color(c.r,c.g,c.b,0.6), 2.0)
			draw_arc(Vector2(cx, cy), 16.0, 0, TAU, 64, Color(c.r,c.g,c.b,0.35), 1.0)
			# 八方分割线
			for i in range(8):
				var a_2_2 = i * PI / 4.0
				draw_line(
					Vector2(cx + cos(a_2_2) * 10, cy + sin(a_2_2) * 10),
					Vector2(cx + cos(a_2_2) * 19, cy + sin(a_2_2) * 19),
					Color(c.r, c.g, c.b, 0.5), 1.0)
			# 八卦爻（外圈）
			for i in range(8):
				var a_2_2_2 = i * PI / 4.0
				var bx = cx + cos(a_2_2_2) * 13
				var by = cy + sin(a_2_2_2) * 13
				# 实线或虚线（阴阳）
				if i % 2 == 0:
					draw_line(Vector2(bx-3,by), Vector2(bx+3,by), Color(c.r,c.g,c.b,0.7), 1.5)
				else:
					draw_line(Vector2(bx-3,by), Vector2(bx,by),   Color(c.r,c.g,c.b,0.7), 1.5)
					draw_line(Vector2(bx,by),   Vector2(bx+3,by), Color(c.r,c.g,c.b,0.7), 1.5)
			# 太极核心（阴阳鱼简化）
			draw_circle(Vector2(cx, cy), 7.0, Color(c.r*0.4, c.g*0.4, c.b*0.4, 0.9))
			draw_arc(Vector2(cx, cy - 3), 4.0, PI, TAU, 16, Color(c.r,c.g,c.b,0.8), 8.0)
			draw_arc(Vector2(cx, cy + 3), 4.0, 0,  PI,  16, Color(c.r*0.2,c.g*0.2,c.b*0.2,0.8), 8.0)
			draw_circle(Vector2(cx, cy - 4), 1.5, Color(c.r,c.g,c.b,0.9))
			draw_circle(Vector2(cx, cy + 4), 1.5, Color(c.r*0.2,c.g*0.2,c.b*0.2,0.9))

func _animate_hover(on: bool) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(func(v: float):
		_hover_offset = v
		queue_redraw()
		, _hover_offset, 14.0 if on else 0.0, 0.12)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_playable:
			card_clicked.emit(card_data)
			var tween: Tween = create_tween()
			tween.tween_property(self,"scale",Vector2(0.9,0.9),0.05)
			tween.tween_property(self,"scale",Vector2(1.0,1.0),0.1)
