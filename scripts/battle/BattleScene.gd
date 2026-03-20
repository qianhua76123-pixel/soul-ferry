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

var _card_scene:   PackedScene = preload("res://scenes/CardUI.tscn")
var _dmgnum_scene: PackedScene = preload("res://scenes/DamageNumber.tscn")

## 显式 preload 保证 Godot 4.6 编译期能找到静态类定义
const EnemyPixelArtClass = preload("res://scripts/ui/EnemyPixelArt.gd")

## Boss UI 控制器（仅 Boss 战时激活）
var _boss_ui: BossUI = null

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

	# 迷你遗物栏（战斗场内展示，用于触发闪光）
	_build_relic_bar()

	# Buff 图标栏 + Tooltip 系统
	_setup_buff_ui()

	var enemy_id = GameState.get_meta("pending_enemy_id", "yuan_gui")
	state_machine.start_battle(str(enemy_id))

func _on_battle_started(enemy_data: Dictionary) -> void:
	enemy_name_label.text   = "── %s ──" % enemy_data.get("name", "???")
	# 遗物：战斗开始触发
	RelicManager.on_battle_start(enemy_data)
	enemy_hp_bar.max_value  = enemy_data.get("hp", 100)
	enemy_hp_bar.value      = enemy_data.get("hp", 100)
	# 像素立绘：替换 ColorRect
	_setup_enemy_sprite(enemy_data)
	enemy_shield_label.text = "🛡 0"
	enemy_intent_label.text = "意图：..."
	du_hua_hint_label.text  = ""
	_update_hud()
	# 音效：按楼层/Boss 选择战斗 BGM
	var is_boss = enemy_data.get("type", "") == "boss"
	SoundManager.play_battle_bgm(GameState.current_layer, is_boss)
	# Boss UI：仅 Boss 战时激活
	if is_boss:
		_setup_boss_ui(enemy_data)

func _on_player_turn_started(turn: int) -> void:
	turn_label.text       = "第 %d 回合" % turn
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

func _on_card_effect(_card: Dictionary, result: Dictionary) -> void:
	enemy_hp_bar.value       = state_machine.enemy_hp
	enemy_shield_label.text  = "🛡 %d" % state_machine.enemy_shield
	player_shield_label.text = "🛡 %d" % state_machine.player_shield
	_update_hud()
	# 浮字：根据效果类型选择颜色和位置
	var rtype = result.get("type","")
	var rval  = result.get("value", 0)
	if rval > 0:
		match rtype:
			"attack","attack_all":
				_spawn_enemy_damage(rval, "damage")
				SoundManager.play_sfx("attack_hit")
			"heal","heal_all_buffs":
				_spawn_player_number(rval, "heal")
				SoundManager.play_sfx("heal")
			"shield":
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
	match result:
		"victory":
			result_label.text = "镇压成功\n\n亡魂已被强行驱散。"
			result_btn.text   = "继续前行"
			SoundManager.play_sfx("battle_victory")
		"du_hua":
			result_label.text = "渡化完成\n\n你帮他说清楚了那件事。\n他终于可以走了。"
			result_btn.text   = "目送他离去"
			SoundManager.play_sfx("du_hua_success")
		"defeat":
			result_label.text = "你也困在这里了\n\n渡魂人，渡人先渡己。"
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
	var player_area = get_node_or_null("UI/AltarLayout/PlayerArea")
	if not player_area: return
	var bar = HBoxContainer.new()
	bar.name = "BattleRelicBar"
	for rid in GameState.relics:
		var lbl = Label.new()
		lbl.name   = "rbtn_" + rid
		lbl.text   = RELIC_ICONS.get(rid, "◈")
		lbl.add_theme_font_size_override("font_size", 20)
		var data   = RelicManager._all_relics_data.get(rid, {})
		lbl.tooltip_text = data.get("name","???") + "\n" + data.get("effect","")
		bar.add_child(lbl)
	player_area.add_child(bar)

## 遗物触发：闪光动画 + 浮字提示
## 同一帧多个触发各自独立（每次创建新 Tween，互不干扰）
func _on_relic_triggered(relic_id: String, effect_desc: String) -> void:
	# ── 特殊处理：烧骨片护盾直接加数值 ──
	if relic_id == "shaogu_pian_shield_2":
		state_machine.player_shield += 2
		player_shield_label.text = "🛡 %d" % state_machine.player_shield

	# ── 图标闪光：找到对应 Label，做 modulate 动画 ──
	_flash_relic_icon(relic_id)

	# ── 浮字提示（左上角上浮淡出）──
	_show_relic_popup(effect_desc)

## 纯 Tween 实现图标闪光，0.25s，不使用 AnimationPlayer
## 多个遗物同帧触发时各自 create_tween()，互相独立不干扰
func _flash_relic_icon(relic_id: String) -> void:
	var bar  = get_node_or_null("UI/AltarLayout/PlayerArea/BattleRelicBar")
	if not bar: return
	var icon = bar.get_node_or_null("rbtn_" + relic_id)
	if not icon: return

	# 记录原始 modulate（如果上一帧动画还没结束，先恢复）
	var original = Color.WHITE

	# 独立 Tween：白色闪光 → 金色高亮 → 恢复白色
	# 每次 create_tween() 都是全新实例，互不影响
	var tw = icon.create_tween()
	tw.tween_property(icon, "modulate", Color(2.0, 1.8, 0.5, 1.0), 0.08)   # 爆闪（HDR超亮）
	tw.tween_property(icon, "modulate", Color(1.0, 0.85, 0.2, 1.0),  0.08)  # 金色留底
	tw.tween_property(icon, "modulate", original,                     0.12)  # 恢复
	# 总时长 0.28s，与需求 0.25s 接近

func _show_relic_popup(desc: String) -> void:
	var lbl = Label.new()
	lbl.text = "✦ " + desc
	lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.0))
	lbl.add_theme_font_size_override("font_size", 13)
	# 挂到 CanvasLayer 避免被场景缩放影响
	var ui_layer = get_node_or_null("UI")
	if ui_layer: ui_layer.add_child(lbl)
	else:        add_child(lbl)
	lbl.position = Vector2(12.0, 80.0 + randf_range(0.0, 20.0))
	var tw = lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 44.0, 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)

func _on_du_hua_available(desc: String) -> void:
	du_hua_btn.visible     = true
	du_hua_hint_label.text = "💡 " + desc

func _on_end_turn_pressed() -> void:
	end_turn_btn.disabled = true
	SoundManager.play_sfx("turn_end")
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
		# 失败 → 结局场景（魂魄消散）
		GameState.trigger_ending("defeat")

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
	SoundManager.play_sfx("card_play")
	state_machine.play_card(card_data)

func _on_emotion_changed(emotion: String, old_val: int, new_val: int) -> void:
	_update_hud()
	_refresh_hand()
	# 情绪变化浮字（在祭坛中央雷达图位置）
	var diff = new_val - old_val
	if diff != 0:
		var radar_area = get_node_or_null("UI/AltarLayout/AltarCenter")
		if radar_area:
			var rect = radar_area.get_global_rect()
			var pos  = Vector2(rect.position.x + rect.size.x * 0.5,
							   rect.position.y + rect.size.y * 0.5)
			var ename = EmotionManager.get_emotion_name(emotion)
			var arrow = "↑" if diff > 0 else "↓"
			spawn_damage_number(abs(diff), "emotion", pos,
				"%s%s%d" % [ename, arrow, abs(diff)])

func _on_disorder_triggered(emotion: String) -> void:
	disorder_warning.text = "⚠ %s 失调！" % EmotionManager.get_emotion_name(emotion)
	SoundManager.play_sfx("disorder_trigger")
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)

func _on_disorder_cleared(_e: String) -> void:
	disorder_warning.text = ""

func _on_player_hp_changed(old_hp: int, new_hp: int) -> void:
	player_hp_bar.max_value = GameState.max_hp
	player_hp_bar.value     = new_hp
	player_hp_label.text    = "%d / %d" % [new_hp, GameState.max_hp]
	# 浮字：受伤/回血
	var diff = new_hp - old_hp
	if diff < 0:
		_spawn_player_number(-diff, "damage")
	elif diff > 0:
		_spawn_player_number(diff, "heal")

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

## ══════════════════════════════════════════════════════
## Buff 图标栏系统
## ══════════════════════════════════════════════════════

# 全局 Tooltip Label（鼠标悬停显示）
var _tooltip_label: Label = null

func _setup_buff_ui() -> void:
	# 连接 BuffManager 信号
	BuffManager.buff_changed.connect(_on_buff_changed)
	BuffManager.buff_expired.connect(func(tgt, _id): _rebuild_buff_bar(tgt))

	# 玩家 Buff 栏：插入 PlayerArea 底部
	var player_area = get_node_or_null("UI/AltarLayout/PlayerArea")
	if player_area:
		var bar = HBoxContainer.new()
		bar.name = "PlayerBuffBar"
		player_area.add_child(bar)

	# 敌人 Buff 栏：插入 EnemyArea 顶部（名字下方）
	var enemy_area = get_node_or_null("UI/AltarLayout/EnemyArea")
	if enemy_area:
		var bar = HBoxContainer.new()
		bar.name = "EnemyBuffBar"
		# 插到敌人名字下面（index 1）
		enemy_area.add_child(bar)
		enemy_area.move_child(bar, 1)

	# 全局 Tooltip Label（挂到 CanvasLayer 最顶层）
	var ui = get_node_or_null("UI")
	if ui:
		_tooltip_label = Label.new()
		_tooltip_label.name             = "BuffTooltip"
		_tooltip_label.visible          = false
		_tooltip_label.z_index          = 100
		_tooltip_label.autowrap_mode    = TextServer.AUTOWRAP_WORD_SMART
		_tooltip_label.custom_minimum_size = Vector2(180, 0)
		_tooltip_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
		_tooltip_label.add_theme_font_size_override("font_size", 12)
		# 添加半透明背景 Panel
		var panel = Panel.new()
		panel.name = "TooltipPanel"
		panel.add_child(_tooltip_label)
		_tooltip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui.add_child(panel)
		panel.visible = false
		_tooltip_label = panel   # 让 _tooltip_label 指向 Panel（一起显示/隐藏）

func _on_buff_changed(target: String, _buff_id: String, _stacks: int) -> void:
	_rebuild_buff_bar(target)

## 重建某一目标的 Buff 图标栏（清空后重建，stacks=0 不显示）
func _rebuild_buff_bar(target: String) -> void:
	var bar_path = "UI/AltarLayout/PlayerArea/PlayerBuffBar" \
		if target == BuffManager.TARGET_PLAYER \
		else "UI/AltarLayout/EnemyArea/EnemyBuffBar"
	var bar = get_node_or_null(bar_path)
	if not bar: return

	# 清空旧图标
	for child in bar.get_children():
		child.queue_free()

	# 重建
	var buffs = BuffManager.get_buffs(target)
	for buff in buffs:
		if buff["stacks"] <= 0: continue
		var slot = _make_buff_icon(buff)
		bar.add_child(slot)

## 构建单个 Buff 图标：半透明色块 + 层数文字 + Tooltip
func _make_buff_icon(buff: Dictionary) -> Control:
	# 外层 Control 作为槽位
	var slot = Control.new()
	slot.custom_minimum_size = Vector2(32, 32)

	# 背景色 Panel
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb = StyleBoxFlat.new()
	sb.bg_color = buff.get("icon_color", Color(0.5, 0.5, 0.5, 0.8))
	sb.set_corner_radius_all(3)
	bg.add_theme_stylebox_override("panel", sb)
	slot.add_child(bg)

	# 层数 Label（右下角）
	var stacks_lbl = Label.new()
	stacks_lbl.text                = str(buff["stacks"])
	stacks_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stacks_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	stacks_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stacks_lbl.add_theme_font_size_override("font_size", 10)
	stacks_lbl.add_theme_color_override("font_color", Color.WHITE)
	slot.add_child(stacks_lbl)

	# Buff 名首字（中央）
	var name_lbl = Label.new()
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
	if not _tooltip_label: return
	var title = buff.get("display_name","???")
	var tip   = buff.get("tooltip","")
	var stacks= buff.get("stacks", 0)
	# 找到 Panel 内的 Label
	var lbl = _tooltip_label.get_node_or_null("BuffTooltip")
	if not lbl: return
	lbl.text = "%s ×%d\n%s" % [title, stacks, tip]
	_tooltip_label.visible  = true
	# 定位在图标上方
	var pos = anchor.get_global_rect().position
	_tooltip_label.position = Vector2(clamp(pos.x - 60, 4, 1080), max(pos.y - 72, 4))

func _hide_tooltip() -> void:
	if _tooltip_label: _tooltip_label.visible = false

## ══════════════════════════════════════════════════════
## 浮字数字系统
## ══════════════════════════════════════════════════════

## 在世界坐标 pos 生成浮字
func spawn_damage_number(value: int, type: String, pos: Vector2, extra: String = "") -> void:
	if not _dmgnum_scene: return
	var node = _dmgnum_scene.instantiate()
	# 挂到 CanvasLayer，不受场景缩放影响
	var ui = get_node_or_null("UI")
	if ui: ui.add_child(node)
	else:  add_child(node)
	node.spawn(value, type, pos, extra)

## 敌人受伤浮字（在 _on_card_effect 里调用）
func _spawn_enemy_damage(value: int, type: String) -> void:
	var enemy_area = get_node_or_null("UI/AltarLayout/EnemyArea")
	if not enemy_area: return
	var rect = enemy_area.get_global_rect()
	var pos  = Vector2(rect.position.x + rect.size.x * 0.5,
					   rect.position.y + rect.size.y * 0.35)
	spawn_damage_number(value, type, pos)

## 玩家受伤/回血浮字
func _spawn_player_number(value: int, type: String) -> void:
	var player_area = get_node_or_null("UI/AltarLayout/PlayerArea")
	if not player_area: return
	var rect = player_area.get_global_rect()
	var pos  = Vector2(rect.position.x + rect.size.x * 0.5,
					   rect.position.y + rect.size.y * 0.4)
	spawn_damage_number(value, type, pos)

## 敌人像素立绘
## ══════════════════════════════════════════════════════
func _setup_enemy_sprite(enemy_data: Dictionary) -> void:
	var enemy_id = enemy_data.get("id", "")
	var sprite_node = get_node_or_null("UI/AltarLayout/EnemyArea/EnemySprite")
	if not sprite_node: return

	# 把 ColorRect 换成 TextureRect（如果还没换过）
	if sprite_node is ColorRect:
		var parent = sprite_node.get_parent()
		var idx    = sprite_node.get_index()
		sprite_node.queue_free()

		var tr = TextureRect.new()
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
	var tex = EnemyPixelArtClass.create_texture(enemy_id)
	if sprite_node is TextureRect:
		sprite_node.texture = tex

	# Boss 发光效果
	var is_boss = enemy_data.get("type","") == "boss"
	if is_boss and sprite_node:
		var tw = sprite_node.create_tween().set_loops()
		tw.tween_property(sprite_node, "modulate",
			Color(1.2, 1.0, 0.8, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sprite_node, "modulate",
			Color.WHITE, 1.0).set_ease(Tween.EASE_IN_OUT)

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
	# 阶段2：愤怒警告文字
	if new_phase == 2 and disorder_warning:
		disorder_warning.text = "⚡ Boss 进入愤怒阶段！"
		var tw = create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(func():
			if disorder_warning.text == "⚡ Boss 进入愤怒阶段！":
				disorder_warning.text = ""
		)
