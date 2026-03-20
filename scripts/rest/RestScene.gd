extends Node2D

## RestScene.gd - 休息节点场景
## 提供两种选择：回复HP / 升级一张牌
## 背景氛围：烛火、古庙

@onready var heal_btn:      Button = $UI/Options/HealBtn
@onready var upgrade_btn:   Button = $UI/Options/UpgradeBtn
@onready var leave_btn:     Button = $UI/LeaveBtn
@onready var status_label:  Label  = $UI/StatusLabel
@onready var deck_container: GridContainer = $UI/DeckPanel/DeckGrid
@onready var deck_panel:    Panel  = $UI/DeckPanel

const HEAL_AMOUNT_PERCENT = 0.30

var _upgrade_mode: bool  = false
var _healed:       bool  = false
var _upgraded:     bool  = false

func _ready() -> void:
	TransitionManager.fade_in_only()
	deck_panel.visible = false
	heal_btn.pressed.connect(_on_heal)
	upgrade_btn.pressed.connect(_on_upgrade_mode)
	leave_btn.pressed.connect(_on_leave)
	_update_status()
	_build_bg_candles()

func _on_heal() -> void:
	if _healed: return
	_healed = true
	var amount = int(GameState.max_hp * HEAL_AMOUNT_PERCENT)
	GameState.heal(amount)
	heal_btn.disabled  = true
	status_label.text  = "休息后回复了 %d HP。" % amount
	_update_status()
	SoundManager.play_sfx("heal")

func _on_upgrade_mode() -> void:
	if _upgraded: return
	_upgrade_mode      = true
	deck_panel.visible = true
	upgrade_btn.disabled = true
	status_label.text  = "选择一张牌进行升级 ✨"

	for child in deck_container.get_children():
		child.queue_free()

	var card_scene = preload("res://scenes/CardUI.tscn")
	for card in DeckManager.get_full_deck():
		var card_ui = card_scene.instantiate() as CardUINode
		card_ui.setup(card)
		card_ui.set_playable(true)
		# 悬停时显示升级预览 tooltip
		card_ui.tooltip_text = _get_upgrade_preview(card)
		card_ui.card_clicked.connect(func(c): _on_card_upgrade_selected(c))
		deck_container.add_child(card_ui)

## 升级预览文字（展示升级后效果）
func _get_upgrade_preview(card: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("✨ 升级效果预览：")
	var cost = card.get("cost", 1)
	var etype = card.get("effect_type", "")
	var eval_ = card.get("effect_value", 0)
	var bonus = card.get("condition_bonus", 0)

	# 费用降低（除0费外）
	if cost >= 1:
		lines.append("• 费用 %d → %d" % [cost, max(0, cost - 1)])

	# 效果值提升（数值类效果+20%）
	if eval_ > 0 and etype in [
		"attack","attack_all","attack_lifesteal","shield","heal",
		"heal_all_buffs","attack_dot","attack_scaling_rage","shield_attack",
		"mass_heal_shield","attack_all_triple","weaken","weaken_fear"
	]:
		var new_val = int(eval_ * 1.25)
		lines.append("• 效果值 %d → %d (+25%%)" % [eval_, new_val])

	# 条件加成提升
	if bonus > 0:
		lines.append("• 条件加成 +%d → +%d" % [bonus, bonus + int(bonus * 0.5) + 1])

	# 传说牌额外说明
	if card.get("rarity","") == "legendary":
		lines.append("• 传说牌：解锁隐藏强化效果")

	lines.append("")
	lines.append(card.get("description", ""))
	return "\n".join(lines)

## 执行升级
func _on_card_upgrade_selected(card: Dictionary) -> void:
	if not _upgrade_mode: return
	_upgraded = true
	_upgrade_mode = false

	var upgrades: Array[String] = []

	# 费用-1
	var old_cost = card.get("cost", 1)
	if old_cost >= 1:
		card["cost"] = old_cost - 1
		upgrades.append("费用 %d→%d" % [old_cost, card["cost"]])

	# 效果值+25%
	var etype = card.get("effect_type", "")
	var eval_ = card.get("effect_value", 0)
	if eval_ > 0 and etype in [
		"attack","attack_all","attack_lifesteal","shield","heal",
		"heal_all_buffs","attack_dot","attack_scaling_rage","shield_attack",
		"mass_heal_shield","attack_all_triple","weaken","weaken_fear"
	]:
		var new_val = int(eval_ * 1.25)
		card["effect_value"] = new_val
		upgrades.append("效果 %d→%d" % [eval_, new_val])

	# 条件加成+50%+1
	var bonus = card.get("condition_bonus", 0)
	if bonus > 0:
		var new_bonus = bonus + int(bonus * 0.5) + 1
		card["condition_bonus"] = new_bonus
		upgrades.append("加成 +%d→+%d" % [bonus, new_bonus])

	# 传说牌额外：情绪偏移翻倍
	if card.get("rarity","") == "legendary":
		var shift = card.get("emotion_shift", {})
		for k in shift:
			shift[k] = shift[k] * 2
		card["emotion_shift"] = shift
		upgrades.append("情绪偏移翻倍")

	# 标记已升级（供 CardDatabase 识别）
	card["level"] = card.get("level", 0) + 1

	deck_panel.visible = false
	var upgrade_text = "、".join(upgrades) if upgrades.size() > 0 else "强化完成"
	status_label.text = "「%s」已升级！\n%s" % [card.get("name","???"), upgrade_text]

	# 升级浮字特效
	_show_upgrade_effect()
	SoundManager.play_sfx("card_upgrade")

## 升级光效（全屏金色粒子模拟）
func _show_upgrade_effect() -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0.98, 0.85, 0.10, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ui = get_node_or_null("UI")
	if ui: ui.add_child(overlay)
	else: add_child(overlay)
	var tw = overlay.create_tween()
	tw.tween_property(overlay, "color:a", 0.35, 0.15)
	tw.tween_property(overlay, "color:a", 0.0,  0.5)
	tw.tween_callback(overlay.queue_free)

	# 升级浮字
	var lbl = Label.new()
	lbl.text = "✨ 升级成功！"
	lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.10))
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var root = get_node_or_null("UI") if get_node_or_null("UI") else self
	root.add_child(lbl)
	lbl.position = Vector2(400, 280)
	var tw2 = lbl.create_tween()
	tw2.tween_property(lbl, "position:y", 220.0, 1.2).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw2.tween_callback(lbl.queue_free)

func _on_leave() -> void:
	TransitionManager.change_scene("res://scenes/MapScene.tscn")

func _update_status() -> void:
	var hp_lbl = get_node_or_null("UI/HPStatus")
	if hp_lbl:
		hp_lbl.text = "HP: %d / %d" % [int(GameState.hp), int(GameState.max_hp)]
	status_label.text = "• 回复HP：恢复最大HP的30%%\n• 升级牌卡：费用-1 + 效果值+25%%\n\n当前HP：%d / %d" % [
		GameState.hp, GameState.max_hp]

## 程序化烛火背景装饰
func _build_bg_candles() -> void:
	var bg = get_node_or_null("BgCanvas")
	if not bg: return
	for i in 5:
		var candle = Label.new()
		candle.text = "🕯"
		candle.add_theme_font_size_override("font_size", 28)
		candle.modulate = Color(0.9, 0.6, 0.2, 0.7)
		candle.position = Vector2(60 + i * 180, 520 + (i % 2) * 30)
		bg.add_child(candle)
		# 烛火摇曳
		var tw = candle.create_tween().set_loops()
		tw.tween_property(candle, "rotation_degrees", 3.0 * (1 if i%2==0 else -1), 0.6 + i*0.1)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(candle, "rotation_degrees", -3.0 * (1 if i%2==0 else -1), 0.6 + i*0.1)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
