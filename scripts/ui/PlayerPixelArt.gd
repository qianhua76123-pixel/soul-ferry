extends RefCounted
class_name PlayerPixelArt

## PlayerPixelArt.gd - 三角色程序化像素立绘
## create_texture(state, char_id) → ImageTexture
## char_id: "ruan_ruyue" / "shen_tiejun" / "wumian" / ""（从 GameState 读）
## state:   "idle" / "attack" / "hurt" / "dead"

static func create_texture(state: String = "idle", char_id: String = "") -> ImageTexture:
	var cid: String = char_id
	if cid == "":
		cid = str(GameState.get_meta("selected_character", "ruan_ruyue"))
	var img: Image = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	match cid:
		"shen_tiejun": _draw_shen(img, state)
		"wumian":      _draw_wumian(img, state)
		_:             _draw_ruan(img, state)
	img.resize(64, 96, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

# ── 辅助 ──────────────────────────────────────────────
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

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx: int = abs(x1-x0); var dy: int = abs(y1-y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy
	while true:
		_px(img, x0, y0, c)
		if x0 == x1 and y0 == y1: break
		var e2: int = 2 * err
		if e2 > -dy: err -= dy; x0 += sx
		if e2 < dx:  err += dx; y0 += sy

# ══════════════════════════════════════════════════════
#  阮如月 — 青灰道袍，持渡魂幡
# ══════════════════════════════════════════════════════
const RY_ROBE   := Color(0.35, 0.42, 0.45, 1.0)
const RY_DARK   := Color(0.22, 0.28, 0.32, 1.0)
const RY_LITE   := Color(0.48, 0.56, 0.58, 1.0)
const RY_SASH   := Color(0.62, 0.12, 0.12, 1.0)
const RY_CROWN  := Color(0.10, 0.08, 0.08, 1.0)
const RY_GOLD   := Color(0.72, 0.55, 0.08, 1.0)
const RY_SKIN   := Color(0.84, 0.76, 0.66, 1.0)
const RY_SKND   := Color(0.65, 0.55, 0.45, 1.0)
const RY_BANN   := Color(0.92, 0.89, 0.82, 1.0)
const RY_RED    := Color(0.72, 0.10, 0.10, 1.0)
const RY_POLE   := Color(0.18, 0.14, 0.10, 1.0)
const RY_INK    := Color(0.08, 0.06, 0.06, 1.0)
const RY_HAIR   := Color(0.10, 0.08, 0.08, 1.0)

static func _draw_ruan(img: Image, state: String) -> void:
	match state:
		"attack": _ruan_attack(img)
		"hurt":   _ruan_hurt(img)
		"dead":   _ruan_dead(img)
		_:        _ruan_idle(img)

static func _ruan_banner(img: Image, ox: int = 0, oy: int = 0) -> void:
	for y in range(0, 19 + oy): _px(img, 7+ox, y, RY_POLE)
	_rect(img, 4+ox, 2+oy, 7, 1, RY_POLE)
	_rect(img, 5+ox, 3+oy, 6, 14, RY_BANN)
	for y in range(3+oy, 17+oy):
		_px(img, 5+ox, y, RY_RED); _px(img, 10+ox, y, RY_RED)
	_rect(img, 5+ox, 3+oy, 6, 1, RY_RED); _rect(img, 5+ox, 16+oy, 6, 1, RY_RED)
	_rect(img, 6+ox, 5+oy, 4, 1, RY_RED); _rect(img, 6+ox, 8+oy, 4, 1, RY_RED)
	_rect(img, 6+ox, 11+oy, 4, 1, RY_RED); _rect(img, 6+ox, 14+oy, 4, 1, RY_RED)
	for y in range(5+oy, 15+oy): _px(img, 7+ox, y, RY_RED)

static func _ruan_head(img: Image, hx: int, hy: int) -> void:
	_circle(img, hx, hy+3, 5, RY_SKIN)
	_px(img, hx-5, hy+3, RY_SKIN); _px(img, hx+5, hy+3, RY_SKIN)
	for y in range(hy, hy+4): _px(img, hx-5, y, RY_HAIR); _px(img, hx+5, y, RY_HAIR)
	_rect(img, hx-3, hy+1, 2, 1, RY_INK); _rect(img, hx+1, hy+1, 2, 1, RY_INK)
	_px(img, hx-2, hy+3, RY_INK); _px(img, hx+2, hy+3, RY_INK)
	_rect(img, hx-3, hy+2, 3, 1, RY_INK); _rect(img, hx+1, hy+2, 3, 1, RY_INK)
	_px(img, hx, hy+4, RY_SKND)
	_px(img, hx-1, hy+5, RY_SKND); _px(img, hx, hy+5, RY_SKND); _px(img, hx+1, hy+5, RY_SKND)
	# 道冠
	_rect(img, hx-4, hy-5, 8, 5, RY_CROWN)
	_rect(img, hx-5, hy-1, 10, 1, RY_GOLD)
	_rect(img, hx-3, hy-5, 6, 1, RY_GOLD)
	_px(img, hx, hy-4, RY_GOLD); _px(img, hx, hy-3, RY_GOLD)

static func _ruan_body(img: Image) -> void:
	_rect(img, 12, 19, 8, 12, RY_ROBE)
	_rect(img, 12, 19, 2, 12, RY_DARK); _rect(img, 18, 19, 2, 12, RY_DARK)
	_rect(img, 14, 19, 2, 10, RY_LITE)
	_px(img, 15, 19, RY_SKIN); _px(img, 16, 19, RY_SKIN); _px(img, 16, 20, RY_SKIN)
	_rect(img, 11, 28, 10, 3, RY_SASH)
	for i in range(16):
		var w: int = 8 + i/2; var x: int = 16 - w/2
		_rect(img, x, 31+i, w, 1, RY_ROBE)
		if i % 4 == 0: _px(img, x, 31+i, RY_DARK); _px(img, x+w-1, 31+i, RY_DARK)
	_rect(img, 8, 46, 16, 1, RY_DARK)
	_rect(img, 11, 47, 4, 1, RY_INK); _rect(img, 17, 47, 4, 1, RY_INK)

static func _ruan_idle(img: Image) -> void:
	_ruan_banner(img)
	_ruan_body(img)
	_rect(img, 9, 20, 3, 12, RY_ROBE); _rect(img, 9, 20, 1, 12, RY_DARK)
	_rect(img, 8, 32, 3, 5, RY_DARK); _rect(img, 8, 37, 3, 3, RY_SKIN)
	_rect(img, 20, 20, 3, 7, RY_ROBE); _rect(img, 22, 20, 1, 7, RY_DARK)
	_rect(img, 21, 27, 3, 5, RY_LITE); _rect(img, 21, 32, 3, 3, RY_SKIN)
	_ruan_head(img, 16, 8)

static func _ruan_attack(img: Image) -> void:
	_ruan_banner(img)
	_ruan_body(img)
	_rect(img, 9, 20, 3, 12, RY_ROBE); _rect(img, 9, 20, 1, 12, RY_DARK)
	_rect(img, 8, 32, 3, 5, RY_DARK); _rect(img, 8, 37, 3, 3, RY_SKIN)
	_rect(img, 20, 16, 3, 7, RY_ROBE); _rect(img, 22, 16, 1, 7, RY_DARK)
	_rect(img, 21, 23, 3, 5, RY_LITE); _rect(img, 21, 28, 3, 3, RY_SKIN)
	_px(img, 22, 15, RY_SKIN); _px(img, 22, 14, RY_SKIN)
	_px(img, 22, 13, Color(0.85, 0.20, 0.20, 0.9))
	_px(img, 24, 14, Color(0.95, 0.75, 0.20, 0.8))
	_px(img, 25, 13, Color(0.95, 0.75, 0.20, 0.5))
	_ruan_head(img, 16, 8)

static func _ruan_hurt(img: Image) -> void:
	_ruan_banner(img, 2, 2)
	_ruan_body(img)
	_rect(img, 9, 21, 3, 12, RY_ROBE)
	_rect(img, 20, 21, 3, 7, RY_ROBE); _rect(img, 21, 28, 3, 5, RY_LITE); _rect(img, 21, 33, 3, 3, RY_SKIN)
	_ruan_head(img, 17, 9)
	for y in range(8, 48):
		for x in range(8, 26):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.1: img.set_pixel(x, y, Color(minf(1.0,c.r+0.15), c.g*0.88, c.b*0.88, c.a))

static func _ruan_dead(img: Image) -> void:
	_line(img, 4, 20, 20, 36, RY_POLE)
	_rect(img, 5, 18, 5, 5, RY_BANN); _rect(img, 5, 18, 1, 5, RY_RED); _rect(img, 9, 18, 1, 5, RY_RED)
	_rect(img, 4, 26, 24, 8, RY_ROBE); _rect(img, 4, 26, 24, 2, RY_DARK)
	_rect(img, 14, 26, 4, 8, RY_SASH)
	_circle(img, 27, 29, 5, RY_SKIN)
	_rect(img, 22, 22, 8, 4, RY_CROWN); _rect(img, 22, 25, 8, 1, RY_GOLD)
	for y in range(0, 48):
		for x in range(0, 32):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.1:
				var g: float = c.r*0.3 + c.g*0.59 + c.b*0.11
				img.set_pixel(x, y, Color(g*0.7+c.r*0.3, g*0.7+c.g*0.3, g*0.7+c.b*0.3, c.a*0.85))

# ══════════════════════════════════════════════════════
#  沈铁钧 — 深蓝捕快服，铁链，宽肩厚实
# ══════════════════════════════════════════════════════
const SJ_COAT   := Color(0.15, 0.20, 0.32, 1.0)   # 捕快深蓝
const SJ_DARK   := Color(0.08, 0.12, 0.22, 1.0)
const SJ_LITE   := Color(0.25, 0.32, 0.48, 1.0)
const SJ_BELT   := Color(0.45, 0.30, 0.10, 1.0)   # 腰带棕皮
const SJ_CHAIN  := Color(0.55, 0.55, 0.58, 1.0)   # 铁链银灰
const SJ_CHAINL := Color(0.72, 0.72, 0.75, 1.0)   # 铁链高光
const SJ_SKIN   := Color(0.80, 0.70, 0.58, 1.0)   # 稍深肤色（老捕快）
const SJ_SKND   := Color(0.60, 0.50, 0.40, 1.0)
const SJ_HAIR   := Color(0.20, 0.16, 0.14, 1.0)   # 灰发（中年）
const SJ_INK    := Color(0.08, 0.06, 0.06, 1.0)
const SJ_BADGE  := Color(0.70, 0.52, 0.08, 1.0)   # 腰牌金色

static func _draw_shen(img: Image, state: String) -> void:
	match state:
		"attack": _shen_attack(img)
		"hurt":   _shen_hurt(img)
		"dead":   _shen_dead(img)
		_:        _shen_idle(img)

static func _shen_head(img: Image, hx: int, hy: int) -> void:
	# 宽脸方颌
	_rect(img, hx-5, hy, 11, 10, SJ_SKIN)
	_rect(img, hx-4, hy-1, 9, 1, SJ_SKIN)
	_rect(img, hx-3, hy+10, 7, 1, SJ_SKIN)
	# 发（两鬓灰白）
	_rect(img, hx-5, hy, 2, 6, SJ_HAIR)
	_rect(img, hx+4, hy, 2, 6, SJ_HAIR)
	_rect(img, hx-4, hy-2, 9, 2, SJ_HAIR)  # 头顶
	# 眉毛（浓）
	_rect(img, hx-3, hy+2, 3, 2, SJ_INK)
	_rect(img, hx+1, hy+2, 3, 2, SJ_INK)
	# 眼睛（锐利）
	_px(img, hx-2, hy+4, SJ_INK); _px(img, hx-1, hy+4, SJ_INK)
	_px(img, hx+1, hy+4, SJ_INK); _px(img, hx+2, hy+4, SJ_INK)
	# 鼻（宽）
	_rect(img, hx-1, hy+5, 3, 2, SJ_SKND)
	# 嘴（抿紧）
	_rect(img, hx-2, hy+7, 5, 1, SJ_INK)
	# 络腮胡（短）
	for bx in [hx-4, hx-3, hx+3, hx+4]:
		_rect(img, bx, hy+5, 1, 4, SJ_HAIR)

static func _shen_chain(img: Image, sx: int, sy: int, length: int) -> void:
	# 绘制铁链（交替圆环）
	var i: int = 0
	while i < length:
		if i % 4 < 2:
			_rect(img, sx,   sy+i, 3, 2, SJ_CHAIN)
			_px(img, sx+1, sy+i, SJ_CHAINL)
		else:
			_rect(img, sx-1, sy+i, 3, 2, SJ_CHAIN)
			_px(img, sx,   sy+i, SJ_CHAINL)
		i += 2

static func _shen_body(img: Image) -> void:
	# 宽肩捕快服躯干
	_rect(img, 10, 18, 12, 14, SJ_COAT)
	_rect(img, 10, 18, 2, 14, SJ_DARK); _rect(img, 20, 18, 2, 14, SJ_DARK)
	_rect(img, 12, 18, 3, 12, SJ_LITE)   # 高光
	# 领口
	_px(img, 15, 18, SJ_SKIN); _px(img, 16, 18, SJ_SKIN)
	_px(img, 15, 19, SJ_SKIN); _px(img, 16, 19, SJ_SKIN)
	# 腰带（皮）
	_rect(img, 10, 30, 12, 3, SJ_BELT)
	_px(img, 15, 30, SJ_BADGE); _px(img, 16, 30, SJ_BADGE)  # 腰牌
	_px(img, 15, 31, SJ_BADGE); _px(img, 16, 31, SJ_BADGE)
	# 下摆+腿（宽腿裤）
	_rect(img, 11, 33, 5, 14, SJ_COAT)
	_rect(img, 16, 33, 5, 14, SJ_COAT)
	_rect(img, 11, 33, 1, 14, SJ_DARK)
	_rect(img, 20, 33, 1, 14, SJ_DARK)
	# 靴子
	_rect(img, 10, 46, 6, 2, SJ_INK)
	_rect(img, 16, 46, 6, 2, SJ_INK)

static func _shen_idle(img: Image) -> void:
	_shen_body(img)
	# 左臂（持铁链）
	_rect(img, 7, 19, 4, 12, SJ_COAT); _rect(img, 7, 19, 1, 12, SJ_DARK)
	_rect(img, 7, 31, 3, 4, SJ_SKIN)
	_shen_chain(img, 5, 25, 12)   # 垂下的铁链
	# 右臂（叉腰）
	_rect(img, 21, 19, 4, 10, SJ_COAT); _rect(img, 24, 19, 1, 10, SJ_DARK)
	_rect(img, 21, 29, 3, 4, SJ_SKIN)
	_shen_head(img, 16, 5)

static func _shen_attack(img: Image) -> void:
	_shen_body(img)
	# 左臂大幅前伸（甩链）
	_rect(img, 5, 15, 4, 14, SJ_COAT); _rect(img, 5, 15, 1, 14, SJ_DARK)
	_rect(img, 4, 29, 4, 4, SJ_SKIN)
	# 甩出的铁链（弧线）
	_line(img, 6, 26, 2, 38, SJ_CHAIN)
	_line(img, 2, 38, 8, 44, SJ_CHAINL)
	_circle(img, 8, 44, 2, SJ_CHAIN)  # 链末端锁头
	# 右臂
	_rect(img, 21, 19, 4, 10, SJ_COAT); _rect(img, 24, 19, 1, 10, SJ_DARK)
	_rect(img, 21, 29, 3, 4, SJ_SKIN)
	_shen_head(img, 15, 4)

static func _shen_hurt(img: Image) -> void:
	_shen_body(img)
	_rect(img, 7, 20, 4, 12, SJ_COAT)
	_rect(img, 22, 20, 4, 10, SJ_COAT)
	_shen_head(img, 17, 6)
	for y in range(4, 48):
		for x in range(7, 25):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.1: img.set_pixel(x, y, Color(minf(1.0,c.r+0.18), c.g*0.85, c.b*0.85, c.a))

static func _shen_dead(img: Image) -> void:
	# 横躺
	_rect(img, 3, 24, 26, 10, SJ_COAT)
	_rect(img, 3, 24, 26, 2, SJ_DARK); _rect(img, 3, 32, 26, 2, SJ_DARK)
	_rect(img, 10, 24, 4, 10, SJ_BELT)
	_circle(img, 28, 28, 5, SJ_SKIN)
	_rect(img, 28-4, 22, 9, 2, SJ_HAIR)
	_shen_chain(img, 2, 36, 8)
	for y in range(0, 48):
		for x in range(0, 32):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.1:
				var g: float = c.r*0.3 + c.g*0.59 + c.b*0.11
				img.set_pixel(x, y, Color(g*0.7+c.r*0.3, g*0.7+c.g*0.3, g*0.7+c.b*0.3, c.a*0.85))

# ══════════════════════════════════════════════════════
#  无名（无面人）— 渐变灰白，无脸，形体模糊
# ══════════════════════════════════════════════════════
const WM_BODY   := Color(0.78, 0.78, 0.74, 1.0)   # 主体浅灰
const WM_SHADE  := Color(0.55, 0.55, 0.52, 1.0)   # 阴影
const WM_LITE   := Color(0.90, 0.90, 0.88, 1.0)   # 高光
const WM_EDGE   := Color(0.50, 0.50, 0.48, 1.0)   # 轮廓线
const WM_FACE   := Color(0.88, 0.88, 0.85, 1.0)   # 脸部（无特征，平整）
const WM_VOID   := Color(0.30, 0.30, 0.30, 0.4)   # 半透明虚影

static func _draw_wumian(img: Image, state: String) -> void:
	match state:
		"attack": _wumian_attack(img)
		"hurt":   _wumian_hurt(img)
		"dead":   _wumian_dead(img)
		_:        _wumian_idle(img)

static func _wumian_silhouette(img: Image, ox: int, oy: int, alpha: float) -> void:
	var body: Color = Color(WM_BODY.r, WM_BODY.g, WM_BODY.b, alpha)
	var shade: Color = Color(WM_SHADE.r, WM_SHADE.g, WM_SHADE.b, alpha)
	var lite: Color = Color(WM_LITE.r, WM_LITE.g, WM_LITE.b, alpha)
	var edge: Color = Color(WM_EDGE.r, WM_EDGE.g, WM_EDGE.b, alpha)
	var face: Color = Color(WM_FACE.r, WM_FACE.g, WM_FACE.b, alpha)
	# 头（无脸：平整椭圆）
	_circle(img, 16+ox, 8+oy, 6, face)
	_circle(img, 16+ox, 8+oy, 6, edge)    # 轮廓
	_circle(img, 16+ox, 8+oy, 5, face)    # 填充覆盖轮廓内部
	# 躯干（无缝外套）
	_rect(img, 12+ox, 15+oy, 8, 16, body)
	_rect(img, 12+ox, 15+oy, 1, 16, shade)
	_rect(img, 19+ox, 15+oy, 1, 16, shade)
	_rect(img, 13+ox, 15+oy, 2, 14, lite)
	# 下身
	for i in range(14):
		var w: int = 8 + i/3; var x: int = 16+ox - w/2
		_rect(img, x, 31+oy+i, w, 1, body if i%3 != 0 else shade)
	# 手臂（无接缝，与躯干同色）
	_rect(img, 9+ox, 16+oy, 3, 14, body)
	_rect(img, 9+ox, 16+oy, 1, 14, shade)
	_rect(img, 20+ox, 16+oy, 3, 14, body)
	_rect(img, 22+ox, 16+oy, 1, 14, shade)
	# 脚（渐隐）
	_rect(img, 11+ox, 45+oy, 4, 2, Color(body.r, body.g, body.b, alpha*0.6))
	_rect(img, 17+ox, 45+oy, 4, 2, Color(body.r, body.g, body.b, alpha*0.6))

static func _wumian_idle(img: Image) -> void:
	# 虚影（偏移2像素，半透明）
	_wumian_silhouette(img, 2, 0, 0.25)
	_wumian_silhouette(img, 0, 0, 1.0)
	# 头部虚光（空度感）
	for r in range(7, 10):
		for dy in range(-r, r+1):
			for dx in range(-r, r+1):
				if dx*dx + dy*dy >= (r-1)*(r-1) and dx*dx + dy*dy <= r*r:
					var alpha: float = 0.12 - r * 0.02
					_px(img, 16+dx, 8+dy, Color(0.9, 0.9, 0.88, alpha))

static func _wumian_attack(img: Image) -> void:
	_wumian_silhouette(img, 0, 0, 1.0)
	# 右手伸出，手掌区域有虚无发光（情绪吸收）
	_rect(img, 23, 22, 5, 5, WM_LITE)
	for i in range(3):
		_rect(img, 24+i, 20-i, 2, 2, Color(0.85, 0.85, 0.82, 0.6 - i*0.15))
	# 吸取的情绪粒子
	for pos in [[26,19],[28,21],[25,18],[29,23]]:
		_px(img, pos[0], pos[1], Color(0.7, 0.5, 0.8, 0.7))

static func _wumian_hurt(img: Image) -> void:
	# 受击时形体更透明，产生裂隙
	_wumian_silhouette(img, 0, 0, 0.7)
	# 裂隙（白色缝隙）
	_line(img, 14, 16, 18, 24, Color(1.0, 1.0, 0.95, 0.9))
	_line(img, 15, 16, 17, 22, Color(0.8, 0.8, 0.78, 0.5))

static func _wumian_dead(img: Image) -> void:
	# 消散：多层半透明轮廓
	for i in range(4):
		_wumian_silhouette(img, i*2-3, -i, 0.3 - i*0.06)
	# 中央最暗版本
	_wumian_silhouette(img, 0, 0, 0.15)
