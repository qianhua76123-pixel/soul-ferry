extends Node2D

## EmotionRadar.gd - 五边形情绪雷达图（_draw直接绘制）

const EMOTION_ORDER = ["calm", "rage", "fear", "grief", "joy"]
const EMOTION_COLORS = {
	"rage":  Color(0.545, 0.102, 0.102, 0.9),
	"fear":  Color(0.294, 0.0,   0.510, 0.9),
	"grief": Color(0.102, 0.227, 0.420, 0.9),
	"joy":   Color(0.722, 0.525, 0.043, 0.9),
	"calm":  Color(0.910, 0.878, 0.816, 0.9),
}
const GRID_COLOR = Color(0.3, 0.25, 0.2, 0.5)

var radius: float = 80.0

var _vals: Dictionary = {"rage":0,"fear":0,"grief":0,"joy":0,"calm":0}
var _dominant: String = ""

func _ready() -> void:
	EmotionManager.emotion_changed.connect(_on_val_changed)
	EmotionManager.dominant_changed.connect(_on_dom_changed)
	EmotionManager.emotions_reset.connect(_on_reset)

func _on_val_changed(emotion: String, _o: int, v: int) -> void:
	_vals[emotion] = v
	queue_redraw()

func _on_dom_changed(_o: String, d: String) -> void:
	_dominant = d
	queue_redraw()

func _on_reset() -> void:
	for e in _vals: _vals[e] = 0
	_dominant = ""
	queue_redraw()

func _draw() -> void:
	# 背景网格
	for level in [1, 2, 3]:
		var r = radius * level / 3.0
		var pts = _poly(r)
		for i in len(pts):
			draw_line(pts[i], pts[(i+1) % len(pts)], GRID_COLOR, 1.0)
	for pt in _poly(radius):
		draw_line(Vector2.ZERO, pt, GRID_COLOR, 1.0)

	# 填充多边形
	var vpts = _val_poly()
	if vpts.size() >= 3:
		var fc = EMOTION_COLORS.get(_dominant, Color(0.5, 0.3, 0.2, 0.4))
		fc.a = 0.4
		draw_colored_polygon(PackedVector2Array(vpts), fc)
		var lc = EMOTION_COLORS.get(_dominant, Color.WHITE)
		for i in len(vpts):
			draw_line(vpts[i], vpts[(i+1) % len(vpts)], lc, 2.0)

	# 标签
	for i in len(EMOTION_ORDER):
		var emotion = EMOTION_ORDER[i]
		var angle = _angle(i)
		var lpos = Vector2(cos(angle), sin(angle)) * (radius + 18)
		var val  = _vals.get(emotion, 0)
		var col  = Color.RED if EmotionManager.is_disorder(emotion) else EMOTION_COLORS.get(emotion, Color.WHITE)
		draw_string(ThemeDB.fallback_font, lpos - Vector2(10, -5),
			EmotionManager.get_emotion_name(emotion) + str(val),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

func _angle(i: int) -> float:
	return -PI / 2.0 + (TAU * i / len(EMOTION_ORDER))

func _poly(r: float) -> Array:
	var pts = []
	for i in len(EMOTION_ORDER):
		var a = _angle(i)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _val_poly() -> Array:
	var pts = []
	for i in len(EMOTION_ORDER):
		var emotion = EMOTION_ORDER[i]
		var ratio = max(_vals.get(emotion, 0) / float(EmotionManager.MAX_VALUE), 0.05)
		var a = _angle(i)
		pts.append(Vector2(cos(a), sin(a)) * radius * ratio)
	return pts
