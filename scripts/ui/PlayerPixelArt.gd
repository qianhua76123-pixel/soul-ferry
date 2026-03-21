extends RefCounted

class_name PlayerPixelArt

## PlayerPixelArt.gd - 渡魂人主角程序化像素立绘
## 调用 create_texture(state) → ImageTexture
## state: "idle" / "attack" / "hurt" / "dead"
##
## 渡魂人形象设定：
##   - 身穿青灰色道袍，腰束朱红宽带
##   - 头戴方形道冠（黑底金边）
##   - 手持长幡（白底红符文）
##   - 面容清瘦，眉目沉静
##   - 整体色调：青灰 · 朱红 · 墨黑 · 纸白

## 画布：32×48，2倍放大到 64×96（像素感）

static func create_texture(state: String = "idle") -> ImageTexture:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	_draw_player(img, state)
	img.resize(64, 96, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

static func _draw_player(img: Image, state: String) -> void:
	match state:
		"idle":   _draw_idle(img)
		"attack": _draw_attack(img)
		"hurt":   _draw_hurt(img)
		"dead":   _draw_dead(img)
		_:        _draw_idle(img)

# ── 辅助 ──────────────────────────────────────────────
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)

static func _rect(img: Image, x:int, y:int, w:int, h:int, c:Color) -> void:
	for dy in h:
		for dx in w:
			_px(img, x+dx, y+dy, c)

static func _circle(img: Image, cx:int, cy:int, r:int, c:Color) -> void:
	for dy in range(-r, r+1):
		for dx in range(-r, r+1):
			if dx*dx + dy*dy <= r*r:
				_px(img, cx+dx, cy+dy, c)

static func _line(img: Image, x0:int, y0:int, x1:int, y1:int, c:Color) -> void:
	var dx: int = abs(x1-x0); var dy = abs(y1-y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	while true:
		_px(img, x0, y0, c)
		if x0 == x1 and y0 == y1: break
		var e2 = 2 * err
		if e2 > -dy: err -= dy; x0 += sx
		if e2 < dx:  err += dx; y0 += sy

# ══════════════════════════════════════════════════════
#  调色板
# ══════════════════════════════════════════════════════
# 道袍：青灰系
const C_ROBE_MID  = Color(0.35, 0.42, 0.45, 1.0)   # 青灰主色
const C_ROBE_DARK = Color(0.22, 0.28, 0.32, 1.0)   # 袍褶阴影
const C_ROBE_LITE = Color(0.48, 0.56, 0.58, 1.0)   # 袍褶高光
# 腰带：朱红
const C_SASH      = Color(0.62, 0.12, 0.12, 1.0)   # 腰带主色
const C_SASH_DARK = Color(0.40, 0.06, 0.06, 1.0)   # 腰带阴影
# 道冠：黑底金边
const C_CROWN_BG  = Color(0.10, 0.08, 0.08, 1.0)   # 冠体黑
const C_CROWN_RIM = Color(0.72, 0.55, 0.08, 1.0)   # 冠沿金色
# 肤色
const C_SKIN      = Color(0.84, 0.76, 0.66, 1.0)   # 脸/手
const C_SKIN_DARK = Color(0.65, 0.55, 0.45, 1.0)   # 脸部阴影
# 幡：白底红字
const C_BANNER    = Color(0.92, 0.89, 0.82, 1.0)   # 幡面纸白
const C_BANNER_RD = Color(0.72, 0.10, 0.10, 1.0)   # 幡面朱红符文
const C_BANNER_PL = Color(0.18, 0.14, 0.10, 1.0)   # 幡杆深棕
# 墨黑轮廓
const C_OUTLINE   = Color(0.08, 0.06, 0.06, 1.0)
# 头发
const C_HAIR      = Color(0.10, 0.08, 0.08, 1.0)
# 眼睛
const C_EYE       = Color(0.15, 0.10, 0.08, 1.0)
const C_EYE_WH    = Color(0.90, 0.88, 0.82, 1.0)

# ══════════════════════════════════════════════════════
#  内部：绘制共用身体部件
# ══════════════════════════════════════════════════════

## 道冠（头顶方形冠）
static func _draw_crown(img: Image, head_y: int) -> void:
	# 冠体（方形，略宽于头部）
	_rect(img, 12, head_y - 5, 8, 5, C_CROWN_BG)
	# 金色冠沿（底边+左右）
	_rect(img, 11, head_y - 1, 10, 1, C_CROWN_RIM)
	_px(img,  11, head_y - 2, C_CROWN_RIM)
	_px(img,  20, head_y - 2, C_CROWN_RIM)
	# 冠顶金色细线
	_rect(img, 13, head_y - 5, 6, 1, C_CROWN_RIM)
	# 冠中竖线装饰
	_px(img, 16, head_y - 4, C_CROWN_RIM)
	_px(img, 16, head_y - 3, C_CROWN_RIM)

## 头部（脸+耳+发）
static func _draw_head(img: Image, head_y: int, blink: bool = false) -> void:
	# 面部底色
	_circle(img, 16, head_y + 3, 5, C_SKIN)
	# 耳朵
	_px(img, 11, head_y + 3, C_SKIN)
	_px(img, 21, head_y + 3, C_SKIN)
	# 发鬓（冠两侧露出的发）
	for y in range(head_y, head_y + 4):
		_px(img, 11, y, C_HAIR)
		_px(img, 21, y, C_HAIR)
	# 脸部细节：眉毛
	_rect(img, 13, head_y + 1, 2, 1, C_OUTLINE)
	_rect(img, 17, head_y + 1, 2, 1, C_OUTLINE)
	# 眼睛
	if blink:
		_rect(img, 13, head_y + 3, 2, 1, C_OUTLINE)
		_rect(img, 17, head_y + 3, 2, 1, C_OUTLINE)
	else:
		_px(img, 14, head_y + 3, C_EYE_WH)
		_px(img, 14, head_y + 3, C_EYE)
		_px(img, 18, head_y + 3, C_EYE_WH)
		_px(img, 18, head_y + 3, C_EYE)
		# 眼神沉静：细长单眼皮
		_px(img, 13, head_y + 2, C_OUTLINE)
		_px(img, 14, head_y + 2, C_OUTLINE)
		_px(img, 15, head_y + 2, C_OUTLINE)
		_px(img, 17, head_y + 2, C_OUTLINE)
		_px(img, 18, head_y + 2, C_OUTLINE)
		_px(img, 19, head_y + 2, C_OUTLINE)
	# 鼻梁（一个像素）
	_px(img, 16, head_y + 4, C_SKIN_DARK)
	# 嘴（薄唇）
	_px(img, 15, head_y + 5, C_SKIN_DARK)
	_px(img, 16, head_y + 5, C_SKIN_DARK)
	_px(img, 17, head_y + 5, C_SKIN_DARK)
	# 下颌阴影
	_px(img, 13, head_y + 6, C_SKIN_DARK)
	_px(img, 19, head_y + 6, C_SKIN_DARK)

## 道袍躯干（站立）
static func _draw_body_robe(img: Image, torso_y: int) -> void:
	# 躯干主体
	_rect(img, 12, torso_y, 8, 12, C_ROBE_MID)
	# 左侧阴影（袍褶）
	_rect(img, 12, torso_y, 2, 12, C_ROBE_DARK)
	_rect(img, 18, torso_y, 2, 12, C_ROBE_DARK)
	# 高光（中央偏左）
	_rect(img, 14, torso_y, 2, 10, C_ROBE_LITE)
	# 领口 V 形
	_px(img, 15, torso_y,     C_SKIN)
	_px(img, 16, torso_y,     C_SKIN)
	_px(img, 16, torso_y + 1, C_SKIN)
	# 腰带
	_rect(img, 11, torso_y + 9, 10, 3, C_SASH)
	_rect(img, 11, torso_y + 11, 10, 1, C_SASH_DARK)
	# 腰带中央结扣
	_rect(img, 15, torso_y + 9, 2, 3, C_SASH_DARK)

## 下袍+腿（站立）
static func _draw_lower_robe(img: Image, waist_y: int) -> void:
	# 下袍（向下展开的 A 字形）
	for i in range(16):
		var w = 8 + i / 2
		var x = 16 - w / 2
		_rect(img, x, waist_y + i, w, 1, C_ROBE_MID)
		# 褶皱阴影
		if i % 4 == 0:
			_px(img, x, waist_y + i, C_ROBE_DARK)
			_px(img, x + w - 1, waist_y + i, C_ROBE_DARK)
	# 袍底
	_rect(img, 8, waist_y + 15, 16, 1, C_ROBE_DARK)
	# 鞋尖（黑色翘头）
	_rect(img, 11, waist_y + 16, 4, 2, C_OUTLINE)
	_rect(img, 17, waist_y + 16, 4, 2, C_OUTLINE)
	_px(img, 10, waist_y + 16, C_OUTLINE)
	_px(img, 21, waist_y + 16, C_OUTLINE)

## 左臂（持幡手，自然下垂）
static func _draw_arm_left(img: Image, shoulder_y: int) -> void:
	# 上臂
	_rect(img, 9, shoulder_y, 3, 7, C_ROBE_MID)
	_px(img, 9, shoulder_y,     C_ROBE_DARK)
	_px(img, 9, shoulder_y + 1, C_ROBE_DARK)
	# 前臂
	_rect(img, 8, shoulder_y + 7, 3, 5, C_ROBE_DARK)
	# 手（持幡杆）
	_rect(img, 8, shoulder_y + 12, 3, 3, C_SKIN)
	_px(img, 8, shoulder_y + 12, C_SKIN_DARK)

## 右臂（空手，微微前伸/道法手势）
static func _draw_arm_right(img: Image, shoulder_y: int, raised: bool = false) -> void:
	var offset_y = -4 if raised else 0
	# 上臂
	_rect(img, 20, shoulder_y + offset_y, 3, 7, C_ROBE_MID)
	_px(img, 22, shoulder_y + offset_y, C_ROBE_DARK)
	# 前臂
	_rect(img, 21, shoulder_y + 7 + offset_y, 3, 5, C_ROBE_LITE)
	# 手（道法手势：食指上指）
	_rect(img, 21, shoulder_y + 12 + offset_y, 3, 3, C_SKIN)
	if raised:
		# 伸出食指（施法）
		_px(img, 22, shoulder_y + 11 + offset_y, C_SKIN)
		_px(img, 22, shoulder_y + 10 + offset_y, C_SKIN)
		# 朱砂指尖（施法时发光）
		_px(img, 22, shoulder_y + 9 + offset_y, Color(0.85, 0.20, 0.20, 0.9))

## 长幡（左手持，垂直挂下）
static func _draw_banner(img: Image, pole_x: int, pole_top_y: int) -> void:
	# 幡杆（从手部到画布顶端）
	for y in range(0, pole_top_y + 16):
		_px(img, pole_x, y, C_BANNER_PL)
	# 幡横木
	_rect(img, pole_x - 3, 2, 7, 1, C_BANNER_PL)
	# 幡面（宽6，高14，从横木下垂）
	_rect(img, pole_x - 2, 3, 6, 14, C_BANNER)
	# 幡边装饰（朱红边框）
	for y in range(3, 17):
		_px(img, pole_x - 2, y, C_BANNER_RD)
		_px(img, pole_x + 3, y, C_BANNER_RD)
	_rect(img, pole_x - 2, 3,  6, 1, C_BANNER_RD)
	_rect(img, pole_x - 2, 16, 6, 1, C_BANNER_RD)
	# 幡面符文（"渡"字简化笔画）
	# 横笔
	_rect(img, pole_x - 1, 5,  4, 1, C_BANNER_RD)
	_rect(img, pole_x - 1, 8,  4, 1, C_BANNER_RD)
	_rect(img, pole_x - 1, 11, 4, 1, C_BANNER_RD)
	_rect(img, pole_x - 1, 14, 4, 1, C_BANNER_RD)
	# 竖笔（中央）
	for y in range(5, 15):
		_px(img, pole_x, y, C_BANNER_RD)
	# 幡脚穗（3条细线）
	for dx in [-1, 0, 1]:
		for y in range(17, 21):
			_px(img, pole_x + dx, y, C_BANNER_RD if y % 2 == 0 else C_BANNER)

# ══════════════════════════════════════════════════════
#  状态立绘
# ══════════════════════════════════════════════════════

## 站立·持幡待机
static func _draw_idle(img: Image) -> void:
	_draw_banner(img, 7, 18)          # 幡（左侧，从顶延伸到手）
	_draw_lower_robe(img, 31)         # 下袍
	_draw_body_robe(img, 19)          # 躯干
	_draw_arm_left(img, 20)           # 左臂（持幡）
	_draw_arm_right(img, 20, false)   # 右臂（自然）
	_draw_head(img, 8)                # 头
	_draw_crown(img, 8)               # 道冠

## 施法·右手前伸发光
static func _draw_attack(img: Image) -> void:
	_draw_banner(img, 7, 18)
	_draw_lower_robe(img, 31)
	_draw_body_robe(img, 19)
	_draw_arm_left(img, 20)
	_draw_arm_right(img, 20, true)    # 右臂上举施法
	_draw_head(img, 8)
	_draw_crown(img, 8)
	# 施法光效（右手指尖放射）
	_px(img, 24, 18, Color(0.95, 0.75, 0.20, 0.8))
	_px(img, 25, 17, Color(0.95, 0.75, 0.20, 0.5))
	_px(img, 25, 19, Color(0.95, 0.75, 0.20, 0.5))
	_px(img, 26, 18, Color(0.85, 0.55, 0.10, 0.35))

## 受击·身体后仰，道冠微斜
static func _draw_hurt(img: Image) -> void:
	_draw_banner(img, 9, 20)          # 幡随后仰偏移
	_draw_lower_robe(img, 32)         # 下袍略低
	# 躯干向右偏1像素
	_rect(img, 13, 20, 8, 12, C_ROBE_MID)
	_rect(img, 13, 20, 2, 12, C_ROBE_DARK)
	_rect(img, 19, 20, 2, 12, C_ROBE_DARK)
	_rect(img, 15, 20, 2, 10, C_ROBE_LITE)
	_rect(img, 12, 29, 10, 3, C_SASH)
	_rect(img, 12, 31, 10, 1, C_SASH_DARK)
	_rect(img, 16, 29, 2, 3, C_SASH_DARK)
	_draw_arm_left(img, 21)
	_draw_arm_right(img, 21, false)
	_draw_head(img, 9, false)
	# 道冠（后仰微斜，右移1）
	_rect(img, 13, 4, 8, 5, C_CROWN_BG)
	_rect(img, 12, 8, 10, 1, C_CROWN_RIM)
	_rect(img, 14, 4, 6, 1, C_CROWN_RIM)
	_px(img, 17, 5, C_CROWN_RIM)
	_px(img, 17, 6, C_CROWN_RIM)
	# 受伤发红（整体色调偏红）
	for y in range(8, 48):
		for x in range(8, 24):
			var cur = img.get_pixel(x, y)
			if cur.a > 0.1:
				img.set_pixel(x, y, Color(
					min(1.0, cur.r + 0.15),
					cur.g * 0.88,
					cur.b * 0.88,
					cur.a
				))

## 死亡·倒地（横向）
static func _draw_dead(img: Image) -> void:
	# 整体旋转效果：用横向布局模拟倒地
	# 幡斜倒（左上到右下）
	_line(img, 4, 20, 20, 36, C_BANNER_PL)
	_rect(img, 5, 18, 5, 5, C_BANNER)
	_rect(img, 5, 18, 1, 5, C_BANNER_RD)
	_rect(img, 9, 18, 1, 5, C_BANNER_RD)

	# 躯体（横躺，从左到右）
	_rect(img, 4, 26, 24, 8, C_ROBE_MID)    # 袍（水平方向）
	_rect(img, 4, 26, 24, 2, C_ROBE_DARK)   # 上轮廓
	_rect(img, 4, 32, 24, 2, C_ROBE_DARK)   # 下轮廓
	_rect(img, 4, 27, 5, 6,  C_ROBE_LITE)   # 高光（左）
	# 腰带
	_rect(img, 14, 26, 4, 8, C_SASH)

	# 头（右侧，圆形）
	_circle(img, 27, 29, 5, C_SKIN)
	# 眼睛（闭合/×）
	_px(img, 25, 28, C_OUTLINE); _px(img, 26, 27, C_OUTLINE)
	_px(img, 27, 28, C_OUTLINE); _px(img, 28, 27, C_OUTLINE)
	_px(img, 29, 28, C_OUTLINE)
	_px(img, 25, 30, C_OUTLINE); _px(img, 26, 31, C_OUTLINE)
	_px(img, 27, 30, C_OUTLINE); _px(img, 28, 31, C_OUTLINE)
	_px(img, 29, 30, C_OUTLINE)

	# 道冠（倒落在头旁）
	_rect(img, 22, 22, 8, 4, C_CROWN_BG)
	_rect(img, 22, 25, 8, 1, C_CROWN_RIM)

	# 整体变灰（死亡色调）
	for y in range(0, 48):
		for x in range(0, 32):
			var cur = img.get_pixel(x, y)
			if cur.a > 0.1:
				var gray = cur.r * 0.3 + cur.g * 0.59 + cur.b * 0.11
				img.set_pixel(x, y, Color(
					gray * 0.7 + cur.r * 0.3,
					gray * 0.7 + cur.g * 0.3,
					gray * 0.7 + cur.b * 0.3,
					cur.a * 0.85
				))
