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

	var rp: Node = get_node_or_null("UI/RemovePanel")
	if rp:
		rp.visible = false

	leave_btn.pressed.connect(_on_leave_pressed)
	remove_btn.pressed.connect(_on_remove_pressed)
	remove_cancel_btn.pressed.connect(func(): 
		var panel: Node = get_node_or_null("UI/RemovePanel")
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
	var orig_cards: Node = get_node_or_null("UI/CardsForSale")
	if orig_cards:
		orig_cards.visible = false
	var orig_remove: Node = get_node_or_null("UI/RemoveSection")
	if orig_remove:
		orig_remove.visible = false

	# ---------- 标题区 ----------
	_build_title_area(ui_layer)

	# ---------- 主体分栏容器 ----------
	var body: HBoxContainer = HBoxContainer.new()
	body.name = "BodyContainer"
	body.anchor_left   = 0.5
	body.anchor_top    = 0.0
	body.anchor_right  = 0.5
	body.anchor_bottom = 0.0
	body.layout_mode   = 1
	# 宽 760px 居中，顶部 130px 留给标题
	body.offset_left   = -380.0
	body.offset_top    = 130.0
	body.offset_right  = 380.0
	body.offset_bottom = 560.0
	body.add_theme_constant_override("separation", 20)
	ui_layer.add_child(body)

	# 左侧卡牌区（520px）
	var left_panel: Control = _build_left_panel()
	body.add_child(left_panel)

	# 右侧区域（220px）
	var right_panel: Control = _build_right_panel()
	body.add_child(right_panel)

	# ---------- 底部区域 ----------
	_build_bottom_area(ui_layer)

func _build_title_area(parent: CanvasLayer) -> void:
	## 标题 + WaterInkDivider + 副标题

	# 主标题（替换 tscn 里的 Title）
	var tscn_title: Node = get_node_or_null("UI/Title")
	if tscn_title:
		tscn_title.visible = false

	var title_lbl: Label = Label.new()
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
	var divider: Node = WaterInkDividerClass.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.anchor_right = 1.0
	divider.offset_top = 62.0
	divider.offset_bottom = 64.0
	divider.layout_mode = 1
	divider.ink_color = UIC.COLORS["gold_dim"]
	parent.add_child(divider)

	# 副标题（替换 tscn 里的 FlavorText）
	var tscn_flavor: Node = get_node_or_null("UI/FlavorText")
	if tscn_flavor:
		tscn_flavor.visible = false

	var flavor: Label = Label.new()
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
		var candle: Label = Label.new()
		candle.text = "🕯"
		candle.add_theme_font_size_override("font_size", 28)
		candle.position = Vector2(640 + side * 180, 16)
		parent.add_child(candle)
		var tw: Tween = candle.create_tween().set_loops()
		tw.tween_property(candle, "modulate:a", 0.65, 0.9 + side * 0.15)
		tw.tween_property(candle, "modulate:a", 1.0,  0.9 + side * 0.15)

func _build_left_panel() -> Control:
	## 左侧卡牌区（宽520px）

	var container: VBoxContainer = VBoxContainer.new()
	container.name = "LeftCardsPanel"
	container.custom_minimum_size = Vector2(520, 400)
	container.add_theme_constant_override("separation", 10)

	# 小标题
	var lbl: Label = Label.new()
	lbl.text = "▸ 今日商品"
	lbl.add_theme_font_size_override("font_size", UIC.FONT_SIZES["caption"])
	lbl.add_theme_color_override("font_color", UIC.COLORS["gold_dim"])
	container.add_child(lbl)

	# 卡牌横排容器
	var cards_row: HBoxContainer = HBoxContainer.new()
	cards_row.name = "CardsRow"
	cards_row.add_theme_constant_override("separation", 24)
	container.add_child(cards_row)

	return container

func _build_right_panel() -> Control:
	var container: VBoxContainer = VBoxContainer.new()
	container.name = "RightPanel"
	container.custom_minimum_size = Vector2(220, 400)
	container.add_theme_constant_override("separation", 10)

	# ── 移除牌区 ──────────────────────────────────────
	var remove_frame: Panel = Panel.new()
	remove_frame.name = "RemoveFrame"
	remove_frame.custom_minimum_size = Vector2(220, 110)
	_apply_inked_stylebox(remove_frame)
	var remove_inner: VBoxContainer = VBoxContainer.new()
	remove_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	remove_inner.offset_left = 10.0; remove_inner.offset_top = 8.0
	remove_inner.offset_right = -10.0; remove_inner.offset_bottom = -8.0
	remove_inner.add_theme_constant_override("separation", 6)
	remove_frame.add_child(remove_inner)
	var remove_title: Label = Label.new()
	remove_title.text = "✦ 移除一张牌  ·  75金"
	remove_title.add_theme_font_size_override("font_size", UIC.FONT_SIZES["body"])
	remove_title.add_theme_color_override("font_color", UIC.COLORS["gold"])
	remove_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remove_inner.add_child(remove_title)
	var remove_desc: Label = Label.new()
	remove_desc.text = "从牌组中永久抹去一张牌"
	remove_desc.add_theme_font_size_override("font_size", UIC.FONT_SIZES["caption"])
	remove_desc.add_theme_color_override("font_color", UIC.COLORS["ash"])
	remove_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remove_inner.add_child(remove_desc)
	var remove_btn_new: Button = Button.new()
	remove_btn_new.name = "RemoveBtnNew"
	remove_btn_new.text = "🗑 选择要移除的牌"
	remove_btn_new.custom_minimum_size = Vector2(200, 32)
	_apply_buy_button_style(remove_btn_new)
	remove_btn_new.pressed.connect(_on_remove_pressed)
	remove_inner.add_child(remove_btn_new)
	container.add_child(remove_frame)

	# ── 锻造入口 ──────────────────────────────────────
	var forge_frame: Panel = Panel.new()
	forge_frame.name = "ForgeFrame"
	forge_frame.custom_minimum_size = Vector2(220, 110)
	_apply_inked_stylebox(forge_frame)
	var forge_inner: VBoxContainer = VBoxContainer.new()
	forge_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	forge_inner.offset_left = 10.0; forge_inner.offset_top = 8.0
	forge_inner.offset_right = -10.0; forge_inner.offset_bottom = -8.0
	forge_inner.add_theme_constant_override("separation", 6)
	forge_frame.add_child(forge_inner)
	var forge_title: Label = Label.new()
	forge_title.text = "⚒ 锻造改造"
	forge_title.add_theme_font_size_override("font_size", UIC.FONT_SIZES["body"])
	forge_title.add_theme_color_override("font_color", UIC.COLORS["gold"])
	forge_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forge_inner.add_child(forge_title)
	var forge_desc: Label = Label.new()
	forge_desc.text = "消耗碎片强化一张牌\n（需先在战斗中积累碎片）"
	forge_desc.add_theme_font_size_override("font_size", UIC.FONT_SIZES["caption"])
	forge_desc.add_theme_color_override("font_color", UIC.COLORS["ash"])
	forge_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forge_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	forge_inner.add_child(forge_desc)
	var forge_btn: Button = Button.new()
	forge_btn.name = "ForgeBtnNew"
	forge_btn.text = "⚒ 进入锻造"
	forge_btn.custom_minimum_size = Vector2(200, 32)
	_apply_buy_button_style(forge_btn)
	forge_btn.pressed.connect(_on_forge_pressed)
	forge_inner.add_child(forge_btn)
	container.add_child(forge_frame)

	# ── 已解锁图纸提示 ────────────────────────────────
	var recipe_lbl: Label = Label.new()
	recipe_lbl.name = "RecipeLbl"
	var locked_count: int = ForgeSystem.unlocked_recipes.size()
	recipe_lbl.text = "已解锁图纸：%d 种" % locked_count if locked_count > 0 else "尚未解锁锻造图纸"
	recipe_lbl.add_theme_font_size_override("font_size", UIC.FONT_SIZES["caption"])
	recipe_lbl.add_theme_color_override("font_color", UIC.COLORS["ash"] if locked_count == 0 else UIC.COLORS["gold_dim"])
	recipe_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(recipe_lbl)

	return container

func _build_bottom_area(parent: CanvasLayer) -> void:
	## 底部：金币显示 + 离开按钮（不重建，使用原有节点并调整位置）

	# GoldLabel 隐藏原位，我们在这里用 tscn 里的 GoldLabel 调整样式就行
	var tscn_gold: Node = get_node_or_null("UI/GoldLabel")
	if tscn_gold:
		tscn_gold.visible = false

	var bottom_bar: HBoxContainer = HBoxContainer.new()
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
	var new_gold: Label = Label.new()
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
	var leave_style: StyleBoxFlat = StyleBoxFlat.new()
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

	# 动态创建的 BodyContainer 挂在 CanvasLayer(UI) 下，需要用名字直接找子节点
	var ui_layer: Node = get_node_or_null("UI")
	var cards_row: Node = null
	if ui_layer:
		var body: Node = ui_layer.get_node_or_null("BodyContainer")
		if body:
			var left: Node = body.get_node_or_null("LeftCardsPanel")
			if left:
				cards_row = left.get_node_or_null("CardsRow")

	# fallback：使用 tscn 里的 HBoxContainer
	if cards_row == null:
		cards_row = get_node_or_null("UI/CardsForSale")
		if cards_row:
			cards_row.visible = true

	if cards_row == null:
		return

	for child in cards_row.get_children():
		child.queue_free()

	for card in _shop_cards:
		var slot: Control = _build_shop_slot(card)
		cards_row.add_child(slot)

	_refresh_afford()

## 构建单个商店卡槽（牌卡 + 价格 + 购买按钮）
func _build_shop_slot(card: Dictionary) -> VBoxContainer:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(110, 260)
	vbox.add_theme_constant_override("separation", 6)

	# 牌卡 UI（110×160px）
	var card_ui: CardUINode = _card_scene.instantiate() as CardUINode
	card_ui.setup(card)
	card_ui.set_playable(false)
	card_ui.custom_minimum_size = Vector2(110, 160)
	vbox.add_child(card_ui)

	# 价格标签
	var price: int = _get_price(card)
	var price_label: Label = Label.new()
	price_label.text = "%s %d" % [UIConstants.ICONS["coin"], price]
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	vbox.add_child(price_label)

	# 购买按钮（InkedPanel 风格）
	var buy_btn: Button = Button.new()
	buy_btn.text = "购买"
	buy_btn.custom_minimum_size = Vector2(110, 30)
	_apply_buy_button_style(buy_btn)
	buy_btn.disabled = GameState.gold < price
	buy_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	buy_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	buy_btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	var captured_card: Dictionary = card
	var captured_price: int = price
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
	var current_gold: int = int(GameState.gold)
	for info in _slot_infos:
		var card_node  = info.get("card_node")
		var price_lbl  = info.get("price_label")
		var buy_btn    = info.get("buy_btn")
		var price_val  = info.get("price", 0)

		# 跳过已购买的卡槽（按钮已 disabled 且文字是"已购买"）
		if buy_btn and buy_btn.text == "已购买":
			continue

		var can_afford: bool = current_gold >= price_val
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

	var panel: Node = get_node_or_null("UI/RemovePanel")
	if panel == null:
		return
	panel.visible = true

	for child in remove_deck_container.get_children():
		child.queue_free()

	var full_deck: Array = DeckManager.get_full_deck()
	for card in full_deck:
		var card_ui: CardUINode = _card_scene.instantiate() as CardUINode
		card_ui.setup(card)
		card_ui.set_playable(true)
		var captured: Dictionary = card
		card_ui.card_clicked.connect(func(_c): _on_remove_card_selected(captured))
		remove_deck_container.add_child(card_ui)

func _on_remove_card_selected(card: Dictionary) -> void:
	if not GameState.spend_gold(REMOVE_PRICE):
		return
	DeckManager.remove_card_from_deck(card.get("id", ""))
	var panel: Node = get_node_or_null("UI/RemovePanel")
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
	var tw: Tween = gold_label.create_tween()
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
	var ui_root: Node = get_node_or_null("UI")
	if ui_root:
		var frame: InkedPanel = InkedPanel.new()
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.fill_color = Color(UIConstants.color_of("parch").r, UIConstants.color_of("parch").g, UIConstants.color_of("parch").b, 0.12)
		frame.border_color = Color(UIConstants.color_of("gold_dim").r, UIConstants.color_of("gold_dim").g, UIConstants.color_of("gold_dim").b, 0.45)
		frame.top_line_color = UIConstants.color_of("gold")
		ui_root.add_child(frame)
		ui_root.move_child(frame, 0)

	var title_divider: WaterInkDivider = WaterInkDivider.new()
	title_divider.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_divider.position.y = 58
	title_divider.custom_minimum_size = Vector2(0, 8)
	title_divider.ink_color = UIConstants.color_of("gold_dim")
	add_child(title_divider)

	# 烛火装饰（两侧各一）
	for side in [-1, 1]:
		var candle: Label = Label.new()
		candle.text = "🕯"
		candle.add_theme_font_size_override("font_size", 28)
		candle.position = Vector2(608 + side * 180, 20)
		add_child(candle)
		# 烛光闪烁动画
		var tw: Tween = candle.create_tween().set_loops()
		tw.tween_property(candle, "modulate:a", 0.65, 0.9 + side * 0.15)
		tw.tween_property(candle, "modulate:a", 1.0,  0.9 + side * 0.15)

	# 金币标签样式增强
	gold_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("heading"))
	gold_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))

	# 离开按钮样式
	var leave_style: StyleBox = UIConstants.make_button_style("parch", "gold_dim")
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
	var vp: Viewport = get_viewport()
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
	var sbox: StyleBoxFlat = StyleBoxFlat.new()
	sbox.bg_color     = Color(0.102, 0.082, 0.031, 0.88)
	sbox.border_color = Color(0.420, 0.353, 0.188, 0.8)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sbox)

func _apply_buy_button_style(btn: Button) -> void:
	## 给购买按钮应用 InkedPanel 风格的三态样式

	# 正常
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color     = Color(0.102, 0.082, 0.031, 0.9)
	normal_style.border_color = Color(0.420, 0.353, 0.188)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(3)

	# hover
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color     = Color(0.18, 0.15, 0.07, 0.9)
	hover_style.border_color = Color(0.784, 0.663, 0.431)
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(3)

	# pressed（与 hover 相近）
	var pressed_style: StyleBoxFlat = StyleBoxFlat.new()
	pressed_style.bg_color     = Color(0.22, 0.18, 0.09, 0.9)
	pressed_style.border_color = Color(0.784, 0.663, 0.431)
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(3)

	# disabled
	var disabled_style: StyleBoxFlat = StyleBoxFlat.new()
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

# ── 锻造面板 ──────────────────────────────────────────

var _forge_panel: Panel = null

func _on_forge_pressed() -> void:
	if _forge_panel and is_instance_valid(_forge_panel):
		_forge_panel.queue_free()
		_forge_panel = null
		return
	var ui_layer: Node = get_node_or_null("UI")
	if not ui_layer: return

	_forge_panel = Panel.new()
	_forge_panel.name = "ForgeSelectPanel"
	_forge_panel.custom_minimum_size = Vector2(680, 480)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_forge_panel.position = Vector2((vp.x - 680) * 0.5, (vp.y - 480) * 0.5)
	_forge_panel.z_index = 100
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.04, 0.02, 0.98)
	ps.border_color = Color(0.65, 0.48, 0.12, 0.9)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(8)
	_forge_panel.add_theme_stylebox_override("panel", ps)
	ui_layer.add_child(_forge_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0; vbox.offset_right = -16.0
	vbox.offset_top = 14.0; vbox.offset_bottom = -14.0
	vbox.add_theme_constant_override("separation", 10)
	_forge_panel.add_child(vbox)

	# 标题
	var title: Label = Label.new()
	title.text = "⚒  锻造工坊  — 选择一张牌"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UIC.COLORS["gold"])
	vbox.add_child(title)

	# 碎片状态
	var shard_row: HBoxContainer = HBoxContainer.new()
	shard_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shard_row.add_theme_constant_override("separation", 12)
	vbox.add_child(shard_row)
	var shard_types: Array[String] = ["bei","ju","nu","xi","ding","seal","chain","void","spirit","echo"]
	var shard_icons: Dictionary = {"bei":"悲","ju":"惧","nu":"怒","xi":"喜","ding":"定",
		"seal":"印","chain":"锁","void":"空","spirit":"灵","echo":"响"}
	for st: String in shard_types:
		var count: int = DiscardSystem.get_shard(st)
		if count == 0: continue
		var sl: Label = Label.new()
		sl.text = "%s×%d" % [shard_icons.get(st,"?"), count]
		sl.add_theme_font_size_override("font_size", 11)
		sl.add_theme_color_override("font_color", UIC.COLORS["gold_dim"])
		shard_row.add_child(sl)

	# 牌组列表（可滚动）
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var card_flow: HFlowContainer = HFlowContainer.new()
	card_flow.add_theme_constant_override("h_separation", 8)
	card_flow.add_theme_constant_override("v_separation", 8)
	scroll.add_child(card_flow)

	var card_scene: PackedScene = preload("res://scenes/CardUI.tscn")
	for card: Dictionary in DeckManager.get_full_deck():
		var can_forge: bool = not card.get("forged", false)
		var card_ui: CardUINode = card_scene.instantiate() as CardUINode
		card_ui.setup(card)
		card_ui.set_playable(can_forge)
		card_ui.custom_minimum_size = Vector2(100, 155)
		card_ui.modulate.a = 1.0 if can_forge else 0.4
		if can_forge:
			var captured: Dictionary = card
			card_ui.card_clicked.connect(func(_c): _show_forge_type_selector(captured))
		card_flow.add_child(card_ui)

	# 关闭
	var close_btn: Button = Button.new()
	close_btn.text = "关闭"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func():
		if _forge_panel and is_instance_valid(_forge_panel):
			_forge_panel.queue_free()
			_forge_panel = null
	)
	var close_row: HBoxContainer = HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.add_child(close_btn)
	vbox.add_child(close_row)

func _show_forge_type_selector(card: Dictionary) -> void:
	if not _forge_panel or not is_instance_valid(_forge_panel): return
	# 清空面板内容，换成锻造类型选择
	for c in _forge_panel.get_children():
		c.queue_free()

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0; vbox.offset_right = -16.0
	vbox.offset_top = 14.0; vbox.offset_bottom = -14.0
	vbox.add_theme_constant_override("separation", 8)
	_forge_panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "⚒  选择锻造类型  ·  「%s」" % card.get("name","???")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UIC.COLORS["gold"])
	vbox.add_child(title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var forge_options: Array[Dictionary] = ForgeSystem.get_available_forges(card)
	for opt: Dictionary in forge_options:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)

		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var name_lbl: Label = Label.new()
		name_lbl.text = opt.get("label","?")
		var is_locked: bool = opt.get("locked", false)
		var is_eligible: bool = opt.get("eligible", true)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color",
			UIC.COLORS["ash"] if is_locked else UIC.COLORS["gold"])
		info.add_child(name_lbl)

		var cost_lbl: Label = Label.new()
		cost_lbl.text = "消耗：%s%s" % [
			opt.get("cost_display","???"),
			"  【需要图纸】" if is_locked else ("  【不适用】" if not is_eligible else "")]
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", UIC.COLORS["ash"])
		info.add_child(cost_lbl)

		var forge_btn: Button = Button.new()
		forge_btn.text = "锻造"
		forge_btn.custom_minimum_size = Vector2(64, 28)
		forge_btn.add_theme_font_size_override("font_size", 12)
		forge_btn.disabled = is_locked or not is_eligible
		var captured_type: String = opt.get("type","")
		var captured_card: Dictionary = card
		forge_btn.pressed.connect(func():
			var result: Dictionary = ForgeSystem.execute_forge(captured_card, captured_type)
			if result.get("forged", false):
				_forge_panel.queue_free()
				_forge_panel = null
		)
		row.add_child(forge_btn)

	var back_btn: Button = Button.new()
	back_btn.text = "← 返回选牌"
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.pressed.connect(func(): _on_forge_pressed(); _on_forge_pressed())
	var back_row: HBoxContainer = HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.add_child(back_btn)
	vbox.add_child(back_row)
