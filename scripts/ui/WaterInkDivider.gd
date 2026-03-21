extends Control
class_name WaterInkDivider

## WaterInkDivider.gd - 水墨渗透分割线
## 用三条线叠加并在两端渐淡，替代生硬直线

@export var ink_color: Color = Color("#6b5a30")
@export var segments: int = 24

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 8)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x <= 8:
		return
	var center_y := size.y * 0.5
	_draw_fade_line(center_y, 1.0, 0.60)
	_draw_fade_line(center_y - 1.0, 0.5, 0.38)
	_draw_fade_line(center_y + 1.0, 0.5, 0.24)

func _draw_fade_line(y: float, width: float, alpha_peak: float) -> void:
	var segs: int = maxi(segments, 6)
	var step_x: float = size.x / float(segs)
	for i in range(segs):
		var x0: float = float(i) * step_x
		var x1: float = float(i + 1) * step_x
		var mid: float = (x0 + x1) * 0.5 / size.x
		var fade: float = 1.0 - absf(mid - 0.5) * 2.0
		var a: float = maxf(0.0, alpha_peak * fade)
		var c := Color(ink_color.r, ink_color.g, ink_color.b, a)
		draw_line(Vector2(x0, y), Vector2(x1, y), c, width)
