extends RefCounted

class_name EnemyPixelArt

## EnemyPixelArt.gd - 程序化生成8个敌人的像素立绘
## 调用 create_texture(enemy_id) → ImageTexture
## BattleScene 在 _setup_enemy() 时调用，赋给 TextureRect

## 全部8个敌人像素数据（32×48 格式，用调色板索引编码）
## 0=透明, 1=主色1, 2=主色2, 3=高光, 4=阴影, 5=轮廓, 6=眼/特征色

## 固定种子 RNG，保证每次渲染结果一致（不随帧变化）
static var _rng: RandomNumberGenerator = null

static func _get_rng(seed_val: int = 12345) -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val
	return _rng

static func create_texture(enemy_id: String) -> ImageTexture:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	_draw_enemy(img, enemy_id)
	img.resize(64, 96, Image.INTERPOLATE_NEAREST)   # 2x 放大保持像素感
	return ImageTexture.create_from_image(img)

static func _draw_enemy(img: Image, enemy_id: String) -> void:
	match enemy_id:
		"gu_hun_you_ling": _draw_gu_hun(img)
		"yuan_gui":        _draw_yuan_gui(img)
		"she_mi_yan":      _draw_she_mi(img)
		"lv_tou_gui":      _draw_lv_tou(img)
		"shan_huo_gui":    _draw_shan_huo(img)
		"shuigui_wanggui": _draw_shuigui(img)
		"hanba_jiaoge":    _draw_hanba(img)
		"guixiniang_sujin":_draw_guixin(img)
		_: _draw_default(img)

# ─ 辅助：画单个像素 ─
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)

# ─ 辅助：画填充矩形 ─
static func _rect(img: Image, x:int, y:int, w:int, h:int, c:Color) -> void:
	for dy in h:
		for dx in w:
			_px(img, x+dx, y+dy, c)

# ─ 辅助：画圆（近似） ─
static func _circle(img: Image, cx:int, cy:int, r:int, c:Color) -> void:
	for dy in range(-r, r+1):
		for dx in range(-r, r+1):
			if dx*dx + dy*dy <= r*r:
				_px(img, cx+dx, cy+dy, c)

## ══════════════════════════════════════════════════════
##  孤魂游灵 (gu_hun_you_ling) — 第一层普通
##  半透明白蓝幽灵，飘带尾巴，茫然圆眼
## ══════════════════════════════════════════════════════
static func _draw_gu_hun(img: Image) -> void:
	var c_body  = Color(0.70, 0.80, 0.95, 0.75)
	var c_glow  = Color(0.85, 0.90, 1.00, 0.55)
	var c_eye   = Color(0.08, 0.08, 0.15, 0.95)
	var c_tail  = Color(0.60, 0.72, 0.90, 0.45)

	# 飘带尾巴
	for i in 8:
		var alpha_tail = c_tail; alpha_tail.a = 0.35 + i*0.03
		_rect(img, 10+i/2, 28+i*2, 12-i, 2, alpha_tail)

	# 身体（椭圆近似）
	_circle(img, 16, 18, 8, c_body)
	_circle(img, 16, 18, 6, c_glow)

	# 眼睛（2个空洞）
	_circle(img, 13, 16, 2, c_eye)
	_circle(img, 19, 16, 2, c_eye)

	# 悲伤嘴（下弧）
	for x in range(13, 20):
		_px(img, x, 22 + (abs(x-16)), c_eye)

## ══════════════════════════════════════════════════════
##  怨鬼 (yuan_gui) — 第一层普通
##  暗红破碎形体，参差轮廓，愤怒眼神
## ══════════════════════════════════════════════════════
static func _draw_yuan_gui(img: Image) -> void:
	var c_body  = Color(0.50, 0.10, 0.10, 1.0)
	var c_dark  = Color(0.30, 0.05, 0.05, 1.0)
	var c_eye   = Color(1.00, 0.85, 0.15, 1.0)
	var c_crack = Color(0.20, 0.02, 0.02, 1.0)

	# 躯体（锯齿状矩形）
	_rect(img, 9, 10, 14, 22, c_body)
	# 锯齿头顶
	for i in [9,11,13,15,17,19,21]:
		_px(img, i, 9, c_body)
		_px(img, i, 8, c_dark)
	# 侧面阴影
	_rect(img, 9, 10, 2, 22, c_dark)
	_rect(img, 21, 10, 2, 22, c_dark)
	# 裂缝
	for y in range(12, 28):
		if y % 3 != 0:
			_px(img, 16, y, c_crack)
	# 愤怒眼（倒三角形）
	_rect(img, 11, 14, 4, 2, c_eye)
	_rect(img, 17, 14, 4, 2, c_eye)
	_px(img, 12, 13, c_eye); _px(img, 14, 13, c_eye)
	_px(img, 18, 13, c_eye); _px(img, 20, 13, c_eye)

## ══════════════════════════════════════════════════════
##  摄魅眼 (she_mi_yan) — 第二层普通
##  巨大单眼漂浮球，四条触须，蓝紫幽光
## ══════════════════════════════════════════════════════
static func _draw_she_mi(img: Image) -> void:
	var c_body   = Color(0.20, 0.10, 0.40, 1.0)
	var c_sclera = Color(0.85, 0.82, 0.78, 1.0)
	var c_iris   = Color(0.55, 0.10, 0.75, 1.0)
	var c_pupil  = Color(0.02, 0.01, 0.05, 1.0)
	var c_vein   = Color(0.70, 0.15, 0.15, 0.7)
	var c_tentacle = Color(0.25, 0.12, 0.45, 1.0)

	# 触须（4条，向四方延伸）
	for i in 5: _px(img, 6-i,  16+i, c_tentacle)
	for i in 5: _px(img, 26+i, 16+i, c_tentacle)
	for i in 4: _px(img, 16,   30+i, c_tentacle)
	for i in 3: _px(img, 16,   8-i,  c_tentacle)

	# 眼球体
	_circle(img, 16, 18, 10, c_body)
	_circle(img, 16, 18,  9, c_sclera)
	# 血丝
	for angle_deg in [30, 120, 210, 300]:
		var a = deg_to_rad(angle_deg)
		for r in range(6, 9):
			_px(img, int(16 + cos(a)*r), int(18 + sin(a)*r), c_vein)
	# 虹膜
	_circle(img, 16, 18, 5, c_iris)
	# 瞳孔
	_circle(img, 16, 18, 2, c_pupil)
	# 高光点
	_px(img, 18, 16, Color.WHITE)
	_px(img, 19, 15, Color(1,1,1,0.6))

## ══════════════════════════════════════════════════════
##  缕头鬼 (lv_tou_gui) — 第二层普通
##  长发遮面女鬼，只露出一双赤红眼，白色碎发
## ══════════════════════════════════════════════════════
static func _draw_lv_tou(img: Image) -> void:
	var c_hair  = Color(0.08, 0.06, 0.08, 1.0)
	var c_skin  = Color(0.78, 0.72, 0.68, 1.0)
	var c_eye   = Color(0.85, 0.10, 0.10, 1.0)
	var c_robe  = Color(0.55, 0.50, 0.60, 1.0)
	var c_dark  = Color(0.15, 0.12, 0.18, 1.0)

	# 身体/长袍
	_rect(img, 10, 24, 12, 20, c_robe)
	_rect(img, 10, 24, 12, 20, c_dark)
	_rect(img, 11, 24, 10, 18, c_robe)

	# 头
	_rect(img, 9, 8, 14, 18, c_skin)
	# 长发（从头顶到腰）- 使用固定种子 RNG 保证一致性
	var rng = _get_rng(77331)
	for x in range(9, 23):
		var hair_len = 28 + abs(x - 16) * 2
		for y in range(6, min(hair_len, 46)):
			if x < 11 or x > 21 or y < 10:
				_px(img, x, y, c_hair)
			elif y < 14:
				# 刘海（遮住上半部分脸）
				if rng.randf() > 0.35:
					_px(img, x, y, c_hair)
	# 露出的眼睛（发缝间）
	_rect(img, 13, 17, 3, 2, c_eye)
	_rect(img, 18, 17, 3, 2, c_eye)
	# 发光感
	_px(img, 14, 18, Color(1, 0.3, 0.3, 0.7))
	_px(img, 19, 18, Color(1, 0.3, 0.3, 0.7))

## ══════════════════════════════════════════════════════
##  闪火鬼 (shan_huo_gui) — 第三层普通
##  火焰包裹的奔跑骷髅，橙黄外焰，白骨内里
## ══════════════════════════════════════════════════════
static func _draw_shan_huo(img: Image) -> void:
	var c_bone   = Color(0.88, 0.84, 0.78, 1.0)
	var c_fire1  = Color(0.95, 0.55, 0.05, 1.0)
	var c_fire2  = Color(0.95, 0.88, 0.15, 0.8)
	var c_shadow = Color(0.20, 0.08, 0.02, 1.0)
	var c_eye    = Color(0.98, 0.95, 0.30, 1.0)

	# 火焰外轮廓（不规则三角上冲）- 使用固定种子 RNG
	var rng = _get_rng(55512)
	for x in range(8, 24):
		var h = 20 - abs(x-16)*2 + rng.randi() % 4
		for y in range(max(4, 14-h), 38):
			if y >= 14 - h:
				_px(img, x, y, c_fire1)
	# 内焰
	for x in range(11, 21):
		for y in range(18, 36):
			if abs(x-16) < 4: _px(img, x, y, c_fire2)

	# 骨骼（头+躯干）
	_circle(img, 16, 14, 5, c_bone)
	_rect(img, 14, 19, 4, 10, c_bone)  # 躯干
	# 肋骨
	for y in [21, 24]:
		_rect(img, 12, y, 3, 1, c_bone)
		_rect(img, 17, y, 3, 1, c_bone)
	# 眼睛（火焰色空洞）
	_circle(img, 14, 13, 1, c_eye)
	_circle(img, 18, 13, 1, c_eye)
	# 地面阴影
	_rect(img, 10, 44, 12, 2, c_shadow)

## ══════════════════════════════════════════════════════
##  水鬼·望归 (shuigui_wanggui) — Boss 第一层
##  溺水者，半透明水蓝，双臂上举渴望，面容模糊
## ══════════════════════════════════════════════════════
static func _draw_shuigui(img: Image) -> void:
	var c_water  = Color(0.25, 0.55, 0.78, 0.85)
	var c_deep   = Color(0.10, 0.30, 0.55, 0.90)
	var c_foam   = Color(0.70, 0.88, 0.95, 0.65)
	var c_eye    = Color(0.02, 0.04, 0.12, 0.95)
	var c_hair   = Color(0.12, 0.18, 0.30, 0.90)

	# 飘散的身体（水柱形）
	_rect(img, 11, 16, 10, 26, c_water)
	_rect(img, 12, 15, 8, 2, c_water)
	# 水纹质感
	for y in range(16, 42, 3):
		for x in [11, 20]:
			_px(img, x, y, c_foam)
	# 头
	_circle(img, 16, 11, 7, c_water)
	_circle(img, 16, 10, 5, c_foam)
	# 飘散长发
	for i in 6:
		_rect(img, 9-i, 8+i*2, 3, 2, c_hair)
		_rect(img, 21+i, 8+i*2, 3, 2, c_hair)
	# 上举的手臂
	_rect(img, 6, 14, 5, 3, c_water)
	_rect(img, 21, 12, 5, 3, c_water)
	_rect(img, 5, 10, 3, 4, c_water)   # 左手上抬
	_rect(img, 24, 8, 3, 4, c_water)   # 右手更高
	# 面部（模糊，只有眼睛轮廓）
	for x in range(13, 16): _px(img, x, 11, c_eye)
	for x in range(18, 21): _px(img, x, 11, c_eye)
	# 眼泪
	for y in range(13, 17): _px(img, 14, y, Color(0.5,0.75,0.9,0.8))
	# 深色边缘
	for y in range(16, 42):
		_px(img, 11, y, c_deep); _px(img, 20, y, c_deep)

## ══════════════════════════════════════════════════════
##  旱魃·焦骨 (hanba_jiaoge) — Boss 第二层
##  干裂橙红骨架，背后火焰光环，手持焦木杖
## ══════════════════════════════════════════════════════
static func _draw_hanba(img: Image) -> void:
	var c_bone   = Color(0.72, 0.42, 0.15, 1.0)
	var c_char   = Color(0.20, 0.08, 0.02, 1.0)
	var c_fire   = Color(0.95, 0.55, 0.08, 0.9)
	var c_glow   = Color(0.98, 0.88, 0.20, 0.7)
	var c_eye    = Color(1.00, 0.90, 0.20, 1.0)
	var c_crack  = Color(0.45, 0.18, 0.04, 1.0)

	# 背后火焰光环
	for angle_deg in range(0, 360, 15):
		var a = deg_to_rad(angle_deg)
		for r in range(10, 14):
			var fx: int = int(16 + cos(a)*r)
			var fy: int = int(16 + sin(a)*r)
			if fy < 20:   # 只画上半部分
				_px(img, fx, fy, c_glow if r < 12 else c_fire)

	# 骨骼躯干
	_rect(img, 13, 14, 6, 20, c_bone)
	# 肩部扩展
	_rect(img, 9, 14, 14, 4, c_bone)
	# 手臂（左伸右握杖）
	_rect(img, 5, 14, 8, 3, c_bone)   # 左臂伸展
	_rect(img, 19, 14, 8, 3, c_bone)  # 右臂持杖
	# 头骨
	_circle(img, 16, 9, 6, c_bone)
	# 裂缝纹路
	for y in range(14, 34, 4):
		_px(img, 15, y, c_crack); _px(img, 17, y, c_crack)
	# 眼睛（燃烧状）
	_circle(img, 13, 8, 2, c_eye)
	_circle(img, 19, 8, 2, c_eye)
	_circle(img, 13, 8, 1, Color(1,1,0.3))
	_circle(img, 19, 8, 1, Color(1,1,0.3))
	# 焦木杖
	for y in range(10, 46):
		_px(img, 27, y, c_char)
		if y % 3 == 0: _px(img, 26, y, c_fire)
	# 炭化阴影
	_rect(img, 13, 14, 6, 20, Color(0,0,0,0))  # 擦除中间（已画）
	for x in [13, 18]:
		for y in range(14, 34, 2):
			_px(img, x, y, c_char)

## ══════════════════════════════════════════════════════
##  鬼新娘·素锦 (guixiniang_sujin) — Boss 第三层
##  白衣红头纱，盘发高冠，手持红烛
## ══════════════════════════════════════════════════════
static func _draw_guixin(img: Image) -> void:
	var c_robe   = Color(0.92, 0.90, 0.88, 1.0)
	var c_veil   = Color(0.88, 0.15, 0.18, 0.85)
	var c_skin   = Color(0.82, 0.78, 0.72, 1.0)
	var c_hair   = Color(0.06, 0.04, 0.06, 1.0)
	var c_candle = Color(1.00, 0.90, 0.25, 1.0)
	var c_flame  = Color(0.95, 0.45, 0.10, 0.9)
	var c_eye    = Color(0.55, 0.05, 0.05, 1.0)
	var c_border = Color(0.60, 0.10, 0.15, 1.0)

	# 白色长袍（宽摆）
	for y in range(22, 46):
		var width = 8 + (y - 22) / 3
		_rect(img, 16-width/2, y, width, 1, c_robe)
	_rect(img, 12, 22, 8, 22, c_robe)

	# 袍边装饰
	for y in range(22, 46, 2):
		_px(img, 12, y, c_border)
		_px(img, 19, y, c_border)

	# 手持红烛（左手）
	_rect(img, 7, 20, 2, 12, c_candle)
	_rect(img, 7, 18, 2, 3,  Color(0.9,0.85,0.75))  # 蜡烛体
	_circle(img, 8, 17, 2, c_flame)   # 烛火
	_px(img, 8, 15, Color(1,0.95,0.5,0.7))  # 光晕

	# 身体
	_rect(img, 12, 14, 8, 10, c_skin)

	# 头
	_circle(img, 16, 9, 6, c_skin)

	# 盘发高冠
	_rect(img, 12, 3, 8, 6, c_hair)
	_rect(img, 14, 1, 4, 3, c_hair)
	_px(img, 15, 0, c_hair); _px(img, 16, 0, c_hair); _px(img, 17, 0, c_hair)

	# 红头纱（覆盖脸的上半部分）
	for y in range(4, 13):
		var veil_w = 10 - abs(y-8)
		_rect(img, 16 - veil_w/2, y, veil_w, 1, Color(c_veil.r, c_veil.g, c_veil.b, 0.65 + y*0.02))

	# 嘴（露出的）
	for x in range(14, 19):
		_px(img, x, 13, Color(0.7, 0.15, 0.15))
	# 眼（纱下透出的红光）
	_rect(img, 13, 9, 2, 1, c_eye)
	_rect(img, 18, 9, 2, 1, c_eye)

## 默认：无法识别 id 时画通用幽灵
static func _draw_default(img: Image) -> void:
	_circle(img, 16, 20, 10, Color(0.6, 0.6, 0.7, 0.8))
	_circle(img, 13, 18, 2, Color(0.1, 0.1, 0.2))
	_circle(img, 19, 18, 2, Color(0.1, 0.1, 0.2))
