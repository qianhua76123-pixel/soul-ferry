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
	result_panel.visible = false
	result_continue_btn.pressed.connect(_on_continue_pressed)
	_load_events()
	# 自动加载（来自地图传入的事件ID）
	var eid = ""
	if GameState.has_meta("pending_event_id"):
		eid = str(GameState.get_meta("pending_event_id"))
		GameState.remove_meta("pending_event_id")
	load_event(eid)

func _load_events() -> void:
	var file = FileAccess.open("res://data/events.json", FileAccess.READ)
	if not file:
		push_error("EventScene: 无法加载事件数据")
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	file.close()
	_all_events = json.get_data().get("events", [])

## 外部调用：传入事件ID或随机加载
func load_event(event_id: String = "") -> void:
	if event_id == "":
		# 按当前层过滤，随机选一个
		var layer_events = _all_events.filter(
			func(e): return e.get("layer", 1) <= GameState.current_layer
		)
		if layer_events.is_empty():
			layer_events = _all_events
		_current_event = layer_events[randi() % len(layer_events)]
	else:
		for e in _all_events:
			if e.get("id", "") == event_id:
				_current_event = e
				break

	_render_event()

func _render_event() -> void:
	title_label.text = _current_event.get("title", "???")
	desc_label.text = _current_event.get("description", "")

	# 清空旧选项
	for child in choices_container.get_children():
		child.queue_free()

	# 创建选项按钮
	var choices = _current_event.get("choices", [])
	for i in len(choices):
		var choice = choices[i]
		var btn = Button.new()
		btn.text = choice.get("text", "选项%d" % (i + 1))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(500, 44)
		# 连接信号（闭包捕获 choice）
		var captured = choice
		btn.pressed.connect(func(): _on_choice_selected(captured))
		choices_container.add_child(btn)

func _on_choice_selected(choice: Dictionary) -> void:
	# 禁用所有按钮，防止重复点击
	for btn in choices_container.get_children():
		btn.disabled = true

	var result = choice.get("result", {})
	_apply_result(result)
	_show_result(result)

func _apply_result(result: Dictionary) -> void:
	var result_type = result.get("type", "")

	match result_type:
		"card_reward":
			var card = CardDatabase.get_card(result.get("card_id", ""))
			if not card.is_empty():
				DeckManager.add_card_to_deck(card)

		"multi":
			for effect in result.get("effects", []):
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
			GameState.gain_gold(result.get("value", 0))

		"curse_card":
			var card = CardDatabase.get_card(result.get("card_id", ""))
			if not card.is_empty():
				card["is_curse"] = true
				DeckManager.add_card_to_deck(card)

func _apply_single_effect(effect: Dictionary) -> void:
	match effect.get("type", ""):
		"card_reward":
			var card = CardDatabase.get_card(effect.get("card_id", ""))
			if not card.is_empty():
				DeckManager.add_card_to_deck(card)
		"emotion_gain":
			EmotionManager.modify(effect.get("emotion", "calm"), effect.get("value", 1))
		"hp_loss":
			GameState.take_damage(effect.get("value", 0))
		"hp_gain":
			GameState.heal(effect.get("value", 0))
		"gold":
			GameState.gain_gold(effect.get("value", 0))
		"relic_reward":
			GameState.add_relic(effect.get("relic_id", ""))
		"max_hp_gain":
			GameState.increase_max_hp(effect.get("value", 0))
		"card_upgrade":
			# 随机升级牌库中一张牌（升级 = 费用-1，不低于0）
			var full_deck = DeckManager.get_full_deck()
			if not full_deck.is_empty():
				var target = full_deck[randi() % len(full_deck)]
				target["cost"] = max(0, target.get("cost", 1) - 1)
		"curse_card":
			var card = CardDatabase.get_card(effect.get("card_id", ""))
			if not card.is_empty():
				card["is_curse"] = true
				DeckManager.add_card_to_deck(card)
		"narrative":
			pass  # 叙事效果只在 result 文本中展示

func _show_result(result: Dictionary) -> void:
	result_panel.visible = true
	var desc = result.get("description", "选择已生效。")
	# 追加叙事文本
	for effect in result.get("effects", []):
		var narrative = effect.get("text", "")
		if narrative != "":
			desc += "\n\n[i]" + narrative + "[/i]"
	result_label.text = desc

func _on_continue_pressed() -> void:
	emit_signal("event_completed", _current_event)
	get_tree().change_scene_to_file("res://scenes/MapScene.tscn")
