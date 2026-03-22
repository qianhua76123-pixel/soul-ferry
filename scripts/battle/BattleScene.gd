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
const EnemyPixelArtClass    = preload("res://scripts/ui/EnemyPixelArt.gd")
const PlayerPixelArtClass   = preload("res://scripts/ui/PlayerPixelArt.gd")
const DeckViewerPanelClass  = preload("res://scripts/ui/DeckViewerPanel.gd")
const BossDialogueUIClass   = preload("res://scripts/ui/BossDialogueUI.gd")

## 卡盘能量标签（右上角）
var _energy_tray_label: Label  = null
var _deck_viewer: Control       = null

## 锁链 HUD 标签（动态创建，显示在敌人区域）
var _chain_label: Label = null

## 印记显示面板（阮如月专属）
var _mark_panel: Control = null

## Boss UI 控制器（仅 Boss 战时激活）
var _boss_ui: BossUI = null

## 双人模式状态机（动态类型，避免依赖已移除的 class_name）
var _coop_sm: Node = null

const CoopBattleStateMachineClass = preload("res://scripts/battle/CoopBattleStateMachine.gd")

func _ready() -> void:
	TransitionManager.fade_in_only()
	result_panel.visible = false
	du_hua_btn.visible   = false

	# 双人模式：使用 CoopBattleStateMachine 替代普通 state_machine
	if CoopManager.is_coop_active:
		_setup_coop_battle()
		return

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
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	# 锁链 HUD：监听锁链层数变化
	state_machine.chain_applied.connect(_on_chain_applied)
	# 无为：监听持续施印
	state_machine.wu_wei_mark_applied.connect(_on_wu_wei_mark_applied)

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

	# ── 弃牌按钮 ──
	_setup_discard_button()

	# ── 碎片显示 ──
	_setup_shard_display()

	# ── 弃牌系统信号 ──
	DiscardSystem.ruyue_seal_bonus_requested.connect(_on_ruyue_seal_bonus)
	DiscardSystem.tiejun_rage_bonus_requested.connect(_on_tiejun_rage_bonus)
	DiscardSystem.tiejun_chain_bonus_requested.connect(_on_tiejun_chain_bonus)
	DiscardSystem.wumian_energy_bonus_requested.connect(_on_wumian_energy_bonus)
	DiscardSystem.wumian_free_card_bonus_requested.connect(_on_wumian_free_card_bonus)

	# ── 无名空鸣选择 ──
	WumianManager.kongming_choice_required.connect(_on_kongming_choice_required)

	# ── 第五步：启动战斗逻辑（最后执行，保证 UI 节点全部就位）──
	var enemy_id: String = str(GameState.get_meta("pending_enemy_id", "yuan_gui"))
	state_machine.start_battle(str(enemy_id))

## 情绪溢出状态栏
var _emotion_status_bar: HBoxContainer = null

func _deferred_layout_setup() -> void:
	## 延迟一帧执行，此时 Control 节点 size 已由引擎布局计算完毕
	_setup_layout_improvements()
	_setup_altar_title_style()
	_setup_emotion_status_bar()
	# 无名角色专属 UI
	var char_id: String = str(GameState.get_meta("selected_character", "ruan_ruyue"))
	if char_id == "wumian":
		_setup_wumian_ui()
	# 印记 UI（阮如月专属，其他角色调用无害）
	_setup_mark_ui()

## 情绪溢出状态图标栏（轮盘右侧/上方）
func _setup_emotion_status_bar() -> void:
	var ac: Node = get_node_or_null("UI/AltarLayout/AltarCenter")
	if not ac: return
	_emotion_status_bar = HBoxContainer.new()
	_emotion_status_bar.name = "EmotionStatusBar"
	_emotion_status_bar.add_theme_constant_override("separation", 6)
	ac.add_child(_emotion_status_bar)
	EmotionManager.emotion_changed.connect(_update_emotion_status_bar.bind())

func _update_emotion_status_bar() -> void:
	if not _emotion_status_bar: return
	for child: Node in _emotion_status_bar.get_children():
		child.queue_free()
	var emo_names: Dictionary = {"grief":"悲","fear":"惧","rage":"怒","joy":"喜","calm":"定"}
	var emo_colors: Dictionary = {
		"rage": Color(0.80,0.20,0.20), "fear": Color(0.40,0.20,0.80),
		"grief": Color(0.20,0.40,0.80),"joy":  Color(0.80,0.67,0.00),
		"calm": Color(0.20,0.80,0.55)
	}
	for emo: String in ["grief","fear","rage","joy","calm"]:
		var val: int = EmotionManager.values.get(emo, 0)
		if val < 4: continue
		var ec: Color = emo_colors.get(emo, Color.WHITE)
		var chip: Panel = Panel.new()
		chip.custom_minimum_size = Vector2(44, 22)
		var chip_style: StyleBoxFlat = StyleBoxFlat.new()
		chip_style.bg_color = Color(ec.r*0.3, ec.g*0.3, ec.b*0.3, 0.9)
		chip_style.border_width_top=1; chip_style.border_width_bottom=1
		chip_style.border_width_left=1; chip_style.border_width_right=1
		chip_style.border_color = ec
		chip_style.set_corner_radius_all(4)
		chip.add_theme_stylebox_override("panel", chip_style)
		var lbl: Label = Label.new()
		lbl.text = "%s %d" % [emo_names.get(emo,"?"), val]
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", ec.lightened(0.3))
		chip.add_child(lbl)
		_emotion_status_bar.add_child(chip)
		# 满值时图标闪烁
		if val >= 5:
			var tw: Tween = chip.create_tween().set_loops()
			tw.tween_property(chip, "modulate", Color(1.4,1.3,1.1,1.0), 0.4)
			tw.tween_property(chip, "modulate", Color.WHITE, 0.4)

## 阮如月印记 UI：在敌人区域上方创建印记层数显示面板
func _setup_mark_ui() -> void:
	## 阮如月：在敌人区域上方创建印记层数显示面板
	var enemy_area: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
	if not enemy_area: return
	# 避免重复创建
	if enemy_area.get_node_or_null("MarkPanel"): return
	var panel: Control = Control.new()
	panel.name = "MarkPanel"
	panel.custom_minimum_size = Vector2(240, 28)
	enemy_area.add_child(panel)
	_mark_panel = panel
	# 五情图标+层数（横排）
	var emotions: Array = ["joy", "calm", "grief", "fear", "rage"]
	var icons: Dictionary = {"joy": "喜", "calm": "定", "grief": "悲", "fear": "惧", "rage": "怒"}
	var colors: Dictionary = {
		"joy":   Color(0.9, 0.75, 0.2),
		"calm":  Color(0.3, 0.75, 0.55),
		"grief": Color(0.45, 0.55, 0.8),
		"fear":  Color(0.7, 0.45, 0.8),
		"rage":  Color(0.9, 0.35, 0.2),
	}
	var x_offset: int = 0
	for emo in emotions:
		var lbl: Label = Label.new()
		lbl.name = "Mark_%s" % emo
		lbl.text = "%s×0" % icons[emo]
		lbl.position = Vector2(x_offset, 0)
		lbl.custom_minimum_size = Vector2(44, 28)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", colors[emo].darkened(0.3))  # 0层暗色
		lbl.visible = false  # 0层时隐藏
		panel.add_child(lbl)
		x_offset += 46
	# 连接信号（避免重复连接）
	if not state_machine.marks_changed.is_connected(_on_marks_changed):
		state_machine.marks_changed.connect(_on_marks_changed)

func _on_marks_changed(marks: Dictionary) -> void:
	## 印记层数变化时更新 UI 显示
	if not _mark_panel: return
	var emotions: Array = ["joy", "calm", "grief", "fear", "rage"]
	var icons: Dictionary = {"joy": "喜", "calm": "定", "grief": "悲", "fear": "惧", "rage": "怒"}
	var colors: Dictionary = {
		"joy":   Color(0.9, 0.75, 0.2),
		"calm":  Color(0.3, 0.75, 0.55),
		"grief": Color(0.45, 0.55, 0.8),
		"fear":  Color(0.7, 0.45, 0.8),
		"rage":  Color(0.9, 0.35, 0.2),
	}
	var resonance_threshold: int = 3  # 默认共鸣阈值
	for emo in emotions:
		var lbl: Node = _mark_panel.get_node_or_null("Mark_%s" % emo)
		if not lbl: continue
		var count: int = marks.get(emo, 0)
		if count <= 0:
			lbl.visible = false
		else:
			lbl.visible = true
			lbl.set("text", "%s×%d" % [icons[emo], count])
			# 达到共鸣阈值时高亮，否则中等亮度
			if count >= resonance_threshold:
				lbl.add_theme_color_override("font_color", colors[emo])
			else:
				lbl.add_theme_color_override("font_color", colors[emo].darkened(0.2))

## 无名角色专属 UI
func _setup_wumian_ui() -> void:
	WumianManager.activate()
	var ac: Node = get_node_or_null("UI/AltarLayout/AltarCenter")
	if not ac: return

	# ── 分段式像素空度进度条容器 ──────────────────────
	# 总宽220px，高36px，分10格，格间1px间隔
	var emp_bg: Panel = Panel.new()
	emp_bg.name = "EmptinessBar"
	emp_bg.custom_minimum_size = Vector2(220, 36)
	var emp_style: StyleBoxFlat = StyleBoxFlat.new()
	emp_style.bg_color = Color(0.10, 0.10, 0.12, 0.9)
	emp_style.border_width_top = 1; emp_style.border_width_bottom = 1
	emp_style.border_width_left = 1; emp_style.border_width_right = 1
	emp_style.border_color = Color(0.7, 0.7, 0.7, 0.5)
	emp_style.set_corner_radius_all(4)
	emp_bg.add_theme_stylebox_override("panel", emp_style)

	# 生成10个 ColorRect 格子（Cell0~Cell9）
	# 每格宽 = (220 - 11px间隔) / 10 = 20.9 → 近似取21px，最后一格自动填满
	const CELL_COUNT: int = 10
	const TOTAL_W: float = 220.0
	const CELL_H: float = 36.0
	const GAP: float = 1.0
	var cell_w: float = (TOTAL_W - GAP * (CELL_COUNT - 1)) / float(CELL_COUNT)
	for i: int in range(CELL_COUNT):
		var cell: ColorRect = ColorRect.new()
		cell.name = "Cell%d" % i
		cell.color = Color(0.12, 0.12, 0.14, 0.8)  # 默认暗底
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.position = Vector2(i * (cell_w + GAP), 0.0)
		cell.size = Vector2(cell_w, CELL_H)
		emp_bg.add_child(cell)

	# 空度文字标签（覆盖在格子上方，居中）
	var emp_lbl: Label = Label.new()
	emp_lbl.name = "EmptinessLabel"
	emp_lbl.text = "空度 0/10"
	emp_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	emp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emp_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	emp_lbl.add_theme_font_size_override("font_size", 13)
	emp_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	emp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emp_bg.add_child(emp_lbl)

	ac.add_child(emp_bg)

	# 分段名称标签
	var tier_lbl: Label = Label.new()
	tier_lbl.name = "EmptinessTier"
	tier_lbl.text = "虚 — 效果+10%"
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	ac.add_child(tier_lbl)

	# ── 镜·无我状态标签（默认隐藏）──────────────────
	var kongming_lbl: Label = Label.new()
	kongming_lbl.name = "KongmingLabel"
	kongming_lbl.text = "✦ 镜·无我 ✦"
	kongming_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kongming_lbl.add_theme_font_size_override("font_size", 15)
	kongming_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	kongming_lbl.visible = false
	ac.add_child(kongming_lbl)

	# ── 连接信号 ──────────────────────────────────────
	WumianManager.emptiness_changed.connect(_on_emptiness_changed)
	WumianManager.kongming_triggered.connect(_on_kongming_triggered)
	WumianManager.stage_changed.connect(_on_stage_changed)

func _on_emptiness_changed(_old: int, new_val: int) -> void:
	# ── 更新10个格子颜色（分段着色）──────────────────
	var emp_bg: Node = get_node_or_null("UI/AltarLayout/AltarCenter/EmptinessBar")
	if emp_bg:
		for i: int in range(10):
			var cell: Node = emp_bg.get_node_or_null("Cell%d" % i)
			if not cell:
				continue
			if i < new_val:
				# 已填充格：按分段上色
				var fill_color: Color
				if i <= 2:
					fill_color = Color(0.35, 0.55, 0.45)   # 青绿（虚段 0-2）
				elif i <= 5:
					fill_color = Color(0.45, 0.45, 0.55)   # 灰蓝（平段 3-5）
				elif i <= 8:
					fill_color = Color(0.7, 0.55, 0.2)     # 琥珀（盈段 6-8）
				else:
					fill_color = Color(0.85, 0.25, 0.15)   # 血红（溢段 9-10）
				# ColorRect 直接赋 color 属性
				if cell is ColorRect:
					(cell as ColorRect).color = fill_color
			else:
				# 未填充格：暗底
				if cell is ColorRect:
					(cell as ColorRect).color = Color(0.12, 0.12, 0.14, 0.8)
		# 文字标签更新
		var lbl: Node = emp_bg.get_node_or_null("EmptinessLabel")
		if lbl:
			lbl.set("text", "空度 %d/10" % new_val)

	# ── 分段名称与颜色更新 ─────────────────────────────
	var tier_lbl: Node = get_node_or_null("UI/AltarLayout/AltarCenter/EmptinessTier")
	if tier_lbl:
		var tier_texts: Array[String] = ["虚 — 效果+10%", "平 — 平衡状态", "盈 — 费用-1", "溢 — 费用0·HP-5/回合"]
		var tier_colors: Array[Color] = [
			Color(0.6, 0.8, 0.6),    # 青绿
			Color(0.7, 0.7, 0.65),   # 灰白
			Color(0.8, 0.7, 0.3),    # 琥珀
			Color(0.9, 0.3, 0.2),    # 血红
		]
		var tier: int = clampi(WumianManager.current_tier, 0, 3)
		tier_lbl.set("text", tier_texts[tier])
		tier_lbl.add_theme_color_override("font_color", tier_colors[tier])

## 分段切换浮字提示（空度：虚→平 等）
func _on_stage_changed(old_stage: int, new_stage: int) -> void:
	var stage_names: Array[String] = ["虚", "平", "盈", "溢"]
	var old_name: String = stage_names[clampi(old_stage, 0, 3)]
	var new_name: String = stage_names[clampi(new_stage, 0, 3)]
	var msg: String = "空度：%s → %s" % [old_name, new_name]
	var stage_colors: Array[Color] = [
		Color(0.6, 0.8, 0.6),
		Color(0.7, 0.7, 0.9),
		Color(0.9, 0.75, 0.3),
		Color(1.0, 0.35, 0.2),
	]
	var color: Color = stage_colors[clampi(new_stage, 0, 3)]
	# 在祭坛中央偏上方浮现
	var ac: Node = get_node_or_null("UI/AltarLayout/AltarCenter")
	var screen_pos: Vector2 = get_viewport().get_visible_rect().size * Vector2(0.5, 0.38)
	if ac:
		var rect: Rect2 = ac.get_global_rect()
		screen_pos = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.3)
	_show_float_text(msg, screen_pos, color, 17)

func _on_kongming_triggered(_pre: int) -> void:
	var ui: Node = get_node_or_null("UI")
	if not ui: return
	# ── 全屏白色闪光 ──────────────────────────────────
	var flash: ColorRect = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 150
	ui.add_child(flash)
	var tw: Tween = flash.create_tween()
	tw.tween_property(flash, "color:a", 0.6, 0.08)
	tw.tween_property(flash, "color:a", 0.0, 0.45)
	tw.tween_callback(flash.queue_free)
	_show_float_text("空  鸣", get_viewport().get_visible_rect().size / 2.0, Color(0.9, 0.9, 0.85, 1.0), 28)

	# ── 镜·无我状态视觉反馈 ───────────────────────────
	if WumianManager.is_kongming_mirror_active():
		var kongming_lbl: Node = get_node_or_null("UI/AltarLayout/AltarCenter/KongmingLabel")
		if kongming_lbl:
			kongming_lbl.visible = true
			kongming_lbl.modulate.a = 0.0
			# pulse 淡入淡出循环3次后自动隐藏
			var ptw: Tween = kongming_lbl.create_tween()
			ptw.tween_property(kongming_lbl, "modulate:a", 1.0, 0.3)
			ptw.tween_property(kongming_lbl, "modulate:a", 0.3, 0.3)
			ptw.tween_property(kongming_lbl, "modulate:a", 1.0, 0.3)
			ptw.tween_property(kongming_lbl, "modulate:a", 0.3, 0.3)
			ptw.tween_property(kongming_lbl, "modulate:a", 1.0, 0.3)
			ptw.tween_property(kongming_lbl, "modulate:a", 0.3, 0.3)
			# 3次循环结束后保持半透明常显（表示镜·无我持续激活）
			ptw.tween_property(kongming_lbl, "modulate:a", 0.85, 0.4)

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
	# Boss 模式激活背景粒子
	if _bg_node and _bg_node.has_method("set_boss_mode"):
		_bg_node.set_boss_mode(is_boss)
	SoundManager.play_battle_bgm(GameState.current_layer, is_boss)
	# 成就：Boss 战开始追踪
	if is_boss:
		AchievementManager.on_boss_battle_start(GameState.hp)
	# 成就：牌库检查
	AchievementManager.check_deck_achievements()
	# Boss UI：仅 Boss 战时激活
	if is_boss:
		_setup_boss_ui(enemy_data)
		_start_boss_effect(enemy_data.get("id", ""))

func _on_player_turn_started(turn: int) -> void:
	var moon_icons: Array = ["🌑","🌒","🌓","🌔","🌕","🌖","🌗","🌘"]
	var moon: String = moon_icons[int(turn - 1) % 8]
	turn_label.text       = "%s 第 %d 回合" % [moon, int(turn)]
	end_turn_btn.disabled = false
	du_hua_btn.visible    = false
	disorder_warning.text = ""
	# 遗物：回合开始触发
	RelicManager.on_turn_start()
	_update_hud()
	# 弃牌按钮重置
	if _discard_btn:
		_discard_btn.visible  = true
		_discard_btn.disabled = false
		_discard_btn.text     = "弃牌 (%d)" % DeckManager.active_discard_limit
	_discard_mode = false
	SoundManager.play_sfx("card_draw")
	if _boss_ui:
		_boss_ui.on_turn_start(state_machine.enemy_hp, turn)

func _on_enemy_turn_started() -> void:
	end_turn_btn.disabled = true
	# 敌人出击动画
	_play_enemy_attack_animation()
	# 特殊行动UI反馈
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

## 通用浮动文字（屏幕任意坐标，指定字号）
## 用于空鸣触发、特殊事件提示等需要大字显示的场合
func _show_float_text(msg: String, screen_pos: Vector2, color: Color, font_size: int = 20) -> void:
	var lbl: Label = Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 160
	var ui: Node = get_node_or_null("UI")
	if ui: ui.add_child(lbl)
	else:  add_child(lbl)
	# 以 screen_pos 为中心（粗略居中，Label 尺寸未知时先偏移半个估算宽度）
	lbl.position = screen_pos - Vector2(font_size * len(msg) * 0.3, font_size * 0.5)
	var tw: Tween = lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 80.0, 1.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.8).set_ease(Tween.EASE_IN).set_delay(0.6)
	tw.chain().tween_callback(lbl.queue_free)

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
			# 敌人受击动画
			var enemy_sprite: Node = get_node_or_null("UI/AltarLayout/EnemyArea/EnemySprite")
			if enemy_sprite:
				_play_hit_animation(enemy_sprite, "enemy")
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
	# 胜利时先播死亡动画，再显示结果面板
	if result in ["victory", "du_hua"]:
		_play_enemy_death_animation()
		await get_tree().create_timer(0.55).timeout
	result_panel.visible = true
	# 遗物：镇压胜利触发烧骨片等
	if result == "victory":
		RelicManager.on_victory_zhenya()
		if _boss_ui: _boss_ui.on_boss_defeated()
	# 成就追踪
	var is_boss: bool = state_machine.enemy_data.get("type","") == "boss"
	var is_elite: bool = bool(GameState.get_meta("is_elite_battle", false))
	if is_boss:
		AchievementManager.on_boss_battle_end(result, GameState.hp)
	elif result == "du_hua":
		AchievementManager.record_du_hua()
	elif result == "victory":
		AchievementManager.record_zhen_ya()
	match result:
		"victory":
			result_label.text = _result_panel_bbcode(
				"⚔  镇  压  成  功",
				"亡魂已被强行驱散。\n\n回合：%d  ·  剩余HP：%d / %d" % [
					state_machine.current_turn, GameState.hp, GameState.max_hp])
			result_btn.text = "继续前行  →"
			SoundManager.play_sfx("battle_victory")
		"du_hua":
			result_label.text = _result_panel_bbcode(
				"🕯  渡  化  完  成",
				"你帮他说清楚了那件事。\n他终于可以走了。\n\n回合：%d  ·  剩余HP：%d / %d" % [
					state_machine.current_turn, GameState.hp, GameState.max_hp])
			result_btn.text = "目送他离去  →"
			SoundManager.play_sfx("du_hua_success")
		"defeat":
			result_label.text = _result_panel_bbcode(
				"☁  魂  魄  消  散",
				"渡魂人，渡人先渡己。\n\n坚持了 %d 回合" % state_machine.current_turn)
			result_btn.text = "接受命运"
			SoundManager.play_sfx("battle_defeat")

	# 结果面板入场动画
	result_panel.modulate.a = 0.0
	result_panel.scale = Vector2(0.92, 0.92)
	var rtw: Tween = result_panel.create_tween()
	rtw.tween_property(result_panel, "modulate:a", 1.0, 0.30)
	rtw.parallel().tween_property(result_panel, "scale", Vector2(1.0, 1.0), 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 精英战胜利 → 弹出遗物选择
	if is_elite and result in ["victory", "du_hua"]:
		call_deferred("_show_relic_reward_panel")

## ── 战斗场内迷你遗物栏 ──────────────────────────────
## 在 _ready() 末尾调用 _build_relic_bar()，渲染玩家持有的遗物图标
## 每个图标 Label 命名为 "rbtn_<relic_id>"，供触发动画精确定位

const RELIC_ICONS = {
	"tong_jing_sui":"🪞","wenlu_xiang":"🕯","duhun_ce":"📖",
	"shaogu_pian":"🦴","qingming_pai":"🪶","wuqing_jie":"🎀",
	"nianhua_yan":"👁","yin_yang_bi":"✒","hun_bo_lu":"🔥","si_xiang_pian":"🌾",
}

## 遗物悬浮说明面板（自定义，不依赖引擎 tooltip）
var _relic_tooltip_panel: Panel = null
var _relic_tooltip_label: RichTextLabel = null

func _ensure_relic_tooltip() -> void:
	if _relic_tooltip_panel: return
	var ui: Node = get_node_or_null("UI")
	if not ui: return
	_relic_tooltip_panel = Panel.new()
	_relic_tooltip_panel.name = "RelicTooltipPanel"
	_relic_tooltip_panel.z_index = 200
	_relic_tooltip_panel.visible = false
	_relic_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.04, 0.03, 0.96)
	ps.border_width_top    = 1; ps.border_width_bottom = 1
	ps.border_width_left   = 1; ps.border_width_right  = 1
	ps.border_color = Color(0.78, 0.60, 0.10, 0.8)
	ps.set_corner_radius_all(5)
	ps.content_margin_left   = 10; ps.content_margin_right  = 10
	ps.content_margin_top    = 8;  ps.content_margin_bottom = 8
	_relic_tooltip_panel.add_theme_stylebox_override("panel", ps)
	_relic_tooltip_label = RichTextLabel.new()
	_relic_tooltip_label.bbcode_enabled = true
	_relic_tooltip_label.fit_content = true
	_relic_tooltip_label.custom_minimum_size = Vector2(220, 0)
	_relic_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_tooltip_label.add_theme_font_size_override("normal_font_size", 12)
	_relic_tooltip_panel.add_child(_relic_tooltip_label)
	ui.add_child(_relic_tooltip_panel)

func _show_relic_tooltip(relic_id: String, btn: Button) -> void:
	_ensure_relic_tooltip()
	if not _relic_tooltip_panel: return
	var data: Dictionary = RelicManager._all_relics_data.get(relic_id, {})
	var rname: String = data.get("name","???")
	var effect: String = data.get("effect","（无说明）")
	var trigger: String = data.get("trigger","")
	var gold: String = Color(0.78,0.60,0.10).to_html(false)
	var parch: String = Color(0.92,0.86,0.74).to_html(false)
	var dim: String = Color(0.55,0.50,0.40).to_html(false)
	var txt: String = "[color=#%s]【%s】[/color]\n[color=#%s]%s[/color]" % [gold, rname, parch, effect]
	if trigger: txt += "\n[color=#%s]触发：%s[/color]" % [dim, trigger]
	_relic_tooltip_label.text = txt
	_relic_tooltip_panel.custom_minimum_size = Vector2(220, 0)
	# 定位：鼠标位置上方
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var mp: Vector2 = get_viewport().get_mouse_position()
	var panel_w: float = 240.0
	var panel_h: float = 80.0
	var px: float = clampf(mp.x - panel_w * 0.5, 4.0, vp_size.x - panel_w - 4.0)
	var py: float = clampf(mp.y - panel_h - 12.0, 4.0, vp_size.y - panel_h - 4.0)
	_relic_tooltip_panel.position = Vector2(px, py)
	_relic_tooltip_panel.visible = true

func _hide_relic_tooltip() -> void:
	if _relic_tooltip_panel:
		_relic_tooltip_panel.visible = false

## 在玩家区底部动态创建迷你遗物栏
func _build_relic_bar() -> void:
	var player_area: Node = get_node_or_null("UI/AltarLayout/PlayerArea")
	if not player_area: return
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "BattleRelicBar"
	for rid: String in GameState.relics:
		var data: Dictionary = RelicManager._all_relics_data.get(rid, {})
		var relic_name: String = data.get("name","???")
		var btn: Button = Button.new()
		btn.name = "rbtn_" + rid
		btn.text = RELIC_ICONS.get(rid, "◈")
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(0.78, 0.60, 0.10, 0.85))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.55))
		# 自定义 tooltip：鼠标进入时显示
		var captured_rid: String = rid
		var captured_btn: Button = btn
		btn.mouse_entered.connect(func(): _show_relic_tooltip(captured_rid, captured_btn))
		btn.mouse_exited.connect(_hide_relic_tooltip)
		bar.add_child(btn)
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
		TransitionManager.change_scene("res://scenes/CardRewardScene.tscn")
	elif result == "defeat":
		GameState.trigger_ending("defeat")
	else:
		TransitionManager.change_scene("res://scenes/MapScene.tscn")

var _last_battle_result: String = ""

func _on_hand_updated(hand: Array) -> void:
	# ① 先记录旧手牌 ID（必须在 queue_free 之前）
	var old_ids: Dictionary = {}
	for child in hand_container.get_children():
		var cd: Variant = child.get("card_data")
		if cd is Dictionary:
			old_ids[cd.get("id", "")] = true

	# ② 清除旧牌
	for child in hand_container.get_children():
		child.queue_free()

	# ③ 建新牌节点
	for i in hand.size():
		var cd2: Dictionary = hand[i]
		var card_ui: Node = _card_scene.instantiate()
		if not card_ui: continue
		if card_ui.has_method("setup"):
			card_ui.setup(cd2)
		var can_afford: bool = DeckManager.current_cost >= maxi(0, cd2.get("cost", 0) - EmotionManager.get_cost_reduction())
		if card_ui.has_method("set_playable"):
			card_ui.set_playable(can_afford and EmotionManager.can_play_card(cd2))
		card_ui.card_clicked.connect(_on_card_clicked)
		# 初始隐藏，等布局稳定后播动画
		card_ui.modulate.a = 0.0
		hand_container.add_child(card_ui)

	# ④ 动态间距
	var card_count: int = hand_container.get_child_count()
	var sep: int = 12
	if card_count > 5:
		sep = maxi(4, 12 - (card_count - 5) * 3)
	hand_container.add_theme_constant_override("separation", sep)

	# ⑤ 等两帧确保布局稳定（HBoxContainer 需要两帧完成尺寸分配）
	await get_tree().process_frame
	await get_tree().process_frame

	# ⑥ 播入场动画（淡入+缩放弹入，stagger 错开）
	var delay: float = 0.0
	var children: Array = hand_container.get_children()
	for idx in children.size():
		var card_node: Node = children[idx]
		var cd3: Variant = card_node.get("card_data")
		var is_new: bool = not (cd3 is Dictionary and old_ids.has(cd3.get("id", "")))
		if card_node.has_method("play_draw_animation"):
			# 用 idx 捕获确保闭包拿到正确节点引用
			var captured: Node = card_node
			var tw: Tween = card_node.create_tween()
			tw.tween_interval(delay)
			tw.tween_callback(func(): captured.play_draw_animation(Vector2.ZERO))
		else:
			card_node.modulate.a = 1.0
		delay += 0.05 if is_new else 0.02

func _on_card_clicked(card_data: Dictionary) -> void:
	if state_machine.current_state != 2: # STATE_PLAYER_TURN
		return

	# 费用不足：抖动反馈
	var card_cost: int = maxi(0, card_data.get("cost", 0) - EmotionManager.get_cost_reduction())
	if DeckManager.current_cost < card_cost:
		for card_ui in hand_container.get_children():
			var cd2: Variant = card_ui.get("card_data")
			if cd2 is Dictionary and cd2.get("id","") == card_data.get("id",""):
				var orig: Vector2 = card_ui.position
				var stw: Tween = card_ui.create_tween()
				stw.tween_property(card_ui, "position:x", orig.x + 6, 0.05)
				stw.tween_property(card_ui, "position:x", orig.x - 6, 0.05)
				stw.tween_property(card_ui, "position:x", orig.x + 4, 0.04)
				stw.tween_property(card_ui, "position:x", orig.x, 0.04)
				break
		SoundManager.play_sfx("card_fail")
		return

	SoundManager.play_sfx("card_play")
	_set_player_sprite_state("attack")
	get_tree().create_timer(0.5).timeout.connect(
		func(): _set_player_sprite_state("idle"), CONNECT_ONE_SHOT)

	# 找到被点击的卡牌节点，播出牌动画（原地缩放淡出）
	for card_ui in hand_container.get_children():
		var cd: Variant = card_ui.get("card_data")
		if cd is Dictionary and cd.get("id","") == card_data.get("id",""):
			if card_ui.has_method("play_card_animation"):
				card_ui.play_card_animation(Vector2.ZERO)
			break

	# 等出牌动画开始后再执行效果
	var effect_type: String = card_data.get("effect_type", "")
	var is_attack: bool = effect_type in ["attack","attack_all","attack_lifesteal","attack_dot",
		"attack_scaling_rage","attack_all_triple","attack_and_weaken_all",
		"shield_attack","remove_enemy_shield","dodge_attack"]
	await get_tree().create_timer(0.12).timeout
	if is_attack:
		_play_player_attack_animation()
		await get_tree().create_timer(0.10).timeout
		_play_attack_flash()
		await get_tree().create_timer(0.06).timeout
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
		# 玩家受击动画
		var player_sprite: Node = get_node_or_null("UI/AltarLayout/PlayerArea/PlayerSprite")
		if player_sprite:
			_play_hit_animation(player_sprite, "player")
		# 屏幕左侧红边闪烁（受伤感）
		_flash_screen_edge(Color(0.85, 0.08, 0.08, 0.45))
		get_tree().create_timer(0.4).timeout.connect(
			func(): _set_player_sprite_state("idle"), CONNECT_ONE_SHOT)
		var is_boss: bool = state_machine.enemy_data.get("type","") == "boss"
		if is_boss:
			AchievementManager.on_player_damaged(-diff)
	elif diff > 0:
		_spawn_player_number(diff, "heal")
	if new_hp <= 0:
		_set_player_sprite_state("dead")

func _update_hud() -> void:
	var cost_now: int = int(DeckManager.current_cost)
	var cost_max: int = int(DeckManager.max_cost)
	cost_label.text          = "⚡%d/%d" % [cost_now, cost_max]
	deck_count_label.text    = "▤ %d" % int(len(DeckManager.deck))
	discard_count_label.text = "↓ %d" % int(len(DeckManager.discard_pile))
	# 卡盘右上角能量标签同步
	if _energy_tray_label:
		_energy_tray_label.text = "⚡ %d / %d" % [cost_now, cost_max]
		# 能量不足时变红提示
		if cost_now == 0:
			_energy_tray_label.add_theme_color_override("font_color", UIConstants.color_of("nu"))
		else:
			_energy_tray_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	# 旧血条数据同步（已隐藏，仅备份）
	player_hp_bar.max_value = GameState.max_hp
	player_hp_bar.value     = GameState.hp
	player_hp_label.text    = "%s %d / %d" % [UIConstants.ICONS["hp"], int(GameState.hp), int(GameState.max_hp)]
	# 新血条同步
	if _player_hbar and _player_hbar.has_method("set_hp"):
		_player_hbar.set_hp(GameState.hp, GameState.max_hp)
	if _player_hbar and _player_hbar.has_method("set_shield"):
		_player_hbar.set_shield(state_machine.player_shield)
	# 锁链 HUD 同步
	_refresh_chain_label(state_machine.enemy_chains)

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

	# 卡组查看器：挂到专用高层 CanvasLayer（layer=90），始终在最前
	_deck_viewer = DeckViewerPanelClass.new()
	_deck_viewer.name = "DeckViewerPanel"
	var deck_layer: CanvasLayer = CanvasLayer.new()
	deck_layer.name  = "DeckViewerLayer"
	deck_layer.layer = 90   # 高于普通 UI（一般 layer=1）但低于 PauseMenu（layer=64）
	add_child(deck_layer)
	deck_layer.add_child(_deck_viewer)
	# 固定按钮仍挂到 UI 层（可见位置），但面板弹出时在 DeckViewerLayer 最前渲染
	var ui_node: Node = get_node_or_null("UI")
	if ui_node:
		_deck_viewer.install_fixed_btn(ui_node, true)

func _result_panel_bbcode(title: String, body: String) -> String:
	var tc := UIConstants.color_of("gold").to_html(false)

## ── 锁链 HUD 辅助函数 ──────────────────────────────────
func _refresh_chain_label(chains: int) -> void:
	## 根据当前锁链层数更新或隐藏标签
	if chains <= 0:
		if _chain_label:
			_chain_label.visible = false
		return
	# 如果标签还没创建，动态添加到敌人区域
	if not _chain_label:
		var enemy_area: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
		if not enemy_area:
			return
		_chain_label = Label.new()
		_chain_label.name = "ChainLabel"
		_chain_label.add_theme_font_size_override("font_size", 14)
		_chain_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		_chain_label.z_index = 5
		enemy_area.add_child(_chain_label)
	_chain_label.visible = true
	if chains >= 5:
		# 5层以上：镇压色（蓝白），提示跳过行动
		_chain_label.text = "⛓ %d  [镇压]" % chains
		_chain_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	else:
		_chain_label.text = "⛓ %d" % chains
		_chain_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))

func _on_chain_applied(total_chains: int) -> void:
	## 接收锁链信号，刷新 HUD 并播放浮字提示
	_refresh_chain_label(total_chains)
	if total_chains > 0:
		_show_float_text("⛓×%d" % total_chains, get_viewport().get_visible_rect().size * Vector2(0.65, 0.35), Color(0.5, 0.8, 1.0), 16)

func _on_wu_wei_mark_applied(emotion: String, count: int, turns_left: int) -> void:
	## 无为·持续施印回调：播放浮字提示
	var emotion_icons: Dictionary = {"joy": "喜", "calm": "定", "grief": "悲", "fear": "惧", "rage": "怒"}
	var icon: String = emotion_icons.get(emotion, emotion)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_show_float_text("无为 %s印×%d (剩%d回合)" % [icon, count, turns_left], vp * Vector2(0.5, 0.4), Color(0.9, 0.85, 0.6), 15)

func _setup_result_panel_theme() -> void:
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color     = Color(0.04, 0.03, 0.02, 0.97)
	ps.border_color = UIConstants.color_of("gold_dim")
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(6)
	result_panel.add_theme_stylebox_override("panel", ps)
	result_label.add_theme_font_size_override("normal_font_size", UIConstants.font_size_of("body"))
	result_label.add_theme_color_override("default_color", UIConstants.color_of("text_primary"))
	result_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	result_btn.add_theme_stylebox_override("hover",  UIConstants.make_button_style("parch", "gold"))
	result_btn.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	result_btn.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))

func _refresh_hand() -> void:
	for card_ui in hand_container.get_children():
		if card_ui.has_method("set_playable") and card_ui.has_method("get") :
			var cd: Variant = card_ui.get("card_data")
			if cd:
				var can_afford: bool = DeckManager.current_cost >= maxi(0, cd.get("cost", 0) - EmotionManager.get_cost_reduction())
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
	for a in acts.slice(0, mini(2, len(acts))):
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
	_tooltip_panel.position = Vector2(clampf(pos.x - 60.0, 4.0, 1080.0), maxf(pos.y - 72.0, 4.0))

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

	# Boss 渡化对话 UI（动态创建并挂到 UI 层）
	var ui_node: Node = get_node_or_null("UI")
	if ui_node and not ui_node.has_node("BossDialogueUI"):
		var dlg: Node = BossDialogueUIClass.new()
		dlg.name = "BossDialogueUI"
		ui_node.add_child(dlg)

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
	# 获取实际视口尺寸（避免硬编码）
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var W: float = vp_size.x   # 1920 (基于视口，自适应)
	var H: float = vp_size.y   # 1080 (基于视口，自适应)

	# 卡盘顶部 Y（tscn HandContainer 从 828 开始，卡盘稍高留边）
	var tray_top: float    = H - 185.0   # ~535px（对应1280x720手牌区顶部）
	var tray_line: float   = H - 190.0   # 水墨分割线
	var energy_top: float  = H - 205.0   # 能量面板顶
	var energy_bot: float  = H - 168.0   # 能量面板底（高37px）

	var ui: Node = get_node_or_null("UI")

	# ── 地面线 ──────────────────────────────────────────
	var ground := ColorRect.new()
	ground.name = "BattleGround"
	ground.color = Color(UIC.COLORS["ding"].darkened(0.7), 0.6)
	ground.position = Vector2(0, tray_top - 116)
	ground.size     = Vector2(W, 4)
	ground.z_index  = 2
	if ui: ui.add_child(ground)

	# ── HandContainer 位置（固定像素坐标）──────────────
	if hand_container:
		hand_container.position = Vector2(0, tray_top)
		hand_container.size     = Vector2(W, H - tray_top - 10)
		hand_container.add_theme_constant_override("separation", 10)
		hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
		hand_container.z_index   = 2

	if not ui: return

	# ── 卡盘像素托盘背景（按角色不同配色）──────────────
	if not ui.get_node_or_null("CardTray"):
		var char_id: String = str(GameState.get_meta("selected_character", "ruan_ruyue"))
		var tray := _build_card_tray(char_id, W, H, tray_top)
		ui.add_child(tray)
		if hand_container:
			hand_container.z_index = 2

	# ── 水墨分割线 ──────────────────────────────────────
	if not ui.get_node_or_null("HandAreaDivider"):
		var strip := WaterInkDivider.new()
		strip.name = "HandAreaDivider"
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.z_index = 1
		strip.position = Vector2(8, tray_line)
		strip.size     = Vector2(W - 16, 6)
		strip.ink_color = UIConstants.color_of("gold_dim")
		ui.add_child(strip)

	# ── 卡盘右上角能量面板 ──────────────────────────────
	if not ui.get_node_or_null("CardTrayEnergy"):
		var energy_panel := Panel.new()
		energy_panel.name     = "CardTrayEnergy"
		energy_panel.z_index  = 3
		energy_panel.position = Vector2(W - 95, energy_top)
		energy_panel.size     = Vector2(82, energy_bot - energy_top)
		var ep_style: StyleBoxFlat = StyleBoxFlat.new()
		ep_style.bg_color = Color(0.08, 0.06, 0.04, 0.90)
		ep_style.border_width_top    = 1; ep_style.border_width_bottom = 1
		ep_style.border_width_left   = 1; ep_style.border_width_right  = 1
		ep_style.border_color = UIConstants.color_of("gold")
		ep_style.set_corner_radius_all(6)
		energy_panel.add_theme_stylebox_override("panel", ep_style)
		var energy_lbl: Label = Label.new()
		energy_lbl.name = "EnergyLabel"
		energy_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		energy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		energy_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		energy_lbl.add_theme_font_size_override("font_size", 14)
		energy_lbl.add_theme_color_override("font_color", UIConstants.color_of("gold"))
		energy_panel.add_child(energy_lbl)
		ui.add_child(energy_panel)
		_energy_tray_label = energy_lbl

	# ── 卡牌悬停预览层 ──────────────────────────────────
	_card_preview = CardPreviewClass.new()
	if ui: ui.add_child(_card_preview)

## 根据角色生成不同风格的卡盘像素背景
func _build_card_tray(char_id: String, W: float, H: float, tray_top: float) -> Control:
	var tray_h: float = H - tray_top
	var img := Image.create(int(W), int(tray_h), false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	match char_id:
		"shen_tiejun": _draw_tray_shen(img, int(W), int(tray_h))
		"wumian":       _draw_tray_wumian(img, int(W), int(tray_h))
		_:              _draw_tray_ruan(img, int(W), int(tray_h))

	var tex := ImageTexture.create_from_image(img)
	var tray := TextureRect.new()
	tray.name          = "CardTray"
	tray.texture       = tex
	tray.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	tray.z_index       = 0
	tray.position      = Vector2(0, tray_top)
	tray.size          = Vector2(W, tray_h)
	tray.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	tray.stretch_mode  = TextureRect.STRETCH_SCALE
	return tray

## 阮如月卡盘 — 朱砂红边框，庙宇瓦片纹，金色符文装饰
func _draw_tray_ruan(img: Image, W: int, H: int) -> void:
	# 底色（深暖墨）
	for y in H:
		var t: float = float(y) / float(H)
		var c: Color = Color(0.08, 0.05, 0.04, 0.85 + t * 0.1)
		for x in W: img.set_pixel(x, y, c)
	# 顶部朱砂红边线（2px）
	for x in W:
		img.set_pixel(x, 0, Color(0.72, 0.12, 0.12, 0.9))
		img.set_pixel(x, 1, Color(0.62, 0.10, 0.10, 0.7))
	# 金色双线边框（距顶4px）
	for x in W:
		img.set_pixel(x, 4, Color(0.78, 0.60, 0.10, 0.5))
		img.set_pixel(x, 6, Color(0.78, 0.60, 0.10, 0.3))
	# 瓦片纹（每40px一组横纹，模拟庙宇砖瓦）
	var tile_c := Color(0.72, 0.12, 0.12, 0.06)
	var i: int = 0
	while i < W:
		for y in range(10, H):
			img.set_pixel(i, y, tile_c)
		i += 40
	# 符文装饰（中央渡字印记，简化）
	var cx: int = W / 2
	for dx in range(-2, 3):
		img.set_pixel(cx + dx, 12, Color(0.78, 0.60, 0.10, 0.25))
	img.set_pixel(cx, 10, Color(0.78, 0.60, 0.10, 0.20))
	img.set_pixel(cx, 14, Color(0.78, 0.60, 0.10, 0.20))

## 沈铁钧卡盘 — 铁链纹，深蓝钢色，铆钉角饰
func _draw_tray_shen(img: Image, W: int, H: int) -> void:
	# 底色（深蓝钢）
	for y in H:
		var t: float = float(y) / float(H)
		var c: Color = Color(0.05, 0.08, 0.14, 0.87 + t * 0.08)
		for x in W: img.set_pixel(x, y, c)
	# 顶部铁灰边线
	for x in W:
		img.set_pixel(x, 0, Color(0.45, 0.48, 0.55, 0.9))
		img.set_pixel(x, 1, Color(0.35, 0.38, 0.45, 0.7))
	# 银色双线
	for x in W:
		img.set_pixel(x, 4, Color(0.60, 0.62, 0.68, 0.45))
		img.set_pixel(x, 6, Color(0.50, 0.52, 0.58, 0.25))
	# 铁链纹（交替矩形）
	var link_c := Color(0.35, 0.38, 0.50, 0.12)
	var j: int = 0
	while j < W:
		for y in range(10, H, 6):
			if (j / 20 + y / 6) % 2 == 0:
				for dy in range(0, 3):
					if y + dy < H:
						img.set_pixel(j % W, y + dy, link_c)
		j += 20
	# 铆钉角（左右各一组）
	for nail_x in [8, 16, W-16, W-8]:
		for ny in range(8, 16):
			var dx2: int = nail_x - (8 if nail_x < W/2 else W-8)
			var dy2: int = ny - 12
			if dx2*dx2 + dy2*dy2 <= 9:
				img.set_pixel(nail_x, ny, Color(0.65, 0.68, 0.72, 0.7))

## 无名卡盘 — 渐变灰白，虚空纹，无边界感
func _draw_tray_wumian(img: Image, W: int, H: int) -> void:
	# 底色（渐变灰白，边缘透明）
	for y in H:
		var t: float = float(y) / float(H)
		var a: float = 0.70 + t * 0.15
		var g: float = 0.12 - t * 0.04
		var c: Color = Color(g + 0.06, g + 0.06, g + 0.05, a)
		for x in W: img.set_pixel(x, y, c)
	# 顶部白色渐隐线（虚空感）
	for x in W:
		var fx: float = float(x) / float(W)
		var edge_a: float = 0.5 * sin(fx * 3.14159)
		img.set_pixel(x, 0, Color(0.85, 0.85, 0.83, edge_a))
		img.set_pixel(x, 1, Color(0.75, 0.75, 0.73, edge_a * 0.6))
	# 粒子纹（稀疏白点，模拟情绪粒子）
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _k in 80:
		var px: int = rng.randi_range(0, W-1)
		var py: int = rng.randi_range(8, H-1)
		var pa: float = rng.randf_range(0.05, 0.20)
		img.set_pixel(px, py, Color(0.9, 0.9, 0.88, pa))

## 祭坛三栏标题：DS-00 配色 + 标题下水墨分割线
func _setup_altar_title_style() -> void:
	var pa: Node = get_node_or_null("UI/AltarLayout/PlayerArea")
	if pa:
		var pt: Node = pa.get_node_or_null("PlayerTitle")
		if pt:
			pt.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))
			pt.add_theme_color_override("font_color", UIConstants.color_of("text_secondary"))
			_insert_ink_divider_below(pa, pt, 168)
	var ac: Node = get_node_or_null("UI/AltarLayout/AltarCenter")
	if ac:
		# 移除祭坛中央区域的硬边框面板（如果有 Panel 节点）
		var bg_panel: Node = ac.get_node_or_null("BgPanel")
		if bg_panel: bg_panel.modulate = Color(0,0,0,0)
		var at: Node = ac.get_node_or_null("AltarTitle")
		if at:
			at.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))
			at.add_theme_color_override("font_color", UIConstants.color_of("gold"))
			_insert_ink_divider_below(ac, at, 200)
	var ea: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
	if ea:
		var en: Node = ea.get_node_or_null("EnemyName")
		if en:
			en.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))
			en.add_theme_color_override("font_color", UIConstants.color_of("text_secondary"))
			_insert_ink_divider_below(ea, en, 168)
	var dw: Node = get_node_or_null("UI/AltarLayout/AltarCenter/DisorderWarning")
	if dw:
		dw.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
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
	## 玩家攻击：敌人精灵冲击动画
	var sprite: Node = get_node_or_null("UI/AltarLayout/EnemyArea/EnemySprite")
	if sprite:
		_play_hit_animation(sprite, "enemy")
	## 同时在敌人区域叠加冲击光
	var enemy_area: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
	if enemy_area:
		_spawn_impact_particles(enemy_area, Color(1.0, 0.85, 0.30))

## ══════════════════════════════════════════════════════
## 攻击/受击/死亡 动画系统（程序化，无需外部素材）
## ══════════════════════════════════════════════════════

## 受击抖动 + 红色闪烁（enemy/player 通用）
func _play_hit_animation(sprite_node: Node, target: String) -> void:
	if not sprite_node: return
	# 停止 idle 浮动（临时）
	var base_pos: Vector2 = sprite_node.position
	# 受击颜色（红色闪烁）
	var htw: Tween = sprite_node.create_tween()
	htw.tween_property(sprite_node, "modulate", Color(1.8, 0.3, 0.3, 1.0), 0.05)
	htw.tween_property(sprite_node, "modulate", Color.WHITE, 0.18)
	# 受击位移（向击打方向偏移）
	var offset_x: float = -12.0 if target == "enemy" else 12.0
	var ptw: Tween = sprite_node.create_tween()
	ptw.tween_property(sprite_node, "position:x", base_pos.x + offset_x, 0.05)\
		.set_ease(Tween.EASE_OUT)
	ptw.tween_property(sprite_node, "position:x", base_pos.x - offset_x * 0.4, 0.06)
	ptw.tween_property(sprite_node, "position:x", base_pos.x, 0.12)\
		.set_trans(Tween.TRANS_SPRING)
	# 竖向微震
	var vtw: Tween = sprite_node.create_tween()
	vtw.tween_property(sprite_node, "position:y", base_pos.y - 4.0, 0.04)
	vtw.tween_property(sprite_node, "position:y", base_pos.y + 3.0, 0.06)
	vtw.tween_property(sprite_node, "position:y", base_pos.y, 0.10)\
		.set_trans(Tween.TRANS_SPRING)

## 玩家出牌冲向敌人动画（攻击型卡牌）
func _play_player_attack_animation() -> void:
	var sprite: Node = get_node_or_null("UI/AltarLayout/PlayerArea/PlayerSprite")
	if not sprite: return
	var base_pos: Vector2 = sprite.position
	# 向右冲刺后弹回
	var atw: Tween = sprite.create_tween()
	atw.tween_property(sprite, "position:x", base_pos.x + 18.0, 0.08)\
		.set_ease(Tween.EASE_OUT)
	atw.tween_property(sprite, "position:x", base_pos.x - 6.0, 0.06)
	atw.tween_property(sprite, "position:x", base_pos.x, 0.14)\
		.set_trans(Tween.TRANS_SPRING)
	# 出击时轻微缩放拉伸
	var stw: Tween = sprite.create_tween()
	stw.tween_property(sprite, "scale", Vector2(1.12, 0.90), 0.08)
	stw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.18)\
		.set_trans(Tween.TRANS_BACK)

## 敌人攻击动画（向玩家方向猛扑）
func _play_enemy_attack_animation() -> void:
	var sprite: Node = get_node_or_null("UI/AltarLayout/EnemyArea/EnemySprite")
	if not sprite: return
	var base_pos: Vector2 = sprite.position
	# 向左冲向玩家
	var atw: Tween = sprite.create_tween()
	atw.tween_property(sprite, "position:x", base_pos.x - 22.0, 0.10)\
		.set_ease(Tween.EASE_OUT)
	atw.tween_property(sprite, "position:x", base_pos.x + 5.0, 0.08)
	atw.tween_property(sprite, "position:x", base_pos.x, 0.16)\
		.set_trans(Tween.TRANS_SPRING)
	# 拉伸
	var stw: Tween = sprite.create_tween()
	stw.tween_property(sprite, "scale", Vector2(0.85, 1.18), 0.10)
	stw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.20)\
		.set_trans(Tween.TRANS_BACK)

## 死亡动画（敌人消散）
func _play_enemy_death_animation() -> void:
	var sprite: Node = get_node_or_null("UI/AltarLayout/EnemyArea/EnemySprite")
	if not sprite: return
	# 先剧烈抖动
	var base_pos: Vector2 = sprite.position
	var dtw: Tween = sprite.create_tween()
	for _i in 4:
		dtw.tween_property(sprite, "position:x", base_pos.x + 6.0, 0.04)
		dtw.tween_property(sprite, "position:x", base_pos.x - 6.0, 0.04)
	dtw.tween_property(sprite, "position:x", base_pos.x, 0.04)
	# 然后上升淡出消散
	dtw.tween_property(sprite, "position:y", base_pos.y - 30.0, 0.45)\
		.set_ease(Tween.EASE_IN)
	dtw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.45)
	# 消散粒子
	var enemy_area: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
	if enemy_area:
		_spawn_death_particles(enemy_area)

## 死亡粒子：8个小方块向外扩散
func _spawn_death_particles(parent: Node) -> void:
	var center: Vector2 = Vector2(parent.size.x * 0.5, parent.size.y * 0.4)
	var colors: Array[Color] = [
		Color(0.85, 0.72, 0.28), Color(0.60, 0.20, 0.20),
		Color(0.90, 0.90, 0.85), Color(0.50, 0.55, 0.65),
	]
	for i in 10:
		var dot: ColorRect = ColorRect.new()
		dot.size = Vector2(randf_range(3.0, 6.0), randf_range(3.0, 6.0))
		dot.color = colors[i % colors.size()]
		dot.color.a = 0.9
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = center + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		parent.add_child(dot)
		var angle: float = TAU * i / 10.0 + randf_range(-0.3, 0.3)
		var dist: float  = randf_range(30.0, 65.0)
		var tw: Tween    = dot.create_tween()
		tw.tween_property(dot, "position",
			dot.position + Vector2(cos(angle), sin(angle)) * dist, 0.55)\
			.set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(dot, "modulate:a", 0.0, 0.55)\
			.set_delay(0.15)
		tw.tween_callback(dot.queue_free)

## 冲击波粒子（攻击命中时）
func _spawn_impact_particles(parent: Node, color: Color) -> void:
	var center: Vector2 = Vector2(parent.size.x * 0.5, parent.size.y * 0.38)
	for i in 8:
		var line: ColorRect = ColorRect.new()
		line.size = Vector2(randf_range(2.0, 4.0), randf_range(10.0, 20.0))
		line.color = color
		line.color.a = 0.85
		line.rotation = TAU * i / 8.0 + randf_range(-0.2, 0.2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.position = center
		parent.add_child(line)
		var dist: float = randf_range(20.0, 45.0)
		var tw: Tween = line.create_tween()
		tw.tween_property(line, "position",
			center + Vector2(cos(line.rotation), sin(line.rotation)) * dist, 0.25)\
			.set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(line, "modulate:a", 0.0, 0.25)
		tw.tween_callback(line.queue_free)
	# 中心亮点
	var glow: ColorRect = ColorRect.new()
	glow.size = Vector2(18, 18)
	glow.color = Color(color.r, color.g, color.b, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.position = center - Vector2(9, 9)
	parent.add_child(glow)
	var gtw: Tween = glow.create_tween()
	gtw.tween_property(glow, "color:a", 0.9, 0.05)
	gtw.tween_property(glow, "color:a", 0.0, 0.22)
	gtw.tween_callback(glow.queue_free)

# ════════════════════════════════════════════════════════
#  弃牌按钮 & 碎片显示
# ════════════════════════════════════════════════════════

var _discard_btn: Button = null
var _shard_display: ShardDisplay = null
var _free_next_card: bool = false    # 无名空流进入段奖励：下一张牌免费

func _setup_discard_button() -> void:
	var ui: Node = get_node_or_null("UI")
	if not ui: return
	_discard_btn = Button.new()
	_discard_btn.name = "DiscardBtn"
	_discard_btn.text = "弃牌"
	_discard_btn.custom_minimum_size = Vector2(64, 28)
	_discard_btn.add_theme_font_size_override("font_size", 12)
	_discard_btn.add_theme_color_override("font_color", UIConstants.color_of("text_muted"))
	_discard_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	_discard_btn.visible = false  # 玩家回合才显示
	_discard_btn.pressed.connect(_on_discard_btn_pressed)
	ui.add_child(_discard_btn)
	# 定位到 HUD 右侧
	var hud: Node = get_node_or_null("UI/HUD")
	if hud:
		_discard_btn.position = Vector2(1100.0, 8.0)

func _setup_shard_display() -> void:
	var ui: Node = get_node_or_null("UI")
	if not ui: return
	_shard_display = ShardDisplay.new()
	_shard_display.name = "ShardDisplay"
	_shard_display.position = Vector2(8.0, 50.0)
	ui.add_child(_shard_display)

func _on_discard_btn_pressed() -> void:
	# 弃牌模式：下一次点击手牌触发主动弃牌
	if not DeckManager.can_active_discard():
		return
	_discard_mode = true
	_discard_btn.text = "选择要弃掉的牌..."
	_discard_btn.disabled = true

var _discard_mode: bool = false

func _handle_card_click_discard(card_data: Dictionary) -> void:
	if not _discard_mode: return
	_discard_mode = false
	DeckManager.active_discard(card_data)
	_update_discard_btn()

func _update_discard_btn() -> void:
	if not _discard_btn: return
	var can: bool = DeckManager.can_active_discard()
	_discard_btn.disabled = not can
	_discard_btn.text = "弃牌 (%d)" % (DeckManager.active_discard_limit - DeckManager.active_discard_used) if can else "弃牌（已用尽）"

# ════════════════════════════════════════════════════════
#  弃牌系统角色专属回调
# ════════════════════════════════════════════════════════

func _on_ruyue_seal_bonus(emotion: String) -> void:
	## 阮如月印散：随机对一个敌人施加对应情绪印记×1
	state_machine._apply_mark(emotion, 1)

func _on_tiejun_rage_bonus() -> void:
	## 沈铁钧余怒：弃怒牌→锁链目标受（怒×2）伤害
	var dmg: int = EmotionManager.values.get("rage", 0) * 2
	if dmg > 0:
		state_machine._deal_damage_to_enemy(dmg)

func _on_tiejun_chain_bonus() -> void:
	## 沈铁钧余怒：弃施锁牌→随机敌人施加锁链×1
	state_machine._apply_chain(1)

func _on_wumian_energy_bonus() -> void:
	## 无名空流进入高段：+1能量
	DeckManager.current_cost = mini(DeckManager.current_cost + 1, DeckManager.max_cost)
	_update_hud()

func _on_wumian_free_card_bonus() -> void:
	## 无名空流进入极高段：下一张牌免费
	_free_next_card = true

# ════════════════════════════════════════════════════════
#  空鸣选择面板
# ════════════════════════════════════════════════════════

func _on_kongming_choice_required() -> void:
	## 空鸣触发后，玩家选择空鸣效果
	## 参考 PauseMenu/CardRewardScene 风格：深色背景+金色边框+大字标题

	# 暂停敌人行动：将状态机切换到 STATE_RESOLVING（值=3）防止继续执行
	const STATE_RESOLVING: int = 3
	if state_machine.current_state != STATE_RESOLVING:
		state_machine.current_state = STATE_RESOLVING

	# 创建高层 CanvasLayer（layer=200，覆盖所有普通 UI）
	var choice_layer: CanvasLayer = CanvasLayer.new()
	choice_layer.name = "KongmingChoiceLayer"
	choice_layer.layer = 200
	add_child(choice_layer)

	# 半透明遮罩
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.68)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_layer.add_child(overlay)

	# 主面板（深色背景+金色边框）
	var panel: Panel = Panel.new()
	panel.name = "KongmingPanel"
	panel.custom_minimum_size = Vector2(400, 200)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	panel.position = Vector2((vp.x - 400.0) * 0.5, (vp.y - 200.0) * 0.5)
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.04, 0.03, 0.98)
	ps.border_width_top    = 2; ps.border_width_bottom = 2
	ps.border_width_left   = 2; ps.border_width_right  = 2
	ps.border_color = Color(0.85, 0.70, 0.20, 1.0)   # 金色边框
	ps.set_corner_radius_all(8)
	ps.content_margin_left   = 20.0; ps.content_margin_right  = 20.0
	ps.content_margin_top    = 18.0; ps.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", ps)
	choice_layer.add_child(panel)

	# 内部垂直布局
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# 大字标题"空 鸣"
	var title_lbl: Label = Label.new()
	title_lbl.text = "✦  空  鸣  ✦"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	vbox.add_child(title_lbl)

	# 副标题说明
	var sub_lbl: Label = Label.new()
	sub_lbl.text = "选择空鸣效果"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.70))
	vbox.add_child(sub_lbl)

	# 两个选项按钮横排
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	# ── 关闭弹窗并恢复状态的通用 Callable ──
	var close_choice: Callable = func() -> void:
		const STATE_PLAYER_TURN: int = 2
		choice_layer.queue_free()
		if state_machine.current_state == STATE_RESOLVING:
			state_machine.current_state = STATE_PLAYER_TURN

	# 按钮样式工厂（深色底+金色边框）
	var make_btn_style: Callable = func(highlight: bool) -> StyleBoxFlat:
		var bs: StyleBoxFlat = StyleBoxFlat.new()
		bs.bg_color = Color(0.10, 0.08, 0.04, 0.95) if not highlight else Color(0.15, 0.12, 0.04, 0.95)
		bs.border_width_top    = 1; bs.border_width_bottom = 1
		bs.border_width_left   = 1; bs.border_width_right  = 1
		bs.border_color = Color(0.85, 0.70, 0.20, 0.85) if highlight else Color(0.60, 0.50, 0.15, 0.75)
		bs.set_corner_radius_all(6)
		return bs

	# 选项 A：渡化之道 — 渡化进度+25%
	var btn_purify: Button = Button.new()
	btn_purify.text = "渡化之道\n渡化进度 +25%"
	btn_purify.custom_minimum_size = Vector2(165, 60)
	btn_purify.add_theme_font_size_override("font_size", 13)
	btn_purify.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))
	btn_purify.add_theme_stylebox_override("normal", make_btn_style.call(false))
	btn_purify.add_theme_stylebox_override("hover",  make_btn_style.call(true))
	btn_purify.pressed.connect(func() -> void:
		# 通过 PurificationPanel 增加渡化进度
		var purif: Node = get_node_or_null("UI/AltarLayout/AltarCenter/PurificationPanel")
		if purif and purif.has_method("add_progress"):
			purif.add_progress(0.25)
		elif state_machine.has_method("_add_du_hua_progress"):
			state_machine._add_du_hua_progress(0.25)
		_show_float_text("渡化 +25%", get_viewport().get_visible_rect().size * Vector2(0.5, 0.45), Color(0.7, 0.9, 0.6), 16)
		close_choice.call()
	)
	hbox.add_child(btn_purify)

	# 选项 B：空鸣穿甲 — 对敌人造成25点穿甲伤害
	var btn_pierce: Button = Button.new()
	btn_pierce.text = "空鸣穿甲\n对敌人25点穿甲伤害"
	btn_pierce.custom_minimum_size = Vector2(165, 60)
	btn_pierce.add_theme_font_size_override("font_size", 13)
	btn_pierce.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))
	btn_pierce.add_theme_stylebox_override("normal", make_btn_style.call(false))
	btn_pierce.add_theme_stylebox_override("hover",  make_btn_style.call(true))
	btn_pierce.pressed.connect(func() -> void:
		# 穿甲伤害（忽略护盾，直接扣敌人HP）
		state_machine._deal_damage_to_enemy(25)
		_show_float_text("空鸣穿甲 -25", get_viewport().get_visible_rect().size * Vector2(0.5, 0.45), Color(1.0, 0.4, 0.2), 16)
		close_choice.call()
	)
	hbox.add_child(btn_pierce)

	# 面板入场动画（缩放弹入）
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.88, 0.88)
	var anim_tw: Tween = panel.create_tween()
	anim_tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	anim_tw.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), 0.20)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ════════════════════════════════════════════════════════
#  Boss 渡化条件检测（每回合结束时调用）
# ════════════════════════════════════════════════════════

var _purification_dialogue_shown: bool = false
var _purification_phase: int = 0   # 0=未开始，1=第一阶段，2=第二阶段，3=完成

func _check_purification_unlock() -> void:
	if _purification_dialogue_shown: return
	var enemy_data: Dictionary = state_machine.enemy_data
	if not enemy_data.get("is_boss", false): return
	var boss_id: String = str(enemy_data.get("id", ""))
	var char_id: String = str(GameState.get_meta("selected_character", ""))

	# 检查数据库中是否有对应对话
	if not BossDialogueDatabase.has_dialogue(boss_id, char_id, "purification"): return

	var trigger: Dictionary = BossDialogueDatabase.get_trigger(boss_id, char_id, "purification")
	for emotion: String in trigger:
		if EmotionManager.values.get(emotion, 0) < int(trigger[emotion]):
			return  # 条件未满足

	# 所有条件满足，显示渡化按钮
	_purification_dialogue_shown = true
	_show_purification_option(boss_id, char_id)

func _show_purification_option(boss_id: String, char_id: String) -> void:
	var btn: Node = get_node_or_null("UI/HUD/DuHuaBtn")
	if not btn: return
	btn.visible = true
	btn.text = "✨ 发起渡化"
	btn.modulate.a = 0.0
	var tw: Tween = btn.create_tween()
	tw.tween_property(btn, "modulate:a", 1.0, 0.5)
	# 覆写点击行为，进入对话流程
	if btn.pressed.get_connections().size() > 0:
		btn.pressed.disconnect(_on_du_hua_pressed)
	btn.pressed.connect(func(): _start_purification_dialogue(boss_id, char_id))

func _start_purification_dialogue(boss_id: String, char_id: String) -> void:
	var phases: Array = BossDialogueDatabase.get_phases(boss_id, char_id, "purification")
	if phases.is_empty():
		state_machine.confirm_du_hua()
		return
	var dlg_ui: Node = get_node_or_null("UI/BossDialogueUI")
	if dlg_ui and dlg_ui.has_method("start_dialogue"):
		dlg_ui.start_dialogue(phases, func():
			var effect: String = BossDialogueDatabase.get_completion_effect(boss_id, char_id, "purification")
			if effect == "purification_complete":
				state_machine.confirm_du_hua()
		)

# ════════════════════════════════════════════════════════
#  精英战遗物奖励面板
# ════════════════════════════════════════════════════════

func _show_relic_reward_panel() -> void:
	var ui: Node = get_node_or_null("UI")
	if not ui: return

	var relics: Array[Dictionary] = RelicManager.get_reward_relics(3)
	if relics.is_empty(): return

	# 背景遮罩
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "RelicRewardOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.z_index = 150
	ui.add_child(overlay)

	# 主面板
	var panel: Panel = Panel.new()
	panel.name = "RelicRewardPanel"
	panel.z_index = 151
	panel.custom_minimum_size = Vector2(520, 260)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	panel.position = Vector2((vp.x - 520) * 0.5, (vp.y - 260) * 0.5)
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.04, 0.02, 0.98)
	ps.border_color = Color(0.85, 0.72, 0.20)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", ps)
	ui.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0; vbox.offset_right = -16.0
	vbox.offset_top = 14.0; vbox.offset_bottom = -14.0
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# 标题
	var title: Label = Label.new()
	title.text = "✦ 精英战奖励 · 选择一件遗物 ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	vbox.add_child(title)

	# 遗物选项横排
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	for relic in relics:
		var rcard: VBoxContainer = _make_relic_card(relic, overlay, panel)
		hbox.add_child(rcard)

	# 跳过按钮
	var skip_btn: Button = Button.new()
	skip_btn.text = "跳过（不选）"
	skip_btn.custom_minimum_size = Vector2(140, 32)
	skip_btn.add_theme_font_size_override("font_size", 12)
	skip_btn.add_theme_color_override("font_color", UIConstants.color_of("ash"))
	skip_btn.pressed.connect(func():
		overlay.queue_free()
		panel.queue_free()
	)
	var skip_hbox: HBoxContainer = HBoxContainer.new()
	skip_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	skip_hbox.add_child(skip_btn)
	vbox.add_child(skip_hbox)

func _make_relic_card(relic: Dictionary, overlay: Node, panel: Node) -> VBoxContainer:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(148, 160)
	vbox.add_theme_constant_override("separation", 6)

	# 遗物图标框
	var frame: Panel = Panel.new()
	frame.custom_minimum_size = Vector2(148, 100)
	var fs: StyleBoxFlat = StyleBoxFlat.new()
	fs.bg_color = Color(0.10, 0.08, 0.03, 0.95)
	fs.border_color = Color(0.55, 0.42, 0.12, 0.85)
	fs.set_border_width_all(1)
	fs.set_corner_radius_all(5)
	frame.add_theme_stylebox_override("panel", fs)
	vbox.add_child(frame)

	var inner: VBoxContainer = VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 8.0; inner.offset_right = -8.0
	inner.offset_top = 8.0; inner.offset_bottom = -8.0
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	frame.add_child(inner)

	# 图标
	var icon_lbl: Label = Label.new()
	icon_lbl.text = _get_relic_icon(relic.get("id",""))
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 28)
	inner.add_child(icon_lbl)

	# 名字
	var name_lbl: Label = Label.new()
	name_lbl.text = relic.get("name","???")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	inner.add_child(name_lbl)

	# 描述（截短）
	var desc_raw: String = str(relic.get("description", relic.get("desc", "")))
	var desc_lbl: Label = Label.new()
	desc_lbl.text = desc_raw.substr(0, 40) + ("…" if len(desc_raw) > 40 else "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", UIConstants.color_of("ash"))
	inner.add_child(desc_lbl)

	# 选择按钮
	var pick_btn: Button = Button.new()
	pick_btn.text = "选择"
	pick_btn.custom_minimum_size = Vector2(148, 30)
	pick_btn.add_theme_font_size_override("font_size", 12)
	pick_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	pick_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	pick_btn.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	var captured_id: String = relic.get("id","")
	pick_btn.pressed.connect(func():
		RelicManager.add_relic_by_id(captured_id)
		overlay.queue_free()
		panel.queue_free()
		_show_float_text("获得遗物：" + relic.get("name",""), get_viewport().get_visible_rect().size / 2.0, Color(0.95, 0.82, 0.25))
	)
	vbox.add_child(pick_btn)
	return vbox

func _get_relic_icon(relic_id: String) -> String:
	var icons: Dictionary = {
		"tong_jing_sui":"🪞","wenlu_xiang":"🕯","duhun_ce":"📖",
		"shaogu_pian":"🦴","qingming_pai":"🪶","wuqing_jie":"🎀",
		"nianhua_yan":"👁","yin_yang_bi":"✒","hun_bo_lu":"🔥","si_xiang_pian":"🌾",
		"liuhun_suo":"⛓","biyue_fan":"🪭","kongming_jue":"🌀","wuming_pao":"🫧",
	}
	return icons.get(relic_id, "💎")

# ════════════════════════════════════════════════════════
#  键盘快捷键
# ════════════════════════════════════════════════════════

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	match event.keycode:
		KEY_E:
			## [E] 结束回合
			if not end_turn_btn.disabled:
				_on_end_turn_pressed()
				get_viewport().set_input_as_handled()
		KEY_D:
			## [D] 切换牌组查看
			if _deck_viewer:
				_deck_viewer.toggle_popup()
				get_viewport().set_input_as_handled()

# ── 成就 Toast ─────────────────────────────────────────
func _on_achievement_unlocked(achievement_id: String) -> void:
	var info: Dictionary = AchievementManager.get_achievement_info(achievement_id)
	_show_float_text(
		"%s 成就：%s" % [info.get("icon","🏆"), info.get("name", achievement_id)],
		Vector2(get_viewport().get_visible_rect().size.x * 0.5, 80.0),
		Color(0.65, 0.90, 0.55),
		16
	)

# ════════════════════════════════════════════════════════
#  双人协作战斗模式
# ════════════════════════════════════════════════════════

func _setup_coop_battle() -> void:
	_coop_sm = CoopBattleStateMachineClass.new()
	_coop_sm.name = "CoopStateMachine"
	add_child(_coop_sm)

	# 连接 coop 信号
	_coop_sm.coop_battle_started.connect(_on_coop_battle_started)
	_coop_sm.turn_changed.connect(_on_coop_turn_changed)
	_coop_sm.battle_ended.connect(_on_coop_battle_ended)
	_coop_sm.coop_resonance_triggered.connect(_on_coop_resonance)

	# 共用的 UI 初始化（用实际存在的函数名）
	_build_relic_bar()
	_setup_shard_display()
	_setup_buff_ui()
	_setup_player_sprite()
	_setup_energy_display()
	_setup_altar_title_style()
	# 卡牌预览内联初始化
	var ui_node2: Node = get_node_or_null("UI")
	if ui_node2 and not _card_preview:
		_card_preview = CardPreviewClass.new()
		ui_node2.add_child(_card_preview)

	WumianManager.activate()
	_deck_viewer = DeckViewerPanelClass.new()
	_deck_viewer.name = "DeckViewerPanel"
	var ui_node: Node = get_node_or_null("UI")
	if ui_node:
		ui_node.add_child(_deck_viewer)
		_deck_viewer.install_fixed_btn(ui_node, true)

	# HUD 顶部加 coop 角色状态栏
	_build_coop_hud()

	var eid: String = str(GameState.get_meta("pending_enemy_id", "yuan_gui"))
	_coop_sm.start_coop_battle(eid)

func _build_coop_hud() -> void:
	var hud: Node = get_node_or_null("UI/HUD")
	if not hud: return

	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "CoopHUD"
	bar.add_theme_constant_override("separation", 20)
	bar.anchor_left = 0.0; bar.anchor_top = 0.0
	bar.anchor_right = 1.0; bar.anchor_bottom = 0.0
	bar.offset_top = 0.0; bar.offset_bottom = 44.0
	bar.layout_mode = 1
	hud.add_child(bar)

	# P1 阮如月
	var p1_lbl: Label = Label.new()
	p1_lbl.name = "P1HP"
	p1_lbl.text = "P1 阮如月  ❤ 80/80"
	p1_lbl.add_theme_font_size_override("font_size", 13)
	p1_lbl.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	p1_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(p1_lbl)

	# 敌方 HP（中间）
	var enemy_mid: Label = Label.new()
	enemy_mid.name = "EnemyHPMid"
	enemy_mid.text = "敌人 ❤ ?"
	enemy_mid.add_theme_font_size_override("font_size", 13)
	enemy_mid.add_theme_color_override("font_color", UIConstants.color_of("nu"))
	enemy_mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(enemy_mid)

	# P2 沈铁钧
	var p2_lbl: Label = Label.new()
	p2_lbl.name = "P2HP"
	p2_lbl.text = "P2 沈铁钧  ❤ 100/100"
	p2_lbl.add_theme_font_size_override("font_size", 13)
	p2_lbl.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	p2_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p2_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(p2_lbl)

func _on_coop_battle_started() -> void:
	turn_label.text = "⚔ 双魂协作 ·  第1回合"
	SoundManager.play_battle_bgm(GameState.current_layer, false)
	_update_coop_hud()

func _on_coop_turn_changed(character: String) -> void:
	match character:
		"ruan": turn_label.text = "🌸 阮如月的回合"
		"shen": turn_label.text = "⛓ 沈铁钧的回合"
		"enemy": turn_label.text = "💀 敌人行动"
	end_turn_btn.disabled = (character == "enemy")
	_update_coop_hud()

func _update_coop_hud() -> void:
	if not _coop_sm: return
	var p1: Label = get_node_or_null("UI/HUD/CoopHUD/P1HP")
	if p1: p1.text = "P1 阮如月  ❤ %d/%d  🛡 %d" % [
		_coop_sm.ruan_hp, _coop_sm.ruan_max_hp, _coop_sm.ruan_shield]
	var p2: Label = get_node_or_null("UI/HUD/CoopHUD/P2HP")
	if p2: p2.text = "P2 沈铁钧  ❤ %d/%d  🛡 %d" % [
		_coop_sm.shen_hp, _coop_sm.shen_max_hp, _coop_sm.shen_shield]
	var em: Label = get_node_or_null("UI/HUD/CoopHUD/EnemyHPMid")
	if em: em.text = "敌人 ❤ %d/%d" % [_coop_sm.enemy_hp, _coop_sm.enemy_max_hp]

func _on_coop_battle_ended(result: String) -> void:
	if result == "victory":
		_show_float_text("⚔ 双魂胜利！", get_viewport().get_visible_rect().size / 2.0,
			UIConstants.color_of("gold"), 24)
		await get_tree().create_timer(1.5).timeout
		TransitionManager.change_scene("res://scenes/CardRewardScene.tscn")
	else:
		GameState.trigger_ending("defeat")

func _on_coop_resonance(bonus_type: String) -> void:
	var labels: Dictionary = {
		"chain_boost":  "⛓ 锁链共鸣！",
		"mark_boost":   "🌸 印记共鸣！",
		"five_harmony": "☯ 五情大共鸣！",
	}
	_show_float_text(
		labels.get(bonus_type, "✦ 协作共鸣！"),
		Vector2(get_viewport().get_visible_rect().size.x * 0.5, 180.0),
		Color(0.90, 0.75, 0.20), 20
	)

## 屏幕边缘闪烁（受伤感/危机感）
func _flash_screen_edge(color: Color) -> void:
	var ui: Node = get_node_or_null("UI")
	if not ui: return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# 四条边框
	for side in 4:
		var bar: ColorRect = ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.z_index = 180
		match side:
			0: bar.size = Vector2(vp.x, 10); bar.position = Vector2(0, 0)
			1: bar.size = Vector2(vp.x, 10); bar.position = Vector2(0, vp.y - 10)
			2: bar.size = Vector2(10, vp.y); bar.position = Vector2(0, 0)
			3: bar.size = Vector2(10, vp.y); bar.position = Vector2(vp.x - 10, 0)
		bar.color = color
		bar.modulate.a = 0.0
		ui.add_child(bar)
		var tw: Tween = bar.create_tween()
		tw.tween_property(bar, "modulate:a", 1.0, 0.07)
		tw.tween_property(bar, "modulate:a", 0.0, 0.38)
		tw.tween_callback(bar.queue_free)

# ════════════════════════════════════════════════════════
#  Boss 专属持续粒子特效
# ════════════════════════════════════════════════════════

var _boss_effect_node: Node = null

func _start_boss_effect(boss_id: String) -> void:
	_stop_boss_effect()
	var enemy_area: Node = get_node_or_null("UI/AltarLayout/EnemyArea")
	if not enemy_area: return

	match boss_id:
		"shuigui_wanggui": _start_wave_effect(enemy_area)
		"hanba_jiaoge":    _start_dust_effect(enemy_area)
		"guixiniang_sujin":_start_petal_effect(enemy_area)

func _stop_boss_effect() -> void:
	if _boss_effect_node and is_instance_valid(_boss_effect_node):
		_boss_effect_node.queue_free()
		_boss_effect_node = null

## 水鬼王：蓝色水波涟漪
func _start_wave_effect(parent: Node) -> void:
	var host: Node2D = Node2D.new()
	host.name = "WaveEffect"
	parent.add_child(host)
	_boss_effect_node = host

	var _t: SceneTreeTimer = get_tree().create_timer(0.0)
	# 每 0.6s 生成一圈水波
	var repeat: Callable = func():
		pass
	var timer: Timer = Timer.new()
	timer.wait_time = 0.55
	timer.autostart = true
	timer.timeout.connect(func():
		if not is_instance_valid(host): return
		var cx: float = parent.size.x * 0.5
		var cy: float = parent.size.y * 0.55
		for ring in 3:
			var ring_node: Control = Control.new()
			ring_node.position = Vector2(cx, cy)
			ring_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(ring_node)
			var delay_t: float = float(ring) * 0.15
			var ring_tween: Tween = ring_node.create_tween()
			ring_tween.tween_interval(delay_t)
			ring_tween.tween_method(func(r: float):
				if not is_instance_valid(ring_node): return
				ring_node.queue_redraw()
				ring_node.set_meta("_r", r)
				ring_node.set_meta("_a", 0.45 * (1.0 - r / 55.0))
			, 0.0, 55.0, 0.55)
			ring_tween.tween_callback(ring_node.queue_free)
			# 用 draw 方式只能在 CanvasItem — 改用 ColorRect 环形近似（多圆弧）
			# 简化：用 4 个 ColorRect 旋转模拟椭圆波
			for seg in 8:
				var dot2: ColorRect = ColorRect.new()
				dot2.size = Vector2(4, 4)
				dot2.color = Color(0.25, 0.55, 0.90, 0.0)
				dot2.mouse_filter = Control.MOUSE_FILTER_IGNORE
				parent.add_child(dot2)
				var angle2: float = TAU * float(seg) / 8.0
				var init_x: float = cx + cos(angle2) * 8.0
				var init_y: float = cy + sin(angle2) * 4.0
				dot2.position = Vector2(init_x, init_y)
				var dtw2: Tween = dot2.create_tween()
				dtw2.tween_interval(delay_t)
				dtw2.tween_property(dot2, "position",
					Vector2(cx + cos(angle2) * 52.0, cy + sin(angle2) * 26.0), 0.55)\
					.set_ease(Tween.EASE_OUT)
				dtw2.parallel().tween_property(dot2, "color:a", 0.5, 0.15)
				dtw2.parallel().tween_property(dot2, "color:a", 0.0, 0.40).set_delay(0.15)
				dtw2.tween_callback(dot2.queue_free)
	)
	host.add_child(timer)

## 旱魃：橙红沙尘粒子上升
func _start_dust_effect(parent: Node) -> void:
	var host2: Node = Node.new()
	host2.name = "DustEffect"
	parent.add_child(host2)
	_boss_effect_node = host2

	var timer2: Timer = Timer.new()
	timer2.wait_time = 0.12
	timer2.autostart = true
	timer2.timeout.connect(func():
		if not is_instance_valid(host2): return
		var dot3: ColorRect = ColorRect.new()
		var sz: float = randf_range(2.0, 5.0)
		dot3.size = Vector2(sz, sz)
		dot3.color = Color(
			randf_range(0.75, 0.95),
			randf_range(0.35, 0.55),
			randf_range(0.05, 0.18),
			randf_range(0.5, 0.8))
		dot3.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var start_x: float = randf_range(20.0, parent.size.x - 20.0)
		dot3.position = Vector2(start_x, parent.size.y * 0.8)
		parent.add_child(dot3)
		var dtw3: Tween = dot3.create_tween()
		var drift: float = randf_range(-20.0, 20.0)
		dtw3.tween_property(dot3, "position",
			Vector2(start_x + drift, parent.size.y * 0.2), randf_range(0.6, 1.2))\
			.set_trans(Tween.TRANS_SINE)
		dtw3.parallel().tween_property(dot3, "color:a", 0.0, 0.5).set_delay(0.4)
		dtw3.tween_callback(dot3.queue_free)
	)
	host2.add_child(timer2)

## 鬼新娘：紫红花瓣飘落 + 红绳缠绕效果
func _start_petal_effect(parent: Node) -> void:
	var host3: Node = Node.new()
	host3.name = "PetalEffect"
	parent.add_child(host3)
	_boss_effect_node = host3

	var timer3: Timer = Timer.new()
	timer3.wait_time = 0.20
	timer3.autostart = true
	timer3.timeout.connect(func():
		if not is_instance_valid(host3): return
		# 花瓣
		var petal: ColorRect = ColorRect.new()
		petal.size = Vector2(randf_range(4.0, 8.0), randf_range(3.0, 6.0))
		petal.rotation = randf_range(0.0, TAU)
		petal.color = Color(
			randf_range(0.70, 0.85),
			randf_range(0.10, 0.30),
			randf_range(0.25, 0.50),
			randf_range(0.6, 0.9))
		petal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var px: float = randf_range(10.0, parent.size.x - 10.0)
		petal.position = Vector2(px, -8.0)
		parent.add_child(petal)
		var ptw: Tween = petal.create_tween()
		var sway: float = randf_range(-30.0, 30.0)
		ptw.tween_property(petal, "position",
			Vector2(px + sway, parent.size.y + 10.0), randf_range(1.0, 2.0))\
			.set_trans(Tween.TRANS_SINE)
		ptw.parallel().tween_property(petal, "rotation",
			petal.rotation + randf_range(-TAU, TAU), randf_range(1.0, 2.0))
		ptw.parallel().tween_property(petal, "color:a", 0.0, 0.5).set_delay(0.8)
		ptw.tween_callback(petal.queue_free)

		# 偶尔出现红绳闪烁
		if randf() > 0.7:
			var rope: ColorRect = ColorRect.new()
			rope.size = Vector2(1.5, randf_range(20.0, 50.0))
			rope.color = Color(0.72, 0.08, 0.12, 0.0)
			rope.position = Vector2(randf_range(0.0, parent.size.x), randf_range(10.0, parent.size.y - 60.0))
			rope.rotation = randf_range(-0.3, 0.3)
			rope.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(rope)
			var rtw2: Tween = rope.create_tween()
			rtw2.tween_property(rope, "color:a", 0.6, 0.10)
			rtw2.tween_property(rope, "color:a", 0.0, 0.35)
			rtw2.tween_callback(rope.queue_free)
	)
	host3.add_child(timer3)
