extends Node2D

## CardRewardScene.gd - 战斗胜利，选择一张牌加入牌库

signal reward_taken(card: Dictionary)

@onready var title_label:    Label          = $UI/Title
@onready var flavor_label:   Label          = $UI/Flavor
@onready var card_container: HBoxContainer  = $UI/CardRow
@onready var skip_btn:       Button         = $UI/SkipBtn
@onready var gold_label:     Label          = $UI/GoldLabel

var _card_scene: PackedScene = preload("res://scenes/CardUI.tscn")
var _reward_cards: Array = []

func _ready() -> void:
	TransitionManager.fade_in_only()
	skip_btn.pressed.connect(_on_skip)
	_show_rewards()
	_update_gold()
	GameState.gold_changed.connect(func(_o,_n): _update_gold())
	_setup_reward_visual()

func _show_rewards() -> void:
	_reward_cards = CardDatabase.get_reward_cards(3)
	for child in card_container.get_children():
		child.queue_free()
	for card in _reward_cards:
		var slot: Control = _build_slot(card)
		card_container.add_child(slot)

func _build_slot(card: Dictionary) -> VBoxContainer:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(110, 200)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var card_ui: Node = _card_scene.instantiate()
	if card_ui.has_method("setup"):
		card_ui.setup(card)
	if card_ui.has_method("set_playable"):
		card_ui.set_playable(true)
	card_ui.card_clicked.connect(func(c): _on_card_chosen(c))
	vbox.add_child(card_ui)
	# 稀有度标签
	var rarity_lbl: Label = Label.new()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.text = {"common":"普通","rare":"★ 稀有","legendary":"★★ 传说"}.get(card.get("rarity","common"),"普通")
	vbox.add_child(rarity_lbl)
	return vbox

func _on_card_chosen(card: Dictionary) -> void:
	DeckManager.add_card_to_deck(card)
	reward_taken.emit(card)
	TransitionManager.change_scene("res://scenes/MapScene.tscn")

func _on_skip() -> void:
	# 跳过奖励：补偿金币
	GameState.gain_gold(40)
	TransitionManager.change_scene("res://scenes/MapScene.tscn")

func _update_gold() -> void:
	gold_label.text = "%s %d" % [UIConstants.ICONS["coin"], int(GameState.gold)]

func _setup_reward_visual() -> void:
	## 奖励场景视觉：暗金色背景 + 标题动画 + 卡牌星尘入场
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.02, 1.0)
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	# 顶部金色细线装饰
	var line: WaterInkDivider = WaterInkDivider.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.custom_minimum_size = Vector2(0, 8)
	line.position.y = 52
	line.ink_color = UIConstants.color_of("gold_dim")
	add_child(line)

	# 标题样式
	if title_label:
		title_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("title"))
		title_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))
		# 入场浮动
		title_label.modulate.a = 0.0
		var tw: Tween = title_label.create_tween()
		tw.tween_property(title_label, "modulate:a", 1.0, 0.6)

	# 跳过按钮样式
	if skip_btn:
		var sty: StyleBox = UIConstants.make_button_style("parch", "gold_dim")
		skip_btn.add_theme_stylebox_override("normal", sty)
		skip_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
		skip_btn.add_theme_color_override("font_color", UIConstants.color_of("text_muted"))

	# 卡牌依次淡入（给 CardRow 的子节点加延迟）
	await get_tree().process_frame
	var delay = 0.15
	for slot in card_container.get_children():
		slot.modulate.a = 0.0
		var tw2: Tween = slot.create_tween()
		tw2.tween_interval(delay)
		tw2.tween_property(slot, "modulate:a", 1.0, 0.25)
		tw2.parallel().tween_property(slot, "position:y", slot.position.y,  0.25)
		delay += 0.12
