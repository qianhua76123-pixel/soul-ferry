extends Node2D

## EventScene.gd - 民俗事件场景
## 从 events.json 加载事件，渲染故事文本和选项，处理选择结果


signal event_completed(result: Dictionary)

# ========== 节点引用 ==========
@onready var title_label: Label = $UI/EventPanel/VBox/EventTitle
@onready var desc_label: RichTextLabel = $UI/EventPanel/VBox/EventDesc
@onready var choices_container: VBoxContainer = $UI/EventPanel/VBox/ChoicesContainer
@onready var result_panel: Panel = $UI/ResultPanel
@onready var result_label: RichTextLabel = $UI/ResultPanel/ResultText
@onready var result_continue_btn: Button = $UI/ResultPanel/ContinueBtn
@onready var atmosphere_particles: CPUParticles2D = $AtmosphereParticles  # 氛围粒子

var _current_event: Dictionary = {}
var _all_events: Array = []

# ========== 初始化 ==========
func _ready() -> void:
	TransitionManager.fade_in_only()
	result_panel.visible = false
	result_continue_btn.pressed.connect(_on_continue_pressed)
	_load_events()
	# 自动加载（来自地图传入的事件ID）
	var eid: String = ""
	if GameState.has_meta("pending_event_id"):
		eid = str(GameState.get_meta("pending_event_id"))
		GameState.remove_meta("pending_event_id")
	load_event(eid)
	_setup_event_visual()

func _load_events() -> void:
	var file: FileAccess = FileAccess.open("res://data/events.json", FileAccess.READ)
	if not file:
		push_error("EventScene: 无法加载事件数据")
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	file.close()
	_all_events = json.get_data().get("events", [])

## 外部调用：传入事件ID或随机加载
func load_event(event_id: String = "") -> void:
	if event_id == "":
		# 按当前层过滤，随机选一个
		var layer_events: Array = _all_events.filter(
			func(e: Dictionary) -> bool: return e.get("layer", 1) <= GameState.current_layer
		)
		if layer_events.is_empty():
			layer_events = _all_events
		_current_event = layer_events[randi() % len(layer_events)]
	else:
		for e: Dictionary in _all_events:
			if e.get("id", "") == event_id:
				_current_event = e
				break

	_render_event()

func _render_event() -> void:
	title_label.text = _current_event.get("title", "???")
	desc_label.text = _current_event.get("description", "")

	# 清空旧选项
	for child: Node in choices_container.get_children():
		child.queue_free()

	# 年画眼：若持有且本局未用，展示所有选项的真实结果
	var show_results: bool = RelicManager.has_relic("nianhua_yan") and not RelicManager.nianhua_used_this_run

	# 创建选项按钮
	var choices: Array = _current_event.get("choices", [])
	for i: int in len(choices):
		var choice: Dictionary = choices[i]
		var btn: Button = Button.new()
		var btn_text: String = choice.get("text", "选项%d" % (i + 1))
		if show_results:
			# 附加真实结果预览
			var result_preview: String = _get_result_preview(choice.get("result", {}))
			btn_text += "\n[年画眼] → " + result_preview
		btn.text = btn_text
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(500, 44)
		btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
		btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
		btn.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
		btn.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))
		var captured: Dictionary = choice
		btn.pressed.connect(func(): _on_choice_selected(captured))
		choices_container.add_child(btn)

	# 年画眼激活按钮（一局一次）
	if RelicManager.has_relic("nianhua_yan") and not RelicManager.nianhua_used_this_run and not show_results:
		var reveal_btn: Button = Button.new()
		reveal_btn.text = "👁 年画眼：看清真相（本局仅一次）"
		reveal_btn.custom_minimum_size = Vector2(500, 36)
		reveal_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
		reveal_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
		reveal_btn.add_theme_color_override("font_color", UIConstants.color_of("gold"))
		reveal_btn.pressed.connect(func():
			RelicManager.use_nianhua_yan()
			_render_event()   # 重新渲染带预览的选项
		)
		choices_container.add_child(reveal_btn)

func _get_result_preview(result: Dictionary) -> String:
	var parts: Array = []
	var rtype: String = result.get("type", "")
	match rtype:
		"hp_gain":        parts.append("HP +%d" % int(result.get("value",0)))
		"hp_loss":        parts.append("HP -%d" % int(result.get("value",0)))
		"gold":           parts.append("金币 +%d" % int(result.get("value",0)))
		"max_hp_gain":    parts.append("最大HP +%d" % int(result.get("value",0)))
		"relic_reward":   parts.append("获得遗物")
		"card_reward":    parts.append("获得牌")
		"curse_card":     parts.append("获得诅咒牌")
		"emotion_gain":
			var e: String = EmotionManager.get_emotion_name(result.get("emotion",""))
			parts.append("%s +%d" % [e, int(result.get("value",0))])
		"multi":
			for eff in result.get("effects", []):
				parts.append(_get_result_preview(eff))
	if parts.is_empty(): return result.get("description","???")
	return "、".join(parts)

func _on_choice_selected(choice: Dictionary) -> void:
	# 禁用所有按钮，防止重复点击
	for btn: Node in choices_container.get_children():
		btn.set("disabled", true)

	var result: Dictionary = choice.get("result", {})
	_apply_result(result)
	_show_result(result)

func _apply_result(result: Dictionary) -> void:
	var result_type: String = result.get("type", "")

	match result_type:
		"card_reward":
			var card: Dictionary = CardDatabase.get_card(result.get("card_id", ""))
			if not card.is_empty():
				DeckManager.add_card_to_deck(card)

		"multi":
			for effect: Dictionary in result.get("effects", []):
				_apply_single_effect(effect)

		"emotion_gain":
			EmotionManager.modify(result.get("emotion", "calm"), result.get("value", 1))

		"hp_gain":
			GameState.heal(result.get("value", 0))

		"hp_loss":
			GameState.take_damage(result.get("value", 0))

		"relic_reward":
			GameState.add_relic(result.get("relic_id", ""))

		"max_hp_gain":
			GameState.increase_max_hp(result.get("value", 0))

		"gold":
			var gv: int = result.get("value", 0)
			if gv >= 0: GameState.gain_gold(gv)
			else: GameState.spend_gold(-gv)

		"curse_card":
			var card_2: Dictionary = CardDatabase.get_card(result.get("card_id", ""))
			if not card_2.is_empty():
				card_2["is_curse"] = true
				DeckManager.add_card_to_deck(card_2)

		"lost_ending":
			## 隐藏结局：迷失轮回
			AchievementManager.unlock("lost_ending")
			await get_tree().create_timer(0.6).timeout
			GameState.trigger_ending("lost")

func _apply_single_effect(effect: Dictionary) -> void:
	match effect.get("type", ""):
		"card_reward":
			var card: Dictionary = CardDatabase.get_card(effect.get("card_id", ""))
			if not card.is_empty():
				DeckManager.add_card_to_deck(card)
		"emotion_gain":
			EmotionManager.modify(effect.get("emotion", "calm"), effect.get("value", 1))
		"hp_loss":
			GameState.take_damage(effect.get("value", 0))
		"hp_gain":
			GameState.heal(effect.get("value", 0))
		"gold":
			var ev: int = effect.get("value", 0)
			if ev >= 0: GameState.gain_gold(ev)
			else: GameState.spend_gold(-ev)
		"relic_reward":
			GameState.add_relic(effect.get("relic_id", ""))
		"max_hp_gain":
			GameState.increase_max_hp(effect.get("value", 0))
		"card_upgrade":
			# 随机升级牌库中一张牌（升级 = 费用-1，不低于0）
			var full_deck: Array = DeckManager.get_full_deck()
			if not full_deck.is_empty():
				var target: Dictionary = full_deck[randi() % len(full_deck)]
				target["cost"] = max(0, target.get("cost", 1) - 1)
		"curse_card":
			var card_2: Dictionary = CardDatabase.get_card(effect.get("card_id", ""))
			if not card_2.is_empty():
				card_2["is_curse"] = true
				DeckManager.add_card_to_deck(card_2)
		"narrative":
			pass  # 叙事效果只在 result 文本中展示

func _show_result(result: Dictionary) -> void:
	result_panel.visible = true
	var desc: String = result.get("description", "选择已生效。")
	# 追加叙事文本
	for effect: Dictionary in result.get("effects", []):
		var narrative: String = effect.get("text", "")
		if narrative != "":
			desc += "\n\n[i]" + narrative + "[/i]"
	result_label.text = desc
	result_label.add_theme_font_size_override("normal_font_size", UIConstants.font_size_of("body"))
	result_continue_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	result_continue_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	result_continue_btn.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))

func _on_continue_pressed() -> void:
	event_completed.emit(_current_event)
	TransitionManager.change_scene("res://scenes/MapScene.tscn")

func _setup_event_visual() -> void:
	## 事件场景氛围：深色面板 + 标题金色

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.06, 1.0)
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	# 顶部金色装饰线
	var deco = ColorRect.new()
	deco.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	deco.size.y = 3
	deco.color  = Color(0.65, 0.50, 0.10, 0.8)
	deco.z_index = 5
	add_child(deco)

	# 底部装饰线
	var deco2 = ColorRect.new()
	deco2.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	deco2.size.y   = 3
	deco2.position.y = -3
	deco2.color    = Color(0.65, 0.50, 0.10, 0.8)
	deco2.z_index  = 5
	add_child(deco2)

	# 事件主面板切角描边（DS-00）
	var event_panel: Node = get_node_or_null("UI/EventPanel")
	if event_panel:
		var inked: InkedPanel = InkedPanel.new()
		inked.set_anchors_preset(Control.PRESET_FULL_RECT)
		inked.fill_color = Color(UIConstants.color_of("parch").r, UIConstants.color_of("parch").g, UIConstants.color_of("parch").b, 0.78)
		inked.border_color = Color(UIConstants.color_of("gold_dim").r, UIConstants.color_of("gold_dim").g, UIConstants.color_of("gold_dim").b, 0.55)
		inked.top_line_color = UIConstants.color_of("gold")
		event_panel.add_child(inked)
		event_panel.move_child(inked, 0)

	# 标题、正文字号统一
	title_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("heading"))
	title_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	desc_label.add_theme_font_size_override("normal_font_size", UIConstants.font_size_of("body"))
	desc_label.add_theme_color_override("default_color", UIConstants.color_of("text_secondary"))

	# 标题与正文之间加一条水墨分割线
	var vbox: Node = get_node_or_null("UI/EventPanel/VBox")
	if vbox:
		var divider: WaterInkDivider = WaterInkDivider.new()
		divider.custom_minimum_size = Vector2(500, 8)
		divider.ink_color = UIConstants.color_of("gold_dim")
		vbox.add_child(divider)
		vbox.move_child(divider, 1)
