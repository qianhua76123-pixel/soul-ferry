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

# ── 每层普通节点数量（不含 Boss）
const LAYER_NODE_COUNTS: Array = [5, 5, 4]

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
	"event":  "res://scenes/EventScene.tscn",
	"shop":   "res://scenes/ShopScene.tscn",
	"boss":   "res://scenes/BattleScene.tscn",
}
const NODE_ICONS: Dictionary = {
	"battle": "⚔", "event": "📜", "shop": "🏮",
	"rest": "🕯", "boss": "☠",
}
const NODE_CN: Dictionary = {
	"battle": "战斗", "event": "事件", "shop": "商店",
	"rest": "休息", "boss": "Boss",
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

	# ── 规则分配：保证合理性 ──
	# 槽位 0 固定战斗
	# 至少 1 个事件（随机插入剩余位置）
	# 至少 1 个商店（随机插入剩余位置）
	# 剩余槽位随机填充（战斗权重最高，无休息——休息改为随机奖励）
	var fixed_types: Array = ["battle"]           # 位置0固定
	var must_have: Array   = ["event", "shop"]    # 保证出现
	var remaining_count: int = count - fixed_types.size() - must_have.size()

	# 剩余槽位用权重随机填充（战斗/事件/商店，无休息避免节奏太松）
	var fill_pool: Array = []
	for _i: int in remaining_count:
		fill_pool.append(_roll_type())

	# 合并 must_have + fill_pool，然后随机打乱（保证must_have不扎堆）
	var middle: Array = must_have + fill_pool
	middle.shuffle()

	# 最终节点类型序列：[battle, ...shuffle..., boss]
	var type_seq: Array = fixed_types + middle

	for i: int in count:
		var enemy_id: String = ""
		if type_seq[i] == "battle":
			enemy_id = _random_enemy_for_layer(layer_num)
		nodes.append({
			"id":      "n_%d_%d" % [layer_num, i],
			"type":    type_seq[i],
			"layer":   layer_num,
			"visited": false,
			"enemy_id": enemy_id,
			"index":   i,
		})

	# Boss 节点最后
	nodes.append({
		"id":       "boss_%d" % layer_num,
		"type":     "boss",
		"layer":    layer_num,
		"visited":  false,
		"enemy_id": LAYER_BOSSES[layer_num],
		"index":    count,
	})
	return nodes

func _roll_type() -> String:
	## 填充槽位权重：战斗60 事件25 商店15（无休息）
	var weights: Dictionary = {"battle": 60, "event": 25, "shop": 15}
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

		var row_end: int = min(i + row_size, len(layer_nodes))
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
		"event":  [Color(0.08, 0.14, 0.08, 0.92), Color(0.35, 0.70, 0.25)],
		"shop":   [Color(0.14, 0.11, 0.03, 0.92), Color(0.90, 0.72, 0.10)],
		"rest":   [Color(0.05, 0.11, 0.18, 0.92), Color(0.20, 0.55, 0.80)],
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
		# Boss 节点脉冲
		if ntype == "boss":
			var tw: Tween = btn.create_tween().set_loops()
			tw.tween_property(btn, "modulate", Color(1.3, 0.7, 0.7), 0.7)
			tw.tween_property(btn, "modulate", Color.WHITE, 0.7)
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
		btn.pressed.connect(func():
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

	# 休息节点：直接在地图内结算，不跳场景
	if ntype == "rest":
		var healed: int = int(GameState.max_hp * 0.30)
		GameState.heal(healed)
		_show_rest_popup(healed)
		_check_layer_done()
		_render_map()
		_update_status()
		return

	# 战斗 / Boss：设置 pending enemy
	if ntype in ["battle", "boss"]:
		var eid: String = nd.get("enemy_id", "")
		if eid.is_empty():
			eid = _random_enemy_for_layer(GameState.current_layer)
		GameState.set_meta("pending_enemy_id", eid)

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
		var lbl := Label.new()
		lbl.text         = relic_icons.get(rid, "◈")
		lbl.tooltip_text = data.get("name", "???") + "\n" + data.get("effect", "")
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", UIConstants.color_of("gold_dim"))
		relic_bar.add_child(lbl)

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
