extends Node2D

## MainMenu.gd - 主菜单场景（M-01 视觉升级）

const UIC = preload("res://scripts/ui/UIConstants.gd")
const WaterInkDividerClass = preload("res://scripts/ui/WaterInkDivider.gd")

@onready var title_label:    Label           = $UI/TitleLabel
@onready var subtitle_label: Label           = $UI/SubtitleLabel
@onready var new_game_btn:   Button          = $UI/ButtonContainer/NewGameBtn
@onready var continue_btn:   Button          = $UI/ButtonContainer/ContinueBtn
@onready var quit_btn:       Button          = $UI/ButtonContainer/QuitBtn
@onready var version_label:  Label           = $UI/VersionLabel
@onready var ink_particles:  GPUParticles2D  = $InkParticles
@onready var bg_canvas:      Node2D          = $BgCanvas

const VERSION = "✦ v0.1 Demo"

# 保存标题原始 y，用于进场动画
var _title_origin_y: float = 0.0

func _ready() -> void:
	# ── 版本号 ─────────────────────────────────
	var vl = get_node_or_null("UI/VersionLabel")
	if vl:
		vl.text = VERSION
		vl.add_theme_color_override("font_color", Color(0.420, 0.353, 0.188))
		vl.add_theme_font_size_override("font_size", 10)

	# ── 存档检查 ───────────────────────────────
	var has_save: bool = GameState.has_save()

	# ── 按钮样式 ───────────────────────────────
	_style_new_game_btn()
	_style_continue_btn(has_save)
	_style_quit_btn()

	# ── 按钮信号 ───────────────────────────────
	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	quit_btn.pressed.connect(get_tree().quit)

	version_label.text = VERSION
	version_label.add_theme_font_size_override("font_size", UIC.font_size_of("micro"))
	version_label.add_theme_color_override("font_color", UIC.color_of("gold_dim"))

	# 用代码生成水墨背景（程序化，不依赖外部贴图）
	_draw_ink_bg()
	_setup_particles()
	_setup_menu_visual_style()

	# ── 标题下方分割线（WaterInkDivider） ─────
	_insert_water_divider()

	# ── 进场动画 ──────────────────────────────
	_play_enter_animation()

## 按钮样式 ─────────────────────────────────────

func _make_flat_style(bg: Color, border: Color, border_w: int = 1) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(0)
	s.content_margin_left   = 12.0
	s.content_margin_right  = 12.0
	s.content_margin_top    = 8.0
	s.content_margin_bottom = 8.0
	return s

func _style_new_game_btn() -> void:
	var btn = get_node_or_null("UI/ButtonContainer/NewGameBtn")
	if not btn: return
	btn.text = "✦  踏  上  旅  途"
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.784, 0.663, 0.431))

	var normal = _make_flat_style(Color(0.102, 0.082, 0.031, 0.7),  Color(0.784, 0.663, 0.431))
	var hover  = _make_flat_style(Color(0.18,  0.15,  0.07,  0.85), Color(1.0,   0.85,  0.55))
	var focus  = hover.duplicate()
	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("focus",   focus)
	btn.add_theme_stylebox_override("pressed", hover)

func _style_continue_btn(has_save: bool) -> void:
	var btn = get_node_or_null("UI/ButtonContainer/ContinueBtn")
	if not btn: return
	btn.text = "继  续  渡  魂"
	btn.add_theme_font_size_override("font_size", 16)

	if has_save:
		var gold_dim = Color(0.420, 0.353, 0.188)
		btn.add_theme_color_override("font_color", Color(0.784, 0.663, 0.431))
		var normal = _make_flat_style(Color(0.102, 0.082, 0.031, 0.7),  gold_dim)
		var hover  = _make_flat_style(Color(0.18,  0.15,  0.07,  0.85), Color(0.784, 0.663, 0.431))
		var focus  = hover.duplicate()
		btn.add_theme_stylebox_override("normal",  normal)
		btn.add_theme_stylebox_override("hover",   hover)
		btn.add_theme_stylebox_override("focus",   focus)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.disabled = false
	else:
		btn.add_theme_color_override("font_color", Color(0.604, 0.565, 0.502))
		var dim = _make_flat_style(Color(0.102, 0.082, 0.031, 0.3), Color(0.420, 0.353, 0.188, 0.4))
		btn.add_theme_stylebox_override("normal",   dim)
		btn.add_theme_stylebox_override("hover",    dim)
		btn.add_theme_stylebox_override("focus",    dim)
		btn.add_theme_stylebox_override("disabled", dim)
		btn.disabled = true

func _style_quit_btn() -> void:
	var btn = get_node_or_null("UI/ButtonContainer/QuitBtn")
	if not btn: return
	btn.text = "就  此  搁  笔"
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.604, 0.565, 0.502))

	# 透明底无边框
	var transparent = StyleBoxFlat.new()
	transparent.bg_color = Color(0, 0, 0, 0)
	transparent.set_border_width_all(0)
	transparent.set_corner_radius_all(0)
	transparent.content_margin_left   = 12.0
	transparent.content_margin_right  = 12.0
	transparent.content_margin_top    = 8.0
	transparent.content_margin_bottom = 8.0

	# hover 底色带朱砂边
	var hover_s = _make_flat_style(Color(0.12, 0.04, 0.04, 0.3), Color(0.753, 0.224, 0.169, 0.5))
	btn.add_theme_stylebox_override("normal",  transparent)
	btn.add_theme_stylebox_override("focus",   transparent)
	btn.add_theme_stylebox_override("pressed", hover_s)
	btn.add_theme_stylebox_override("hover",   hover_s)

	# hover 文字颜色通过 mouse_entered / mouse_exited 信号动态切换
	btn.mouse_entered.connect(func():
		btn.add_theme_color_override("font_color", Color(0.753, 0.224, 0.169))
	)
	btn.mouse_exited.connect(func():
		btn.add_theme_color_override("font_color", Color(0.604, 0.565, 0.502))
	)

## 水墨背景竖线（叠加在 BgCanvas 上，用新 Node2D） ──

func _draw_ink_bg() -> void:
	var overlay = Node2D.new()
	overlay.name = "InkLinesOverlay"

	# 用内部类持有绘制逻辑
	overlay.set_script(null)  # 普通 Node2D，通过 draw 信号绑定

	# 连接绘制信号
	overlay.draw.connect(_draw_ink_lines.bind(overlay))

	if bg_canvas:
		bg_canvas.add_child(overlay)
	else:
		# fallback：加到自身
		add_child(overlay)

	overlay.queue_redraw()

func _draw_ink_lines(node: Node2D) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var W = 1280.0
	var H = 720.0

	for _i in 30:
		var x      = rng.randf_range(0.0, W)
		var w_line = rng.randf_range(1.0, 2.0)
		var h_line = rng.randf_range(400.0, 700.0)
		var y_start = rng.randf_range(0.0, H - h_line)
		var alpha  = rng.randf_range(0.03, 0.05)
		var col    = Color(0.784, 0.663, 0.431, alpha)
		node.draw_line(Vector2(x, y_start), Vector2(x, y_start + h_line), col, w_line)

## 标题下方 WaterInkDivider ──────────────────────

func _insert_water_divider() -> void:
	var ui_layer = get_node_or_null("UI")
	if not ui_layer: return

	var btn_container = get_node_or_null("UI/ButtonContainer")
	if not btn_container: return

	var divider: Control = WaterInkDividerClass.new()
	divider.name = "TitleDivider"
	divider.custom_minimum_size = Vector2(300.0, 2.0)
	# 与按钮容器同层，放在 ButtonContainer 之前
	# 先添加到 UI
	ui_layer.add_child(divider)
	# 放到 ButtonContainer 同 CanvasLayer，位置在副标题下方
	# 水平居中
	var sub = get_node_or_null("UI/SubtitleLabel")
	if sub:
		divider.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		divider.offset_left  = -150.0
		divider.offset_right =  150.0
		divider.offset_top   = sub.offset_top + 40.0
		divider.offset_bottom = sub.offset_top + 42.0
	else:
		divider.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		divider.offset_left  = -150.0
		divider.offset_right =  150.0
		divider.offset_top   = 310.0
		divider.offset_bottom = 312.0

	# 初始隐藏，留给进场动画
	divider.modulate.a = 0.0
	divider.scale.x    = 0.0

## 进场动画 ─────────────────────────────────────

func _play_enter_animation() -> void:
	var tl = get_node_or_null("UI/TitleLabel")
	var sl = get_node_or_null("UI/SubtitleLabel")
	var div = get_node_or_null("UI/TitleDivider")
	var bc  = get_node_or_null("UI/ButtonContainer")

	# 初始化隐藏状态
	if tl:
		_title_origin_y = tl.offset_top
		tl.modulate.a   = 0.0
		tl.offset_top   = _title_origin_y + 20.0

	if sl:
		sl.modulate.a = 0.0

	if bc:
		for btn in bc.get_children():
			btn.modulate.a = 0.0

	# 构建链式 Tween
	var tw = create_tween().set_parallel(false)

	# a. 标题淡入 + 上移归位（0.8s）
	if tl:
		tw.tween_property(tl, "modulate:a",   1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		# 平行：位置归位
		tw.parallel().tween_property(tl, "offset_top", _title_origin_y, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 等待 0.5s 后副标题
	tw.tween_interval(0.5)

	# b. 副标题淡入（0.4s）
	if sl:
		tw.tween_property(sl, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)

	# c. 分割线从中间展开（1.0s 后开始，即从头算 0+0.8+0.5+0.4=1.7，但相对先等 1.0-0.5-0.4=0.1 的 interval）
	tw.tween_interval(0.1)
	if div:
		tw.tween_property(div, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(div, "scale:x", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		tw.tween_interval(0.3)

	# d. 按钮逐个淡入（1.3s 后，即上面动画完毕后再等 0.0s，已经在约 1.3s 处）
	tw.tween_interval(0.0)
	if bc:
		var btns = bc.get_children()
		for i in btns.size():
			var btn = btns[i]
			tw.tween_property(btn, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
			if i < btns.size() - 1:
				tw.tween_interval(0.15)

	# ── 标题永久轻微浮动（进场后启动） ──
	if tl:
		tw.tween_callback(func():
			var float_tw = tl.create_tween().set_loops()
			float_tw.tween_property(tl, "offset_top",
				_title_origin_y - 6.0, 2.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			float_tw.tween_property(tl, "offset_top",
				_title_origin_y,        2.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		)

## 按钮回调 ───────────────────────────────────

func _on_new_game() -> void:
	GameState.delete_save()
	GameState.new_run()
	DeckManager.init_starter_deck()
	_transition_to("res://scenes/MapScene.tscn")

func _on_continue() -> void:
	if GameState.load_from_file():
		_transition_to("res://scenes/MapScene.tscn")
	else:
		var cb = get_node_or_null("UI/ButtonContainer/ContinueBtn")
		if cb:
			cb.text     = "存档损坏"
			cb.disabled = true

func _transition_to(scene_path: String) -> void:
	var title_map = {
		"res://scenes/MapScene.tscn": "踏上渡魂之路"
	}
	TransitionManager.change_scene(scene_path, title_map.get(scene_path, ""))

## 粒子参数（在 _ready 里动态设置，因为 .tscn 不存 GDScript 属性） ─────
func _setup_particles() -> void:
	if not ink_particles: return
	ink_particles.amount        = 35
	ink_particles.lifetime      = 8.0
	ink_particles.emitting      = true
	ink_particles.local_coords  = false

	var mat = ParticleProcessMaterial.new()
	mat.direction           = Vector3(0, 1, 0)
	mat.spread              = 40.0
	mat.gravity             = Vector3(0, 18, 0)
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 35.0
	mat.angular_velocity_min = -90.0
	mat.angular_velocity_max =  90.0
	mat.scale_min            = 2.0
	mat.scale_max            = 5.0
	# 颜色：深墨色，低透明度
	var grad = Gradient.new()
	grad.colors = [Color(0.10,0.08,0.07,0.0), Color(0.10,0.08,0.07,0.22), Color(0.08,0.06,0.05,0.0)]
	grad.offsets= [0.0, 0.4, 1.0]
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	ink_particles.process_material = mat
	ink_particles.position          = Vector2(640, -20)

	# Godot 4：GPUParticles2D 使用 texture 作为粒子外形，不再有 draw_pass_1 / QuadMesh
	# 细长竖条（接近提示词 1×4px 意象，略放大以便过滤）
	var strip := Image.create(2, 8, false, Image.FORMAT_RGBA8)
	strip.fill(Color(1, 1, 1, 1))
	ink_particles.texture = ImageTexture.create_from_image(strip)

func _setup_menu_visual_style() -> void:
	for btn in [new_game_btn, continue_btn, quit_btn]:
		btn.add_theme_stylebox_override("normal", UIC.make_button_style("parch", "gold_dim"))
		btn.add_theme_stylebox_override("hover", UIC.make_button_style("parch", "gold"))
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
