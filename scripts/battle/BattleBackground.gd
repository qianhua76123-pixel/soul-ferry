extends Node2D

## BattleBackground.gd - 战场水墨氛围背景
## 挂在 BattleScene 下，z_index=-10，纯代码绘制

@export var base_color:   Color = Color(0.04, 0.05, 0.08, 1.0)
@export var accent_color: Color = Color(0.04, 0.08, 0.12, 1.0)

const SCREEN_W = 1216.0
const SCREEN_H = 684.0

func _ready() -> void:
	z_index = -10
	_apply_chapter_theme(GameState.current_layer)

func _draw() -> void:
	# 渐变背景（20条横线模拟）
	for i in 21:
		var y     = SCREEN_H * float(i) / 20.0
		var t     = float(i) / 20.0
		var color: Color = base_color.lerp(base_color.darkened(0.35), t)
		color.a   = 1.0
		draw_line(Vector2(0, y), Vector2(SCREEN_W, y), color, SCREEN_H / 20.0 + 1)

	# 水墨竖线（固定 seed，每次图案相同）
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1337
	for _i in 28:
		var x     = rng.randf_range(0.0, SCREEN_W)
		var y_2     = rng.randf_range(0.0, SCREEN_H * 0.75)
		var h     = rng.randf_range(55.0, 190.0)
		var alpha: float = rng.randf_range(0.025, 0.075)
		var w     = rng.randf_range(0.4, 1.6)
		draw_line(Vector2(x, y_2), Vector2(x, y_2 + h), Color(0.8, 0.82, 0.85, alpha), w)

	# 玩家侧：左边淡青绿暗角
	var left_color = Color(0.04, 0.18, 0.12, 0.045)
	draw_rect(Rect2(0, 0, 260, SCREEN_H), left_color)

	# 敌人侧：右边淡红暗角
	var right_color = Color(0.22, 0.05, 0.05, 0.045)
	draw_rect(Rect2(SCREEN_W - 260, 0, 260, SCREEN_H), right_color)

	# 地面线（战场区底部）
	var ground_y = 490.0
	draw_line(Vector2(0, ground_y), Vector2(SCREEN_W, ground_y),
		Color(0.10, 0.18, 0.10, 0.55), 1.5)

func _apply_chapter_theme(chapter: int) -> void:
	match chapter:
		1: base_color = Color(0.04, 0.08, 0.12, 1.0)   # 望归村·江边夜色
		2: base_color = Color(0.10, 0.07, 0.03, 1.0)   # 古祠·暗棕
		3: base_color = Color(0.07, 0.04, 0.10, 1.0)   # 幽冥渡口·深紫
		_: base_color = Color(0.04, 0.05, 0.08, 1.0)
	accent_color = base_color.lightened(0.06)
	queue_redraw()
