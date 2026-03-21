extends Control

class_name CardUINode

## CardUINode.gd - 牌卡UI（_draw渲染，像素民俗风占位符）

signal card_clicked(card_data: Dictionary)

const CARD_W = 120.0   # 1920x1080 下加大卡牌
const CARD_H = 180.0

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
	var cost: int = data.get("cost", 0) - EmotionManager.get_cost_reduction()
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
	draw_rect(Rect2(ofs + Vector2(2,2), Vector2(CARD_W-4, 10)), _emotion_color)
	# 占位插图（插图区高度 = CARD_H * 0.40）
	var art_h: float = CARD_H * 0.40
	_draw_placeholder(ofs + Vector2(2, 14), Vector2(CARD_W-4, art_h))
	# 分割线
	var div_y: float = 14.0 + art_h + 4.0
	draw_line(ofs+Vector2(2, div_y), ofs+Vector2(CARD_W-2, div_y), _rarity_color, 1.2)
	# 牌名
	var name_y: float = div_y + 14.0
	var name: String = card_data.get("name","???")
	var tc := UIConstants.color_of("text_primary")
	draw_string(ThemeDB.fallback_font, ofs+Vector2(5, name_y), name,
		HORIZONTAL_ALIGNMENT_LEFT, int(CARD_W-10), 13, tc)
	# 描述（去除 BBCode 标签，多行换行显示）
	var raw_desc: String = card_data.get("desc", card_data.get("description",""))
	var desc: String = raw_desc.replace("[color=#f0c040]","").replace("[/color]","") \
		.replace("[b]","").replace("[/b]","") \
		.replace("[i]","").replace("[/i]","")
	var muted := UIConstants.color_of("text_muted")
	draw_multiline_string(ThemeDB.fallback_font, ofs+Vector2(5, name_y+16), desc,
		HORIZONTAL_ALIGNMENT_LEFT, int(CARD_W-10), 10, 3, muted)
	# 费用圆（左上角）
	var ink := UIConstants.color_of("ink")
	draw_circle(ofs+Vector2(16, 16), 13.0, Color(ink.r * 1.2, ink.g * 1.2, ink.b * 1.2))
	draw_arc(ofs+Vector2(16, 16), 13.0, 0, TAU, 32, _rarity_color, 1.8)
	draw_string(ThemeDB.fallback_font, ofs+Vector2(10, 21), _cost_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tc)
	# 情绪图标（右下角）
	var c: Color = _emotion_color; c.a = 0.85
	draw_circle(ofs+Vector2(CARD_W-16, CARD_H-16), 10.0, c)
	draw_string(ThemeDB.fallback_font, ofs+Vector2(CARD_W-22, CARD_H-10),
		EmotionManager.get_emotion_name(card_data.get("emotion_tag","calm")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)

func _draw_placeholder(pos: Vector2, size: Vector2) -> void:
	# 底色
	var bg: Color = _emotion_color; bg.a = 0.08
	draw_rect(Rect2(pos, size), bg)
	var cx: float = pos.x + size.x / 2.0
	var cy: float = pos.y + size.y / 2.0
	var c  = _emotion_color
	var cd = Color(c.r * 0.6, c.g * 0.6, c.b * 0.6, 0.9)  # 暗色
	var cl = Color(min(c.r+0.3,1.0), min(c.g+0.3,1.0), min(c.b+0.3,1.0), 0.5) # 亮色

	match card_data.get("emotion_tag", "calm"):

		"rage":
			# 烈焰：三层火舌+中心爆点
			var flame_c: Array = [
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
				var ex: float = cx + cos(ang) * 14
				var ey: float = cy + sin(ang) * 11
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
				var a: float = i * PI / 4.0
				var inner = 6.0; var outer = 20.0
				draw_line(
					Vector2(cx + cos(a) * inner, cy + sin(a) * inner),
					Vector2(cx + cos(a) * outer, cy + sin(a) * outer),
					Color(0.98, 0.88, 0.20, 0.6 - i * 0.02), 1.5)
			# 花瓣（4片）
			for i in 4:
				var a_2: float = i * PI / 2.0 + PI/4.0
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
				var a_2_2: float = i * PI / 4.0
				draw_line(
					Vector2(cx + cos(a_2_2) * 10, cy + sin(a_2_2) * 10),
					Vector2(cx + cos(a_2_2) * 19, cy + sin(a_2_2) * 19),
					Color(c.r, c.g, c.b, 0.5), 1.0)
			# 八卦爻（外圈）
			for i in range(8):
				var a_2_2_2: float = i * PI / 4.0
				var bx: float = cx + cos(a_2_2_2) * 13
				var by: float = cy + sin(a_2_2_2) * 13
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

## 悬浮进入动画：上移 + 放大 + 亮度提升
func _animate_hover(on: bool) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	# 上浮偏移
	tween.tween_method(func(v: float):
		_hover_offset = v
		queue_redraw()
		, _hover_offset, 18.0 if on else 0.0, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 放大
	tween.tween_property(self, "scale",
		Vector2(1.08, 1.08) if on else Vector2(1.0, 1.0), 0.14) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# 发光（亮度提升）
	tween.tween_property(self, "modulate",
		Color(1.15, 1.12, 1.05, 1.0) if on else Color.WHITE, 0.14)

## 出牌飞出动画：飞向祭坛中央，淡出消失
func play_card_animation(target_global_pos: Vector2) -> void:
	var start_pos: Vector2 = global_position
	var tween: Tween = create_tween().set_parallel(true)
	# 飞向目标（全局坐标转换）
	var delta: Vector2 = target_global_pos - start_pos
	tween.tween_property(self, "position", position + delta * 0.85, 0.22) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	# 同时缩小
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.22) \
		.set_ease(Tween.EASE_IN)
	# 淡出
	tween.tween_property(self, "modulate:a", 0.0, 0.20) \
		.set_ease(Tween.EASE_IN)
	# 动画结束后销毁
	tween.chain().tween_callback(queue_free)

## 抽入动画（由外部调用，传入起始偏移）
func play_draw_animation(from_offset: Vector2) -> void:
	var orig_pos: Vector2 = position
	position = orig_pos + from_offset
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", orig_pos, 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_playable:
			card_clicked.emit(card_data)
			# 点击弹跳反馈
			var tween: Tween = create_tween()
			tween.tween_property(self, "scale", Vector2(0.88, 0.88), 0.06) \
				.set_ease(Tween.EASE_IN)
			tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.10) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
