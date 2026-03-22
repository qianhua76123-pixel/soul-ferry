extends Node2D

## CardRewardScene.gd - 战斗胜利选牌奖励（完整重写）
## 全屏水墨风格，三牌居中，点击选牌动画，跳过给金币

signal reward_taken(card: Dictionary)

@onready var title_label:    Label          = $UI/Title
@onready var flavor_label:   Label          = $UI/Flavor
@onready var card_container: HBoxContainer  = $UI/CardRow
@onready var skip_btn:       Button         = $UI/SkipBtn
@onready var gold_label:     Label          = $UI/GoldLabel

var _card_scene: PackedScene = preload("res://scenes/CardUI.tscn")
var _reward_cards: Array = []
var _chosen: bool = false

func _ready() -> void:
	TransitionManager.fade_in_only()
	skip_btn.pressed.connect(_on_skip)
	_setup_visual()
	_show_rewards()
	_update_gold()
	GameState.gold_changed.connect(func(_o, _n): _update_gold())

# ════════════════════════════════════════════════════════
#  视觉设置
# ════════════════════════════════════════════════════════

func _setup_visual() -> void:
	# 背景
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.02, 1.0)
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	# 水墨粒子氛围（轻量，几个漂浮点）
	for i in 6:
		var dot: ColorRect = ColorRect.new()
		dot.size = Vector2(2, 2)
		dot.color = Color(0.78, 0.60, 0.10, randf_range(0.15, 0.35))
		dot.position = Vector2(randf_range(60, 1220), randf_range(100, 620))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		var tw: Tween = dot.create_tween().set_loops()
		tw.tween_property(dot, "position:y", dot.position.y - randf_range(30, 70),
			randf_range(3.0, 6.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(dot, "position:y", dot.position.y,
			randf_range(3.0, 6.0)).set_trans(Tween.TRANS_SINE)

	# 顶部水墨分割线
	var line: WaterInkDivider = WaterInkDivider.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.custom_minimum_size = Vector2(0, 6)
	line.offset_top = 56
	line.offset_bottom = 62
	line.ink_color = UIConstants.color_of("gold_dim")
	add_child(line)

	# 标题样式
	if title_label:
		title_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("title"))
		title_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))
		title_label.modulate.a = 0.0
		var tw2: Tween = title_label.create_tween()
		tw2.tween_property(title_label, "modulate:a", 1.0, 0.5)

	if flavor_label:
		flavor_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))
		flavor_label.add_theme_color_override("font_color", UIConstants.color_of("text_secondary"))
		flavor_label.modulate.a = 0.0
		var tw3: Tween = flavor_label.create_tween()
		tw3.tween_interval(0.3)
		tw3.tween_property(flavor_label, "modulate:a", 1.0, 0.4)

	# 跳过按钮
	if skip_btn:
		skip_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
		skip_btn.add_theme_stylebox_override("hover",  UIConstants.make_button_style("parch", "gold"))
		skip_btn.add_theme_color_override("font_color", UIConstants.color_of("text_muted"))
		skip_btn.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
		skip_btn.text = "跳过（获得 40 金币）"

# ════════════════════════════════════════════════════════
#  卡牌奖励
# ════════════════════════════════════════════════════════

func _show_rewards() -> void:
	_reward_cards = CardDatabase.get_reward_cards(3)
	for child in card_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	var delay: float = 0.10
	for card in _reward_cards:
		var slot: Control = _build_slot(card)
		slot.modulate.a = 0.0
		slot.position.y += 20.0
		card_container.add_child(slot)
		# 入场动画：从下淡入
		var tw: Tween = slot.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(slot, "modulate:a", 1.0, 0.30)
		tw.parallel().tween_property(slot, "position:y", slot.position.y - 20.0, 0.30)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += 0.12

func _build_slot(card: Dictionary) -> VBoxContainer:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(140, 230)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)

	# 卡牌主体
	var card_ui: Node = _card_scene.instantiate()
	if card_ui.has_method("setup"):
		card_ui.setup(card)
	if card_ui.has_method("set_playable"):
		card_ui.set_playable(true)
	card_ui.card_clicked.connect(func(c): _on_card_chosen(c))
	vbox.add_child(card_ui)

	# 稀有度标签
	var rarity_map: Dictionary = {
		"common":    ["普通",    Color(0.75, 0.73, 0.68)],
		"rare":      ["★ 稀有",  Color(0.40, 0.65, 0.90)],
		"legendary": ["★★ 传说", Color(0.90, 0.75, 0.20)],
	}
	var rarity: String = card.get("rarity", "common")
	var rdata: Array = rarity_map.get(rarity, rarity_map["common"])
	var rarity_lbl: Label = Label.new()
	rarity_lbl.text = str(rdata[0])
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	rarity_lbl.add_theme_color_override("font_color", rdata[1])
	vbox.add_child(rarity_lbl)

	# 悬停高亮边框
	var hover_rect: Panel = Panel.new()
	hover_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_rect.z_index = 10
	var hs: StyleBoxFlat = StyleBoxFlat.new()
	hs.bg_color = Color.TRANSPARENT
	hs.border_color = UIConstants.color_of("gold")
	hs.set_border_width_all(0)
	hs.set_corner_radius_all(6)
	hover_rect.add_theme_stylebox_override("panel", hs)
	hover_rect.visible = false
	vbox.add_child(hover_rect)

	vbox.mouse_entered.connect(func():
		hs.set_border_width_all(2)
		hover_rect.visible = true
		var htw: Tween = vbox.create_tween()
		htw.tween_property(vbox, "scale", Vector2(1.04, 1.04), 0.12)
	)
	vbox.mouse_exited.connect(func():
		hover_rect.visible = false
		hs.set_border_width_all(0)
		var htw: Tween = vbox.create_tween()
		htw.tween_property(vbox, "scale", Vector2(1.0, 1.0), 0.10)
	)

	return vbox

# ════════════════════════════════════════════════════════
#  选牌逻辑
# ════════════════════════════════════════════════════════

func _on_card_chosen(card: Dictionary) -> void:
	if _chosen: return
	_chosen = true

	DeckManager.add_card_to_deck(card)
	reward_taken.emit(card)

	# 选中时全屏金光闪烁
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(0.90, 0.72, 0.10, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 100
	add_child(flash)
	var ftw: Tween = flash.create_tween()
	ftw.tween_property(flash, "color:a", 0.35, 0.12)
	ftw.tween_property(flash, "color:a", 0.0,  0.35)

	# 延迟跳转，让动画播完
	await get_tree().create_timer(0.55).timeout
	TransitionManager.change_scene("res://scenes/MapScene.tscn")

func _on_skip() -> void:
	if _chosen: return
	_chosen = true
	GameState.gain_gold(40)
	TransitionManager.change_scene("res://scenes/MapScene.tscn")

func _update_gold() -> void:
	if gold_label:
		gold_label.text = "%s %d" % [UIConstants.ICONS["coin"], int(GameState.gold)]
