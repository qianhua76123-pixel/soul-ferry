# WaterInkDivider.gd
# 渡魂录水墨分割线组件
# 水平分割线，中间最深两端渐淡
extends Control

@export var line_color: Color = Color(0.420, 0.353, 0.188)
@export var line_height: float = 1.0


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var y: float = h * 0.5

	# 分段数：将宽度分为若干段，alpha 从中心向两端衰减
	var segments: int = 32
	var seg_w: float = w / float(segments)
	var half: float = float(segments) * 0.5

	for i in range(segments):
		var x_start: float = float(i) * seg_w
		var x_end: float = float(i + 1) * seg_w

		# 计算该段中心距中点的相对距离（0=中心, 1=边缘）
		var seg_center: float = float(i) + 0.5
		var dist: float = abs(seg_center - half) / half  # [0, 1]

		# alpha 衰减：中心 alpha=1，边缘 alpha=0（使用平滑曲线）
		var alpha: float = 1.0 - (dist * dist)
		alpha = clampf(alpha, 0.0, 1.0)

		var seg_color: Color = Color(line_color.r, line_color.g, line_color.b, line_color.a * alpha)
		draw_line(Vector2(x_start, y), Vector2(x_end, y), seg_color, line_height, true)
