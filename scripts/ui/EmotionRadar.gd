extends Control

## EmotionRadar.gd - 五情祭坛（重设计 v2）
## 设计语言：水墨黑金，无硬框，每个情绪独立弧度进度环+汉字标注
## 去掉 BBCode 方块进度条，用 _draw() 绘制弧形进度和装饰

const EMOTIONS       = ["calm", "rage", "fear", "grief", "joy"]
const EMOTION_CN     = {"calm":"定","rage":"怒","fear":"惧","grief":"悲","joy":"喜"}
## 角度：定在正上方 -90°，顺时针排列
const EMOTION_ANGLES = {"calm":-90.0, "rage":-18.0, "fear":54.0, "grief":126.0, "joy":198.0}
const MAX_VAL        = 5
const RADAR_R        = 68.0     # 雷达最大半径
const RING_R         = 88.0     # 情绪进度弧外径
const RING_W         = 6.0      # 弧线宽度
const LABEL_R        = 110.0    # 情绪名称与数值位置半径

const EMOTION_COLORS = {
	"calm":  Color(0.114, 0.416, 0.329),   # 定·绿
	"rage":  Color(0.753, 0.224, 0.169),   # 怒·红
	"fear":  Color(0.424, 0.204, 0.514),   # 惧·紫
	"grief": Color(0.102, 0.322, 0.463),   # 悲·蓝
	"joy":   Color(0.718, 0.467, 0.051),   # 喜·金
}
const GRID_COLOR  = Color(1, 1, 1, 0.06)
const AXIS_COLOR  = Color(1, 1, 1, 0.10)
const FILL_BASE   = Color(0.16, 0.30, 0.50, 0.50)

var _label_nodes:  Dictionary = {}   # emotion → { name_lbl, val_lbl }
var _edge_rects:   Array      = []
var _warn_tween:   Tween      = null
var _pulse_timers: Dictionary = {}
var _disorder_emotions: Array = []   # 当前失调的情绪列表

@export var show_title: bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(260, 260)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_labels()
	_build_edge_vignettes()
	EmotionManager.emotion_changed.connect(_on_emotion_changed)
	EmotionManager.disorder_triggered.connect(_on_disorder_triggered)
	EmotionManager.disorder_cleared.connect(_on_disorder_cleared)
	for e in EMOTIONS:
		_pulse_timers[e] = 0.0
	set_process(true)

# ── 脉冲动画帧更新 ───────────────────────────────────
func _process(delta: float) -> void:
	var need_redraw: bool = false
	for e: String in EMOTIONS:
		var v: int = EmotionManager.values.get(e, 0)
		if v >= MAX_VAL or e in _disorder_emotions:
			_pulse_timers[e] = _pulse_timers.get(e, 0.0) + delta
			need_redraw = true
		else:
			_pulse_timers[e] = 0.0
	if need_redraw:
		queue_redraw()

# ── 标签节点构建 ─────────────────────────────────────
func _build_labels() -> void:
	for emotion in EMOTIONS:
		var name_lbl: Label = Label.new()
		name_lbl.name = "EL_name_" + emotion
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", EMOTION_COLORS[emotion])
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(name_lbl)

		var val_lbl: Label = Label.new()
		val_lbl.name = "EL_val_" + emotion
		val_lbl.add_theme_font_size_override("font_size", 10)
		val_lbl.add_theme_color_override("font_color",
			EMOTION_COLORS[emotion].lerp(Color.WHITE, 0.30))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(val_lbl)

		_label_nodes[emotion] = {"name": name_lbl, "val": val_lbl}
	_refresh_labels()

func _refresh_labels() -> void:
	var effective_size: Vector2 = size if size.x > 4 else custom_minimum_size
	var center: Vector2 = effective_size / 2.0
	for emotion in EMOTIONS:
		var nodes: Dictionary = _label_nodes.get(emotion, {})
		if nodes.is_empty(): continue
		var name_lbl: Label = nodes["name"]
		var val_lbl:  Label = nodes["val"]
		var val: int = EmotionManager.values.get(emotion, 0)
		var angle: float = deg_to_rad(EMOTION_ANGLES[emotion])
		var lpos: Vector2 = center + Vector2(cos(angle), sin(angle)) * LABEL_R
		# 名称标签
		name_lbl.text = EMOTION_CN[emotion]
		name_lbl.position = lpos + Vector2(-16.0, -22.0)
		name_lbl.custom_minimum_size = Vector2(32, 20)
		# 数值标签（细体小字）
		val_lbl.text = "%d" % val
		val_lbl.position = lpos + Vector2(-16.0, -4.0)
		val_lbl.custom_minimum_size = Vector2(32, 16)
		# 失调时名称变色闪烁（在 _draw 里已处理，标签颜色跟随）
		var base_c: Color = EMOTION_COLORS[emotion]
		var is_dis: bool = emotion in _disorder_emotions
		name_lbl.add_theme_color_override("font_color",
			Color.WHITE if is_dis else base_c)
		name_lbl.add_theme_font_size_override("font_size", 15 if val >= MAX_VAL else 14)

# ── 屏幕边缘晕染 ─────────────────────────────────────
func _build_edge_vignettes() -> void:
	var root_ui: Node = get_tree().root.find_child("UI", true, false)
	if not root_ui: root_ui = get_parent()
	for i in range(4):
		var r: ColorRect = ColorRect.new()
		r.name = "EdgeVig%d" % i
		r.color = Color(0, 0, 0, 0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.z_index = 10
		root_ui.add_child(r)
		match i:
			0: r.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE);   r.custom_minimum_size.x = 28
			1: r.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE);  r.custom_minimum_size.x = 28
			2: r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);    r.custom_minimum_size.y = 18
			3: r.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); r.custom_minimum_size.y = 18
		_edge_rects.append(r)

# ── 主绘制 ───────────────────────────────────────────
func _draw() -> void:
	var effective_size: Vector2 = size if size.x > 4 else custom_minimum_size
	var center: Vector2 = effective_size / 2.0

	# 1. 底部半透明圆形背景（无硬框，水墨风格）
	draw_circle(center, RING_R + 22.0, Color(0.04, 0.06, 0.08, 0.82))

	# 微光外环
	draw_arc(center, RING_R + 20.0, 0, TAU, 64,
		Color(UIConstants.COLORS["gold_dim"].r,
			  UIConstants.COLORS["gold_dim"].g,
			  UIConstants.COLORS["gold_dim"].b, 0.25), 1.0)

	# 2. 同心五边形网格（4层）
	for level in range(1, 5):
		var pts: PackedVector2Array = _pentagon(center, RADAR_R * float(level) / 4.0)
		pts.append(pts[0])
		var gc: Color = GRID_COLOR if level < 4 else Color(1, 1, 1, 0.12)
		draw_polyline(pts, gc, 1.0)

	# 3. 轴线
	for emotion: String in EMOTIONS:
		var angle: float = deg_to_rad(EMOTION_ANGLES[emotion])
		var val: int = EmotionManager.values.get(emotion, 0)
		var ec: Color = EMOTION_COLORS.get(emotion, Color.WHITE)
		if val >= MAX_VAL:
			draw_line(center, center + Vector2(cos(angle), sin(angle)) * RADAR_R,
				Color(ec.r, ec.g, ec.b, 0.65), 2.0)
		else:
			draw_line(center, center + Vector2(cos(angle), sin(angle)) * RADAR_R,
				AXIS_COLOR, 0.8)

	# 4. 填充多边形（根据最高情绪调色）
	var fill_pts: PackedVector2Array = PackedVector2Array()
	for emotion in EMOTIONS:
		var val: int = EmotionManager.values.get(emotion, 0)
		var ratio: float = float(val) / float(MAX_VAL)
		var angle: float = deg_to_rad(EMOTION_ANGLES[emotion])
		fill_pts.append(center + Vector2(cos(angle), sin(angle)) * RADAR_R * maxf(ratio, 0.04))
	var fill_c: Color = _fill_color()
	draw_colored_polygon(fill_pts, fill_c)
	# 填充边线
	var border_pts: PackedVector2Array = PackedVector2Array(fill_pts)
	border_pts.append(border_pts[0])
	draw_polyline(border_pts, fill_c.lightened(0.28), 1.8)

	# 5. 每个情绪的弧形进度环
	for emotion: String in EMOTIONS:
		var val: int = EmotionManager.values.get(emotion, 0)
		var ec: Color = EMOTION_COLORS.get(emotion, Color.WHITE)
		var center_angle: float = deg_to_rad(EMOTION_ANGLES[emotion])
		var arc_span: float = TAU / float(EMOTIONS.size()) * 0.72   # 每个弧占 72% 扇区

		# 底环（灰暗轨道）
		draw_arc(center, RING_R, center_angle - arc_span * 0.5,
			center_angle + arc_span * 0.5, 24,
			Color(ec.r * 0.18, ec.g * 0.18, ec.b * 0.18, 0.7), RING_W)

		# 填充弧（按情绪值比例）
		if val > 0:
			var ratio: float = float(val) / float(MAX_VAL)
			var pulse_phase: float = _pulse_timers.get(emotion, 0.0)
			var alpha: float = 1.0
			if val >= MAX_VAL:
				alpha = 0.75 + 0.25 * sin(pulse_phase * 5.0)
			var fill_end: float = center_angle - arc_span * 0.5 + arc_span * ratio
			draw_arc(center, RING_R, center_angle - arc_span * 0.5, fill_end,
				24, Color(ec.r, ec.g, ec.b, alpha), RING_W)

			# 满值时外发光
			if val >= MAX_VAL:
				var glow_a: float = 0.4 + 0.3 * sin(pulse_phase * 5.0)
				draw_arc(center, RING_R, center_angle - arc_span * 0.5,
					center_angle + arc_span * 0.5, 24,
					Color(ec.r, ec.g, ec.b, glow_a * 0.35), RING_W + 4.0)
				# 顶端亮点
				var tip_pos: Vector2 = center + Vector2(cos(center_angle + arc_span * 0.5 * (2.0 * ratio - 1.0)),
					sin(center_angle + arc_span * 0.5 * (2.0 * ratio - 1.0))) * RING_R
				draw_circle(tip_pos, 4.0 + 2.0 * sin(pulse_phase * 5.0),
					Color(ec.r, ec.g, ec.b, glow_a))

	# 6. 失调情绪：轴端绘制警告图标（⚠ 三角）
	for emotion: String in _disorder_emotions:
		var angle: float = deg_to_rad(EMOTION_ANGLES[emotion])
		var ec: Color = EMOTION_COLORS.get(emotion, Color.WHITE)
		var tip: Vector2 = center + Vector2(cos(angle), sin(angle)) * (RADAR_R + 8.0)
		var phase: float = _pulse_timers.get(emotion, 0.0)
		var w_a: float = 0.7 + 0.3 * sin(phase * 6.0)
		_draw_warn_triangle(tip, angle, ec, w_a)

	# 7. 中心点装饰（小圆 + 阴阳符号风格交叉）
	draw_circle(center, 3.5, Color(UIConstants.COLORS["gold"].r,
		UIConstants.COLORS["gold"].g, UIConstants.COLORS["gold"].b, 0.8))
	draw_circle(center, 5.5, Color(UIConstants.COLORS["gold_dim"].r,
		UIConstants.COLORS["gold_dim"].g, UIConstants.COLORS["gold_dim"].b, 0.4))

	# 8. 标题（可选）
	if show_title:
		var title_pos: Vector2 = center + Vector2(0, -(RING_R + 22.0))
		draw_string(ThemeDB.fallback_font, title_pos + Vector2(-26, 0),
			"五情祭坛", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(UIConstants.COLORS["gold_dim"].r,
				  UIConstants.COLORS["gold_dim"].g,
				  UIConstants.COLORS["gold_dim"].b, 0.9))

func _draw_warn_triangle(pos: Vector2, base_angle: float, color: Color, alpha: float) -> void:
	var size: float = 7.0
	var pts: PackedVector2Array = PackedVector2Array([
		pos + Vector2(cos(base_angle), sin(base_angle)) * size,
		pos + Vector2(cos(base_angle + 2.3), sin(base_angle + 2.3)) * size * 0.65,
		pos + Vector2(cos(base_angle - 2.3), sin(base_angle - 2.3)) * size * 0.65,
	])
	draw_colored_polygon(pts, Color(color.r, color.g, color.b, alpha * 0.7))
	pts.append(pts[0])
	draw_polyline(pts, Color(color.r, color.g, color.b, alpha), 1.5)

# ── 辅助函数 ─────────────────────────────────────────
func _pentagon(center: Vector2, r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(5):
		var a: float = deg_to_rad(EMOTION_ANGLES[EMOTIONS[i]])
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts

func _fill_color() -> Color:
	var max_v: int = 0
	for e in EMOTIONS:
		max_v = maxi(max_v, EmotionManager.values.get(e, 0))
	if max_v >= MAX_VAL: return Color(0.65, 0.05, 0.05, 0.68)
	if max_v >= 3:       return Color(0.75, 0.58, 0.10, 0.60)
	if max_v >= 2:       return Color(0.14, 0.38, 0.58, 0.60)
	return                      Color(0.14, 0.28, 0.46, 0.50)

# ── 事件响应 ─────────────────────────────────────────
func _on_emotion_changed(emotion: String, _old: int, new_val: int) -> void:
	queue_redraw()
	call_deferred("_refresh_labels")
	_update_edge_vignette(emotion, new_val)
	if new_val >= MAX_VAL:
		_play_shake()

func _on_disorder_triggered(emotion: String) -> void:
	if emotion not in _disorder_emotions:
		_disorder_emotions.append(emotion)
	queue_redraw()
	call_deferred("_refresh_labels")

func _on_disorder_cleared(emotion: String) -> void:
	_disorder_emotions.erase(emotion)
	queue_redraw()
	call_deferred("_refresh_labels")

func _update_edge_vignette(emotion: String, val: int) -> void:
	if _edge_rects.is_empty(): return
	var ec: Color = EMOTION_COLORS.get(emotion, Color.RED)
	var alpha: float = clampf(float(val - 1) / 3.0, 0.0, 0.20)
	for r: ColorRect in _edge_rects:
		r.color = Color(ec.r, ec.g, ec.b, alpha)

func _play_shake() -> void:
	if _warn_tween: _warn_tween.kill()
	var orig_x: float = position.x
	_warn_tween = create_tween()
	for i in range(4):
		_warn_tween.tween_property(self, "position:x",
			orig_x + (4.0 if i % 2 == 0 else -4.0), 0.04)
	_warn_tween.tween_property(self, "position:x", orig_x, 0.04)
