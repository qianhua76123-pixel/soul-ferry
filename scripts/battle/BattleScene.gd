extends Node2D

## BattleScene.gd - 战斗场景主控（祭坛式布局）

const UIC = preload("res://scripts/ui/UIConstants.gd")

@onready var state_machine       = $BattleStateMachine
@onready var hand_container      = $UI/HandContainer
@onready var turn_label          = $UI/HUD/TurnLabel
@onready var cost_label:          Label    = $UI/HUD/CostLabel
@onready var deck_count_label:    Label    = $UI/HUD/DeckCount
@onready var discard_count_label: Label    = $UI/HUD/DiscardCount
@onready var end_turn_btn:        Button   = $UI/HUD/EndTurnBtn
@onready var du_hua_btn:          Button   = $UI/HUD/DuHuaBtn
@onready var player_hp_bar:       ProgressBar = $UI/AltarLayout/PlayerArea/HPBar
@onready var player_hp_label:     Label    = $UI/AltarLayout/PlayerArea/HPLabel
@onready var player_shield_label: Label    = $UI/AltarLayout/PlayerArea/ShieldLabel
@onready var enemy_name_label    = $UI/AltarLayout/EnemyArea/EnemyName
@onready var enemy_hp_bar        = $UI/AltarLayout/EnemyArea/HPBar
@onready var enemy_shield_label  = $UI/AltarLayout/EnemyArea/ShieldLabel
@onready var enemy_intent_label  = $UI/AltarLayout/EnemyArea/IntentLabel
@onready var du_hua_hint_label   = $UI/AltarLayout/EnemyArea/DuHuaHint
@onready var disorder_warning    = $UI/AltarLayout/AltarCenter/DisorderWarning
@onready var result_panel        = $UI/ResultPanel
@onready var result_label        = $UI/ResultPanel/ResultLabel
@onready var result_btn          = $UI/ResultPanel/ContinueBtn

var _card_scene:   PackedScene = preload("res://scenes/CardUI.tscn")
var _dmgnum_scene: PackedScene = preload("res://scenes/DamageNumber.tscn")

## B-02 双层残影血条组件实例
var _player_hbar: Control = null
var _enemy_hbar:  Control = null

## B-04 敌人意图预告组件
var _intent_display:    Control = null
var _purif_panel:       Control = null
const IntentDisplayClass    = preload("res://scripts/ui/IntentDisplay.gd")
const PurificationPanelClass = preload("res://scripts/ui/PurificationPanel.gd")

## B-05 卡牌悬停预览组件
var _card_preview: Control = null
const CardPreviewClass = preload("res://scripts/ui/CardPreview.gd")

## B-07 战场氛围背景 + 费用圆点HUD
var _bg_node:        Node2D  = null
var _energy_display: Control = null
const BattleBackgroundClass = preload("res://scripts/battle/BattleBackground.gd")
const EnergyDisplayClass    = preload("res://scripts/ui/EnergyDisplay.gd")

## 显式 preload 保证 Godot 4.6 编译期能找到静态类定义
const EnemyPixelArtClass  = preload("res://scripts/ui/EnemyPixelArt.gd")
const PlayerPixelArtClass = preload("res://scripts/ui/PlayerPixelArt.gd")

## Boss UI 控制器（仅 Boss 战时激活）
var _boss_ui: BossUI = null

func _ready() -> void:
	TransitionManager.fade_in_only()
	result_panel.visible = false
	du_hua_btn.visible   = false

	# ── 第一步：信号连接（纯逻辑，无 UI 依赖）──
	state_machine.battle_started.connect(_on_battle_started)
	state_machine.player_turn_started.connect(_on_player_turn_started)
	state_machine.enemy_turn_started.connect(_on_enemy_turn_started)
	state_machine.card_effect_applied.connect(_on_card_effect)
	state_machine.battle_ended.connect(_on_battle_ended)
	state_machine.du_hua_available.connect(_on_du_hua_available)
	state_machine.intent_updated.connect(_on_intent_updated)

	EmotionManager.emotion_changed.connect(_on_emotion_changed)
	EmotionManager.disorder_triggered.connect(_on_disorder_triggered)
	EmotionManager.disorder_cleared.connect(_on_disorder_cleared)
	GameState.hp_changed.connect(_on_player_hp_changed)
	DeckManager.hand_updated.connect(_on_hand_updated)

	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	du_hua_btn.pressed.connect(_on_du_hua_pressed)
	result_btn.pressed.connect(_on_result_continue)

	RelicManager.relic_triggered.connect(_on_relic_triggered)
	state_machine.du_hua_succeeded.connect(func(_eid): RelicManager.on_du_hua_success())

	# ── 第二步：UI 主题 & 样式（不依赖布局尺寸）──
	_setup_hud_theme()
	_setup_result_panel_theme()

	# ── 第三步：动态 UI 组件（添加子节点，不依赖 size）──
	_setup_battle_background()   # 最底层背景，先挂上
	if RelicManager.has_relic("wenlu_xiang"):
		_add_wenlu_btn()
	_build_relic_bar()
	_setup_buff_ui()
	_setup_player_sprite()
	_setup_intent_display()
	_setup_purification_panel()
	_setup_energy_display()

	# ── 第四步：布局微调（需要节点树已完整，延迟一帧）──
	call_deferred("_deferred_layout_setup")

	# ── 第五步：启动战斗逻辑（最后执行，保证 UI 节点全部就位）──
	var enemy_id: String = str(GameState.get_meta("pending_enemy_id", "yuan_gui"))
	state_machine.start_battle(str(enemy_id))

func _deferred_layout_setup() -> void:
	## 延迟一帧执行，此时 Control 节点 size 已由引擎布局计算完毕
	_setup_layout_improvements()
	_setup_altar_title_style()

func _on_battle_started(enemy_data: Dictionary) -> void:
	enemy_name_label.text   = "── %s ──" % enemy_data.get("name", "???")
	RelicManager.on_battle_start(enemy_data)
	# 新血条（主显示）
	var enemy_max := int(enemy_data.get("hp", 100))
	if _enemy_hbar and _enemy_hbar.has_method("set_hp"):
		_enemy_hbar.set_hp(enemy_max, enemy_max)
	# 旧 ProgressBar 隐藏，仅保留数据同步（给依赖它的其他代码用）
	enemy_hp_bar.max_value = enemy_max
	enemy_hp_bar.value     = enemy_max
	_setup_enemy_sprite(enemy_data)
	enemy_shield_label.text = "🛡 0"
	du_hua_hint_label.text  = ""
	if _purif_panel and _purif_panel.has_method("setup_conditions"):
		_purif_panel.setup_conditions(enemy_data)
	_update_hud()
	var is_boss: bool = enemy_data.get("type", "") == "boss"
	SoundManager.play_battle_bgm(GameState.current_layer, is_boss)
	# 成就：Boss 战开始追踪
	if is_boss:
		AchievementManager.on_boss_battle_start(GameState.hp)
	# 成就：牌库检查
	AchievementManager.check_deck_achievements()
	# Boss UI：仅 Boss 战时激活
	if is_boss:
		_setup_boss_ui(enemy_data)

func _on_player_turn_started(turn: int) -> void:
	var moon_icons: Array = ["🌑","🌒","🌓","🌔","🌕","🌖","🌗","🌘"]
	var moon: String = moon_icons[int(turn - 1) % 8]
	turn_label.text       = "%s 第 %d 回合" % [moon, int(turn)]
	end_turn_btn.disabled = false
	du_hua_btn.visible    = false
	disorder_warning.text = ""
	# 遗物：回合开始触发（DeckManager.on_turn_start 之后，手牌已摸完）
	RelicManager.on_turn_start()
	_update_hud()
	SoundManager.play_sfx("card_draw")
	# Boss UI：回合开始刷新意图预告
	if _boss_ui:
		_boss_ui.on_turn_start(state_machine.enemy_hp, turn)

func _on_enemy_turn_started() -> void:
	# 敌人行动时锁定结束回合按钮
	end_turn_btn.disabled = true
	# 特殊行动UI反馈：摸牌陷阱提示
	var last_action: String = state_machine.enemy_data.get("_last_action_type", "")
	match last_action:
		"draw_player":
			_spawn_special_text("💀 摄魅凝视！强迫摸牌", Color(0.55, 0.10, 0.75))
		"summon_tide":
			_spawn_special_text("🌊 召唤潮汐！连续冲击", Color(0.25, 0.55, 0.78))
		"rage_card_storm":
			_spawn_special_text("💢 花嫁之怒！手牌越多伤越高", Color(0.88, 0.15, 0.18))

func _spawn_special_text(msg: String, color: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ui: Node = get_node_or_null("UI")
	if ui: ui.add_child(lbl)
	else: add_child(lbl)
	lbl.position = Vector2(576 - 160, 260)
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 60, 1.5)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.5)
	tw.tween_callback(lbl.queue_free)

func _on_card_effect(_card: Dictionary, result: Dictionary) -> void:
	# 敌人血条（新 + 旧同步）
	enemy_hp_bar.value = state_machine.enemy_hp
	if _enemy_hbar and _enemy_hbar.has_method("set_hp"):
		_enemy_hbar.set_hp(state_machine.enemy_hp, state_machine.enemy_max_hp)
	if _enemy_hbar and _enemy_hbar.has_method("set_shield"):
		_enemy_hbar.set_shield(state_machine.enemy_shield)
	enemy_shield_label.text  = "🛡 %d" % int(state_machine.enemy_shield)
	player_shield_label.text = "🛡 %d" % int(state_machine.player_shield)
	if _player_hbar and _player_hbar.has_method("set_shield"):
		_player_hbar.set_shield(state_machine.player_shield)
	_update_hud()
	var rtype: String = result.get("type","")
	var rval: int  = int(result.get("value", 0))
	if rval > 0:
		var dmg_types   = ["attack","attack_all","attack_lifesteal","attack_dot","attack_scaling_rage","attack_all_triple","attack_and_weaken_all","shield_attack","remove_enemy_shield"]
		var heal_types  = ["heal","heal_all_buffs","heal_and_draw","heal_scale_grief","mass_heal_shield"]
		var shield_types= ["shield","shield_and_draw","reset_shield","balance_emotions"]
		if rtype in dmg_types:
			_spawn_enemy_damage(rval, "damage")
			SoundManager.play_sfx("attack_hit")
		elif rtype in heal_types:
			_spawn_player_number(rval, "heal")
			SoundManager.play_sfx("heal")
		elif rtype in shield_types:
			_spawn_player_number(rval, "shield")
			SoundManager.play_sfx("shield_block")
	_show_popup(result)
	# Boss UI：卡牌效果后更新 Boss 状态
	if _boss_ui:
		_boss_ui.on_card_played(_card, result, state_machine.enemy_hp, state_machine.current_turn)

func _on_battle_ended(result: String) -> void:
	_last_battle_result = result
	end_turn_btn.disabled = true
	result_panel.visible  = true
	# 遗物：镇压胜利触发烧骨片等
	if result == "victory":
		RelicManager.on_victory_zhenya()
		if _boss_ui: _boss_ui.on_boss_defeated()
	# 成就追踪
	var is_boss: bool = state_machine.enemy_data.get("type","") == "boss"
	if is_boss:
		AchievementManager.on_boss_battle_end(result, GameState.hp)
	elif result == "du_hua":
		AchievementManager.record_du_hua()
	elif result == "victory":
		AchievementManager.record_zhen_ya()
	match result:
		"victory":
			result_label.text = _result_panel_bbcode("镇压成功", "亡魂已被强行驱散。")
			result_btn.text   = "继续前行"
			SoundManager.play_sfx("battle_victory")
		"du_hua":
			result_label.text = _result_panel_bbcode("渡化完成", "你帮他说清楚了那件事。\n他终于可以走了。")
			result_btn.text   = "目送他离去"
			SoundManager.play_sfx("du_hua_success")
		"defeat":
			result_label.text = _result_panel_bbcode("你也困在这里了", "渡魂人，渡人先渡己。")
			result_btn.text   = "重新开始"
			SoundManager.play_sfx("battle_defeat")

## ── 战斗场内迷你遗物栏 ──────────────────────────────
## 在 _ready() 末尾调用 _build_relic_bar()，渲染玩家持有的遗物图标
## 每个图标 Label 命名为 "rbtn_<relic_id>"，供触发动画精确定位

const RELIC_ICONS = {
	"tong_jing_sui":"🪞","wenlu_xiang":"🕯","duhun_ce":"📖",
	"shaogu_pian":"🦴","qingming_pai":"🪶","wuqing_jie":"🎀",
	"nianhua_yan":"👁","yin_yang_bi":"✒","hun_bo_lu":"🔥","si_xiang_pian":"🌾",
}

## 在玩家区底部动态创建迷你遗物栏
func _build_relic_bar() -> void:
	var player_area: Node = get_node_or_null("UI/AltarLayout/PlayerArea")
	if not player_area: return
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "BattleRelicBar"
	for rid in GameState.relics:
		var lbl: Label = Label.new()
		lbl.name   = "rbtn_" + rid
		lbl.text   = RELIC_ICONS.get(rid, "◈")
		lbl.add_theme_font_size_override("font_size", 20)
		var data: Dictionary = RelicManager._all_relics_data.get(rid, {})
		lbl.tooltip_text = data.get("name","???") + "\n" + data.get("effect","")
		bar.add_child(lbl)
	player_area.add_child(bar)

## 遗物触发：闪光动画 + 浮字提示
## 同一帧多个触发各自独立（每次创建新 Tween，互不干扰）
func _on_relic_triggered(relic_id: String, effect_desc: String) -> void:
	# ── 特殊处理：烧骨片护盾直接加数值 ──
	if relic_id == "shaogu_pian_shield_2":
		state_machine.player_shield += 2
		player_shield_label.text = "🛡 %d" % int(state_machine.player_shield)

	# ── 图标闪光：找到对应 Label，做 modulate 动画 ──
	_flash_relic_icon(relic_id)

	# ── 浮字提示（左上角上浮淡出）──
	_show_relic_popup(effect_desc)

## 纯 Tween 实现图标闪光，0.25s，不使用 AnimationPlayer
## 多个遗物同帧触发时各自 create_tween()，互相独立不干扰
func _flash_relic_icon(relic_id: String) -> void:
	var bar: Node = get_node_or_null("UI/AltarLayout/PlayerArea/BattleRelicBar")
	if not bar: return
	var icon: Node = bar.get_node_or_null("rbtn_" + relic_id)
	if not icon: return

	# 记录原始 modulate（如果上一帧动画还没结束，先恢复）
	var original: Color = Color.WHITE

	# 独立 Tween：白色闪光 → 金色高亮 → 恢复白色
	# 每次 create_tween() 都是全新实例，互不影响
	var tw: Tween = icon.create_tween()
	tw.tween_property(icon, "modulate", Color(2.0, 1.8, 0.5, 1.0), 0.08)   # 爆闪（HDR超亮）
	tw.tween_property(icon, "modulate", Color(1.0, 0.85, 0.2, 1.0),  0.08)  # 金色留底
	tw.tween_property(icon, "modulate", original,                     0.12)  # 恢复
	# 总时长 0.28s，与需求 0.25s 接近

func _show_relic_popup(desc: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = "✦ " + desc
	lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.0))
	lbl.add_theme_font_size_override("font_size", 13)
	# 挂到 CanvasLayer 避免被场景缩放影响
	var ui_layer: Node = get_node_or_null("UI")
	if ui_layer: ui_layer.add_child(lbl)
	else:        add_child(lbl)
	lbl.position = Vector2(12.0, 80.0 + randf_range(0.0, 20.0))
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 44.0, 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)

func _on_du_hua_available(desc: String) -> void:
	du_hua_btn.visible     = true
	du_hua_hint_label.text = "💡 " + desc
	if _purif_panel and _purif_panel.has_method("on_du_hua_available"):
		_purif_panel.on_du_hua_available(desc)

func _on_end_turn_pressed() -> void:
	end_turn_btn.disabled = true
	SoundManager.play_sfx("turn_end")
	state_machine.end_player_turn()

func _on_du_hua_pressed() -> void:
	state_machine.confirm_du_hua()

func _on_result_continue() -> void:
	result_panel.visible = false
	var result: String = _last_battle_result
	if result == "victory" or result == "du_hua":
		# 胜利/渡化 → 选牌奖励
		TransitionManager.change_scene("res://scenes/CardRewardScene.tscn")
	else:
		# 失败 → 结局场景（魂魄消散）
		GameState.trigger_ending("defeat")

var _last_battle_result: String = ""

func _on_hand_updated(hand: Array) -> void:
	for child in hand_container.get_children():
		child.queue_free()
	for card_data in hand:
		var card_ui: Node = _card_scene.instantiate()
		if not card_ui: continue
		if card_ui.has_method("setup"):
			card_ui.setup(card_data)
		var can_afford: bool = DeckManager.current_cost >= max(0, card_data.get("cost", 0) - EmotionManager.get_cost_reduction())
		if card_ui.has_method("set_playable"):
			card_ui.set_playable(can_afford and EmotionManager.can_play_card(card_data))
		card_ui.card_clicked.connect(_on_card_clicked)
		hand_container.add_child(card_ui)
	# 根据手牌数量动态调整间距，最多7张不溢出
	var card_count: int = hand_container.get_child_count()
	var sep: int = 12
	if card_count > 5:
		sep = max(4, 12 - (card_count - 5) * 3)
	hand_container.add_theme_constant_override("separation", sep)
	# 手牌滑入动画：每张牌从下方 +30px 位移滑入
	var delay = 0.0
	for card_ui in hand_container.get_children():
		card_ui.modulate.a = 0.0
		var orig_y: float = card_ui.position.y
		card_ui.position.y = orig_y + 30
		var tw: Tween = card_ui.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(card_ui, "position:y", orig_y, 0.18)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(card_ui, "modulate:a", 1.0, 0.18)
		delay += 0.04

func _on_card_clicked(card_data: Dictionary) -> void:
	if state_machine.current_state != 2: # STATE_PLAYER_TURN
		return
	SoundManager.play_sfx("card_play")
	# 出牌时切换施法立绘
	_set_player_sprite_state("attack")
	get_tree().create_timer(0.5).timeout.connect(
		func(): _set_player_sprite_state("idle"), CONNECT_ONE_SHOT)
	# 根据牌型播放不同的命中动画，然后触发效果
	var effect_type: String = card_data.get("effect_type", "")
	var is_attack: bool = effect_type in ["attack","attack_all","attack_lifesteal","attack_dot",
		"attack_scaling_rage","attack_all_triple","attack_and_weaken_all",
		"shield_attack","remove_enemy_shield","dodge_attack"]
	if is_attack:
		_play_attack_flash()
		await get_tree().create_timer(0.12).timeout
	state_machine.play_card(card_data)

func _on_emotion_changed(emotion: String, old_val: int, new_val: int) -> void:
	_update_hud()
	_refresh_hand()
	# 情绪变化浮字（在祭坛中央雷达图位置）
	var diff: int = new_val - old_val
	if diff != 0:
		var radar_area: Node = get_node_or_null("UI/AltarLayout/AltarCenter")
		if radar_area:
			var rect: Rect2 = radar_area.get_global_rect()
			var pos  = Vector2(rect.position.x + rect.size.x * 0.5,
							   rect.position.y + rect.size.y * 0.5)
			var ename: String = EmotionManager.get_emotion_name(emotion)
			var arrow = "↑" if diff > 0 else "↓"
			spawn_damage_number(abs(diff), "emotion", pos,
				"%s%s%d" % [ename, arrow, int(abs(diff))])

func _on_disorder_triggered(emotion: String) -> void:
	disorder_warning.text = "⚠ %s 失调！" % EmotionManager.get_emotion_name(emotion)
	SoundManager.play_sfx("disorder_trigger")
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)

func _on_disorder_cleared(_e: String) -> void:
	disorder_warning.text = ""

func _on_player_hp_changed(old_hp: int, new_hp: int) -> void:
	# 旧 ProgressBar（已隐藏，仅保留数据）
	player_hp_bar.max_value = GameState.max_hp
	player_hp_bar.value     = new_hp
	player_hp_label.text    = "%s %d / %d" % [UIConstants.ICONS["hp"], int(new_hp), int(GameState.max_hp)]
	# 新双层血条（主显示）
	if _player_hbar and _player_hbar.has_method("set_hp"):
		_player_hbar.set_hp(new_hp, GameState.max_hp)
	# 浮字：受伤/回血
	var diff := new_hp - old_hp
	if diff < 0:
		_spawn_player_number(-diff, "damage")
		_set_player_sprite_state("hurt")
		get_tree().create_timer(0.4).timeout.connect(
			func(): _set_player_sprite_state("idle"), CONNECT_ONE_SHOT)
		# 成就：Boss战伤害追踪
		var is_boss: bool = state_machine.enemy_data.get("type","") == "boss"
		if is_boss:
			AchievementManager.on_player_damaged(-diff)
	elif diff > 0:
		_spawn_player_number(diff, "heal")
	if new_hp <= 0:
		_set_player_sprite_state("dead")

func _update_hud() -> void:
	cost_label.text          = "费用: %d" % int(DeckManager.current_cost)
	deck_count_label.text    = "▤ 牌库: %d" % int(len(DeckManager.deck))
	discard_count_label.text = "↓ 弃牌: %d" % int(len(DeckManager.discard_pile))
	# 旧血条数据同步（已隐藏，仅备份）
	player_hp_bar.max_value = GameState.max_hp
	player_hp_bar.value     = GameState.hp
	player_hp_label.text    = "%s %d / %d" % [UIConstants.ICONS["hp"], int(GameState.hp), int(GameState.max_hp)]
	# 新血条同步
	if _player_hbar and _player_hbar.has_method("set_hp"):
		_player_hbar.set_hp(GameState.hp, GameState.max_hp)
	if _player_hbar and _player_hbar.has_method("set_shield"):
		_player_hbar.set_shield(state_machine.player_shield)

func _setup_hud_theme() -> void:
	turn_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("heading"))
	turn_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	deck_count_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
	discard_count_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
	deck_count_label.add_theme_color_override("font_color", UIConstants.color_of("text_secondary"))
	discard_count_label.add_theme_color_override("font_color", UIConstants.color_of("text_muted"))
	end_turn_btn.text = "结束回合 [E]"
	end_turn_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	end_turn_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	end_turn_btn.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	end_turn_btn.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))
	du_hua_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold"))
	var du_hover := UIConstants.make_button_style("parch", "gold")
	du_hover.bg_color = du_hover.bg_color.lightened(0.06)
	du_hua_btn.add_theme_stylebox_override("hover", du_hover)
	du_hua_btn.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))

func _result_panel_bbcode(title: String, body: String) -> String:
	var tc := UIConstants.color_of("gold").to_html(false)
	var bc := UIConstants.color_of("ash").to_html(false)
	return "[center][color=#%s]%s[/color]\n\n[color=#%s]%s[/color][/center]" % [tc, title, bc, body]

func _setup_result_panel_theme() -> void:
	result_panel.add_theme_stylebox_override("panel", UIConstants.make_panel_style())
	result_label.add_theme_font_size_override("normal_font_size", UIConstants.font_size_of("body"))
	result_label.add_theme_color_override("default_color", UIConstants.color_of("text_primary"))
	result_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	result_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	result_btn.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	result_btn.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))

func _refresh_hand() -> void:
	for card_ui in hand_container.get_children():
		if card_ui.has_method("set_playable") and card_ui.has_method("get") :
			var cd: Variant = card_ui.get("card_data")
			if cd:
				var can_afford: bool = DeckManager.current_cost >= max(0, cd.get("cost", 0) - EmotionManager.get_cost_reduction())
				card_ui.set_playable(can_afford and EmotionManager.can_play_card(cd))

func _show_popup(result: Dictionary) -> void:
	var value: int = int(result.get("value", 0))
	if value <= 0: return
	var is_dmg: bool = result.get("type", "") in [
		"attack","attack_all","attack_lifesteal","attack_dot",
		"attack_scaling_rage","attack_all_triple","attack_and_weaken_all",
		"shield_attack","remove_enemy_shield"]
	var lbl: Label = Label.new()
	lbl.text = ("-%d" if is_dmg else "+%d") % value
	lbl.add_theme_color_override("font_color",
		UIConstants.color_of("damage_flash") if is_dmg else UIConstants.color_of("heal_flash"))
	lbl.add_theme_font_size_override("font_size", 22)
	add_child(lbl)
	lbl.position = Vector2(900 + randf_range(-30, 30), 280)
	var tween: Tween = create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 70, 0.7)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tween.tween_callback(lbl.queue_free)

## 问路香按钮（动态添加到 HUD）
func _add_wenlu_btn() -> void:
	var hud: Node = get_node_or_null("UI/HUD")
	if not hud: return
	var btn: Button = Button.new()
	btn.name = "WenluBtn"
	btn.text = "🕯问路香"
	btn.custom_minimum_size = Vector2(100, 30)
	btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	var dis := UIConstants.make_button_style("parch", "ash")
	dis.bg_color = Color(dis.bg_color.r, dis.bg_color.g, dis.bg_color.b, 0.5)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	btn.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
	btn.pressed.connect(_on_wenlu_pressed)
	hud.add_child(btn)

func _on_wenlu_pressed() -> void:
	if not RelicManager.use_wenlu_xiang(): return
	# 展示敌人下两回合意图（从 state_machine 读取）
	var acts: Array = state_machine.enemy_data.get("actions", [])
	if acts.is_empty(): return
	var preview: Array[String] = []
	for a in acts.slice(0, min(2, len(acts))):
		preview.append("%s %s" % [a.get("type", "?"), str(a.get("value", ""))])
	var line := "感知：" + " / ".join(preview)
	if _intent_display and _intent_display.has_method("show_intent_custom"):
		var rage := int(state_machine.boss_phase) == 2
		_intent_display.show_intent_custom("🕯", line, rage)
	# 禁用按钮
	var btn: Node = get_node_or_null("UI/HUD/WenluBtn")
	if btn: btn.disabled = true

## ══════════════════════════════════════════════════════
## Buff 图标栏系统
## ══════════════════════════════════════════════════════

# 全局 Tooltip（Panel 包 Label，鼠标悬停显示）
var _tooltip_panel: Panel = null
var _tooltip_label: Label = null

func _setup_buff_ui() -> void:
	# 连接 BuffManager 信号
	BuffManager.buff_changed.connect(_on_buff_changed)
	BuffManager.buff_expired.connect(func(tgt, _id): _rebuild_buff_bar(tgt))

	# 玩家 Buff 栏：插入 PlayerArea 底部
	var player_area: Node = get_node_or_null("UI/AltarLayout/PlayerArea")
	if player_area:
		var bar: HBoxContainer = HBoxContainer.new()
		bar.name = "PlayerBuffBar"
		player_area.add_child(bar)

	# 敌人 Buff 栏：插入 EnemyArea 顶部（名字下方）
	var enemy_area: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
	if enemy_area:
		var enemy_bar: HBoxContainer = HBoxContainer.new()
		enemy_bar.name = "EnemyBuffBar"
		enemy_area.add_child(enemy_bar)
		enemy_area.move_child(enemy_bar, 1)

	# 全局 Tooltip（Panel 包 Label，挂到 UI 最顶层）
	var ui: Node = get_node_or_null("UI")
	if ui:
		_tooltip_label = Label.new()
		_tooltip_label.name            = "BuffTooltip"
		_tooltip_label.z_index         = 100
		_tooltip_label.autowrap_mode   = TextServer.AUTOWRAP_WORD_SMART
		_tooltip_label.custom_minimum_size = Vector2(180, 0)
		_tooltip_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
		_tooltip_label.add_theme_font_size_override("font_size", 12)
		# 背景 Panel
		_tooltip_panel = Panel.new()
		_tooltip_panel.name = "TooltipPanel"
		_tooltip_panel.add_child(_tooltip_label)
		_tooltip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui.add_child(_tooltip_panel)
		_tooltip_panel.visible = false

	## B-02 新增双层血条组件（复用上方已声明的 player_area / enemy_area）
	var PlayerHealthBarClass: GDScript = preload("res://scripts/ui/PlayerHealthBar.gd")
	var EnemyHealthBarClass  = preload("res://scripts/ui/EnemyHealthBar.gd")
	var pa2: Node = get_node_or_null("UI/AltarLayout/PlayerArea")
	var ea2: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
	if pa2:
		# 隐藏旧版原始 ProgressBar + Label，避免与新双层血条重叠
		var old_hpbar: Node = pa2.get_node_or_null("HPBar")
		if old_hpbar: old_hpbar.visible = false
		var old_hplabel: Node = pa2.get_node_or_null("HPLabel")
		if old_hplabel: old_hplabel.visible = false
		_player_hbar = PlayerHealthBarClass.new()
		pa2.add_child(_player_hbar)
		_player_hbar.set_hp(GameState.hp, GameState.max_hp)
	if ea2:
		var old_ehpbar: Node = ea2.get_node_or_null("HPBar")
		if old_ehpbar: old_ehpbar.visible = false
		_enemy_hbar = EnemyHealthBarClass.new()
		ea2.add_child(_enemy_hbar)

func _on_buff_changed(target: String, _buff_id: String, _stacks: int) -> void:
	_rebuild_buff_bar(target)

## 重建某一目标的 Buff 图标栏（清空后重建，stacks=0 不显示）
func _rebuild_buff_bar(target: String) -> void:
	var bar_path: String = "UI/AltarLayout/PlayerArea/PlayerBuffBar" \
		if target == BuffManager.TARGET_PLAYER \
		else "UI/AltarLayout/EnemyArea/EnemyBuffBar"
	var bar: Node = get_node_or_null(bar_path)
	if not bar: return

	# 清空旧图标
	for child in bar.get_children():
		child.queue_free()

	# 重建
	var buffs: Array = BuffManager.get_buffs(target)
	for buff in buffs:
		if buff["stacks"] <= 0: continue
		var slot: Control = _make_buff_icon(buff)
		bar.add_child(slot)

## 构建单个 Buff 图标：半透明色块 + 层数文字 + Tooltip
func _make_buff_icon(buff: Dictionary) -> Control:
	# 外层 Control 作为槽位
	var slot: Control = Control.new()
	slot.custom_minimum_size = Vector2(32, 32)

	# 背景色 Panel
	var bg: Panel = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = buff.get("icon_color", Color(0.5, 0.5, 0.5, 0.8))
	sb.set_corner_radius_all(3)
	bg.add_theme_stylebox_override("panel", sb)
	slot.add_child(bg)

	# 层数 Label（右下角）
	var stacks_lbl: Label = Label.new()
	stacks_lbl.text                = str(buff["stacks"])
	stacks_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stacks_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	stacks_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stacks_lbl.add_theme_font_size_override("font_size", 10)
	stacks_lbl.add_theme_color_override("font_color", Color.WHITE)
	slot.add_child(stacks_lbl)

	# Buff 名首字（中央）
	var name_lbl: Label = Label.new()
	name_lbl.text                 = buff.get("display_name","?").substr(0,1)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1,1,1,0.9))
	slot.add_child(name_lbl)

	# Tooltip：鼠标 Enter/Exit
	slot.mouse_entered.connect(func(): _show_tooltip(buff, slot))
	slot.mouse_exited.connect(func():  _hide_tooltip())

	return slot

func _show_tooltip(buff: Dictionary, anchor: Control) -> void:
	if not _tooltip_panel or not _tooltip_label: return
	var title: String  = buff.get("display_name", "???")
	var tip: String    = buff.get("tooltip", "")
	var stacks: int = buff.get("stacks", 0)
	_tooltip_label.text    = "%s ×%d\n%s" % [title, int(stacks), tip]
	_tooltip_panel.visible = true
	var pos: Vector2 = anchor.get_global_rect().position
	_tooltip_panel.position = Vector2(clamp(pos.x - 60, 4, 1080), max(pos.y - 72, 4))

func _hide_tooltip() -> void:
	if _tooltip_panel: _tooltip_panel.visible = false

## ══════════════════════════════════════════════════════
## 浮字数字系统
## ══════════════════════════════════════════════════════

## 在世界坐标 pos 生成浮字
func spawn_damage_number(value: int, type: String, pos: Vector2, extra: String = "") -> void:
	if not _dmgnum_scene: return
	var node: Node = _dmgnum_scene.instantiate()
	# 挂到 CanvasLayer，不受场景缩放影响
	var ui: Node = get_node_or_null("UI")
	if ui: ui.add_child(node)
	else:  add_child(node)
	node.spawn(value, type, pos, extra)

## 敌人受伤浮字（在 _on_card_effect 里调用）
func _spawn_enemy_damage(value: int, type: String) -> void:
	var enemy_area: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
	if not enemy_area: return
	var rect: Rect2 = enemy_area.get_global_rect()
	var pos  = Vector2(rect.position.x + rect.size.x * 0.5,
					   rect.position.y + rect.size.y * 0.35)
	spawn_damage_number(value, type, pos)

## 玩家受伤/回血浮字
func _spawn_player_number(value: int, type: String) -> void:
	var player_area: Node = get_node_or_null("UI/AltarLayout/PlayerArea")
	if not player_area: return
	var rect: Rect2 = player_area.get_global_rect()
	var pos  = Vector2(rect.position.x + rect.size.x * 0.5,
					   rect.position.y + rect.size.y * 0.4)
	spawn_damage_number(value, type, pos)

## 敌人像素立绘
## ══════════════════════════════════════════════════════
func _setup_enemy_sprite(enemy_data: Dictionary) -> void:
	var enemy_id: String = enemy_data.get("id", "")
	var sprite_node: Node = get_node_or_null("UI/AltarLayout/EnemyArea/EnemySprite")
	if not sprite_node: return

	# 把 ColorRect 换成 TextureRect（如果还没换过）
	if sprite_node is ColorRect:
		var parent: Node = sprite_node.get_parent()
		var idx    = sprite_node.get_index()
		sprite_node.queue_free()

		var tr: TextureRect = TextureRect.new()
		tr.name              = "EnemySprite"
		tr.texture_filter    = CanvasItem.TEXTURE_FILTER_NEAREST   # 保持像素感
		# Godot 4.4+ expand_mode 枚举改名，用 stretch_mode 替代更稳定
		tr.stretch_mode      = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(80, 112)
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		parent.add_child(tr)
		parent.move_child(tr, idx)
		sprite_node = tr

	# 生成像素纹理
	var tex: ImageTexture = EnemyPixelArtClass.create_texture(enemy_id)
	if sprite_node is TextureRect:
		sprite_node.texture = tex

	# Boss 发光脉冲 + 慢速浮动
	var is_boss: bool = enemy_data.get("type","") == "boss"
	if is_boss and sprite_node:
		var tw: Tween = sprite_node.create_tween().set_loops()
		tw.tween_property(sprite_node, "modulate",
			Color(1.2, 1.0, 0.8, 1.0), 1.2).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sprite_node, "modulate",
			Color.WHITE, 1.2).set_ease(Tween.EASE_IN_OUT)
	# 所有敌人都有 idle 浮动（Boss 幅度更大更慢）
	if sprite_node:
		var amp    = 6.0 if is_boss else 3.5
		var period = 2.6 if is_boss else 2.0
		_start_idle_float(sprite_node, amp, period)

## ══════════════════════════════════════════════════════
## Boss UI 初始化
## ══════════════════════════════════════════════════════
func _setup_boss_ui(enemy_data: Dictionary) -> void:
	_boss_ui = BossUI.new()
	_boss_ui.name = "BossUI"
	add_child(_boss_ui)
	_boss_ui.boss_phase_changed.connect(_on_boss_phase_changed)
	_boss_ui.activate(self, enemy_data)

func _on_boss_phase_changed(new_phase: int) -> void:
	# 同步到状态机：愤怒阶段行动权重倍增
	state_machine.boss_phase = new_phase
	# 阶段2：愤怒警告文字
	if new_phase == 2 and disorder_warning:
		disorder_warning.text = "⚡ Boss 进入愤怒阶段！"
		var tw: Tween = create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(func():
			if disorder_warning.text == "⚡ Boss 进入愤怒阶段！":
				disorder_warning.text = ""
		)

## ══════════════════════════════════════════════════════
## 主角像素立绘
## ══════════════════════════════════════════════════════

func _setup_player_sprite() -> void:
	var sprite: Node = get_node_or_null("UI/AltarLayout/PlayerArea/PlayerSprite")
	if not sprite: return
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_set_player_sprite_state("idle")
	# idle 浮动动画：上下 4px，1.8s 循环
	_start_idle_float(sprite, 4.0, 1.8)

func _set_player_sprite_state(state: String) -> void:
	var sprite: Node = get_node_or_null("UI/AltarLayout/PlayerArea/PlayerSprite")
	if not sprite: return
	var char_id: String = str(GameState.get_meta("selected_character", "ruan_ruyue"))
	sprite.texture = PlayerPixelArtClass.create_texture(state, char_id)
	# 非 idle 状态时停止浮动，idle 时重新启动
	if state == "idle":
		_start_idle_float(sprite, 4.0, 1.8)
	else:
		sprite.set_meta("_float_active", false)

## 立绘 idle 浮动动画（主角 & 敌人通用）
func _start_idle_float(node: Control, amp: float = 4.0, period: float = 2.0) -> void:
	if not node: return
	node.set_meta("_float_active", true)
	var base_y: float = node.position.y
	var tw: Tween = node.create_tween().set_loops()
	tw.tween_property(node, "position:y", base_y - amp, period * 0.5)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "position:y", base_y + amp * 0.3, period * 0.5)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

## ══════════════════════════════════════════════════════
## B-01 布局优化
## ══════════════════════════════════════════════════════

func _setup_layout_improvements() -> void:
	# 地面线（BattleGround）：深墨绿细条，衬托立绘站位
	var ground = ColorRect.new()
	ground.name = "BattleGround"
	ground.color = UIC.COLORS["ding"].darkened(0.7)
	ground.color.a = 0.6
	# 全宽固定高度：anchor 左右拉满，高度固定 4px
	ground.set_anchor_and_offset(SIDE_LEFT,  0.0, 0)
	ground.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0)
	ground.set_anchor_and_offset(SIDE_TOP,   0.0, 484)
	ground.set_anchor_and_offset(SIDE_BOTTOM,0.0, 488)
	ground.z_index = 2
	var ui: Node = get_node_or_null("UI")
	if ui: ui.add_child(ground)

	# HandContainer：居中对齐 + 卡牌间距
	if hand_container:
		hand_container.add_theme_constant_override("separation", 12)
		hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
		# 手牌区上方水墨分割线（与 HandContainer 左右边距对齐）
		if ui and not ui.get_node_or_null("HandAreaDivider"):
			var strip := WaterInkDivider.new()
			strip.name = "HandAreaDivider"
			strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			strip.z_index = 1
			var top := int(hand_container.offset_top) - 10
			strip.set_anchor_and_offset(SIDE_LEFT, 0.0, 8)
			strip.set_anchor_and_offset(SIDE_RIGHT, 1.0, -8)
			strip.set_anchor_and_offset(SIDE_TOP, 0.0, top)
			strip.set_anchor_and_offset(SIDE_BOTTOM, 0.0, top + 8)
			strip.ink_color = UIConstants.color_of("gold_dim")
			ui.add_child(strip)

	# 卡牌悬停预览层（复用上方已声明的 ui）
	_card_preview = CardPreviewClass.new()
	if ui: ui.add_child(_card_preview)

## 祭坛三栏标题：DS-00 配色 + 标题下水墨分割线
func _setup_altar_title_style() -> void:
	var pa: Node = get_node_or_null("UI/AltarLayout/PlayerArea")
	if pa:
		var pt: Node = pa.get_node_or_null("PlayerTitle")
		if pt:
			pt.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
			pt.add_theme_color_override("font_color", UIConstants.color_of("gold_dim"))
			_insert_ink_divider_below(pa, pt, 168)
	var ac: Node = get_node_or_null("UI/AltarLayout/AltarCenter")
	if ac:
		var at: Node = ac.get_node_or_null("AltarTitle")
		if at:
			at.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
			at.add_theme_color_override("font_color", UIConstants.color_of("gold"))
			_insert_ink_divider_below(ac, at, 200)
	var ea: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
	if ea:
		var en: Node = ea.get_node_or_null("EnemyName")
		if en:
			en.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
			en.add_theme_color_override("font_color", UIConstants.color_of("gold_dim"))
			_insert_ink_divider_below(ea, en, 168)
	var dw: Node = get_node_or_null("UI/AltarLayout/AltarCenter/DisorderWarning")
	if dw:
		dw.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
		# 节点自带红色 modulate，正文用浅色保证可读
		dw.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	for path in [
		"UI/AltarLayout/PlayerArea/ShieldLabel",
		"UI/AltarLayout/PlayerArea/HPLabel",
		"UI/AltarLayout/EnemyArea/ShieldLabel",
	]:
		var sl: Node = get_node_or_null(path)
		if sl:
			sl.add_theme_color_override("font_color", UIConstants.color_of("text_secondary"))
			sl.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
	var dh: Node = get_node_or_null("UI/AltarLayout/EnemyArea/DuHuaHint")
	if dh:
		dh.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
		dh.add_theme_color_override("font_color", UIConstants.color_of("gold"))

func _insert_ink_divider_below(parent: Node, after_node: Node, width_px: int) -> void:
	var div := WaterInkDivider.new()
	div.custom_minimum_size = Vector2(width_px, 6)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	div.ink_color = UIConstants.color_of("gold_dim")
	parent.add_child(div)
	parent.move_child(div, after_node.get_index() + 1)

## ══════════════════════════════════════════════════════
## B-04 敌人意图预告
## ══════════════════════════════════════════════════════

func _setup_intent_display() -> void:
	var enemy_area: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
	if not enemy_area: return
	_intent_display = IntentDisplayClass.new()
	_intent_display.name = "BattleIntentDisplay"
	enemy_area.add_child(_intent_display)
	if enemy_intent_label:
		enemy_intent_label.visible = false
	# 初始显示"蓄势待发"
	_intent_display.show_intent({})

func _on_intent_updated(intent: Dictionary) -> void:
	if _intent_display:
		_intent_display.show_intent(intent)

## ══════════════════════════════════════════════════════
## B-07 战场氛围背景 + 费用圆点HUD
## ══════════════════════════════════════════════════════

func _setup_battle_background() -> void:
	_bg_node = BattleBackgroundClass.new()
	_bg_node.name = "BattleBackground"
	add_child(_bg_node)
	move_child(_bg_node, 0)   # 移到最底层

func _setup_energy_display() -> void:
	var hud: Node = get_node_or_null("UI/HUD")
	if not hud: return
	_energy_display = EnergyDisplayClass.new()
	_energy_display.name = "EnergyDots"
	hud.add_child(_energy_display)
	# 隐藏原来的纯文字费用标签（保留节点，只隐藏）
	if cost_label: cost_label.visible = false

## ══════════════════════════════════════════════════════
## B-05 卡牌悬停预览公开接口
## ══════════════════════════════════════════════════════

func show_card_preview(card: Dictionary, pos: Vector2) -> void:
	if _card_preview: _card_preview.show_preview(card, pos)

func hide_card_preview() -> void:
	if _card_preview: _card_preview.hide_preview()

## ══════════════════════════════════════════════════════
## B-06 渡化条件面板
## ══════════════════════════════════════════════════════

func _setup_purification_panel() -> void:
	# 挂在五情祭坛中央区域下方
	var altar_center: Node = get_node_or_null("UI/AltarLayout/AltarCenter")
	if not altar_center: return
	_purif_panel = PurificationPanelClass.new()
	_purif_panel.name = "PurificationPanel"
	altar_center.add_child(_purif_panel)
	# 渡化按钮点击 → 触发状态机
	_purif_panel.purify_requested.connect(func():
		if state_machine.du_hua_triggered:
			state_machine.confirm_du_hua()
	)

func _play_attack_flash() -> void:
	## 攻击牌命中闪光：在敌人区域叠加白色闪光
	var enemy_area: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
	if not enemy_area: return
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 20
	enemy_area.add_child(flash)
	var tw: Tween = flash.create_tween()
	tw.tween_property(flash, "color:a", 0.55, 0.06)
	tw.tween_property(flash, "color:a", 0.0,  0.18)
	tw.tween_callback(flash.queue_free)
