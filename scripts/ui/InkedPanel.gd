# InkedPanel.gd
# 渡魂录可复用切角面板组件
# 使用方式：preload 后作为子节点添加，或直接在场景中使用
extends Control

@export var fill_color: Color = Color(0.102, 0.082, 0.031, 0.88)
@export var border_color: Color = Color(0.420, 0.353, 0.188, 0.6)
@export var corner_cut: float = 6.0
@export var show_top_line: bool = true
@export var top_line_color: Color = Color(0.784, 0.663, 0.431)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var c: float = corner_cut

	# 切角多边形顶点（顺时针，左上角开始切角）
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(c, 0.0),
		Vector2(w - c, 0.0),
		Vector2(w, c),
		Vector2(w, h - c),
		Vector2(w - c, h),
		Vector2(c, h),
		Vector2(0.0, h - c),
		Vector2(0.0, c),
	])

	# 填充
	draw_colored_polygon(points, fill_color)

	# 边框描边（逐边 draw_line）
	var n: int = points.size()
	for i in range(n):
		draw_line(points[i], points[(i + 1) % n], border_color, 1.0, true)

	# 顶部装饰线（2px）
	if show_top_line:
		draw_line(Vector2(c, 1.0), Vector2(w - c, 1.0), top_line_color, 2.0, true)
