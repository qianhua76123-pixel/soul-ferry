extends Node2D

## BattleScene.gd - 战斗场景主控
## 祭坛式：左(玩家) | 中(情绪雷达) | 右(敌人) | 底(手牌)

# ========== 节点引用（路径与 BattleScene.tscn 严格对齐）==========
@onready var state_machine = $BattleStateMachine
@onready var hand_container:      HBoxContainer      = $UI/HandContainer

# HUD
@onready var turn_label:          Label       = $UI/HUD/TurnLabel
@onready var cost_label:          Label       = $UI/HUD/CostLabel
@onready var deck_count_label:    Label       = $UI/HUD/DeckCount
@onready var discard_count_label: Label       = $UI/HUD/DiscardCount
@onready var end_turn_btn:        Button      = $UI/HUD/EndTurnBtn
@onready var du_hua_btn:          Button      = $UI/HUD/DuHuaBtn

# 玩家区
@onready var player_hp_bar:       ProgressBar = $UI/AltarLayout/PlayerArea/HPBar
@onready var player_hp_label:     Label       = $UI/AltarLayout/PlayerArea/HPLabel
@onready var player_shield_label: Label       = $UI/AltarLayout/PlayerArea/ShieldLabel

# 敌人区
@onready var enemy_name_label:    Label       = $UI/AltarLayout/EnemyArea/EnemyName
@onready var enemy_hp_bar:        ProgressBar = $UI/AltarLayout/EnemyArea/HPBar
@onready var enemy_shield_label:  Label       = $UI/AltarLayout/EnemyArea/ShieldLabel
@onready var enemy_intent_label:  Label       = $UI/AltarLayout/EnemyArea/IntentLabel
@onready var du_hua_hint_label:   Label       = $UI/AltarLayout/EnemyArea/DuHuaHint
@onready var disorder_warning:    Label       = $UI/AltarLayout/AltarCenter/DisorderWarning

# 结算
@onready var result_panel:  Panel  = $UI/ResultPanel
@onready var result_label:  Label  = $UI/ResultPanel/ResultLabel
@onready var result_btn:    Button = $UI/ResultPanel/ContinueBtn

var _card_scene: PackedScene = preload("res://scenes/CardUI.tscn")

# ========== 初始化 ==========
func _ready() -> void:
	result_panel.visible = false
	du_hua_btn.visible   = false

	# 连接状态机
	state_machine.battle_started.connect(_on_battle_started)
	state_machine.player_turn_started.connect(_on_player_turn_started)
	state_machine.card_effect_applied.connect(_on_card_effect)
	state_machine.battle_ended.connect(_on_battle_ended)
	state_machine.du_hua_available.connect(_on_du_hua_available)

	# 连接情绪变化
	EmotionManager.emotion_changed.connect(_on_emotion_changed)
	EmotionManager.disorder_triggered.connect(_on_disorder_triggered)
	EmotionManager.disorder_cleared.connect(_on_disorder_cleared)

	# 连接游戏状态
	GameState.hp_changed.connect(_on_player_hp_changed)
	DeckManager.hand_updated.connect(_on_hand_updated)

	# 按钮
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	du_hua_btn.pressed.connect(_on_du_hua_pressed)
	result_btn.pressed.connect(_on_result_continue)

	# 读取挂载的敌人ID（由 MapScene 通过 meta 传入）
	var enemy_id = GameState.get_meta("pending_enemy_id", "yuan_gui")
	start_battle(enemy_id)

func start_battle(enemy_id: String) -> void:
	state_machine.start_battle(enemy_id)

# ========== 战斗信号响应 ==========

func _on_battle_started(enemy_data: Dictionary) -> void:
	enemy_name_label.text = "── %s ──" % enemy_data.get("name", "???")
	enemy_hp_bar.max_value = enemy_data.get("hp", 100)
	enemy_hp_bar.value     = enemy_data.get("hp", 100)
	enemy_shield_label.text = "🛡 护盾: 0"
	enemy_intent_label.text = "意图：..."
	du_hua_hint_label.text  = ""
	_update_hud()

func _on_player_turn_started(turn: int) -> void:
	turn_label.text       = "第 %d 回合" % turn
	end_turn_btn.disabled = false
	du_hua_btn.visible    = false
	disorder_warning.text = ""
	_update_hud()

func _on_card_effect(_card: Dictionary, result: Dictionary) -> void:
	enemy_hp_bar.value       = state_machine.enemy_hp
	enemy_shield_label.text  = "🛡 护盾: %d" % state_machine.enemy_shield
	player_shield_label.text = "🛡 护盾: %d" % state_machine.player_shield
	_update_hud()
	_show_damage_popup(result)

func _on_battle_ended(result: String) -> void:
	end_turn_btn.disabled = true
	result_panel.visible  = true
	match result:
		"victory":
			result_label.text = "镇压成功\n\n亡魂已被强行驱散。\n世间少了一份执念，也少了一个故事。"
			result_btn.text   = "继续前行"
		"du_hua":
			result_label.text = "渡化完成\n\n你帮他说清楚了那件事。\n他终于可以走了。"
			result_btn.text   = "目送他离去"
		"defeat":
			result_label.text = "你也困在这里了\n\n渡魂人，渡人先渡己。\n你忘了这条行规。"
			result_btn.text   = "重新开始"

func _on_du_hua_available(condition_desc: String) -> void:
	du_hua_btn.visible = true
	du_hua_hint_label.text = "💡 " + condition_desc

# ========== 按钮 ==========

func _on_end_turn_pressed() -> void:
	end_turn_btn.disabled = true
	state_machine.end_player_turn()

func _on_du_hua_pressed() -> void:
	state_machine.confirm_du_hua()

func _on_result_continue() -> void:
	result_panel.visible = false
	get_tree().change_scene_to_file("res://scenes/MapScene.tscn")

# ========== 手牌 UI ==========

func _on_hand_updated(hand: Array) -> void:
	for child in hand_container.get_children():
		child.queue_free()

	for card_data in hand:
		var card_ui = _card_scene.instantiate()
		if not card_ui:
			continue
		card_ui.setup(card_data)
		var can_afford = DeckManager.current_cost >= max(0, card_data.get("cost", 0) - EmotionManager.get_cost_reduction())
		card_ui.set_playable(can_afford and EmotionManager.can_play_card(card_data))
		card_ui.card_clicked.connect(_on_card_clicked)
		hand_container.add_child(card_ui)

func _on_card_clicked(card_data: Dictionary) -> void:
	if state_machine.current_state != 2: # PLAYER_TURN
		return
	state_machine.play_card(card_data)

# ========== 情绪变化 ==========

func _on_emotion_changed(_emotion: String, _old: int, _new: int) -> void:
	_update_hud()
	_refresh_hand_playable()

func _on_disorder_triggered(emotion: String) -> void:
	disorder_warning.text = "⚠ %s 失调！" % EmotionManager.get_emotion_name(emotion)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)

func _on_disorder_cleared(emotion: String) -> void:
	disorder_warning.text = ""

func _on_player_hp_changed(_old: int, new_hp: int) -> void:
	player_hp_bar.max_value = GameState.max_hp
	player_hp_bar.value     = new_hp
	player_hp_label.text    = "%d / %d" % [new_hp, GameState.max_hp]

# ========== HUD 更新 ==========

func _update_hud() -> void:
	cost_label.text          = "费用: %d" % DeckManager.current_cost
	deck_count_label.text    = "牌库: %d" % len(DeckManager.deck)
	discard_count_label.text = "弃牌: %d" % len(DeckManager.discard_pile)
	player_hp_bar.max_value  = GameState.max_hp
	player_hp_bar.value      = GameState.hp
	player_hp_label.text     = "%d / %d" % [GameState.hp, GameState.max_hp]

func _refresh_hand_playable() -> void:
	for card_ui in hand_container.get_children():
		if card_ui != null:
			var can_afford = DeckManager.current_cost >= max(0, card_ui.card_data.get("cost", 0) - EmotionManager.get_cost_reduction())
			card_ui.set_playable(can_afford and EmotionManager.can_play_card(card_ui.card_data))

# ========== 伤害弹出数字 ==========

func _show_damage_popup(result: Dictionary) -> void:
	var value = result.get("value", 0)
	if value <= 0:
		return
	var is_attack = result.get("type", "") in ["attack", "attack_all"]
	var lbl = Label.new()
	lbl.text = ("-%d" if is_attack else "+%d") % value
	lbl.add_theme_color_override("font_color", Color.RED if is_attack else Color.GREEN)
	lbl.add_theme_font_size_override("font_size", 22)
	add_child(lbl)
	# 弹出位置：敌人区域附近（固定屏幕坐标估算）
	lbl.position = Vector2(900 + randf_range(-30, 30), 300)
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 70, 0.7)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tween.tween_callback(lbl.queue_free)
