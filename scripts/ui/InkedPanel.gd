extends Control
class_name InkedPanel

## InkedPanel.gd - 切角水墨面板
## 三层语言：暗边 + 纸色填充 + 顶部装饰线

@export var fill_color: Color = Color("#1a1508", 0.88)
@export var border_color: Color = Color("#6b5a30", 0.40)
@export var top_line_color: Color = Color("#c8a96e", 0.95)
@export var corner_cut: float = 6.0
@export var border_width: float = 1.0
@export var show_top_line: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 4.0 or rect.size.y < 4.0:
		return
	_draw_inked_panel(rect, fill_color, border_color)
	if show_top_line:
		var c := min(corner_cut, rect.size.x * 0.2)
		var p0 := Vector2(c, 1.0)
		var p1 := Vector2(rect.size.x - c, 1.0)
		draw_line(p0, p1, top_line_color, 2.0)

func _draw_inked_panel(rect: Rect2, c_fill: Color, c_border: Color) -> void:
	var c := min(corner_cut, min(rect.size.x, rect.size.y) * 0.25)
	var p := rect
	var points := PackedVector2Array([
		Vector2(p.position.x + c, p.position.y),
		Vector2(p.end.x - c,      p.position.y),
		Vector2(p.end.x,          p.position.y + c),
		Vector2(p.end.x,          p.end.y - c),
		Vector2(p.end.x - c,      p.end.y),
		Vector2(p.position.x + c, p.end.y),
		Vector2(p.position.x,     p.end.y - c),
		Vector2(p.position.x,     p.position.y + c),
	])
	draw_colored_polygon(points, c_fill)
	draw_polyline(points + PackedVector2Array([points[0]]), c_border, border_width)
