extends Node2D

## BgCanvas.gd - 主菜单程序化水墨背景绘制

func _draw() -> void:
	var W = 1280.0
	var H = 720.0

	# 底色
	draw_rect(Rect2(0, 0, W, H), Color(0.039, 0.027, 0.020))

	# 水墨渐变（从顶部深 → 底部稍亮）
	for y in 80:
		var t   = float(y) / 79.0
		var col = Color(
			lerp(0.025, 0.055, t),
			lerp(0.018, 0.040, t),
			lerp(0.012, 0.030, t),
		)
		draw_line(Vector2(0, y * 9.0), Vector2(W, y * 9.0), col, 9.1)

	# 墨迹装饰（程序化不规则色块，模拟晕染）
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260319
	for _i in 18:
		var cx  = rng.randf_range(60, W - 60)
		var cy  = rng.randf_range(40, H - 40)
		var r   = rng.randf_range(8, 55)
		var a   = rng.randf_range(0.04, 0.13)
		draw_circle(Vector2(cx, cy), r, Color(0.05, 0.035, 0.025, a))

	# 朱红细线边框（四边内缩4px）
	var bc = Color(0.545, 0.102, 0.102, 0.25)
	draw_line(Vector2(4,4),     Vector2(W-4, 4),   bc, 1.0)
	draw_line(Vector2(4,H-4),   Vector2(W-4, H-4), bc, 1.0)
	draw_line(Vector2(4,4),     Vector2(4,   H-4), bc, 1.0)
	draw_line(Vector2(W-4,4),   Vector2(W-4, H-4), bc, 1.0)

	# 角落装饰（朱红 L 形）
	var corner_len = 28.0
	var cc = Color(0.545, 0.102, 0.102, 0.55)
	# 左上
	draw_line(Vector2(4,4), Vector2(4+corner_len, 4),   cc, 1.5)
	draw_line(Vector2(4,4), Vector2(4, 4+corner_len),   cc, 1.5)
	# 右上
	draw_line(Vector2(W-4,4), Vector2(W-4-corner_len,4), cc, 1.5)
	draw_line(Vector2(W-4,4), Vector2(W-4,4+corner_len), cc, 1.5)
	# 左下
	draw_line(Vector2(4,H-4), Vector2(4+corner_len,H-4), cc, 1.5)
	draw_line(Vector2(4,H-4), Vector2(4,H-4-corner_len), cc, 1.5)
	# 右下
	draw_line(Vector2(W-4,H-4), Vector2(W-4-corner_len,H-4), cc, 1.5)
	draw_line(Vector2(W-4,H-4), Vector2(W-4,H-4-corner_len), cc, 1.5)

	# 中央竖向光晕（标题后面）
	for r in range(200, 0, -20):
		var a = (200.0 - r) / 200.0 * 0.025
		draw_circle(Vector2(W/2, H * 0.3), float(r), Color(0.545, 0.102, 0.102, a))
