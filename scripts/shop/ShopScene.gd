extends Node2D

## ShopScene.gd - 渡魂商店 (M-03 重设计)
## 左右分栏布局 · 金币充足性反馈 · InkedPanel 风格按钮 · 背景升级

const UIC = preload("res://scripts/ui/UIConstants.gd")
const WaterInkDividerClass = preload("res://scripts/ui/WaterInkDivider.gd")

# ========== 节点引用（防御性访问） ==========
@onready var gold_label: Label         = $UI/GoldLabel
@onready var cards_container: HBoxContainer = $UI/CardsForSale
@onready var remove_btn: Button        = $UI/RemoveSection/RemoveButton
@onready var remove_label: Label       = $UI/RemoveSection/RemoveLabel
@onready var leave_btn: Button         = $UI/LeaveButton
@onready var remove_panel: Panel       = $UI/RemovePanel
@onready var remove_deck_container: GridContainer = $UI/RemovePanel/DeckGrid
@onready var remove_cancel_btn: Button = $UI/RemovePanel/CancelBtn

const CARD_PRICE_COMMON   = 60
const CARD_PRICE_RARE     = 120
const CARD_PRICE_LEGENDARY = 200
const REMOVE_PRICE        = 75

var _shop_cards: Array = []
var _card_scene: PackedScene = preload("res://scenes/CardUI.tscn")

# 用于金币充足性刷新：存储每个卡槽的组件引用
# 每个元素: { slot, card_node, price_label, buy_btn, price }
var _slot_infos: Array = []

# ========== 初始化 ==========
func _ready() -> void:
	TransitionManager.fade_in_only()

	var rp = get_node_or_null("UI/RemovePanel")
	if rp:
		rp.visible = false

	leave_btn.pressed.connect(_on_leave_pressed)
	remove_btn.pressed.connect(_on_remove_pressed)
	remove_cancel_btn.pressed.connect(func(): 
		var panel = get_node_or_null("UI/RemovePanel")
		if panel:
			panel.visible = false
	)

	GameState.gold_changed.connect(_on_gold_changed)
	_update_gold_label()
	_setup_shop_visual()
	_rebuild_layout()
	_generate_shop()

# ========== 布局重建 ==========

func _rebuild_layout() -> void:
	## 重建整体布局：标题区 + 左右分栏 + 底部区

	var ui_layer: CanvasLayer = get_node_or_null("UI")
	if ui_layer == null:
		return

	# 隐藏 tscn 里的原有布局节点，用代码节点替代
	var orig_cards = get_node_or_null("UI/CardsForSale")
	if orig_cards:
		orig_cards.visible = false
	var orig_remove = get_node_or_null("UI/RemoveSection")
	if orig_remove:
		orig_remove.visible = false

	# ---------- 标题区 ----------
	_build_title_area(ui_layer)

	# ---------- 主体分栏容器 ----------
	var body = HBoxContainer.new()
	body.name = "BodyContainer"
	body.set_anchors_preset(Control.PRESET_CENTER)
	body.position = Vector2(640 - (520 + 20 + 220) / 2.0, 130)
	body.custom_minimum_size = Vector2(760, 420)
	body.add_theme_constant_override("separation", 20)
	ui_layer.add_child(body)

	# 左侧卡牌区（520px）
	var left_panel = _build_left_panel()
	body.add_child(left_panel)

	# 右侧区域（220px）
	var right_panel = _build_right_panel()
	body.add_child(right_panel)

	# ---------- 底部区域 ----------
	_build_bottom_area(ui_layer)

func _build_title_area(parent: CanvasLayer) -> void:
	## 标题 + WaterInkDivider + 副标题

	# 主标题（替换 tscn 里的 Title）
	var tscn_title = get_node_or_null("UI/Title")
	if tscn_title:
		tscn_title.visible = false

	var title_lbl = Label.new()
	title_lbl.text = "渡 魂 商 店"
	title_lbl.add_theme_font_size_override("font_size", UIC.FONT_SIZES["title"])
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.76, 0.08))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.anchor_right = 1.0
	title_lbl.offset_top = 18.0
	title_lbl.offset_bottom = 18.0 + 40.0
	title_lbl.layout_mode = 1
	parent.add_child(title_lbl)

	# WaterInkDivider
	var divider = WaterInkDividerClass.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.anchor_right = 1.0
	divider.offset_top = 62.0
	divider.offset_bottom = 64.0
	divider.layout_mode = 1
	divider.line_color = UIC.COLORS["gold_dim"]
	parent.add_child(divider)

	# 副标题（替换 tscn 里的 FlavorText）
	var tscn_flavor = get_node_or_null("UI/FlavorText")
	if tscn_flavor:
		tscn_flavor.visible = false

	var flavor = Label.new()
	flavor.text = "「有些东西，走这一程才能用得上。」"
	flavor.add_theme_font_size_override("font_size", UIC.FONT_SIZES["caption"])
	flavor.add_theme_color_override("font_color", UIC.COLORS["ash"])
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.anchor_right = 1.0
	flavor.offset_top = 68.0
	flavor.offset_bottom = 68.0 + 22.0
	flavor.layout_mode = 1
	parent.add_child(flavor)

	# 烛火装饰（两侧各一）
	for side in [-1, 1]:
		var candle = Label.new()
		candle.text = "🕯"
		candle.add_theme_font_size_override("font_size", 28)
		candle.position = Vector2(640 + side * 180, 16)
		parent.add_child(candle)
		var tw = candle.create_tween().set_loops()
		tw.tween_property(candle, "modulate:a", 0.65, 0.9 + side * 0.15)
		tw.tween_property(candle, "modulate:a", 1.0,  0.9 + side * 0.15)

func _build_left_panel() -> Control:
	## 左侧卡牌区（宽520px）

	var container = VBoxContainer.new()
	container.name = "LeftCardsPanel"
	container.custom_minimum_size = Vector2(520, 400)
	container.add_theme_constant_override("separation", 10)

	# 小标题
	var lbl = Label.new()
	lbl.text = "▸ 今日商品"
	lbl.add_theme_font_size_override("font_size", UIC.FONT_SIZES["caption"])
	lbl.add_theme_color_override("font_color", UIC.COLORS["gold_dim"])
	container.add_child(lbl)

	# 卡牌横排容器
	var cards_row = HBoxContainer.new()
	cards_row.name = "CardsRow"
	cards_row.add_theme_constant_override("separation", 24)
	container.add_child(cards_row)

	return container

func _build_right_panel() -> Control:
	## 右侧区域（宽220px）：移除牌区

	var container = VBoxContainer.new()
	container.name = "RightPanel"
	container.custom_minimum_size = Vector2(220, 400)
	container.add_theme_constant_override("separation", 12)

	# 移除区面板（InkedPanel 风格 StyleBoxFlat）
	var remove_frame = Panel.new()
	remove_frame.name = "RemoveFrame"
	remove_frame.custom_minimum_size = Vector2(220, 130)
	_apply_inked_stylebox(remove_frame)

	var remove_inner = VBoxContainer.new()
	remove_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	remove_inner.offset_left  = 10.0
	remove_inner.offset_top   = 10.0
	remove_inner.offset_right  = -10.0
	remove_inner.offset_bottom = -10.0
	remove_inner.add_theme_constant_override("separation", 6)
	remove_frame.add_child(remove_inner)

	# 移除区标题
	var remove_title = Label.new()
	remove_title.text = "✦ 移除一张牌  ·  75金"
	remove_title.add_theme_font_size_override("font_size", UIC.FONT_SIZES["body"])
	remove_title.add_theme_color_override("font_color", UIC.COLORS["gold"])
	remove_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remove_inner.add_child(remove_title)

	# 移除区描述
	var remove_desc = Label.new()
	remove_desc.text = "从牌组中永久抹去一张牌"
	remove_desc.add_theme_font_size_override("font_size", UIC.FONT_SIZES["caption"])
	remove_desc.add_theme_color_override("font_color", UIC.COLORS["ash"])
	remove_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remove_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	remove_inner.add_child(remove_desc)

	# 移除按钮
	var remove_btn_new = Button.new()
	remove_btn_new.name = "RemoveBtnNew"
	remove_btn_new.text = "🗑 选择要移除的牌"
	remove_btn_new.custom_minimum_size = Vector2(200, 36)
	_apply_buy_button_style(remove_btn_new)
	remove_btn_new.pressed.connect(_on_remove_pressed)
	remove_inner.add_child(remove_btn_new)

	container.add_child(remove_frame)

	return container

func _build_bottom_area(parent: CanvasLayer) -> void:
	## 底部：金币显示 + 离开按钮（不重建，使用原有节点并调整位置）

	# GoldLabel 隐藏原位，我们在这里用 tscn 里的 GoldLabel 调整样式就行
	var tscn_gold = get_node_or_null("UI/GoldLabel")
	if tscn_gold:
		tscn_gold.visible = false

	var bottom_bar = HBoxContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.anchor_left  = 0.5
	bottom_bar.anchor_top   = 1.0
	bottom_bar.anchor_right = 0.5
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_left  = -200.0
	bottom_bar.offset_top   = -52.0
	bottom_bar.offset_right = 200.0
	bottom_bar.offset_bottom = -12.0
	bottom_bar.layout_mode  = 1
	bottom_bar.alignment    = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 30)
	parent.add_child(bottom_bar)

	# 金币标签（新建，替代 tscn 的 GoldLabel，保存引用供后续更新）
	var new_gold = Label.new()
	new_gold.name = "GoldLabelNew"
	new_gold.text = "💰 %d" % int(GameState.gold)
	new_gold.add_theme_font_size_override("font_size", 16)
	new_gold.add_theme_color_override("font_color", Color(0.95, 0.76, 0.08))
	new_gold.custom_minimum_size = Vector2(140, 0)
	new_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_bar.add_child(new_gold)

	# 将 gold_label 引用指向新 label
	gold_label = new_gold

	# 离开按钮样式
	var leave_style = StyleBoxFlat.new()
	leave_style.bg_color     = Color(0.12, 0.08, 0.04)
	leave_style.border_color = Color(0.55, 0.42, 0.08)
	leave_style.set_border_width_all(2)
	leave_style.set_corner_radius_all(4)
	leave_btn.add_theme_stylebox_override("normal", leave_style)
	leave_btn.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	leave_btn.add_theme_font_size_override("font_size", 14)
	bottom_bar.add_child(leave_btn)

# ========== 生成商店卡牌 ==========

func _generate_shop() -> void:
	_shop_cards = CardDatabase.get_reward_cards(3)
	_slot_infos.clear()

	# 找左侧容器的 CardsRow
	var cards_row = get_node_or_null("UI/BodyContainer/LeftCardsPanel/CardsRow")
	if cards_row == null:
		# fallback：使用 tscn 里的 HBoxContainer
		cards_row = get_node_or_null("UI/CardsForSale")
		if cards_row:
			cards_row.visible = true

	if cards_row == null:
		return

	for child in cards_row.get_children():
		child.queue_free()

	for card in _shop_cards:
		var slot = _build_shop_slot(card)
		cards_row.add_child(slot)

	_refresh_afford()

## 构建单个商店卡槽（牌卡 + 价格 + 购买按钮）
func _build_shop_slot(card: Dictionary) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(110, 260)
	vbox.add_theme_constant_override("separation", 6)

	# 牌卡 UI（110×160px）
	var card_ui = _card_scene.instantiate() as CardUINode
	card_ui.setup(card)
	card_ui.set_playable(false)
	card_ui.custom_minimum_size = Vector2(110, 160)
	vbox.add_child(card_ui)

	# 价格标签
	var price = _get_price(card)
	var price_label = Label.new()
	price_label.text = "%s %d" % [UIConstants.ICONS["coin"], price]
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	vbox.add_child(price_label)

	# 购买按钮（InkedPanel 风格）
	var buy_btn = Button.new()
	buy_btn.text = "购买"
	buy_btn.custom_minimum_size = Vector2(110, 30)
	_apply_buy_button_style(buy_btn)
	buy_btn.disabled = GameState.gold < price
	buy_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	buy_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	buy_btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	var captured_card = card
	var captured_price = price
	var captured_btn   = buy_btn
	buy_btn.pressed.connect(func(): _on_buy_card(captured_card, captured_price, captured_btn, vbox))
	vbox.add_child(buy_btn)

	# 记录引用供金币刷新使用
	_slot_infos.append({
		"slot": vbox,
		"card_node": card_ui,
		"price_label": price_label,
		"buy_btn": buy_btn,
		"price": price,
	})

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
	btn.text = "已购买"
	btn.disabled = true
	slot.modulate = Color(0.5, 0.5, 0.5)

# ========== 金币充足性视觉反馈 ==========

func _refresh_afford() -> void:
	var current_gold = int(GameState.gold)
	for info in _slot_infos:
		var card_node  = info.get("card_node")
		var price_lbl  = info.get("price_label")
		var buy_btn    = info.get("buy_btn")
		var price_val  = info.get("price", 0)

		# 跳过已购买的卡槽（按钮已 disabled 且文字是"已购买"）
		if buy_btn and buy_btn.text == "已购买":
			continue

		var can_afford = current_gold >= price_val
		if can_afford:
			if card_node:
				card_node.modulate = Color(1, 1, 1, 1)
			if price_lbl:
				price_lbl.add_theme_color_override("font_color", UIC.COLORS["gold"])
			if buy_btn:
				buy_btn.disabled = false
		else:
			if card_node:
				card_node.modulate = Color(0.45, 0.45, 0.45, 0.8)
			if price_lbl:
				price_lbl.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
			if buy_btn:
				buy_btn.disabled = true

# ========== 移除牌卡 ==========

func _on_remove_pressed() -> void:
	if GameState.gold < REMOVE_PRICE:
		if remove_label:
			remove_label.text = "移除一张牌（%d金币）— 金币不足" % REMOVE_PRICE
		return

	var panel = get_node_or_null("UI/RemovePanel")
	if panel == null:
		return
	panel.visible = true

	for child in remove_deck_container.get_children():
		child.queue_free()

	var full_deck = DeckManager.get_full_deck()
	for card in full_deck:
		var card_ui = _card_scene.instantiate() as CardUINode
		card_ui.setup(card)
		card_ui.set_playable(true)
		var captured = card
		card_ui.card_clicked.connect(func(_c): _on_remove_card_selected(captured))
		remove_deck_container.add_child(card_ui)

func _on_remove_card_selected(card: Dictionary) -> void:
	if not GameState.spend_gold(REMOVE_PRICE):
		return
	DeckManager.remove_card_from_deck(card.get("id", ""))
	var panel = get_node_or_null("UI/RemovePanel")
	if panel:
		panel.visible = false

# ========== 其他事件 ==========

func _on_gold_changed(_old: int, _new: int) -> void:
	_update_gold_label()
	_refresh_afford()

func _update_gold_label() -> void:
	gold_label.text = "%s %d" % [UIConstants.ICONS["coin"], int(GameState.gold)]

func _on_leave_pressed() -> void:
	TransitionManager.change_scene("res://scenes/MapScene.tscn")

func _update_gold_display() -> void:
	if gold_label == null:
		return
	gold_label.text = "💰 %d" % int(GameState.gold)
	var tw = gold_label.create_tween()
	tw.tween_property(gold_label, "modulate", Color(1.5, 1.3, 0.5), 0.1)
	tw.tween_property(gold_label, "modulate", Color(1.0, 1.0, 1.0), 0.4)

# ========== 视觉设置 ==========

func _setup_shop_visual() -> void:
	## 背景升级：深色底 + 两侧幕帘 + 底部扫描线

	# 主背景
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.05, 0.02, 1.0)
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	# 两侧半透明幕帘
	var curtain_left = ColorRect.new()
	curtain_left.color = Color(0.051, 0.039, 0.0, 0.6)
	curtain_left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	curtain_left.custom_minimum_size = Vector2(80, 0)
	curtain_left.offset_right = 80.0
	curtain_left.anchor_right = 0.0
	curtain_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain_left.z_index = -9
	add_child(curtain_left)

	# 主体面板描边（DS-00）
	var ui_root = get_node_or_null("UI")
	if ui_root:
		var frame = InkedPanel.new()
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.fill_color = Color(UIConstants.color_of("parch").r, UIConstants.color_of("parch").g, UIConstants.color_of("parch").b, 0.12)
		frame.border_color = Color(UIConstants.color_of("gold_dim").r, UIConstants.color_of("gold_dim").g, UIConstants.color_of("gold_dim").b, 0.45)
		frame.top_line_color = UIConstants.color_of("gold")
		ui_root.add_child(frame)
		ui_root.move_child(frame, 0)

	var title_divider = WaterInkDivider.new()
	title_divider.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_divider.position.y = 58
	title_divider.custom_minimum_size = Vector2(0, 8)
	title_divider.ink_color = UIConstants.color_of("gold_dim")
	add_child(title_divider)

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
	gold_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("heading"))
	gold_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))

	# 离开按钮样式
	var leave_style = UIConstants.make_button_style("parch", "gold_dim")
	leave_btn.add_theme_stylebox_override("normal", leave_style)
	leave_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	leave_btn.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	leave_btn.add_theme_font_size_override("font_size", 14)

	var curtain_right = ColorRect.new()
	curtain_right.color = Color(0.051, 0.039, 0.0, 0.6)
	curtain_right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	curtain_right.custom_minimum_size = Vector2(80, 0)
	curtain_right.offset_left = -80.0
	curtain_right.anchor_left = 1.0
	curtain_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain_right.z_index = -9
	add_child(curtain_right)

	# 底部横向细线（5条，从底部向上，间隔40px）
	var vp_h = 600.0  # 默认视口高度
	var vp = get_viewport()
	if vp:
		vp_h = float(vp.get_visible_rect().size.y)
	for i in range(5):
		var scan = ColorRect.new()
		scan.color = Color(1.0, 1.0, 1.0, 0.04)
		scan.set_anchors_preset(Control.PRESET_TOP_WIDE)
		scan.custom_minimum_size = Vector2(0, 1)
		scan.offset_top  = vp_h - float(i + 1) * 40.0
		scan.offset_bottom = scan.offset_top + 1.0
		scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scan.z_index = -8
		add_child(scan)

# ========== 样式辅助 ==========

func _apply_inked_stylebox(panel: Panel) -> void:
	## 给 Panel 应用 InkedPanel 风格的 StyleBoxFlat
	var sbox = StyleBoxFlat.new()
	sbox.bg_color     = Color(0.102, 0.082, 0.031, 0.88)
	sbox.border_color = Color(0.420, 0.353, 0.188, 0.8)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sbox)

func _apply_buy_button_style(btn: Button) -> void:
	## 给购买按钮应用 InkedPanel 风格的三态样式

	# 正常
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color     = Color(0.102, 0.082, 0.031, 0.9)
	normal_style.border_color = Color(0.420, 0.353, 0.188)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(3)

	# hover
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color     = Color(0.18, 0.15, 0.07, 0.9)
	hover_style.border_color = Color(0.784, 0.663, 0.431)
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(3)

	# pressed（与 hover 相近）
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color     = Color(0.22, 0.18, 0.09, 0.9)
	pressed_style.border_color = Color(0.784, 0.663, 0.431)
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(3)

	# disabled
	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color     = Color(0.05, 0.05, 0.05, 0.5)
	disabled_style.border_color = Color(0.25, 0.25, 0.25)
	disabled_style.set_border_width_all(1)
	disabled_style.set_corner_radius_all(3)

	btn.add_theme_stylebox_override("normal",   normal_style)
	btn.add_theme_stylebox_override("hover",    hover_style)
	btn.add_theme_stylebox_override("pressed",  pressed_style)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	btn.add_theme_color_override("font_color",          UIC.COLORS["gold"])
	btn.add_theme_color_override("font_hover_color",    UIC.COLORS["gold"])
	btn.add_theme_color_override("font_disabled_color", UIC.COLORS["ash"])
	btn.add_theme_font_size_override("font_size", UIC.FONT_SIZES["caption"])
