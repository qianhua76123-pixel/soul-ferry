extends Node2D

## BattleScene.gd - 战斗场景主控（祭坛式布局）

@onready var state_machine       = $BattleStateMachine
@onready var hand_container      = $UI/HandContainer
@onready var turn_label          = $UI/HUD/TurnLabel
@onready var cost_label          = $UI/HUD/CostLabel
@onready var deck_count_label    = $UI/HUD/DeckCount
@onready var discard_count_label = $UI/HUD/DiscardCount
@onready var end_turn_btn        = $UI/HUD/EndTurnBtn
@onready var du_hua_btn          = $UI/HUD/DuHuaBtn
@onready var player_hp_bar       = $UI/AltarLayout/PlayerArea/HPBar
@onready var player_hp_label     = $UI/AltarLayout/PlayerArea/HPLabel
@onready var player_shield_label = $UI/AltarLayout/PlayerArea/ShieldLabel
@onready var enemy_name_label    = $UI/AltarLayout/EnemyArea/EnemyName
@onready var enemy_hp_bar        = $UI/AltarLayout/EnemyArea/HPBar
@onready var enemy_shield_label  = $UI/AltarLayout/EnemyArea/ShieldLabel
@onready var enemy_intent_label  = $UI/AltarLayout/EnemyArea/IntentLabel
@onready var du_hua_hint_label   = $UI/AltarLayout/EnemyArea/DuHuaHint
@onready var disorder_warning    = $UI/AltarLayout/AltarCenter/DisorderWarning
@onready var result_panel        = $UI/ResultPanel
@onready var result_label        = $UI/ResultPanel/ResultLabel
@onready var result_btn          = $UI/ResultPanel/ContinueBtn

var _card_scene: PackedScene = preload("res://scenes/CardUI.tscn")

func _ready() -> void:
	result_panel.visible = false
	du_hua_btn.visible   = false

	state_machine.battle_started.connect(_on_battle_started)
	state_machine.player_turn_started.connect(_on_player_turn_started)
	state_machine.card_effect_applied.connect(_on_card_effect)
	state_machine.battle_ended.connect(_on_battle_ended)
	state_machine.du_hua_available.connect(_on_du_hua_available)

	EmotionManager.emotion_changed.connect(_on_emotion_changed)
	EmotionManager.disorder_triggered.connect(_on_disorder_triggered)
	EmotionManager.disorder_cleared.connect(_on_disorder_cleared)
	GameState.hp_changed.connect(_on_player_hp_changed)
	DeckManager.hand_updated.connect(_on_hand_updated)

	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	du_hua_btn.pressed.connect(_on_du_hua_pressed)
	result_btn.pressed.connect(_on_result_continue)

	# 连接 RelicManager 触发信号 → UI 提示
	RelicManager.relic_triggered.connect(_on_relic_triggered)
	# 连接渡化成功
	state_machine.du_hua_succeeded.connect(func(_eid): RelicManager.on_du_hua_success())

	# 问路香按钮（仅持有时可见）
	if RelicManager.has_relic("wenlu_xiang"):
		_add_wenlu_btn()

	var enemy_id = GameState.get_meta("pending_enemy_id", "yuan_gui")
	state_machine.start_battle(str(enemy_id))

func _on_battle_started(enemy_data: Dictionary) -> void:
	enemy_name_label.text   = "── %s ──" % enemy_data.get("name", "???")
	# 遗物：战斗开始触发
	RelicManager.on_battle_start(enemy_data)
	enemy_hp_bar.max_value  = enemy_data.get("hp", 100)
	enemy_hp_bar.value      = enemy_data.get("hp", 100)
	enemy_shield_label.text = "🛡 0"
	enemy_intent_label.text = "意图：..."
	du_hua_hint_label.text  = ""
	_update_hud()

func _on_player_turn_started(turn: int) -> void:
	turn_label.text       = "第 %d 回合" % turn
	end_turn_btn.disabled = false
	du_hua_btn.visible    = false
	disorder_warning.text = ""
	# 遗物：回合开始触发（DeckManager.on_turn_start 之后，手牌已摸完）
	RelicManager.on_turn_start()
	_update_hud()

func _on_card_effect(_card: Dictionary, result: Dictionary) -> void:
	enemy_hp_bar.value       = state_machine.enemy_hp
	enemy_shield_label.text  = "🛡 %d" % state_machine.enemy_shield
	player_shield_label.text = "🛡 %d" % state_machine.player_shield
	_update_hud()
	_show_popup(result)

func _on_battle_ended(result: String) -> void:
	_last_battle_result = result
	end_turn_btn.disabled = true
	result_panel.visible  = true
	# 遗物：镇压胜利触发烧骨片等
	if result == "victory":
		RelicManager.on_victory_zhenya()
	match result:
		"victory":
			result_label.text = "镇压成功\n\n亡魂已被强行驱散。"
			result_btn.text   = "继续前行"
		"du_hua":
			result_label.text = "渡化完成\n\n你帮他说清楚了那件事。\n他终于可以走了。"
			result_btn.text   = "目送他离去"
		"defeat":
			result_label.text = "你也困在这里了\n\n渡魂人，渡人先渡己。"
			result_btn.text   = "重新开始"

## 遗物触发时在屏幕左上角浮现提示
func _on_relic_triggered(relic_id: String, effect_desc: String) -> void:
	# 烧骨片护盾：直接加到 state_machine
	if relic_id == "shaogu_pian_shield_2":
		state_machine.player_shield += 2
		player_shield_label.text = "🛡 %d" % state_machine.player_shield
	_show_relic_popup(effect_desc)

func _show_relic_popup(desc: String) -> void:
	var lbl = Label.new()
	lbl.text = "✦ " + desc
	lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.0))
	lbl.add_theme_font_size_override("font_size", 13)
	add_child(lbl)
	lbl.position = Vector2(12, 80 + randf_range(0, 20))
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 40, 1.2)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tween.tween_callback(lbl.queue_free)

func _on_du_hua_available(desc: String) -> void:
	du_hua_btn.visible     = true
	du_hua_hint_label.text = "💡 " + desc

func _on_end_turn_pressed() -> void:
	end_turn_btn.disabled = true
	state_machine.end_player_turn()

func _on_du_hua_pressed() -> void:
	state_machine.confirm_du_hua()

func _on_result_continue() -> void:
	result_panel.visible = false
	var result = _last_battle_result
	if result == "victory" or result == "du_hua":
		# 胜利/渡化 → 选牌奖励
		get_tree().change_scene_to_file("res://scenes/CardRewardScene.tscn")
	else:
		# 失败 → 回主菜单（以后做存档）
		GameState.new_run()
		DeckManager.init_starter_deck()
		get_tree().change_scene_to_file("res://scenes/MapScene.tscn")

var _last_battle_result: String = ""

func _on_hand_updated(hand: Array) -> void:
	for child in hand_container.get_children():
		child.queue_free()
	for card_data in hand:
		var card_ui = _card_scene.instantiate()
		if not card_ui: continue
		if card_ui.has_method("setup"):
			card_ui.setup(card_data)
		var can_afford = DeckManager.current_cost >= max(0, card_data.get("cost", 0) - EmotionManager.get_cost_reduction())
		if card_ui.has_method("set_playable"):
			card_ui.set_playable(can_afford and EmotionManager.can_play_card(card_data))
		card_ui.card_clicked.connect(_on_card_clicked)
		hand_container.add_child(card_ui)

func _on_card_clicked(card_data: Dictionary) -> void:
	if state_machine.current_state != 2: # STATE_PLAYER_TURN
		return
	state_machine.play_card(card_data)

func _on_emotion_changed(_e: String, _o: int, _n: int) -> void:
	_update_hud()
	_refresh_hand()

func _on_disorder_triggered(emotion: String) -> void:
	disorder_warning.text = "⚠ %s 失调！" % EmotionManager.get_emotion_name(emotion)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)

func _on_disorder_cleared(_e: String) -> void:
	disorder_warning.text = ""

func _on_player_hp_changed(_o: int, new_hp: int) -> void:
	player_hp_bar.max_value = GameState.max_hp
	player_hp_bar.value     = new_hp
	player_hp_label.text    = "%d / %d" % [new_hp, GameState.max_hp]

func _update_hud() -> void:
	cost_label.text          = "费用: %d" % DeckManager.current_cost
	deck_count_label.text    = "牌库: %d" % len(DeckManager.deck)
	discard_count_label.text = "弃牌: %d" % len(DeckManager.discard_pile)
	player_hp_bar.max_value  = GameState.max_hp
	player_hp_bar.value      = GameState.hp
	player_hp_label.text     = "%d / %d" % [GameState.hp, GameState.max_hp]

func _refresh_hand() -> void:
	for card_ui in hand_container.get_children():
		if card_ui.has_method("set_playable") and card_ui.has_method("get") :
			var cd = card_ui.get("card_data")
			if cd:
				var can_afford = DeckManager.current_cost >= max(0, cd.get("cost", 0) - EmotionManager.get_cost_reduction())
				card_ui.set_playable(can_afford and EmotionManager.can_play_card(cd))

func _show_popup(result: Dictionary) -> void:
	var value = result.get("value", 0)
	if value <= 0: return
	var is_dmg = result.get("type", "") in ["attack", "attack_all"]
	var lbl = Label.new()
	lbl.text = ("-%d" if is_dmg else "+%d") % value
	lbl.add_theme_color_override("font_color", Color.RED if is_dmg else Color.GREEN)
	lbl.add_theme_font_size_override("font_size", 22)
	add_child(lbl)
	lbl.position = Vector2(900 + randf_range(-30, 30), 280)
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 70, 0.7)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tween.tween_callback(lbl.queue_free)

## 问路香按钮（动态添加到 HUD）
func _add_wenlu_btn() -> void:
	var hud = get_node_or_null("UI/HUD")
	if not hud: return
	var btn = Button.new()
	btn.name = "WenluBtn"
	btn.text = "🕯问路香"
	btn.custom_minimum_size = Vector2(90, 30)
	btn.pressed.connect(_on_wenlu_pressed)
	hud.add_child(btn)

func _on_wenlu_pressed() -> void:
	if not RelicManager.use_wenlu_xiang(): return
	# 展示敌人下两回合意图（从 state_machine 读取）
	var intent_lbl = get_node_or_null("UI/AltarLayout/EnemyArea/IntentLabel")
	if intent_lbl:
		var acts = state_machine.enemy_data.get("actions", [])
		if acts.is_empty(): return
		var preview = []
		for a in acts.slice(0, min(2, len(acts))):
			preview.append("%s %s" % [a.get("type","?"), str(a.get("value",""))])
		intent_lbl.text = "感知：" + " / ".join(preview)
	# 禁用按钮
	var btn = get_node_or_null("UI/HUD/WenluBtn")
	if btn: btn.disabled = true
