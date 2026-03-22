extends Node2D

## BattleBackground.gd - 战场水墨氛围背景（完整动画版）
## 无需外部素材，纯程序生成：渐变底色 + 水墨竖线 + 雾气飘动 + 烛火粒子 + 月亮

@export var base_color:   Color = Color(0.04, 0.05, 0.08, 1.0)
@export var accent_color: Color = Color(0.04, 0.08, 0.12, 1.0)

const SCREEN_W = 1280.0
const SCREEN_H = 720.0

# ── 雾气层（3层视差）────────────────────────────────
var _fog_layers: Array[Dictionary] = []

# ── 烛火粒子 ─────────────────────────────────────────
var _candles: Array[Dictionary] = []

# ── 月亮/太阳相位 ─────────────────────────────────────
var _moon_phase:  float = 0.0   # 0~1 循环
var _moon_bob:    float = 0.0

# ── 水墨笔触（固定，每层不同形状）───────────────────
var _ink_strokes: Array[Dictionary] = []

# ── Boss 警戒粒子 ─────────────────────────────────────
var _boss_particles: Array[Dictionary] = []
var _is_boss: bool = false

func _ready() -> void:
	z_index = -10
	_apply_chapter_theme(GameState.current_layer)
	_gen_ink_strokes()
	_gen_fog_layers()
	_gen_candles()

func _process(delta: float) -> void:
	_moon_phase  = fmod(_moon_phase  + delta * 0.04, 1.0)
	_moon_bob    = fmod(_moon_bob    + delta * 0.8,  TAU)

	# 雾气飘移
	for fog: Dictionary in _fog_layers:
		fog["x"] = fmod(fog["x"] + fog["speed"] * delta, SCREEN_W + fog["w"])
		if fog["x"] > SCREEN_W:
			fog["x"] -= SCREEN_W + fog["w"]

	# 烛火闪烁
	for c: Dictionary in _candles:
		c["flicker"] = fmod(c["flicker"] + delta * c["fspeed"], TAU)
		c["alpha"]   = 0.55 + sin(c["flicker"]) * 0.18

	# Boss 粒子
	if _is_boss:
		for p: Dictionary in _boss_particles:
			p["y"]    -= delta * p["vy"]
			p["alpha"] = clampf(p["alpha"] - delta * 0.4, 0.0, 1.0)
			if p["alpha"] <= 0.0:
				p["y"]     = SCREEN_H * 0.9 + randf_range(0.0, 60.0)
				p["x"]     = randf_range(0.0, SCREEN_W)
				p["alpha"] = randf_range(0.3, 0.8)

	queue_redraw()

# ════════════════════════════════════════════════════════
#  _draw — 全部绘制
# ════════════════════════════════════════════════════════

func _draw() -> void:
	_draw_bg_gradient()
	_draw_ink_strokes()
	_draw_moon()
	_draw_fog()
	_draw_candles()
	_draw_ground()
	_draw_vignette()
	if _is_boss:
		_draw_boss_particles()

func _draw_bg_gradient() -> void:
	# 20条横线模拟顶到底渐变
	for i in 22:
		var y: float   = SCREEN_H * float(i) / 21.0
		var t: float   = float(i) / 21.0
		var col: Color = base_color.lerp(base_color.darkened(0.45), t)
		col.a          = 1.0
		draw_line(Vector2(0.0, y), Vector2(SCREEN_W, y), col, SCREEN_H / 21.0 + 1.5)

	# 玩家侧左暗角（青绿）
	for i in 8:
		var t2: float  = float(i) / 7.0
		var col2: Color = Color(0.04, 0.18, 0.12, 0.06 * (1.0 - t2))
		draw_rect(Rect2(float(i) * 30.0, 0.0, 30.0, SCREEN_H), col2)

	# 敌人侧右暗角（暗红）
	for i in 8:
		var t3: float   = float(i) / 7.0
		var col3: Color = Color(0.22, 0.05, 0.04, 0.06 * t3)
		draw_rect(Rect2(SCREEN_W - (8 - i) * 30.0, 0.0, 30.0, SCREEN_H), col3)

func _draw_ink_strokes() -> void:
	for s: Dictionary in _ink_strokes:
		var col: Color = Color(s["r"], s["g"], s["b"], s["a"])
		draw_line(
			Vector2(s["x"], s["y"]),
			Vector2(s["x"] + s["dx"], s["y"] + s["dy"]),
			col, s["w"])
		# 笔触末端渐淡（再画一段更细的）
		if s["dy"] > 20.0:
			var col2: Color = col; col2.a *= 0.4
			draw_line(
				Vector2(s["x"] + s["dx"] * 0.7, s["y"] + s["dy"] * 0.7),
				Vector2(s["x"] + s["dx"] * 1.1, s["y"] + s["dy"] * 1.1),
				col2, s["w"] * 0.5)

func _draw_moon() -> void:
	# 月亮位置（右上角，随时间缓慢上下浮动）
	var mx: float = SCREEN_W * 0.82
	var my: float = 68.0 + sin(_moon_bob) * 4.0
	var r: float  = 28.0
	var layer_int: int = GameState.current_layer

	# 月亮本体
	var moon_col: Color = Color(0.92, 0.88, 0.78, 0.82)
	draw_circle(Vector2(mx, my), r, moon_col)

	# 月晕（光晕渐变，用多个透明圆模拟）
	for i in 5:
		var hr: float   = r + 6.0 + float(i) * 5.0
		var ha: float   = 0.06 - float(i) * 0.01
		draw_circle(Vector2(mx, my), hr, Color(0.88, 0.85, 0.70, ha))

	# 月相阴影（黑色遮盖圆，偏移制造弦月效果）
	match layer_int:
		1: # 望月（接近满月）
			draw_circle(Vector2(mx + r * 0.15, my), r * 0.95, Color(base_color.r, base_color.g, base_color.b, 0.92))
		2: # 半月
			draw_circle(Vector2(mx + r * 0.5, my), r, Color(base_color.r * 0.7, base_color.g * 0.7, base_color.b * 0.7, 0.94))
		3: # 残月（血色）
			draw_circle(Vector2(mx + r * 0.7, my), r * 0.9, Color(0.10, 0.03, 0.03, 0.95))
			# 血色内核
			draw_circle(Vector2(mx, my), r * 0.35, Color(0.55, 0.08, 0.08, 0.45))

func _draw_fog() -> void:
	for fog: Dictionary in _fog_layers:
		var x: float = fog["x"] - fog["w"]
		var alpha_fog: float = fog["alpha"]
		var col: Color = Color(fog["r"], fog["g"], fog["b"], alpha_fog)
		# 用多条矩形模拟雾带（高度方向渐变）
		var h: float = fog["h"]
		for j in 6:
			var jt: float  = float(j) / 5.0
			var ja: float  = alpha_fog * (1.0 - abs(jt - 0.5) * 1.8)
			var jcol: Color = Color(col.r, col.g, col.b, maxf(ja, 0.0))
			draw_rect(Rect2(x, fog["y"] + (jt - 0.5) * h, fog["w"], h / 6.0 + 1.0), jcol)
		# 第二片（无缝循环）
		var x2: float = x + fog["w"] + SCREEN_W * 0.5
		for j in 6:
			var jt: float  = float(j) / 5.0
			var ja: float  = alpha_fog * (1.0 - abs(jt - 0.5) * 1.8)
			var jcol: Color = Color(col.r, col.g, col.b, maxf(ja, 0.0))
			draw_rect(Rect2(x2, fog["y"] + (jt - 0.5) * h, fog["w"] * 0.8, h / 6.0 + 1.0), jcol)

func _draw_candles() -> void:
	for c: Dictionary in _candles:
		var cx: float = c["x"]; var cy: float = c["y"]
		var alpha_c: float = c["alpha"]
		# 蜡烛体
		draw_rect(Rect2(cx - 3.0, cy, 6.0, 18.0), Color(0.78, 0.72, 0.60, 0.75))
		# 火焰（小三角形用两条线近似）
		var flame_y: float = cy - 3.0 + sin(c["flicker"]) * 1.5
		draw_line(Vector2(cx, flame_y - 7.0), Vector2(cx - 4.0, flame_y), Color(0.98, 0.70, 0.15, alpha_c), 2.0)
		draw_line(Vector2(cx, flame_y - 7.0), Vector2(cx + 4.0, flame_y), Color(0.98, 0.70, 0.15, alpha_c), 2.0)
		draw_line(Vector2(cx - 4.0, flame_y), Vector2(cx + 4.0, flame_y), Color(0.95, 0.55, 0.10, alpha_c), 2.0)
		# 火芯
		draw_circle(Vector2(cx, flame_y - 2.0), 2.0, Color(1.0, 0.90, 0.60, alpha_c))
		# 光晕
		for gi in 4:
			var gr: float = 8.0 + float(gi) * 7.0
			draw_circle(Vector2(cx, flame_y - 2.0), gr,
				Color(0.90, 0.60, 0.12, 0.025 * alpha_c / 0.7))

func _draw_ground() -> void:
	# 地面分隔线（水墨渗晕风格）
	var gy: float = 500.0
	for gi in 4:
		var ga: float = 0.35 - float(gi) * 0.07
		var gw: float = 1.2 - float(gi) * 0.2
		draw_line(Vector2(0.0, gy + float(gi)), Vector2(SCREEN_W, gy + float(gi)),
			Color(0.15, 0.22, 0.15, ga), gw)
	# 地面上方淡青绿渐变（草地感）
	for gi in 8:
		var gt: float = float(gi) / 7.0
		draw_rect(Rect2(0.0, gy - float(gi) * 3.0, SCREEN_W, 3.0),
			Color(0.08, 0.14, 0.10, 0.018 * (1.0 - gt)))

func _draw_vignette() -> void:
	# 四角暗角（压暗感）
	var corners: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(SCREEN_W, 0.0),
		Vector2(0.0, SCREEN_H), Vector2(SCREEN_W, SCREEN_H)]
	for corner: Vector2 in corners:
		for vi in 6:
			var vr: float = 80.0 + float(vi) * 60.0
			var va: float = 0.06 - float(vi) * 0.009
			draw_circle(corner, vr, Color(0.0, 0.0, 0.0, maxf(va, 0.0)))

func _draw_boss_particles() -> void:
	for p: Dictionary in _boss_particles:
		var pc: Color = Color(p["r"], p["g"], p["b"], p["alpha"])
		draw_circle(Vector2(p["x"], p["y"]), p["size"], pc)

# ════════════════════════════════════════════════════════
#  数据生成
# ════════════════════════════════════════════════════════

func _gen_ink_strokes() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0xDEADBEEF
	_ink_strokes.clear()
	for _i in 32:
		var sx: float = rng.randf_range(0.0, SCREEN_W)
		var sy: float = rng.randf_range(0.0, SCREEN_H * 0.75)
		var is_vert: bool = rng.randf() > 0.3
		_ink_strokes.append({
			"x":  sx, "y": sy,
			"dx": rng.randf_range(-8.0,  8.0)  if is_vert else rng.randf_range(30.0, 110.0),
			"dy": rng.randf_range(50.0, 200.0) if is_vert else rng.randf_range(-4.0,  4.0),
			"w":  rng.randf_range(0.4, 2.0),
			"r":  rng.randf_range(0.75, 0.88),
			"g":  rng.randf_range(0.78, 0.90),
			"b":  rng.randf_range(0.80, 0.95),
			"a":  rng.randf_range(0.018, 0.055),
		})

func _gen_fog_layers() -> void:
	_fog_layers.clear()
	# 三层：慢/中/快，不同高度
	var cfg: Array[Dictionary] = [
		{"y": 420.0, "h": 80.0,  "speed": 14.0,  "alpha": 0.06, "w": 520.0},
		{"y": 460.0, "h": 55.0,  "speed": 22.0,  "alpha": 0.04, "w": 380.0},
		{"y": 488.0, "h": 30.0,  "speed": 36.0,  "alpha": 0.03, "w": 260.0},
	]
	for i in cfg.size():
		var layer_int: int = GameState.current_layer
		var r: float; var g: float; var b: float
		match layer_int:
			1: r = 0.70; g = 0.82; b = 0.88   # 江边：淡蓝白
			2: r = 0.82; g = 0.72; b = 0.55   # 古祠：暖米
			3: r = 0.55; g = 0.50; b = 0.75   # 幽冥：淡紫
			_: r = 0.70; g = 0.75; b = 0.80
		_fog_layers.append({
			"x":     float(i) * 200.0,
			"y":     cfg[i]["y"], "h": cfg[i]["h"],
			"speed": cfg[i]["speed"], "alpha": cfg[i]["alpha"],
			"w":     cfg[i]["w"],
			"r": r, "g": g, "b": b,
		})

func _gen_candles() -> void:
	_candles.clear()
	# 固定位置：玩家侧2根，敌人侧1根（Boss时3根）
	var positions: Array[Vector2] = [
		Vector2(80.0,  470.0),
		Vector2(140.0, 475.0),
		Vector2(SCREEN_W - 100.0, 468.0),
	]
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 42
	for pos: Vector2 in positions:
		_candles.append({
			"x": pos.x, "y": pos.y,
			"flicker": rng2.randf_range(0.0, TAU),
			"fspeed":  rng2.randf_range(3.5, 6.5),
			"alpha":   0.70,
		})

func _gen_boss_particles() -> void:
	_boss_particles.clear()
	var rng3: RandomNumberGenerator = RandomNumberGenerator.new()
	rng3.seed = 99
	for _i in 30:
		var layer_int: int = GameState.current_layer
		var r: float; var g: float; var b: float
		match layer_int:
			1: r = 0.55; g = 0.20; b = 0.20   # 旱魃：暗红
			2: r = 0.30; g = 0.55; b = 0.80   # 水鬼：深蓝
			3: r = 0.72; g = 0.25; b = 0.65   # 鬼新娘：紫红
			_: r = 0.60; g = 0.20; b = 0.20
		_boss_particles.append({
			"x":     rng3.randf_range(0.0, SCREEN_W),
			"y":     rng3.randf_range(SCREEN_H * 0.3, SCREEN_H * 0.9),
			"vy":    rng3.randf_range(15.0, 55.0),
			"size":  rng3.randf_range(2.0, 5.0),
			"alpha": rng3.randf_range(0.0, 0.7),
			"r": r, "g": g, "b": b,
		})

# ════════════════════════════════════════════════════════
#  公共 API
# ════════════════════════════════════════════════════════

func _apply_chapter_theme(chapter: int) -> void:
	match chapter:
		1: base_color = Color(0.04, 0.07, 0.12, 1.0)   # 望乡·江边夜色
		2: base_color = Color(0.10, 0.07, 0.03, 1.0)   # 焦土·暗棕
		3: base_color = Color(0.06, 0.03, 0.10, 1.0)   # 幽冥·深紫
		_: base_color = Color(0.04, 0.05, 0.08, 1.0)
	accent_color = base_color.lightened(0.06)
	_gen_fog_layers()

func set_boss_mode(is_boss: bool) -> void:
	_is_boss = is_boss
	if is_boss:
		_gen_boss_particles()
	else:
		_boss_particles.clear()
	queue_redraw()
