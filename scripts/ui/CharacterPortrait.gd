extends RefCounted
class_name CharacterPortrait

## CharacterPortrait.gd
## 为角色选择界面生成 128×192 大尺寸像素立绘
## create(char_id) → ImageTexture

static func create(char_id: String) -> ImageTexture:
	var img: Image = Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	match char_id:
		"shen_tiejun": _draw_shen(img)
		"wumian":      _draw_wumian(img)
		_:             _draw_ruan(img)
	img.resize(128, 192, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

# ── 工具 ──────────────────────────────────────────────
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for dy in h:
		for dx in w:
			_px(img, x+dx, y+dy, c)

static func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for dy in range(-r, r+1):
		for dx in range(-r, r+1):
			if dx*dx + dy*dy <= r*r:
				_px(img, cx+dx, cy+dy, c)

static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for dy in range(-ry, ry+1):
		for dx in range(-rx, rx+1):
			if float(dx*dx)/float(rx*rx) + float(dy*dy)/float(ry*ry) <= 1.0:
				_px(img, cx+dx, cy+dy, c)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx: int = abs(x1-x0); var dy: int = abs(y1-y0)
	var sx: int = 1 if x0<x1 else -1; var sy: int = 1 if y0<y1 else -1
	var err: int = dx-dy
	while true:
		_px(img, x0, y0, c)
		if x0==x1 and y0==y1: break
		var e2: int = 2*err
		if e2 > -dy: err-=dy; x0+=sx
		if e2 <  dx: err+=dx; y0+=sy

static func _gradient_rect(img: Image, x: int, y: int, w: int, h: int,
		c_top: Color, c_bot: Color) -> void:
	for dy in h:
		var t: float = float(dy)/float(maxi(h-1,1))
		var c: Color = c_top.lerp(c_bot, t)
		for dx in w:
			_px(img, x+dx, y+dy, c)

# ══════════════════════════════════════════════════════
#  阮如月 — 青灰道袍，渡魂幡，柔和气质
# ══════════════════════════════════════════════════════
static func _draw_ruan(img: Image) -> void:
	# 背景光晕（暖橙/朱红渐变）
	_gradient_rect(img, 0, 0, 64, 96, Color(0.12,0.08,0.10,1), Color(0.06,0.04,0.06,1))
	for r in range(28, 12, -2):
		var a: float = 0.04 - float(28-r)*0.001
		_circle(img, 32, 36, r, Color(0.72,0.20,0.08, a))

	# ── 幡（左侧）──
	var pole_c: Color = Color(0.25,0.18,0.12,1)
	var bann_c: Color = Color(0.92,0.88,0.80,1)
	var red_c: Color  = Color(0.72,0.10,0.10,1)
	for y in range(0, 56): _px(img, 10, y, pole_c)
	_rect(img, 6, 3, 9, 1, pole_c)      # 横木
	_rect(img, 7, 4, 7, 20, bann_c)     # 幡面
	for y in range(4, 24):               # 幡边
		_px(img, 7, y, red_c); _px(img, 13, y, red_c)
	_rect(img, 7, 4, 7, 1, red_c); _rect(img, 7, 23, 7, 1, red_c)
	# 符文（简化"渡"）
	_rect(img, 8, 6, 5, 1, red_c); _rect(img, 8, 9, 5, 1, red_c)
	_rect(img, 8,12, 5, 1, red_c); _rect(img, 8,15, 5, 1, red_c)
	for y in range(6, 22): _px(img, 10, y, red_c)
	# 幡穗
	for dx in [-1,0,1]:
		for y in range(24, 30):
			_px(img, 10+dx, y, red_c if y%2==0 else bann_c)

	# ── 道冠 ──
	var crown_c: Color = Color(0.10,0.08,0.08,1)
	var gold_c: Color  = Color(0.78,0.60,0.10,1)
	_rect(img, 26, 3, 12, 7, crown_c)
	_rect(img, 24, 9, 16, 2, gold_c)    # 金色冠沿
	_rect(img, 27, 3, 10, 1, gold_c)    # 冠顶
	_px(img, 32, 4, gold_c); _px(img, 32, 5, gold_c); _px(img, 32, 6, gold_c)  # 中央竖饰

	# ── 头部 ──
	var skin_c: Color  = Color(0.88,0.80,0.70,1)
	var sknd_c: Color  = Color(0.68,0.58,0.48,1)
	var hair_c: Color  = Color(0.12,0.10,0.10,1)
	var ink_c: Color   = Color(0.08,0.06,0.06,1)
	_ellipse(img, 32, 18, 7, 8, skin_c)
	# 发鬓
	for y in range(10, 22): _px(img, 25, y, hair_c); _px(img, 39, y, hair_c)
	_rect(img, 26, 10, 12, 2, hair_c)
	# 眉
	_rect(img, 27,15, 4,1, ink_c); _rect(img, 33,15, 4,1, ink_c)
	# 眼（细长，沉静）
	_rect(img, 27,17, 4,1, ink_c); _rect(img, 33,17, 4,1, ink_c)
	_px(img,28,18, ink_c); _px(img,29,18, ink_c)
	_px(img,34,18, ink_c); _px(img,35,18, ink_c)
	# 鼻
	_px(img,32,20, sknd_c)
	# 嘴（淡红薄唇）
	_rect(img, 30,22, 4,1, Color(0.65,0.30,0.28,1))
	# 朱砂印堂
	_px(img, 32, 14, Color(0.80,0.10,0.10,0.9))

	# ── 道袍躯干 ──
	var robe_c: Color = Color(0.38,0.46,0.50,1)
	var robe_d: Color = Color(0.22,0.30,0.35,1)
	var robe_l: Color = Color(0.52,0.60,0.64,1)
	var sash_c: Color = Color(0.65,0.12,0.12,1)
	# 衣领三角
	_rect(img, 28,26, 8,3, robe_c)
	_px(img,31,26, skin_c); _px(img,32,26, skin_c); _px(img,32,27, skin_c)
	# 躯干
	_rect(img, 22,28, 20,22, robe_c)
	_rect(img, 22,28, 3,22, robe_d); _rect(img, 39,28, 3,22, robe_d)
	_rect(img, 25,28, 4,20, robe_l)
	# 腰带
	_rect(img, 20,46, 24,5, sash_c)
	_rect(img, 20,49, 24,2, Color(0.45,0.08,0.08,1))
	_rect(img, 30,46, 4,5, Color(0.40,0.08,0.08,1))  # 腰带结
	# 袖子（宽）
	_rect(img, 14,29, 9,16, robe_c); _rect(img, 14,29, 2,16, robe_d)
	_rect(img, 41,29, 9,16, robe_c); _rect(img, 48,29, 2,16, robe_d)
	# 手
	_rect(img, 15,45, 6,5, skin_c); _rect(img, 43,45, 6,5, skin_c)
	# 下袍（A字展开）
	for i in range(28):
		var w: int = 20 + i*2/3; var x: int = 32 - w/2
		_rect(img, x, 51+i, w, 1, robe_c if i%4!=0 else robe_d)
	_rect(img, 16,78, 32,1, robe_d)
	# 鞋尖（黑色翘头）
	_rect(img, 19,79, 9,3, ink_c); _rect(img, 36,79, 9,3, ink_c)
	_px(img,18,79,ink_c); _px(img,45,79,ink_c)

	# ── 右手施法光（朱砂指尖）──
	_px(img, 49, 44, Color(0.90,0.20,0.18,0.9))
	_px(img, 50, 43, Color(0.90,0.55,0.18,0.7))
	_px(img, 51, 44, Color(0.90,0.55,0.18,0.5))

# ══════════════════════════════════════════════════════
#  沈铁钧 — 深蓝捕快服，铁链，方颌宽肩
# ══════════════════════════════════════════════════════
static func _draw_shen(img: Image) -> void:
	# 背景（冷蓝暗调）
	_gradient_rect(img, 0, 0, 64, 96, Color(0.06,0.08,0.14,1), Color(0.03,0.04,0.08,1))
	for r in range(26, 12, -2):
		var a: float = 0.035
		_circle(img, 32, 40, r, Color(0.30,0.42,0.65, a))

	# ── 铁链（挂在腰侧）──
	var chain_c: Color  = Color(0.58,0.58,0.62,1)
	var chain_l: Color  = Color(0.78,0.78,0.82,1)
	var i: int = 0
	while i < 28:
		if i%4 < 2:
			_rect(img, 46, 52+i, 4, 2, chain_c); _px(img, 47, 52+i, chain_l)
		else:
			_rect(img, 45, 52+i, 4, 2, chain_c); _px(img, 46, 52+i, chain_l)
		i += 2
	# 铁链末端锁头
	_rect(img, 44, 79, 6, 5, chain_c)
	_rect(img, 45, 80, 4, 3, chain_l)
	_px(img, 47, 79, Color(0.30,0.30,0.32,1))

	# ── 头部（宽脸方颌）──
	var skin_c: Color  = Color(0.82,0.72,0.60,1)
	var sknd_c: Color  = Color(0.62,0.52,0.42,1)
	var hair_c: Color  = Color(0.28,0.24,0.22,1)   # 灰发带白
	var hair_l: Color  = Color(0.52,0.48,0.46,1)
	var ink_c: Color   = Color(0.08,0.06,0.06,1)
	# 脸（方形，宽）
	_rect(img, 23, 9, 18, 18, skin_c)
	_rect(img, 22,11, 20,14, skin_c)
	_rect(img, 24, 9, 16, 2, skin_c)
	_rect(img, 24,25, 16, 2, skin_c)
	# 两鬓胡须
	for y in range(20, 28):
		_px(img, 22, y, hair_c); _px(img, 23, y, hair_c)
		_px(img, 41, y, hair_c); _px(img, 40, y, hair_c)
	# 头顶发（灰白混合）
	_rect(img, 22, 5, 20, 6, hair_c)
	_rect(img, 24, 4, 16, 2, hair_c)
	for x in range(24, 40, 3): _px(img, x, 5, hair_l)  # 白发丝
	# 浓眉
	_rect(img, 25,14, 6,2, ink_c); _rect(img, 33,14, 6,2, ink_c)
	# 眼（锐利，细眯）
	_rect(img, 25,17, 6,1, ink_c); _rect(img, 33,17, 6,1, ink_c)
	_px(img,27,18, ink_c); _px(img,28,18, ink_c)
	_px(img,35,18, ink_c); _px(img,36,18, ink_c)
	# 鼻（宽）
	_rect(img, 30,20, 4,3, sknd_c)
	# 嘴（抿紧，有威严）
	_rect(img, 27,23, 10,1, ink_c)
	_rect(img, 27,24,  2,1, skin_c); _rect(img, 35,24, 2,1, skin_c)  # 嘴角
	# 络腮胡
	for y in range(21, 28):
		if y >= 22:
			_px(img, 23, y, hair_c); _px(img, 40, y, hair_c)
		_px(img, 24, y, hair_c if y%2==0 else sknd_c)
		_px(img, 39, y, hair_c if y%2==0 else sknd_c)
	# 官帽（捕快巾帻）
	var hat_c: Color = Color(0.10,0.10,0.14,1)
	var hat_r: Color = Color(0.30,0.35,0.55,1)   # 蓝色帽缘
	_rect(img, 22, 4, 20, 6, hat_c)
	_rect(img, 20, 9, 24, 2, hat_r)
	_rect(img, 23, 3, 18, 2, hat_c)
	_rect(img, 24, 2, 16, 2, hat_c)
	_px(img, 32, 1, hat_c)

	# ── 捕快深蓝服（宽肩）──
	var coat_c: Color = Color(0.15,0.22,0.38,1)
	var coat_d: Color = Color(0.08,0.12,0.22,1)
	var coat_l: Color = Color(0.25,0.35,0.52,1)
	var belt_c: Color = Color(0.42,0.28,0.10,1)
	var badge_c: Color = Color(0.75,0.56,0.10,1)
	# 衣领
	_rect(img, 28,28, 8,4, coat_c)
	_px(img,31,28, skin_c); _px(img,32,28, skin_c); _px(img,32,29, skin_c)
	# 躯干（宽）
	_rect(img, 18,30, 28,20, coat_c)
	_rect(img, 18,30, 3,20, coat_d); _rect(img, 43,30, 3,20, coat_d)
	_rect(img, 21,30, 5,18, coat_l)
	# 腰带（皮）
	_rect(img, 17,48, 30,5, belt_c)
	_rect(img, 29,48, 6,5, Color(0.32,0.20,0.06,1))  # 腰带扣
	_rect(img, 30,49, 4,3, badge_c)   # 腰牌金色
	_px(img,32,50, Color(0.40,0.28,0.06,1))  # 腰牌纹
	# 袖子（粗壮）
	_rect(img,  8,30, 12,18, coat_c); _rect(img,  8,30, 2,18, coat_d)
	_rect(img, 44,30, 12,18, coat_c); _rect(img, 54,30, 2,18, coat_d)
	# 手（粗）
	_rect(img, 8,47, 10,6, skin_c)
	_rect(img, 46,47, 10,6, skin_c)
	# 宽腿裤
	_rect(img, 18,53, 12,30, coat_c); _rect(img, 18,53, 2,30, coat_d)
	_rect(img, 34,53, 12,30, coat_c); _rect(img, 44,53, 2,30, coat_d)
	# 靴子（黑厚底）
	_rect(img, 16,82, 15,4, ink_c); _rect(img, 33,82, 15,4, ink_c)
	_rect(img, 15,84, 17,2, Color(0.18,0.18,0.20,1))

# ══════════════════════════════════════════════════════
#  无名（无面人）— 渐变灰白，无脸，轮廓光晕
# ══════════════════════════════════════════════════════
static func _draw_wumian(img: Image) -> void:
	# 背景（极暗，几乎全黑，中央有白光）
	_gradient_rect(img, 0, 0, 64, 96, Color(0.05,0.05,0.06,1), Color(0.02,0.02,0.03,1))
	# 中央柔光
	for r in range(32, 6, -2):
		var a: float = 0.025 - float(32-r)*0.0005
		_circle(img, 32, 38, r, Color(0.88,0.88,0.85, maxf(0.0, a)))

	# ── 虚影（偏移，低透明度）──
	var body_s: Color = Color(0.72,0.72,0.70,0.22)
	var body_m: Color = Color(0.82,0.82,0.80,0.55)
	var body_b: Color = Color(0.90,0.90,0.88,1.0)
	var edge_c: Color = Color(0.50,0.50,0.48,1.0)
	var lite_c: Color = Color(0.96,0.96,0.95,1.0)
	var face_c: Color = Color(0.88,0.88,0.86,1.0)   # 脸面（完全平整，无特征）

	# 最远虚影
	for off in [[3,0],[-3,0],[0,-2]]:
		_draw_wumian_shape(img, off[0], off[1], body_s)
	# 近虚影
	_draw_wumian_shape(img, 1, 0, body_m)
	_draw_wumian_shape(img, -1, 0, body_m)
	# 主体
	_draw_wumian_shape(img, 0, 0, body_b)

	# ── 脸（平整，无眼鼻嘴，只有轮廓光）──
	_ellipse(img, 32, 18, 10, 12, face_c)
	# 脸部外轮廓光晕
	for r in range(14, 10, -1):
		var a: float = 0.15 - float(14-r)*0.04
		_ellipse(img, 32, 18, r+2, r+3, Color(lite_c.r, lite_c.g, lite_c.b, a))
	# 非常隐约的脸部纹路（存在感痕迹，像极淡的五官影子）
	_rect(img, 27,16, 4,1, Color(0.75,0.75,0.73,0.25))  # 眉影
	_rect(img, 33,16, 4,1, Color(0.75,0.75,0.73,0.25))
	_rect(img, 28,19, 3,1, Color(0.72,0.72,0.70,0.20))  # 眼影
	_rect(img, 33,19, 3,1, Color(0.72,0.72,0.70,0.20))
	# 脸部边缘轮廓
	for ang in range(0, 360, 12):
		var rad: float = ang * 0.01745
		var ex: int = int(32 + cos(rad)*10)
		var ey: int = int(18 + sin(rad)*12)
		_px(img, ex, ey, edge_c)

	# ── 情绪粒子（漂浮，表现吸取/释放情绪的能力）──
	var particles: Array = [
		[14, 22, Color(0.55,0.35,0.75,0.8)],  # 紫（悲/惧）
		[50, 28, Color(0.72,0.20,0.18,0.7)],  # 红（怒）
		[18, 48, Color(0.80,0.68,0.15,0.75)], # 金（喜）
		[46, 44, Color(0.25,0.55,0.65,0.65)], # 青（定）
		[10, 36, Color(0.55,0.35,0.75,0.50)], # 淡紫
		[52, 56, Color(0.25,0.55,0.65,0.45)], # 淡青
	]
	for p in particles:
		_circle(img, p[0], p[1], 2, p[2])
		_px(img, p[0], p[1], Color(1.0,1.0,1.0,0.6))  # 中心白点
		# 粒子光晕
		_circle(img, p[0], p[1], 4, Color(p[2].r, p[2].g, p[2].b, p[2].a*0.3))

	# ── 向手的拖尾（情绪流向手掌）──
	_line(img, 14, 60, 20, 52, Color(0.55,0.35,0.75,0.4))
	_line(img, 50, 60, 44, 52, Color(0.72,0.20,0.18,0.4))

static func _draw_wumian_shape(img: Image, ox: int, oy: int, c: Color) -> void:
	# 躯干
	_rect(img, 24+ox, 30+oy, 16, 24, c)
	# 头（椭圆，通过多个矩形近似）
	_ellipse(img, 32+ox, 18+oy, 9, 11, c)
	# 臂
	_rect(img, 14+ox, 31+oy, 11, 18, c)
	_rect(img, 39+ox, 31+oy, 11, 18, c)
	# 下身
	for i in range(24):
		var w: int = 16 + i/2
		_rect(img, 32+ox - w/2, 54+oy+i, w, 1, c)
