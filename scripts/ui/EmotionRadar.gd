extends Node2D

## EmotionRadar.gd - 五情雷达图（五边形）
## 祭坛式布局核心 UI，以 _draw() 直接绘制多边形
## 五情各占一个顶点（顺时针：怒/惧/悲/喜/定）


# ========== 配置 ==========
@export var radius: float = 80.0         # 最大半径
@export var center: Vector2 = Vector2(0, 0)
@export var line_width: float = 2.0
@export var show_labels: bool = true

# 五情顶点顺序（从顶部顺时针）
const EMOTION_ORDER = ["calm", "rage", "fear", "grief", "joy"]
const LABEL_OFFSET = 20.0  # 标签距离顶点的偏移

# 各情绪对应颜色
const EMOTION_COLORS = {
	"rage":  Color(0.545, 0.102, 0.102, 0.9),   # 朱红
	"fear":  Color(0.294, 0.0,   0.510, 0.9),   # 深紫
	"grief": Color(0.102, 0.227, 0.420, 0.9),   # 幽蓝
	"joy":   Color(0.722, 0.525, 0.043, 0.9),   # 暖金
	"calm":  Color(0.910, 0.878, 0.816, 0.9),   # 素白
}

# 背景网格颜色
const GRID_COLOR = Color(0.3, 0.25, 0.2, 0.5)
const DOMINANT_GLOW = Color(1.0, 1.0, 0.8, 0.3)

# ========== 状态 ==========
var _current_values: Dictionary = {
	"rage": 0, "fear": 0, "grief": 0, "joy": 0, "calm": 0
}
var _dominant: String = ""

# ========== 初始化 ==========
func _ready() -> void:
	EmotionManager.emotion_changed.connect(_on_emotion_changed)
	EmotionManager.dominant_changed.connect(_on_dominant_changed)
	EmotionManager.emotions_reset.connect(_on_emotions_reset)

func _on_emotion_changed(emotion: String, _old: int, new_val: int) -> void:
	_current_values[emotion] = new_val
	queue_redraw()

func _on_dominant_changed(_old: String, new_dom: String) -> void:
	_dominant = new_dom
	queue_redraw()

func _on_emotions_reset() -> void:
	for e in _current_values:
		_current_values[e] = 0
	_dominant = ""
	queue_redraw()

# ========== 绘制 ==========
func _draw() -> void:
	_draw_grid()
	_draw_filled_polygon()
	_draw_outline()
	if show_labels:
		_draw_labels()
	if _dominant != "":
		_draw_dominant_glow()

## 绘制背景网格（3层同心五边形）
func _draw_grid() -> void:
	for level in [1, 2, 3]:
		var r = radius * level / 3.0
		var pts = _get_polygon_points(r, 1.0)
		for i in len(pts):
			draw_line(pts[i], pts[(i + 1) % len(pts)], GRID_COLOR, 1.0)
		# 从中心到顶点的轴线
		for pt in _get_polygon_points(radius, 1.0):
			draw_line(center, pt, GRID_COLOR, 1.0)

## 绘制填充多边形（按当前情绪值）
func _draw_filled_polygon() -> void:
	var pts = _get_value_points()
	if pts.size() < 3:
		return
	# 为主导情绪选主色，其他混合
	var fill_color = Color(0.5, 0.3, 0.2, 0.4)
	if _dominant != "":
		fill_color = EMOTION_COLORS.get(_dominant, fill_color)
		fill_color.a = 0.45
	draw_colored_polygon(PackedVector2Array(pts), fill_color)

## 绘制轮廓线
func _draw_outline() -> void:
	var pts = _get_value_points()
	if pts.size() < 3:
		return
	var color = Color.WHITE
	if _dominant != "":
		color = EMOTION_COLORS.get(_dominant, Color.WHITE)
		color.a = 1.0
	for i in len(pts):
		draw_line(pts[i], pts[(i + 1) % len(pts)], color, line_width)

## 绘制顶点标签（情绪中文名 + 数值）
func _draw_labels() -> void:
	for i in len(EMOTION_ORDER):
		var emotion = EMOTION_ORDER[i]
		var angle = _get_angle(i)
		var label_pos = center + Vector2(
			cos(angle) * (radius + LABEL_OFFSET),
			sin(angle) * (radius + LABEL_OFFSET)
		)
		var val = _current_values.get(emotion, 0)
		var color = EMOTION_COLORS.get(emotion, Color.WHITE)
		# 失调时标签变红
		if EmotionManager.is_disorder(emotion):
			color = Color.RED
		draw_string(
			ThemeDB.fallback_font,
			label_pos - Vector2(12, 6),
			EmotionManager.get_emotion_name(emotion) + " " + str(val),
			HORIZONTAL_ALIGNMENT_CENTER,
			-1, 14, color
		)

## 主导情绪光晕
func _draw_dominant_glow() -> void:
	if _dominant == "":
		return
	var idx = EMOTION_ORDER.find(_dominant)
	if idx < 0:
		return
	var angle = _get_angle(idx)
	var pt = center + Vector2(cos(angle), sin(angle)) * radius * (_current_values.get(_dominant, 0) / 5.0)
	var glow_color = EMOTION_COLORS.get(_dominant, Color.WHITE)
	glow_color.a = 0.6
	draw_circle(pt, 10.0, glow_color)

# ========== 工具方法 ==========

## 获取第 i 个顶点的角度（从正上方开始，顺时针）
func _get_angle(index: int) -> float:
	return -PI / 2.0 + (2.0 * PI * index / len(EMOTION_ORDER))

## 获取最大五边形的顶点坐标
func _get_polygon_points(r: float, scale: float = 1.0) -> Array:
	var pts = []
	for i in len(EMOTION_ORDER):
		var angle = _get_angle(i)
		pts.append(center + Vector2(cos(angle), sin(angle)) * r * scale)
	return pts

## 根据当前情绪值获取填充多边形顶点
func _get_value_points() -> Array:
	var pts = []
	for i in len(EMOTION_ORDER):
		var emotion = EMOTION_ORDER[i]
		var val = _current_values.get(emotion, 0)
		var ratio = val / float(EmotionManager.MAX_VALUE)
		# 最小显示 0.05，避免全零时退化为点
		ratio = max(ratio, 0.05)
		var angle = _get_angle(i)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius * ratio)
	return pts
