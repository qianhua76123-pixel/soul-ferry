extends Node2D

## MapScene.gd - 路线地图
## 设计：每层 N 个普通节点 + 1 个 Boss 节点
## 玩家在当前层依次完成节点，全部完成后解锁下一层
## 第一个节点固定为战斗；每层保证至少 1 事件、1 商店

@onready var node_container: VBoxContainer = $UI/NodeContainer
@onready var layer_label:    Label         = $UI/LayerLabel
@onready var title_label:    Label         = $UI/TopBar/Title
@onready var hp_label:       Label         = $UI/TopBar/HPLabel
@onready var gold_label:     Label         = $UI/TopBar/GoldLabel
@onready var relic_bar:      HBoxContainer = $UI/RelicBar

const DeckViewerPanelClass = preload("res://scripts/ui/DeckViewerPanel.gd")
var _deck_viewer: Control = null

# ── 每层普通节点数量（不含 Boss）
const LAYER_NODE_COUNTS: Array = [6, 6, 5]   # 每层普通节点数（不含 Boss 和 Boss前休整）

const LAYER_BOSSES: Dictionary = {
	1: "shuigui_wanggui",
	2: "hanba_jiaoge",
	3: "guixiniang_sujin",
}
const LAYER_NAMES: Dictionary = {
	1: "第一层：荒村（悲·惧）",
	2: "第二层：古祠（怒·定）",
	3: "第三层：幽冥渡口（喜·定）",
}
const SCENE_PATHS: Dictionary = {
	"battle": "res://scenes/BattleScene.tscn",
	"elite":  "res://scenes/BattleScene.tscn",
	"event":  "res://scenes/EventScene.tscn",
	"shop":   "res://scenes/ShopScene.tscn",
	"boss":   "res://scenes/BattleScene.tscn",
}
const NODE_ICONS: Dictionary = {
	"battle": "⚔", "event": "📜", "shop": "🏮",
	"rest": "🕯", "boss": "☠", "elite": "💀", "pre_boss_rest": "⛩",
}
const NODE_CN: Dictionary = {
	"battle": "战斗", "event": "事件", "shop": "商店",
	"rest": "休息", "boss": "Boss", "elite": "精英", "pre_boss_rest": "休整",
}
const LAYER_BG_COLORS: Dictionary = {
	1: Color("#0a1008"),
	2: Color("#120a08"),
	3: Color("#08080f"),
}

# 地图数据持久化
var _map_data: Array = []

# ══════════════════════════════════════════════════════
#  初始化
# ══════════════════════════════════════════════════════

func _ready() -> void:
	TransitionManager.fade_in_only()
	if GameState.hp <= 0 or DeckManager.get_total_card_count() == 0:
		GameState.new_run()
		DeckManager.init_starter_deck()

	GameState.hp_changed.connect(func(_o: int, _n: int): _update_status())
	GameState.gold_changed.connect(func(_o: int, _n: int): _update_status())
	GameState.relic_added.connect(func(_id: String): _render_relics())
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)

	if GameState.has_meta("map_data"):
		_map_data = GameState.get_meta("map_data")
	else:
		_generate_map()
		GameState.set_meta("map_data", _map_data)

	_update_status()
	_render_map()
	_render_relics()
	_apply_ui_theme()

	if not GameState.check_victory_condition():
		_check_layer_done()

	# 初始化卡组查看器：挂到高层 CanvasLayer，始终最前
	_deck_viewer = DeckViewerPanelClass.new()
	_deck_viewer.name = "DeckViewer"
	var deck_layer: CanvasLayer = CanvasLayer.new()
	deck_layer.name  = "DeckViewerLayer"
	deck_layer.layer = 90
	add_child(deck_layer)
	deck_layer.add_child(_deck_viewer)
	var ui_layer: Node = get_node_or_null("UI")
	if ui_layer:
		_deck_viewer.install_fixed_btn(ui_layer, false)

# ══════════════════════════════════════════════════════
#  地图生成
# ══════════════════════════════════════════════════════

func _generate_map() -> void:
	_map_data = []
	for layer_idx: int in 3:
		var layer_num: int = layer_idx + 1
		var nodes: Array = _generate_layer_nodes(layer_num)
		_map_data.append(nodes)

func _generate_layer_nodes(layer_num: int) -> Array:
	var count: int = LAYER_NODE_COUNTS[layer_num - 1]
	var nodes: Array = []

	# ── 规则分配 ──────────────────────────────────────────
	# 结构：[battle(固定)] + [随机中段] + [pre_boss_rest(固定)] + [boss(固定)]
	# 保证出现：event × 1，shop × 1，elite × 1-2
	# 剩余槽位随机填充（battle/event）
	var fixed_start: Array = ["battle"]              # 位置0固定战斗
	var must_have: Array   = ["event", "shop", "elite"]  # 每层保证出现

	# 50% 概率第二个精英
	if randi() % 2 == 0:
		must_have.append("elite")

	var remaining_count: int = count - fixed_start.size() - must_have.size()
	remaining_count = maxi(0, remaining_count)

	# 剩余槽位随机填充
	var fill_pool: Array = []
	for _i: int in remaining_count:
		fill_pool.append(_roll_type())

	# 中段 = must_have + fill_pool 随机打乱
	var middle: Array = must_have + fill_pool
	middle.shuffle()

	# 最终普通节点序列（不含 pre_boss_rest 和 boss）
	var type_seq: Array = fixed_start + middle

	for i: int in type_seq.size():
		var enemy_id: String = ""
		var is_elite: bool = type_seq[i] == "elite"
		if type_seq[i] in ["battle", "elite"]:
			enemy_id = _random_enemy_for_layer(layer_num)
		nodes.append({
			"id":       "n_%d_%d" % [layer_num, i],
			"type":     type_seq[i],
			"layer":    layer_num,
			"visited":  false,
			"enemy_id": enemy_id,
			"index":    i,
			"is_elite": is_elite,
		})

	# ── Boss 前休整节点（固定倒数第二）──
	nodes.append({
		"id":       "pre_boss_%d" % layer_num,
		"type":     "pre_boss_rest",
		"layer":    layer_num,
		"visited":  false,
		"enemy_id": "",
		"index":    type_seq.size(),
		"is_elite": false,
	})

	# ── Boss 节点（固定最后）──
	nodes.append({
		"id":       "boss_%d" % layer_num,
		"type":     "boss",
		"layer":    layer_num,
		"visited":  false,
		"enemy_id": LAYER_BOSSES[layer_num],
		"index":    type_seq.size() + 1,
		"is_elite": false,
	})
	return nodes

func _roll_type() -> String:
	## 填充槽位权重：战斗55 事件25 商店15 休息5（精英由 must_have 保证）
	var weights: Dictionary = {"battle": 55, "event": 25, "shop": 15, "rest": 5}
	var total: int = 0
	for w: int in weights.values():
		total += w
	var roll: int = randi() % total
	var cum: int = 0
	for t: String in weights:
		cum += weights[t]
		if roll < cum:
			return t
	return "battle"

# ══════════════════════════════════════════════════════
#  渲染地图
# ══════════════════════════════════════════════════════

func _render_map() -> void:
	layer_label.text = LAYER_NAMES.get(GameState.current_layer, "???")
	var bg: ColorRect = get_node_or_null("Background") as ColorRect
	if bg:
		bg.color = LAYER_BG_COLORS.get(GameState.current_layer, UIConstants.color_of("ink"))

	for child: Node in node_container.get_children():
		child.queue_free()

	# 只渲染当前层
	var cur_layer: int = GameState.current_layer
	var layer_idx: int = cur_layer - 1
	if layer_idx < 0 or layer_idx >= len(_map_data):
		return

	var layer_nodes: Array = _map_data[layer_idx]

	# ── 顶部：层名 + 进度信息 ──
	var progress_lbl := Label.new()
	var visited_count: int = 0
	for nd: Dictionary in layer_nodes:
		if nd.get("visited", false):
			visited_count += 1
	progress_lbl.text = "进度  %d / %d" % [visited_count, len(layer_nodes)]
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_lbl.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
	progress_lbl.add_theme_color_override("font_color", UIConstants.color_of("ash"))
	node_container.add_child(progress_lbl)

	# 分割线
	var div_top := WaterInkDivider.new()
	div_top.custom_minimum_size = Vector2(600, 6)
	div_top.ink_color = UIConstants.color_of("gold_dim")
	node_container.add_child(div_top)

	# ── 计算当前应该解锁到哪个节点 ──
	# 规则：节点按 index 顺序解锁，前一个 visited 才可点下一个
	# Boss 节点在所有普通节点全部完成后才解锁
	var next_idx: int = _get_next_unlocked_index(layer_nodes)

	# ── 节点按行排列（每行最多 3 个，横向居中）──
	var row_size: int = 3
	var i: int = 0
	while i < len(layer_nodes):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		row.custom_minimum_size = Vector2(0, 110)

		var row_end: int = mini(i + row_size, len(layer_nodes))
		for j: int in range(i, row_end):
			var nd: Dictionary = layer_nodes[j]
			var is_unlocked: bool = (j == next_idx)
			row.add_child(_make_node_btn(nd, is_unlocked))

		node_container.add_child(row)

		# 行间连接箭头（非最后一行）
		if row_end < len(layer_nodes):
			var arrow_lbl := Label.new()
			arrow_lbl.text = "▼"
			arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arrow_lbl.add_theme_font_size_override("font_size", 14)
			arrow_lbl.add_theme_color_override("font_color",
				UIConstants.color_of("gold") if next_idx >= row_end else UIConstants.color_of("ash"))
			node_container.add_child(arrow_lbl)

		i = row_end

	# 底部分割线
	var div_bot := WaterInkDivider.new()
	div_bot.custom_minimum_size = Vector2(600, 6)
	div_bot.ink_color = UIConstants.color_of("gold_dim")
	node_container.add_child(div_bot)

	# 提示文字（当所有节点完成时）
	if next_idx == -1:
		var done_lbl := Label.new()
		done_lbl.text = "✦ 本层已完成，前往下一层 ✦"
		done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done_lbl.add_theme_color_override("font_color", UIConstants.color_of("gold"))
		done_lbl.add_theme_font_size_override("font_size", UIConstants.font_size_of("body"))
		node_container.add_child(done_lbl)

func _get_next_unlocked_index(layer_nodes: Array) -> int:
	## 返回下一个可点击的节点 index；全部完成返回 -1
	for i: int in len(layer_nodes):
		if not layer_nodes[i].get("visited", false):
			return i
	return -1

# ══════════════════════════════════════════════════════
#  节点按钮
# ══════════════════════════════════════════════════════

func _make_node_btn(nd: Dictionary, is_unlocked: bool) -> Control:
	var ntype:   String = nd.get("type", "battle")
	var visited: bool   = nd.get("visited", false)

	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(110, 110)
	container.add_theme_constant_override("separation", 4)

	# ── 主按钮 ──
	var btn := Button.new()
	btn.text = NODE_ICONS.get(ntype, "◈")
	btn.custom_minimum_size = Vector2(80, 80)
	btn.add_theme_font_size_override("font_size", 32)

	# 颜色方案
	var COLOR_MAP: Dictionary = {
		"battle": [Color(0.22, 0.07, 0.07, 0.92), Color(0.75, 0.20, 0.15)],
		"boss":   [Color(0.28, 0.04, 0.04, 0.95), Color(1.00, 0.25, 0.10)],
		"elite":  [Color(0.22, 0.05, 0.22, 0.95), Color(0.85, 0.20, 0.85)],
		"event":  [Color(0.08, 0.14, 0.08, 0.92), Color(0.35, 0.70, 0.25)],
		"shop":   [Color(0.14, 0.11, 0.03, 0.92), Color(0.90, 0.72, 0.10)],
		"rest":         [Color(0.05, 0.11, 0.18, 0.92), Color(0.20, 0.55, 0.80)],
		"pre_boss_rest":[Color(0.05, 0.14, 0.10, 0.95), Color(0.30, 0.80, 0.55)],
	}
	var nc: Array = COLOR_MAP.get(ntype, [Color(0.12, 0.12, 0.12), Color(0.5, 0.5, 0.5)])

	var normal_style := StyleBoxFlat.new()
	normal_style.set_corner_radius_all(6)
	normal_style.set_border_width_all(2)

	if visited:
		normal_style.bg_color     = Color(0.10, 0.09, 0.08, 0.7)
		normal_style.border_color = Color(0.28, 0.24, 0.20, 0.5)
		btn.add_theme_color_override("font_color", Color(0.35, 0.30, 0.25))
	elif is_unlocked:
		normal_style.bg_color     = nc[0]
		normal_style.border_color = nc[1]
		btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82))
		# 节点专属动画
		_start_node_idle_animation(btn, ntype)
	else:
		# 未解锁：暗色 + 低透明
		normal_style.bg_color     = Color(nc[0].r * 0.35, nc[0].g * 0.35, nc[0].b * 0.35, 0.55)
		normal_style.border_color = Color(nc[1].r * 0.30, nc[1].g * 0.30, nc[1].b * 0.30, 0.50)
		btn.add_theme_color_override("font_color", Color(0.40, 0.36, 0.30, 0.6))

	btn.add_theme_stylebox_override("normal", normal_style)

	# Hover（仅解锁节点）
	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.border_color = UIConstants.color_of("gold")
	hover_style.bg_color     = Color(nc[0].r + 0.06, nc[0].g + 0.04, nc[0].b + 0.02, 0.95).clamp()
	btn.add_theme_stylebox_override("hover", hover_style)

	# Pressed
	var pressed_style: StyleBoxFlat = normal_style.duplicate()
	pressed_style.bg_color = nc[1].darkened(0.3)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Disabled
	var disabled_style: StyleBoxFlat = normal_style.duplicate()
	disabled_style.bg_color     = Color(0.10, 0.09, 0.08, 0.5)
	disabled_style.border_color = Color(0.25, 0.22, 0.18, 0.4)
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.disabled = not is_unlocked or visited

	# 点击逻辑
	if is_unlocked and not visited:
		var cap: Dictionary = nd
		# 悬停提示
		btn.mouse_entered.connect(func(): _show_node_tip(cap, btn.global_position))
		btn.mouse_exited.connect(func(): _hide_node_tip())
		btn.pressed.connect(func():
			_hide_node_tip()
			var tw2: Tween = btn.create_tween()
			tw2.tween_property(btn, "scale", Vector2(0.88, 0.88), 0.07)
			tw2.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10)
			tw2.tween_callback(func(): _on_node_pressed(cap))
		)

	container.add_child(btn)

	# ── 节点名标签 ──
	var name_lbl := Label.new()
	name_lbl.text = NODE_CN.get(ntype, "???")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", UIConstants.font_size_of("caption"))
	if visited:
		name_lbl.add_theme_color_override("font_color", UIConstants.color_of("text_dim"))
		name_lbl.text = "✓ " + name_lbl.text
	elif is_unlocked:
		name_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.7, 0.4) if ntype == "boss" else UIConstants.color_of("gold"))
	else:
		name_lbl.add_theme_color_override("font_color", UIConstants.color_of("ash"))
		name_lbl.modulate.a = 0.5

	container.add_child(name_lbl)
	return container

# ══════════════════════════════════════════════════════
#  节点点击处理
# ══════════════════════════════════════════════════════

func _on_node_pressed(nd: Dictionary) -> void:
	nd["visited"] = true
	GameState.set_meta("map_data", _map_data)
	GameState.advance_node(nd["id"])
	GameState.save_to_file()

	var ntype: String = nd.get("type", "battle")

	# 普通休息节点：直接在地图内结算，不跳场景
	if ntype == "rest":
		var healed: int = int(GameState.max_hp * 0.30)
		GameState.heal(healed)
		_show_rest_popup(healed)
		_check_layer_done()
		_render_map()
		_update_status()
		return

	# Boss 前休整节点：弹出面板，可选择升级牌 or 回复 HP
	if ntype == "pre_boss_rest":
		_show_pre_boss_rest_panel()
		return

	# 战斗 / Boss / 精英：设置 pending enemy
	if ntype in ["battle", "boss", "elite"]:
		var eid: String = nd.get("enemy_id", "")
		if eid.is_empty():
			eid = _random_enemy_for_layer(GameState.current_layer)
		GameState.set_meta("pending_enemy_id", eid)
		GameState.set_meta("is_elite_battle", ntype == "elite")

	# 事件：设置 pending event
	if ntype == "event":
		var eid2: String = nd.get("event_id", "")
		if not eid2.is_empty():
			GameState.set_meta("pending_event_id", eid2)

	var path: String = SCENE_PATHS.get(ntype, "")
	if not path.is_empty():
		TransitionManager.change_scene(path, _get_scene_title(ntype))

func _show_rest_popup(healed: int) -> void:
	## 简单弹出提示
	var lbl := Label.new()
	lbl.text = "🕯 休息  ♥ +%d" % healed
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", UIConstants.font_size_of("heading"))
	lbl.add_theme_color_override("font_color", UIConstants.color_of("heal_flash"))
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.z_index = 100
	get_tree().root.add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 0.0, 1.8).set_delay(1.0)
	tw.tween_callback(lbl.queue_free)

# ── Boss 前休整面板 ───────────────────────────────────

var _pre_boss_overlay: ColorRect = null
var _pre_boss_panel: Panel = null
var _pre_boss_upgrade_mode: bool = false
var _pre_boss_used: bool = false   # 每次只能选一项

func _show_pre_boss_rest_panel() -> void:
	var root: Node = get_tree().root
	if _pre_boss_overlay and is_instance_valid(_pre_boss_overlay):
		return

	# 遮罩
	_pre_boss_overlay = ColorRect.new()
	_pre_boss_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pre_boss_overlay.color = Color(0, 0, 0, 0.72)
	_pre_boss_overlay.z_index = 200
	root.add_child(_pre_boss_overlay)

	# 主面板
	_pre_boss_panel = Panel.new()
	_pre_boss_panel.z_index = 201
	_pre_boss_panel.custom_minimum_size = Vector2(540, 380)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_pre_boss_panel.position = Vector2((vp.x - 540) * 0.5, (vp.y - 380) * 0.5)
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.08, 0.06, 0.98)
	ps.border_color = Color(0.30, 0.75, 0.50, 0.9)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(8)
	_pre_boss_panel.add_theme_stylebox_override("panel", ps)
	root.add_child(_pre_boss_panel)

	_pre_boss_used = false
	_build_pre_boss_main_view()

func _build_pre_boss_main_view() -> void:
	# 清空面板旧内容
	for c in _pre_boss_panel.get_children():
		c.queue_free()

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0; vbox.offset_right = -20.0
	vbox.offset_top = 18.0; vbox.offset_bottom = -18.0
	vbox.add_theme_constant_override("separation", 14)
	_pre_boss_panel.add_child(vbox)

	# 标题
	var title: Label = Label.new()
	title.text = "⛩  Boss 前休整"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.30, 0.88, 0.58))
	vbox.add_child(title)

	# 副标题
	var sub: Label = Label.new()
	sub.text = "选择一项：升级一张牌卡  或  回复 HP"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.70, 0.85, 0.75))
	vbox.add_child(sub)

	# 当前 HP 信息
	var hp_lbl: Label = Label.new()
	hp_lbl.text = "当前 HP：%d / %d" % [int(GameState.hp), int(GameState.max_hp)]
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 12)
	hp_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))
	vbox.add_child(hp_lbl)

	# 两个选项按钮
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	# 选项1：升级牌
	var upgrade_btn: Button = Button.new()
	upgrade_btn.text = "✦ 升级一张牌"
	upgrade_btn.custom_minimum_size = Vector2(200, 48)
	upgrade_btn.add_theme_font_size_override("font_size", 14)
	_style_pre_boss_btn(upgrade_btn, Color(0.85, 0.72, 0.20))
	upgrade_btn.pressed.connect(_show_pre_boss_upgrade_view)
	btn_row.add_child(upgrade_btn)

	# 选项2：回血（全满）
	var heal_amount: int = int(GameState.max_hp * 0.50)
	var heal_btn: Button = Button.new()
	heal_btn.text = "♥ 回复 %d HP\n（50%% 最大HP）" % heal_amount
	heal_btn.custom_minimum_size = Vector2(200, 48)
	heal_btn.add_theme_font_size_override("font_size", 14)
	_style_pre_boss_btn(heal_btn, Color(0.85, 0.35, 0.35))
	heal_btn.disabled = GameState.hp >= GameState.max_hp
	heal_btn.pressed.connect(func():
		GameState.heal(heal_amount)
		_pre_boss_used = true
		heal_btn.text = "♥ 已回复 %d HP" % heal_amount
		heal_btn.disabled = true
		upgrade_btn.disabled = true
		# 更新 HP 显示
		hp_lbl.text = "当前 HP：%d / %d" % [int(GameState.hp), int(GameState.max_hp)]
	)
	btn_row.add_child(heal_btn)

	# 分隔线
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# 牌组预览（小尺寸，只显示名字）
	var deck_title: Label = Label.new()
	deck_title.text = "当前牌组（%d张）" % DeckManager.get_total_card_count()
	deck_title.add_theme_font_size_override("font_size", 11)
	deck_title.add_theme_color_override("font_color", Color(0.6, 0.8, 0.65))
	vbox.add_child(deck_title)

	var deck_scroll: ScrollContainer = ScrollContainer.new()
	deck_scroll.custom_minimum_size = Vector2(0, 80)
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(deck_scroll)

	var deck_flow: HFlowContainer = HFlowContainer.new()
	deck_flow.add_theme_constant_override("separation", 4)
	deck_scroll.add_child(deck_flow)

	for card in DeckManager.get_full_deck():
		var pill: Label = Label.new()
		pill.text = card.get("name", "???")
		pill.add_theme_font_size_override("font_size", 10)
		var upgraded: bool = card.get("upgraded", false)
		pill.add_theme_color_override("font_color",
			Color(0.95, 0.82, 0.25) if upgraded else Color(0.72, 0.78, 0.72))
		deck_flow.add_child(pill)

	# 关闭按钮
	var close_btn: Button = Button.new()
	close_btn.text = "离开（不选）"
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	close_btn.pressed.connect(_close_pre_boss_panel)
	var close_row: HBoxContainer = HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.add_child(close_btn)
	vbox.add_child(close_row)

func _show_pre_boss_upgrade_view() -> void:
	## 展示牌组，点击升级
	for c in _pre_boss_panel.get_children():
		c.queue_free()

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0; vbox.offset_right = -16.0
	vbox.offset_top = 14.0; vbox.offset_bottom = -14.0
	vbox.add_theme_constant_override("separation", 10)
	_pre_boss_panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "✦ 选择一张牌升级"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	vbox.add_child(title)

	# 牌组滚动列表
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	var card_scene: PackedScene = preload("res://scenes/CardUI.tscn")
	for card in DeckManager.get_full_deck():
		var can_up: bool = CardDatabase.can_upgrade(card)
		var card_ui: CardUINode = card_scene.instantiate() as CardUINode
		card_ui.setup(card)
		card_ui.set_playable(can_up)
		card_ui.custom_minimum_size = Vector2(110, 160)
		card_ui.modulate.a = 1.0 if can_up else 0.4
		if can_up:
			var captured: Dictionary = card
			card_ui.card_clicked.connect(func(_c):
				CardDatabase.upgrade_card(captured)
				_pre_boss_used = true
				_close_pre_boss_panel()
			)
		grid.add_child(card_ui)

	# 返回按钮
	var back_btn: Button = Button.new()
	back_btn.text = "← 返回"
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.pressed.connect(_build_pre_boss_main_view)
	var back_row: HBoxContainer = HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.add_child(back_btn)
	vbox.add_child(back_row)

func _close_pre_boss_panel() -> void:
	if _pre_boss_overlay and is_instance_valid(_pre_boss_overlay):
		_pre_boss_overlay.queue_free()
		_pre_boss_overlay = null
	if _pre_boss_panel and is_instance_valid(_pre_boss_panel):
		_pre_boss_panel.queue_free()
		_pre_boss_panel = null
	_check_layer_done()
	_render_map()
	_update_status()

func _style_pre_boss_btn(btn: Button, accent: Color) -> void:
	var sty: StyleBoxFlat = StyleBoxFlat.new()
	sty.bg_color = Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.95)
	sty.border_color = accent
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(5)
	var hover_sty: StyleBoxFlat = sty.duplicate()
	hover_sty.bg_color = Color(accent.r * 0.30, accent.g * 0.30, accent.b * 0.30, 0.95)
	btn.add_theme_stylebox_override("normal", sty)
	btn.add_theme_stylebox_override("hover", hover_sty)
	btn.add_theme_color_override("font_color", accent)

# ══════════════════════════════════════════════════════
#  层进度检测
# ══════════════════════════════════════════════════════

func _check_layer_done() -> void:
	var idx: int = GameState.current_layer - 1
	if idx < 0 or idx >= len(_map_data):
		return
	# 当前层所有节点全部访问完才推进
	for nd: Dictionary in _map_data[idx]:
		if not nd.get("visited", false):
			return
	GameState.advance_layer()
	GameState.set_meta("map_data", _map_data)
	if GameState.check_victory_condition():
		GameState.trigger_ending("success")
		return
	_render_map()

# ══════════════════════════════════════════════════════
#  敌人随机
# ══════════════════════════════════════════════════════

func _random_enemy_for_layer(layer: int) -> String:
	var file: FileAccess = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if not file: return "yuan_gui"
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return "yuan_gui"
	file.close()
	var pool: Array = json.get_data().get("enemies", []).filter(
		func(e: Dictionary) -> bool:
			return e.get("layer", 1) == layer and e.get("type", "") == "normal"
	)
	if pool.is_empty():
		pool = json.get_data().get("enemies", []).filter(
			func(e: Dictionary) -> bool: return e.get("type", "") == "normal"
		)
	if pool.is_empty(): return "yuan_gui"
	return pool[randi() % len(pool)].get("id", "yuan_gui")

# ══════════════════════════════════════════════════════
#  遗物 / 状态栏 / 主题
# ══════════════════════════════════════════════════════

## 遗物悬浮面板
var _relic_tip: Panel = null
var _relic_tip_lbl: RichTextLabel = null

func _ensure_relic_tip() -> void:
	if _relic_tip: return
	var ui: Node = get_node_or_null("UI")
	if not ui: return
	_relic_tip = Panel.new()
	_relic_tip.name = "RelicTip"
	_relic_tip.z_index = 200
	_relic_tip.visible = false
	_relic_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = Color(0.06,0.04,0.03,0.96)
	ps.border_width_top=1; ps.border_width_bottom=1
	ps.border_width_left=1; ps.border_width_right=1
	ps.border_color=Color(0.78,0.60,0.10,0.8)
	ps.set_corner_radius_all(5)
	ps.content_margin_left=10; ps.content_margin_right=10
	ps.content_margin_top=8; ps.content_margin_bottom=8
	_relic_tip.add_theme_stylebox_override("panel", ps)
	_relic_tip_lbl = RichTextLabel.new()
	_relic_tip_lbl.bbcode_enabled = true
	_relic_tip_lbl.fit_content = true
	_relic_tip_lbl.custom_minimum_size = Vector2(220, 0)
	_relic_tip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_tip_lbl.add_theme_font_size_override("normal_font_size", 12)
	_relic_tip.add_child(_relic_tip_lbl)
	ui.add_child(_relic_tip)

func _show_relic_tip(rid: String) -> void:
	_ensure_relic_tip()
	if not _relic_tip: return
	var data: Dictionary = RelicManager._all_relics_data.get(rid, {})
	var rname: String = data.get("name","???")
	var effect: String = data.get("effect","（无说明）")
	var gold: String = Color(0.78,0.60,0.10).to_html(false)
	var parch: String = Color(0.92,0.86,0.74).to_html(false)
	_relic_tip_lbl.text = "[color=#%s]【%s】[/color]\n[color=#%s]%s[/color]" % [gold, rname, parch, effect]
	var mp: Vector2 = get_viewport().get_mouse_position()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_relic_tip.position = Vector2(clampf(mp.x-110, 4, vp.x-244), clampf(mp.y-80, 4, vp.y-100))
	_relic_tip.visible = true

func _hide_relic_tip() -> void:
	if _relic_tip: _relic_tip.visible = false

func _render_relics() -> void:
	for child: Node in relic_bar.get_children():
		child.queue_free()
	var relic_icons: Dictionary = {
		"tong_jing_sui": "🪞", "wenlu_xiang": "🕯", "duhun_ce": "📖",
		"shaogu_pian": "🦴", "qingming_pai": "🪶", "wuqing_jie": "🎀",
		"nianhua_yan": "👁", "yin_yang_bi": "✒", "hun_bo_lu": "🔥",
		"si_xiang_pian": "🌾",
	}
	for rid: String in GameState.relics:
		var data: Dictionary = RelicManager._all_relics_data.get(rid, {})
		var relic_name: String = data.get("name", "???")
		var relic_effect: String = data.get("effect", "（无说明）")
		# 用 Button 代替 Label，使 mouse_filter 可接收 hover
		var btn: Button = Button.new()
		btn.text = relic_icons.get(rid, "◈") + " " + relic_name
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", UIConstants.color_of("gold_dim"))
		btn.add_theme_color_override("font_hover_color", UIConstants.color_of("gold"))
		# 自定义 tooltip：悬停显示完整说明
		var tooltip_text: String = "[%s]
%s" % [relic_name, relic_effect]
		btn.tooltip_text = tooltip_text
		relic_bar.add_child(btn)

func _update_status() -> void:
	hp_label.text   = "%s %d/%d" % [UIConstants.ICONS["hp"], GameState.hp, GameState.max_hp]
	gold_label.text = "%s %d" % [UIConstants.ICONS["coin"], GameState.gold]

func _apply_ui_theme() -> void:
	title_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("heading"))
	title_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	layer_label.add_theme_font_size_override("font_size", UIConstants.font_size_of("heading"))
	layer_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	hp_label.add_theme_color_override("font_color", UIConstants.color_of("text_secondary"))
	gold_label.add_theme_color_override("font_color", UIConstants.color_of("gold"))

func _get_scene_title(ntype: String) -> String:
	var layer: int = GameState.current_layer
	var layer_names: Dictionary = {1: "第一层·望乡", 2: "第二层·焦土", 3: "第三层·幽冥"}
	match ntype:
		"battle": return layer_names.get(layer, "战斗")
		"boss":   return "☠ Boss 战"
		"event":  return "奇遇"
		"shop":   return "幽冥集市"
		"rest":   return "古庙休息"
		_:        return ""

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			if _deck_viewer:
				_deck_viewer.toggle_popup()
			get_viewport().set_input_as_handled()

func _on_achievement_unlocked(achievement_id: String) -> void:
	_show_achievement_toast(achievement_id)

func _show_achievement_toast(achievement_id: String) -> void:
	var info: Dictionary = AchievementManager.get_achievement_info(achievement_id)
	var name_str: String = info.get("name", achievement_id)
	var root: Node = get_tree().root
	var toast: Panel = Panel.new()
	toast.z_index = 300
	toast.custom_minimum_size = Vector2(280, 60)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	toast.position = Vector2((vp.x - 280) * 0.5, vp.y - 80.0)
	var ts: StyleBoxFlat = StyleBoxFlat.new()
	ts.bg_color = Color(0.06, 0.10, 0.06, 0.95)
	ts.border_color = Color(0.35, 0.70, 0.30, 0.9)
	ts.set_border_width_all(2)
	ts.set_corner_radius_all(6)
	toast.add_theme_stylebox_override("panel", ts)
	root.add_child(toast)
	var lbl: Label = Label.new()
	lbl.text = "🏆 成就解锁：%s" % name_str
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 12.0; lbl.offset_right = -12.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 0.55))
	toast.add_child(lbl)
	var tw: Tween = toast.create_tween()
	tw.tween_property(toast, "modulate:a", 0.0, 0.6).set_delay(2.8)
	tw.tween_callback(toast.queue_free)

# ══════════════════════════════════════════════════════
#  节点悬停提示
# ══════════════════════════════════════════════════════

var _node_tip_panel: Control = null

func _show_node_tip(nd: Dictionary, btn_pos: Vector2) -> void:
	_hide_node_tip()
	var ntype: String = nd.get("type", "battle")
	var tip_lines: Dictionary = {
		"battle":       "⚔ 普通战斗\n消耗手牌击败亡魂\n胜利后获得选牌奖励",
		"elite":        "💀 精英战斗\n更强的亡魂，需要策略\n胜利后必得一枚遗物",
		"boss":         "☠ Boss 战\n层的终点，渡化或镇压\n将影响后续路线",
		"event":        "📜 奇遇\n随机遭遇，选择影响命运\n可获得金币、遗物或诅咒",
		"shop":         "🏮 幽冥集市\n消耗金币购买遗物和牌\n可移除一张牌（75金）",
		"rest":         "🕯 古庙休息\n恢复 30% 最大HP\n也可选择升级一张牌",
		"pre_boss_rest":"⛩ Boss 前休整\n升级一张牌 或 恢复 50% HP\n只能选一种",
	}
	var tip_text: String = tip_lines.get(ntype, ntype)

	var ui: Node = get_node_or_null("UI")
	if not ui: return

	_node_tip_panel = Panel.new()
	_node_tip_panel.name = "NodeTip"
	_node_tip_panel.z_index = 200
	_node_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts: StyleBoxFlat = StyleBoxFlat.new()
	ts.bg_color = Color(0.05, 0.04, 0.02, 0.94)
	ts.border_color = Color(0.65, 0.50, 0.12, 0.85)
	ts.set_border_width_all(1)
	ts.set_corner_radius_all(5)
	_node_tip_panel.add_theme_stylebox_override("panel", ts)
	ui.add_child(_node_tip_panel)

	var lbl: Label = Label.new()
	lbl.text = tip_text
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 10.0; lbl.offset_right = -10.0
	lbl.offset_top  = 8.0;  lbl.offset_bottom = -8.0
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", UIConstants.color_of("text_secondary"))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_node_tip_panel.add_child(lbl)

	# 位置：在按钮上方
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var panel_w: float = 180.0
	var panel_h: float = 80.0
	_node_tip_panel.custom_minimum_size = Vector2(panel_w, panel_h)
	var tx: float = clampf(btn_pos.x - panel_w * 0.5, 4.0, vp.x - panel_w - 4.0)
	var ty: float = btn_pos.y - panel_h - 12.0
	if ty < 4.0: ty = btn_pos.y + 44.0
	_node_tip_panel.position = Vector2(tx, ty)

	# 淡入
	_node_tip_panel.modulate.a = 0.0
	var tw: Tween = _node_tip_panel.create_tween()
	tw.tween_property(_node_tip_panel, "modulate:a", 1.0, 0.15)

func _hide_node_tip() -> void:
	if _node_tip_panel and is_instance_valid(_node_tip_panel):
		_node_tip_panel.queue_free()
		_node_tip_panel = null

# ══════════════════════════════════════════════════════
#  节点 Idle 动画
# ══════════════════════════════════════════════════════

func _start_node_idle_animation(btn: Button, ntype: String) -> void:
	match ntype:
		"boss":
			# 红色心跳脉冲 + 轻微缩放
			var tw: Tween = btn.create_tween().set_loops()
			tw.tween_property(btn, "modulate", Color(1.35, 0.60, 0.60), 0.65)\
				.set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(btn, "modulate", Color.WHITE, 0.65)\
				.set_ease(Tween.EASE_IN_OUT)
			var stw: Tween = btn.create_tween().set_loops()
			stw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.65)\
				.set_ease(Tween.EASE_IN_OUT)
			stw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.65)\
				.set_ease(Tween.EASE_IN_OUT)

		"elite":
			# 紫色冷光闪烁
			var tw2: Tween = btn.create_tween().set_loops()
			tw2.tween_property(btn, "modulate", Color(1.1, 0.85, 1.4), 1.1)\
				.set_ease(Tween.EASE_IN_OUT)
			tw2.tween_property(btn, "modulate", Color.WHITE, 1.1)\
				.set_ease(Tween.EASE_IN_OUT)

		"battle":
			# 微小浮动（上下 2px）
			var btw: Tween = btn.create_tween().set_loops()
			btw.tween_property(btn, "position:y", btn.position.y - 2.0, 1.4)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			btw.tween_property(btn, "position:y", btn.position.y + 1.0, 1.4)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		"event":
			# 金色微光跳动
			var etw: Tween = btn.create_tween().set_loops()
			etw.tween_property(btn, "modulate", Color(1.15, 1.10, 0.85), 1.8)\
				.set_ease(Tween.EASE_IN_OUT)
			etw.tween_property(btn, "modulate", Color.WHITE, 1.8)\
				.set_ease(Tween.EASE_IN_OUT)

		"shop":
			# 金黄缓慢呼吸
			var sptw: Tween = btn.create_tween().set_loops()
			sptw.tween_property(btn, "modulate", Color(1.2, 1.15, 0.75), 2.2)\
				.set_ease(Tween.EASE_IN_OUT)
			sptw.tween_property(btn, "modulate", Color.WHITE, 2.2)\
				.set_ease(Tween.EASE_IN_OUT)

		"rest", "pre_boss_rest":
			# 青绿柔和呼吸
			var rtw3: Tween = btn.create_tween().set_loops()
			rtw3.tween_property(btn, "modulate", Color(0.85, 1.15, 1.05), 2.5)\
				.set_ease(Tween.EASE_IN_OUT)
			rtw3.tween_property(btn, "modulate", Color.WHITE, 2.5)\
				.set_ease(Tween.EASE_IN_OUT)
