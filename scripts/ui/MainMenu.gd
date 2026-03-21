extends Node2D

## MainMenu.gd - 主菜单场景

@onready var title_label    = $UI/TitleLabel
@onready var subtitle_label = $UI/SubtitleLabel
@onready var new_game_btn   = $UI/ButtonContainer/NewGameBtn
@onready var continue_btn   = $UI/ButtonContainer/ContinueBtn
@onready var quit_btn       = $UI/ButtonContainer/QuitBtn
@onready var version_label  = $UI/VersionLabel
@onready var ink_particles  = $InkParticles
@onready var bg_canvas      = $BgCanvas

const VERSION = "v0.1 Demo"

func _ready() -> void:
	# 存档检查
	continue_btn.disabled = not GameState.has_save()

	# 按钮信号
	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	quit_btn.pressed.connect(get_tree().quit)

	version_label.text = VERSION
	version_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("micro"))
	version_label.add_theme_color_override("font_color", UIConstants.color_of("gold_dim"))

	# 用代码生成水墨背景（程序化，不依赖外部贴图）
	_draw_ink_bg()
	_setup_particles()
	_setup_menu_visual_style()

	# 入场动画
	title_label.modulate.a    = 0.0
	subtitle_label.modulate.a = 0.0
	for btn in $UI/ButtonContainer.get_children():
		btn.modulate.a = 0.0

	var tw = create_tween().set_parallel(false)
	tw.tween_property(title_label,    "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.2)
	tw.tween_property(subtitle_label, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.15)
	# 按钮依次淡入
	for i in $UI/ButtonContainer.get_children().size():
		var btn = $UI/ButtonContainer.get_children()[i]
		tw.tween_property(btn, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.08)

	# 标题永久轻微浮动
	var float_tw = title_label.create_tween().set_loops()
	float_tw.tween_property(title_label, "position:y",
		title_label.position.y - 6.0, 2.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	float_tw.tween_property(title_label, "position:y",
		title_label.position.y,        2.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

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
		# 读档失败（文件损坏）→ 直接新游戏
		continue_btn.text     = "存档损坏"
		continue_btn.disabled = true

func _transition_to(scene_path: String) -> void:
	# 使用 TransitionManager 统一过场体验
	var title_map = {
		"res://scenes/MapScene.tscn": "踏上渡魂之路"
	}
	TransitionManager.change_scene(scene_path, title_map.get(scene_path, ""))

## 程序化水墨背景 ─────────────────────────────

func _draw_ink_bg() -> void:
	if not bg_canvas: return
	bg_canvas.draw.connect(_bg_draw)
	bg_canvas.queue_redraw()

func _bg_draw() -> void:
	# 由 BgCanvas（Node2D）的 _draw 方法绘制
	pass   # 实际在 BgCanvas 节点上绑定 _draw，这里留空

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
		btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
		btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
