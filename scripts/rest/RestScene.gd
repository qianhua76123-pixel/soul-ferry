extends Node2D

## RestScene.gd - 休息节点场景
## 提供三种选择：回复HP / 升级一张牌 / 移除一张牌
## 背景氛围：烛火、古庙

@onready var heal_btn:       Button        = $UI/Options/HealBtn
@onready var upgrade_btn:    Button        = $UI/Options/UpgradeBtn
@onready var remove_btn:     Button        = $UI/Options/RemoveBtn
@onready var leave_btn:      Button        = $UI/LeaveBtn
@onready var status_label:   Label         = $UI/StatusLabel
@onready var deck_container: GridContainer = $UI/DeckPanel/DeckGrid
@onready var deck_panel:     Panel         = $UI/DeckPanel

const HEAL_AMOUNT_PERCENT = 0.20

var _upgrade_mode: bool = false
var _remove_mode:  bool = false
var _healed:       bool = false
var _upgraded:     bool = false
var _removed:      bool = false

func _ready() -> void:
	TransitionManager.fade_in_only()
	deck_panel.visible = false
	heal_btn.pressed.connect(_on_heal)
	upgrade_btn.pressed.connect(_on_upgrade_mode)
	remove_btn.pressed.connect(_on_remove_mode)
	leave_btn.pressed.connect(_on_leave)
	_update_status()
	_build_bg_candles()
	_setup_rest_visual()

func _on_heal() -> void:
	if _healed: return
	_healed = true
	var amount: int = int(GameState.max_hp * HEAL_AMOUNT_PERCENT)
	GameState.heal(amount)
	heal_btn.disabled = true
	status_label.text = "休息后回复了 %d HP。" % int(amount)
	_update_status()
	SoundManager.play_sfx("heal")

func _on_upgrade_mode() -> void:
	if _upgraded: return
	_upgrade_mode        = true
	deck_panel.visible   = true
	upgrade_btn.disabled = true
	status_label.text    = "选择一张牌进行升级 ✨"

	for child in deck_container.get_children():
		child.queue_free()

	# 每行5张，布局更美观
	deck_container.columns = 5

	var card_scene: PackedScene = preload("res://scenes/CardUI.tscn")
	for card: Dictionary in DeckManager.get_full_deck():
		var can_up: bool = CardDatabase.can_upgrade(card)
		var card_ui: CardUINode = card_scene.instantiate() as CardUINode
		card_ui.setup(card)
		card_ui.set_playable(can_up)
		card_ui.modulate.a = 1.0 if can_up else 0.45
		# 升级预览 tooltip
		if can_up:
			card_ui.tooltip_text = _get_upgrade_preview(card)
			card_ui.card_clicked.connect(func(c: Dictionary) -> void: _on_card_upgrade_selected(c))
		deck_container.add_child(card_ui)

func _on_remove_mode() -> void:
	if _removed: return
	_remove_mode         = true
	deck_panel.visible   = true
	remove_btn.disabled  = true
	status_label.text    = "选择一张牌将其移除（此操作不可撤销）"

	for child in deck_container.get_children():
		child.queue_free()

	# 每行5张，布局更美观
	deck_container.columns = 5

	var card_scene: PackedScene = preload("res://scenes/CardUI.tscn")
	for card: Dictionary in DeckManager.get_full_deck():
		# 起始牌（rarity=starter）不允许移除
		var can_remove: bool = card.get("rarity", "") != "starter"
		var card_ui: CardUINode = card_scene.instantiate() as CardUINode
		card_ui.setup(card)
		card_ui.set_playable(can_remove)
		card_ui.modulate.a = 1.0 if can_remove else 0.35
		if can_remove:
			card_ui.card_clicked.connect(func(c: Dictionary) -> void: _on_card_remove_selected(c))
		deck_container.add_child(card_ui)

func _on_card_remove_selected(card: Dictionary) -> void:
	if not _remove_mode: return
	_removed      = true
	_remove_mode  = false
	DeckManager.remove_card(card)
	deck_panel.visible = false
	status_label.text  = "「%s」已移除。\n牌组 -1 张。" % card.get("name", "???")
	_update_status()

	# 移除浮字特效（红色）
	var lbl: Label = Label.new()
	lbl.text = "🗑 已移除"
	lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.25))
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var root: Node = get_node_or_null("UI") if get_node_or_null("UI") else self
	root.add_child(lbl)
	lbl.position = Vector2(400, 300)
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "position:y", 240.0, 1.0).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(lbl.queue_free)

## 升级预览文字（展示升级后效果）
func _get_upgrade_preview(card: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("✨ 升级效果预览：")
	var cost: int    = card.get("cost", 1)
	var etype: String = card.get("effect_type", "")
	var eval_: int   = card.get("effect_value", 0)
	var bonus: int   = card.get("condition_bonus", 0)

	# 费用降低（除0费外）
	if cost >= 1:
		lines.append("• 费用 %d → %d" % [int(cost), int(maxi(0, cost - 1))])

	# 效果值提升（数值类效果+20%）
	if eval_ > 0 and etype in [
		"attack","attack_all","attack_lifesteal","shield","heal",
		"heal_all_buffs","attack_dot","attack_scaling_rage","shield_attack",
		"mass_heal_shield","attack_all_triple","weaken","weaken_fear"
	]:
		var new_val: int = int(eval_ * 1.25)
		lines.append("• 效果值 %d → %d (+25%%)" % [int(eval_), int(new_val)])

	# 条件加成提升
	if bonus > 0:
		lines.append("• 条件加成 +%d → +%d" % [int(bonus), int(bonus) + int(int(bonus) * 0.5) + 1])

	# 传说牌额外说明
	if card.get("rarity", "") == "legendary":
		lines.append("• 传说牌：解锁隐藏强化效果")

	lines.append("")
	lines.append(card.get("description", ""))
	return "\n".join(lines)

## 执行升级 — 统一走 CardDatabase.upgrade_card()
func _on_card_upgrade_selected(card: Dictionary) -> void:
	if not _upgrade_mode: return
	_upgraded     = true
	_upgrade_mode = false

	var upgraded: Dictionary = CardDatabase.upgrade_card(card)
	deck_panel.visible = false
	var utype: String = str(upgraded.get("upgrade_type", "power"))
	var type_label: Dictionary = {
		"power":     "【强化】数值提升",
		"cost":      "【省能】费用-1",
		"extend":    "【扩展】追加效果",
		"unlock":    "【解锁】移除限制",
		"transform": "【转化】彻底重铸",
	}
	status_label.text = "「%s」已升级！\n%s" % [
		upgraded.get("name", "???"),
		type_label.get(utype, "强化完成")]

	# 升级浮字特效
	_show_upgrade_effect()
	SoundManager.play_sfx("card_upgrade")
	_update_status()

## 升级光效（全屏金色粒子模拟）
func _show_upgrade_effect() -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.98, 0.85, 0.10, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ui: Node = get_node_or_null("UI")
	if ui: ui.add_child(overlay)
	else: add_child(overlay)
	var tw: Tween = overlay.create_tween()
	tw.tween_property(overlay, "color:a", 0.35, 0.15)
	tw.tween_property(overlay, "color:a", 0.0,  0.5)
	tw.tween_callback(overlay.queue_free)

	# 升级浮字
	var lbl: Label = Label.new()
	lbl.text = "✨ 升级成功！"
	lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.10))
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var root: Node = get_node_or_null("UI") if get_node_or_null("UI") else self
	root.add_child(lbl)
	lbl.position = Vector2(400, 280)
	var tw2: Tween = lbl.create_tween()
	tw2.tween_property(lbl, "position:y", 220.0, 1.2).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw2.tween_callback(lbl.queue_free)

func _on_leave() -> void:
	TransitionManager.change_scene("res://scenes/MapScene.tscn")

func _update_status() -> void:
	## 实时刷新 HP 显示 + 操作状态提示
	var hp_lbl: Node = get_node_or_null("UI/HPStatus")
	if hp_lbl:
		hp_lbl.set("text", "HP: %d / %d" % [int(GameState.hp), int(GameState.max_hp)])

	# 根据已选行动更新状态文字
	var opts: Array[String] = []
	if not _healed:
		opts.append("• 回复HP：恢复最大HP的20%%（%d点）" % int(GameState.max_hp * 0.2))
	else:
		opts.append("✓ 已回复HP")
	if not _upgraded:
		opts.append("• 升级牌卡：选一张牌升级")
	else:
		opts.append("✓ 已升级牌卡")
	if not _removed:
		opts.append("• 移除牌卡：删除一张牌")
	else:
		opts.append("✓ 已移除牌卡")
	opts.append("")
	opts.append("当前HP：%d / %d" % [int(GameState.hp), int(GameState.max_hp)])
	status_label.text = "\n".join(opts)

## 程序化烛火背景装饰
func _build_bg_candles() -> void:
	var bg: Node = get_node_or_null("BgCanvas")
	if not bg: return
	for i: int in range(5):
		var candle: Label = Label.new()
		candle.text = "🕯"
		candle.add_theme_font_size_override("font_size", 28)
		candle.modulate = Color(0.9, 0.6, 0.2, 0.7)
		candle.position = Vector2(60 + i * 180, 520 + (i % 2) * 30)
		bg.add_child(candle)
		# 烛火摇曳
		var tw: Tween = candle.create_tween().set_loops()
		tw.tween_property(candle, "rotation_degrees", 3.0 * (1 if i%2==0 else -1), 0.6 + i*0.1)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(candle, "rotation_degrees", -3.0 * (1 if i%2==0 else -1), 0.6 + i*0.1)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _setup_rest_visual() -> void:
	## 休息场景氛围：古庙烛台 + 温暖色调背景

	# 背景（深青灰）
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.08, 1.0)
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	# 标题
	var title_lbl: Label = Label.new()
	title_lbl.text = "古 祠 小 憩"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.75, 0.62, 0.35))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_lbl.position.y = 24
	add_child(title_lbl)

	var ui_root: Node = get_node_or_null("UI")
	if ui_root:
		var frame: InkedPanel = InkedPanel.new()
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.fill_color   = Color(UIConstants.color_of("parch").r,     UIConstants.color_of("parch").g,     UIConstants.color_of("parch").b,     0.10)
		frame.border_color = Color(UIConstants.color_of("gold_dim").r,  UIConstants.color_of("gold_dim").g,  UIConstants.color_of("gold_dim").b,  0.45)
		frame.top_line_color = UIConstants.color_of("gold")
		ui_root.add_child(frame)
		ui_root.move_child(frame, 0)

	var divider: WaterInkDivider = WaterInkDivider.new()
	divider.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	divider.position.y = 56
	divider.ink_color  = UIConstants.color_of("gold_dim")
	add_child(divider)

	# 3支烛台
	for i: int in range(3):
		var candle: Label = Label.new()
		candle.text = "🕯"
		candle.add_theme_font_size_override("font_size", 24)
		candle.position = Vector2(460 + i * 148, 520 + (i % 2) * 20)
		add_child(candle)
		var tw: Tween = candle.create_tween().set_loops()
		var period: float = 1.1 + i * 0.18
		tw.tween_property(candle, "modulate:a", 0.55, period)
		tw.tween_property(candle, "modulate:a", 1.0,  period)

	# 强化按钮样式（heal / upgrade / remove 统一风格）
	for btn: Button in [heal_btn, upgrade_btn, remove_btn]:
		var sty: StyleBox = UIConstants.make_button_style("parch", "gold_dim")
		btn.add_theme_stylebox_override("normal", sty)
		btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
		btn.add_theme_color_override("font_color", Color(0.80, 0.90, 0.75))
		btn.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))

	# 离开按钮
	var leave_sty: StyleBox = UIConstants.make_button_style("parch", "gold_dim")
	leave_btn.add_theme_stylebox_override("normal", leave_sty)
	leave_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	leave_btn.add_theme_color_override("font_color", Color(0.65, 0.55, 0.38))
