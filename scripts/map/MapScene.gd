extends Node2D

## MapScene.gd - 地图节点系统
## 生成三层地图，每层横排节点，点击节点跳转场景


# ========== 节点引用 ==========
@onready var node_container: VBoxContainer = $UI/NodeContainer
@onready var layer_label:    Label         = $UI/LayerLabel
@onready var hp_label:       Label         = $UI/TopBar/HPLabel
@onready var gold_label:     Label         = $UI/TopBar/GoldLabel

# ========== 常量 ==========
const NODE_WEIGHTS       = { "battle": 50, "event": 25, "shop": 15, "rest": 10 }
const LAYER_NODE_COUNTS  = [5, 5, 4]
const LAYER_BOSSES       = { 1: "shuigui_wanggui", 2: "hanba_jiaoge", 3: "guixiniang_sujin" }
const LAYER_NAMES        = {
	1: "第一层：荒村  （悲·惧）",
	2: "第二层：古祠  （怒·定）",
	3: "第三层：幽冥渡口  （喜·定）"
}
const SCENE_PATHS        = {
	"battle": "res://scenes/BattleScene.tscn",
	"event":  "res://scenes/EventScene.tscn",
	"shop":   "res://scenes/ShopScene.tscn",
	"rest":   "",       # 就地处理，不跳转
	"boss":   "res://scenes/BattleScene.tscn",
}
const NODE_ICONS = {
	"battle": "⚔",
	"event":  "📜",
	"shop":   "🏮",
	"rest":   "🕯",
	"boss":   "☠",
}

# ========== 地图数据 ==========
var map_data: Array = []

# ========== 初始化 ==========
func _ready() -> void:
	GameState.hp_changed.connect(func(_o, _n): _update_status())
	GameState.gold_changed.connect(func(_o, _n): _update_status())
	_update_status()

	# 首次进入：初始化新局
	if GameState.hp <= 0 or DeckManager.get_total_card_count() == 0:
		GameState.new_run()
		DeckManager.init_starter_deck()

	# 首次进入或新局：生成地图
	if map_data.is_empty():
		_generate_map()

	_render_map()

# ========== 地图生成 ==========

func _generate_map() -> void:
	map_data = []
	for layer_idx in 3:
		var layer_nodes = []
		for node_idx in LAYER_NODE_COUNTS[layer_idx]:
			layer_nodes.append({
				"id":       "n_%d_%d" % [layer_idx + 1, node_idx],
				"type":     _roll_node_type(),
				"layer":    layer_idx + 1,
				"index":    node_idx,
				"visited":  false,
				"enemy_id": "",
			})
		# Boss 节点（每层末尾）
		layer_nodes.append({
			"id":       "boss_%d" % (layer_idx + 1),
			"type":     "boss",
			"layer":    layer_idx + 1,
			"index":    LAYER_NODE_COUNTS[layer_idx],
			"visited":  false,
			"enemy_id": LAYER_BOSSES[layer_idx + 1],
		})
		map_data.append(layer_nodes)

func _roll_node_type() -> String:
	var total = 0
	for w in NODE_WEIGHTS.values(): total += w
	var roll = randi() % total
	var cum  = 0
	for t in NODE_WEIGHTS:
		cum += NODE_WEIGHTS[t]
		if roll < cum: return t
	return "battle"

# ========== 渲染 ==========

func _render_map() -> void:
	layer_label.text = LAYER_NAMES.get(GameState.current_layer, "???")

	for child in node_container.get_children():
		child.queue_free()

	for layer_idx in len(map_data):
		var layer     = map_data[layer_idx]
		var layer_num = layer_idx + 1
		var is_current = (layer_num == GameState.current_layer)

		# 层名称行
		var row_lbl = Label.new()
		row_lbl.text = LAYER_NAMES.get(layer_num, "第%d层" % layer_num)
		row_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row_lbl.modulate = Color.WHITE if is_current else Color(0.45, 0.45, 0.45)
		node_container.add_child(row_lbl)

		# 节点横排
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		for nd in layer:
			hbox.add_child(_build_node_btn(nd, is_current))
		node_container.add_child(hbox)

		var sep = HSeparator.new()
		sep.modulate = Color(0.25, 0.20, 0.16)
		node_container.add_child(sep)

func _build_node_btn(nd: Dictionary, is_current: bool) -> Button:
	var btn   = Button.new()
	var ntype = nd.get("type", "battle")
	btn.text  = NODE_ICONS.get(ntype, "?") + "\n" + _type_cn(ntype)
	btn.custom_minimum_size = Vector2(78, 74)
	btn.disabled = not is_current or nd.get("visited", false)

	if nd.get("visited", false):
		btn.modulate = Color(0.38, 0.38, 0.38)
	elif not is_current:
		btn.modulate = Color(0.50, 0.50, 0.50)

	var captured = nd
	btn.pressed.connect(func(): _on_node_selected(captured))
	return btn

func _type_cn(t: String) -> String:
	match t:
		"battle": return "战斗"
		"event":  return "事件"
		"shop":   return "商店"
		"rest":   return "休息"
		"boss":   return "Boss"
	return "???"

# ========== 节点选择 ==========

func _on_node_selected(nd: Dictionary) -> void:
	nd["visited"] = true
	GameState.advance_node(nd["id"])

	var ntype = nd.get("type", "battle")

	# 休息：原地处理，刷新地图
	if ntype == "rest":
		var heal = int(GameState.max_hp * 0.30)
		GameState.heal(heal)
		_check_layer_complete()
		_render_map()
		return

	# 战斗 / Boss：把敌人ID挂到 GameState meta，供 BattleScene 读取
	if ntype in ["battle", "boss"]:
		var eid = nd.get("enemy_id", "")
		if eid == "":
			eid = _pick_random_enemy()
		GameState.set_meta("pending_enemy_id", eid)

	var path = SCENE_PATHS.get(ntype, "")
	if path != "":
		get_tree().change_scene_to_file(path)

func _pick_random_enemy() -> String:
	var file = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if not file: return "yuan_gui"
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK: return "yuan_gui"
	file.close()
	var layer = GameState.current_layer
	var pool  = json.get_data().get("enemies", []).filter(
		func(e): return e.get("layer", 1) == layer and e.get("type", "") == "normal"
	)
	if pool.is_empty(): return "yuan_gui"
	return pool[randi() % len(pool)].get("id", "yuan_gui")

func _check_layer_complete() -> void:
	var idx = GameState.current_layer - 1
	if idx >= len(map_data): return
	var done = map_data[idx].all(func(n): return n.get("visited", false))
	if done:
		GameState.advance_layer()

# ========== 状态栏 ==========

func _update_status() -> void:
	hp_label.text   = "HP: %d/%d" % [GameState.hp, GameState.max_hp]
	gold_label.text = "金币: %d"   % GameState.gold
