extends Control

## EmotionRadar.gd - 五情祭坛雷达图（重设计版）
## 功能：五边形雷达 + 失调预警动画 + 屏幕边缘晕染

const EMOTIONS       = ["calm", "rage", "fear", "grief", "joy"]
const EMOTION_CN     = {"calm":"定","rage":"怒","fear":"惧","grief":"悲","joy":"喜"}
const EMOTION_ANGLES = {"calm":-90.0,"rage":-18.0,"fear":54.0,"grief":126.0,"joy":198.0}
const MAX_VAL        = 4
const RADIUS         = 72.0
const GRID_COLOR     = Color(1, 1, 1, 0.07)
const BORDER_COLOR   = Color(0.55, 0.42, 0.08, 0.85)
const EMOTION_COLORS = {
	"calm":  Color(0.15, 0.68, 0.38),
	"rage":  Color(0.75, 0.22, 0.17),
	"fear":  Color(0.56, 0.27, 0.68),
	"grief": Color(0.16, 0.50, 0.73),
	"joy":   Color(0.95, 0.61, 0.07),
}

var _label_nodes: Dictionary = {}
var _edge_rects:  Array      = []
var _warn_tween:  Tween      = null
@export var show_inner_title: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	_build_labels()
	_build_edge_vignettes()
	EmotionManager.emotion_changed.connect(_on_emotion_changed)

func _build_labels() -> void:
	for emotion in EMOTIONS:
		var lbl: Label = Label.new()
		lbl.name = "EL_" + emotion
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lbl)
		_label_nodes[emotion] = lbl
	_refresh_labels()

func _build_edge_vignettes() -> void:
	# 找 BattleScene 的 UI 根节点挂晕染层
	var root_ui = get_tree().root.find_child("UI", true, false)
	if not root_ui:
		root_ui = get_parent()
	for i in range(4):
		var r = ColorRect.new()
		r.name = "EdgeVignette%d" % i
		r.color = Color(0, 0, 0, 0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.z_index = 10
		root_ui.add_child(r)
		match i:
			0: r.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE);   r.size.x = 30
			1: r.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE);  r.size.x = 30
			2: r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);    r.size.y = 20
			3: r.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); r.size.y = 20
		_edge_rects.append(r)

func _refresh_labels() -> void:
	var effective_size = size if size.x > 4 else custom_minimum_size
	var center = effective_size / 2.0
	for emotion in EMOTIONS:
		var lbl: Variant = _label_nodes.get(emotion)
		if not lbl: continue
		var val   = EmotionManager.values.get(emotion, 0)
		var angle = deg_to_rad(EMOTION_ANGLES[emotion])
		var r     = RADIUS + 22.0
		var lpos  = center + Vector2(cos(angle), sin(angle)) * r
		lbl.position = lpos - Vector2(22, 20)
		lbl.custom_minimum_size = Vector2(44, 40)
		var c = EMOTION_COLORS[emotion]
		lbl.add_theme_color_override("font_color", c)
		var bars = ""
		for b in range(MAX_VAL):
			bars += "█" if b < val else "░"
		lbl.text = "%s\n%d/4\n%s" % [EMOTION_CN[emotion], val, bars]

func _draw() -> void:
	# 布局未计算完时 size 可能为 (0,0)，用 custom_minimum_size 兜底
	var effective_size = size if size.x > 4 else custom_minimum_size
	var center = effective_size / 2.0
	# 背景面板
	var bg_rect = Rect2(center - Vector2(RADIUS + 24, RADIUS + 24),
						Vector2((RADIUS + 24) * 2, (RADIUS + 24) * 2))
	draw_rect(bg_rect, Color(0.04, 0.08, 0.12, 0.88), true)
	draw_rect(bg_rect, BORDER_COLOR, false, 1.5)
	# 同心五边形网格（4层）
	for level in range(1, 5):
		var pts: Array = _get_pentagon(center, RADIUS * float(level) / 4.0)
		pts.append(pts[0])
		draw_polyline(PackedVector2Array(pts), GRID_COLOR, 1.0)
	# 轴线
	for emotion in EMOTIONS:
		var angle = deg_to_rad(EMOTION_ANGLES[emotion])
		draw_line(center, center + Vector2(cos(angle), sin(angle)) * RADIUS, GRID_COLOR, 0.8)
	# 填充多边形
	var fill_pts: PackedVector2Array = PackedVector2Array()
	for emotion in EMOTIONS:
		var val   = EmotionManager.values.get(emotion, 0)
		var ratio: float = float(val) / float(MAX_VAL)
		var angle_2 = deg_to_rad(EMOTION_ANGLES[emotion])
		fill_pts.append(center + Vector2(cos(angle_2), sin(angle_2)) * RADIUS * max(ratio, 0.04))
	var fill_color = _get_fill_color()
	draw_colored_polygon(fill_pts, fill_color)
	# 填充边线
	var border_pts = PackedVector2Array(fill_pts)
	border_pts.append(border_pts[0])
	draw_polyline(border_pts, fill_color.lightened(0.3), 2.0)
	# 标题（默认关闭，避免与外部 AltarTitle 重复）
	if show_inner_title:
		draw_string(ThemeDB.fallback_font,
			center + Vector2(-28, -(RADIUS + 14)),
			"五情祭坛", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.65, 0.52, 0.12))

func _get_pentagon(center: Vector2, r: float) -> Array:
	var pts = []
	for i in range(5):
		var a = deg_to_rad(EMOTION_ANGLES[EMOTIONS[i]])
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts

func _get_fill_color() -> Color:
	var max_v = 0
	for e in EMOTIONS: max_v = max(max_v, EmotionManager.values.get(e, 0))
	if max_v >= MAX_VAL: return Color(0.55, 0.0,  0.0,  0.72)
	if max_v >= 3:       return Color(0.83, 0.63, 0.09, 0.65)
	if max_v >= 2:       return Color(0.16, 0.42, 0.62, 0.65)
	return                      Color(0.16, 0.30, 0.50, 0.55)

func _on_emotion_changed(emotion: String, _old: int, new_val: int) -> void:
	queue_redraw()
	call_deferred("_refresh_labels")
	_update_edge_vignette(emotion, new_val)
	if new_val >= MAX_VAL:
		_play_shake()
	elif new_val == 3:
		_play_label_warn(emotion)

func _update_edge_vignette(emotion: String, val: int) -> void:
	if _edge_rects.is_empty(): return
	var ec    = EMOTION_COLORS.get(emotion, Color.RED)
	var alpha: float = clamp(float(val - 1) / 3.0, 0.0, 0.22)
	for r in _edge_rects:
		r.color = Color(ec.r, ec.g, ec.b, alpha)

func _play_shake() -> void:
	if _warn_tween: _warn_tween.kill()
	var orig_x = position.x
	_warn_tween = create_tween()
	for i in range(4):
		_warn_tween.tween_property(self, "position:x",
			orig_x + (3.0 if i % 2 == 0 else -3.0), 0.05)
	_warn_tween.tween_property(self, "position:x", orig_x, 0.05)

func _play_label_warn(emotion: String) -> void:
	var lbl: Variant = _label_nodes.get(emotion)
	if not lbl: return
	if lbl.get_meta("_warning", false): return
	lbl.set_meta("_warning", true)
	var tw: Tween = lbl.create_tween().set_loops(3)
	tw.tween_property(lbl, "modulate:a", 0.35, 0.4)
	tw.tween_property(lbl, "modulate:a", 1.0,  0.4)
	tw.tween_callback(func(): lbl.set_meta("_warning", false))
