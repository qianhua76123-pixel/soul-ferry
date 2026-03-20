extends Node2D

## ShopScene.gd - 渡魂商店
## 随机展示3张可购买牌卡，支持移除牌卡，使用金币交易


# ========== 节点引用 ==========
@onready var gold_label: Label = $UI/GoldLabel
@onready var cards_container: HBoxContainer = $UI/CardsForSale
@onready var remove_btn: Button = $UI/RemoveSection/RemoveButton
@onready var remove_label: Label = $UI/RemoveSection/RemoveLabel
@onready var leave_btn: Button = $UI/LeaveButton
@onready var remove_panel: Panel = $UI/RemovePanel
@onready var remove_deck_container: GridContainer = $UI/RemovePanel/DeckGrid
@onready var remove_cancel_btn: Button = $UI/RemovePanel/CancelBtn

const CARD_PRICE_COMMON = 60
const CARD_PRICE_RARE = 120
const CARD_PRICE_LEGENDARY = 200
const REMOVE_PRICE = 75

var _shop_cards: Array = []
var _card_scene: PackedScene = preload("res://scenes/CardUI.tscn")

# ========== 初始化 ==========
func _ready() -> void:
	TransitionManager.fade_in_only()
	remove_panel.visible = false
	leave_btn.pressed.connect(_on_leave_pressed)
	remove_btn.pressed.connect(_on_remove_pressed)
	remove_cancel_btn.pressed.connect(func(): remove_panel.visible = false)

	GameState.gold_changed.connect(_on_gold_changed)
	_update_gold_label()
	_generate_shop()
	_setup_shop_visual()

func _generate_shop() -> void:
	_shop_cards = CardDatabase.get_reward_cards(3)

	for child in cards_container.get_children():
		child.queue_free()

	for card in _shop_cards:
		var slot = _build_shop_slot(card)
		cards_container.add_child(slot)

## 构建单个商店卡槽（牌卡 + 价格 + 购买按钮）
func _build_shop_slot(card: Dictionary) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(110, 220)

	# 牌卡 UI
	var card_ui = _card_scene.instantiate() as CardUINode
	card_ui.setup(card)
	card_ui.set_playable(false)  # 商店里不能直接出牌
	vbox.add_child(card_ui)

	# 价格标签
	var price = _get_price(card)
	var price_label = Label.new()
	price_label.text = "💰 %d" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(price_label)

	# 购买按钮
	var buy_btn = Button.new()
	buy_btn.text = "购买"
	buy_btn.disabled = GameState.gold < price
	var captured_card = card
	var captured_price = price
	var captured_btn = buy_btn
	buy_btn.pressed.connect(func(): _on_buy_card(captured_card, captured_price, captured_btn, vbox))
	vbox.add_child(buy_btn)

	return vbox

func _get_price(card: Dictionary) -> int:
	match card.get("rarity", "common"):
		"rare":      return CARD_PRICE_RARE
		"legendary": return CARD_PRICE_LEGENDARY
		_:           return CARD_PRICE_COMMON

func _on_buy_card(card: Dictionary, price: int, btn: Button, slot: VBoxContainer) -> void:
	if not GameState.spend_gold(price):
		return
	DeckManager.add_card_to_deck(card)
	# 标记已购买
	btn.text = "已购买"
	btn.disabled = true
	slot.modulate = Color(0.5, 0.5, 0.5)

# ========== 移除牌卡 ==========

func _on_remove_pressed() -> void:
	if GameState.gold < REMOVE_PRICE:
		remove_label.text = "移除一张牌（%d金币）— 金币不足" % REMOVE_PRICE
		return

	# 展示全部牌库供选择
	remove_panel.visible = true
	for child in remove_deck_container.get_children():
		child.queue_free()

	var full_deck = DeckManager.get_full_deck()
	for card in full_deck:
		var card_ui = _card_scene.instantiate() as CardUINode
		card_ui.setup(card)
		card_ui.set_playable(true)
		var captured = card
		card_ui.card_clicked.connect(func(c): _on_remove_card_selected(c))
		remove_deck_container.add_child(card_ui)

func _on_remove_card_selected(card: Dictionary) -> void:
	if not GameState.spend_gold(REMOVE_PRICE):
		return
	DeckManager.remove_card_from_deck(card.get("id", ""))
	remove_panel.visible = false

# ========== 其他 ==========

func _on_gold_changed(_old: int, _new: int) -> void:
	_update_gold_label()
	_update_gold_display()

func _update_gold_label() -> void:
	gold_label.text = "💰 %d" % int(GameState.gold)

func _on_leave_pressed() -> void:
	TransitionManager.change_scene("res://scenes/MapScene.tscn")

func _update_gold_display() -> void:
	gold_label.text = "💰 %d" % int(GameState.gold)
	# 金色闪光反馈
	var tw = gold_label.create_tween()
	tw.tween_property(gold_label, "modulate", Color(1.5, 1.3, 0.5), 0.1)
	tw.tween_property(gold_label, "modulate", Color(1.0, 1.0, 1.0), 0.4)

func _setup_shop_visual() -> void:
	## 商店场景氛围：烛光面板 + 金币高亮

	# 背景色（深棕暖色）
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.05, 0.02, 1.0)
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	# 标题面板
	var title_lbl = Label.new()
	title_lbl.text = "渡 魂 商 店"
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.76, 0.08))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_lbl.position.y = 24
	add_child(title_lbl)

	# 烛火装饰（两侧各一）
	for side in [-1, 1]:
		var candle = Label.new()
		candle.text = "🕯"
		candle.add_theme_font_size_override("font_size", 28)
		candle.position = Vector2(608 + side * 180, 20)
		add_child(candle)
		# 烛光闪烁动画
		var tw = candle.create_tween().set_loops()
		tw.tween_property(candle, "modulate:a", 0.65, 0.9 + side * 0.15)
		tw.tween_property(candle, "modulate:a", 1.0,  0.9 + side * 0.15)

	# 金币标签样式增强
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.add_theme_color_override("font_color", Color(0.95, 0.76, 0.08))

	# 离开按钮样式
	var leave_style = StyleBoxFlat.new()
	leave_style.bg_color     = Color(0.12, 0.08, 0.04)
	leave_style.border_color = Color(0.55, 0.42, 0.08)
	leave_style.set_border_width_all(2)
	leave_style.set_corner_radius_all(4)
	leave_btn.add_theme_stylebox_override("normal", leave_style)
	leave_btn.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	leave_btn.add_theme_font_size_override("font_size", 14)
