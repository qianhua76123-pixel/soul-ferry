extends Node2D

## MapScene.gd - 路线地图（三层节点）

@onready var node_container = $UI/NodeContainer
@onready var layer_label    = $UI/LayerLabel
@onready var hp_label       = $UI/TopBar/HPLabel
@onready var gold_label     = $UI/TopBar/GoldLabel
@onready var relic_bar      = $UI/RelicBar

const NODE_WEIGHTS      = {"battle":50,"event":25,"shop":15,"rest":10}
const LAYER_NODE_COUNTS = [5,5,4]
const LAYER_BOSSES      = {1:"shuigui_wanggui",2:"hanba_jiaoge",3:"guixiniang_sujin"}
const LAYER_NAMES       = {
	1:"第一层：荒村（悲·惧）",
	2:"第二层：古祠（怒·定）",
	3:"第三层：幽冥渡口（喜·定）"
}
const SCENE_PATHS = {
	"battle":"res://scenes/BattleScene.tscn",
	"event": "res://scenes/EventScene.tscn",
	"shop":  "res://scenes/ShopScene.tscn",
	"boss":  "res://scenes/BattleScene.tscn",
}
const NODE_ICONS = {"battle":"[战]","event":"[事]","shop":"[店]","rest":"[息]","boss":"[魔]"}
const NODE_CN    = {"battle":"战斗","event":"事件","shop":"商店","rest":"休息","boss":"Boss"}

# 地图数据持久化在 GameState.meta 中
var _map_data: Array = []

func _ready() -> void:
	# 首次进入
	if GameState.hp <= 0 or DeckManager.get_total_card_count() == 0:
		GameState.new_run()
		DeckManager.init_starter_deck()

	GameState.hp_changed.connect(func(_o,_n): _update_status())
	GameState.gold_changed.connect(func(_o,_n): _update_status())
	GameState.relic_added.connect(func(_id): _render_relics())

	# 加载或生成地图数据
	if GameState.has_meta("map_data"):
		_map_data = GameState.get_meta("map_data")
	else:
		_generate_map()
		GameState.set_meta("map_data", _map_data)

	_update_status()
	_render_map()
	_render_relics()

func _generate_map() -> void:
	_map_data = []
	for layer_idx in 3:
		var layer_nodes = []
		for node_idx in LAYER_NODE_COUNTS[layer_idx]:
			layer_nodes.append({
				"id":   "n_%d_%d" % [layer_idx+1, node_idx],
				"type": _roll_type(),
				"layer": layer_idx+1,
				"visited": false,
				"enemy_id": "",
			})
		layer_nodes.append({
			"id":       "boss_%d" % (layer_idx+1),
			"type":     "boss",
			"layer":    layer_idx+1,
			"visited":  false,
			"enemy_id": LAYER_BOSSES[layer_idx+1],
		})
		_map_data.append(layer_nodes)

func _roll_type() -> String:
	var total = 0
	for w in NODE_WEIGHTS.values(): total += w
	var roll = randi() % total
	var cum  = 0
	for t in NODE_WEIGHTS:
		cum += NODE_WEIGHTS[t]
		if roll < cum: return t
	return "battle"

func _render_map() -> void:
	layer_label.text = LAYER_NAMES.get(GameState.current_layer, "???")
	for child in node_container.get_children():
		child.queue_free()

	for layer_idx in len(_map_data):
		var layer_num  = layer_idx + 1
		var is_current = layer_num == GameState.current_layer

		var lbl = Label.new()
		lbl.text = LAYER_NAMES.get(layer_num, "第%d层" % layer_num)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color.WHITE if is_current else Color(0.45,0.45,0.45)
		node_container.add_child(lbl)

		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		for nd in _map_data[layer_idx]:
			if not hbox.get_children().is_empty():
				var sep = Label.new()
				sep.text = " — "
				sep.modulate = Color(0.3,0.25,0.2)
				hbox.add_child(sep)
			hbox.add_child(_make_node_btn(nd, is_current))
		node_container.add_child(hbox)

		var line = HSeparator.new()
		line.modulate = Color(0.15,0.12,0.09)
		node_container.add_child(line)

func _make_node_btn(nd: Dictionary, is_current: bool) -> Button:
	var btn      = Button.new()
	var ntype    = nd.get("type","battle")
	var visited  = nd.get("visited", false)
	btn.text     = "%s\n%s" % [NODE_ICONS.get(ntype,"?"), NODE_CN.get(ntype,"???")]
	btn.custom_minimum_size = Vector2(82, 76)
	btn.disabled = not is_current or visited
	if visited:         btn.modulate = Color(0.35, 0.30, 0.25)
	elif not is_current: btn.modulate = Color(0.50, 0.45, 0.40)
	elif ntype == "boss": btn.modulate = Color(1.0, 0.6, 0.6)
	var cap = nd
	btn.pressed.connect(func(): _on_node_pressed(cap))
	return btn

func _on_node_pressed(nd: Dictionary) -> void:
	nd["visited"] = true
	GameState.set_meta("map_data", _map_data)
	GameState.advance_node(nd["id"])
	var ntype = nd.get("type","battle")

	if ntype == "rest":
		var healed = int(GameState.max_hp * 0.30)
		GameState.heal(healed)
		_check_layer_done()
		_render_map()
		_update_status()
		return

	if ntype in ["battle","boss"]:
		var eid = nd.get("enemy_id","")
		if eid == "": eid = _random_enemy_for_layer(GameState.current_layer)
		GameState.set_meta("pending_enemy_id", eid)

	if ntype == "event":
		var eid = nd.get("event_id","")
		if eid != "": GameState.set_meta("pending_event_id", eid)

	var path = SCENE_PATHS.get(ntype,"")
	if path != "":
		get_tree().change_scene_to_file(path)

func _random_enemy_for_layer(layer: int) -> String:
	var file = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if not file: return "yuan_gui"
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK: return "yuan_gui"
	file.close()
	var pool = json.get_data().get("enemies",[]).filter(
		func(e): return e.get("layer",1) == layer and e.get("type","") == "normal"
	)
	if pool.is_empty():
		pool = json.get_data().get("enemies",[]).filter(
			func(e): return e.get("type","") == "normal"
		)
	if pool.is_empty(): return "yuan_gui"
	return pool[randi() % len(pool)].get("id","yuan_gui")

func _check_layer_done() -> void:
	var idx = GameState.current_layer - 1
	if idx >= len(_map_data): return
	var all_visited = true
	for nd in _map_data[idx]:
		if not nd.get("visited",false): all_visited = false; break
	if all_visited:
		GameState.advance_layer()
		layer_label.text = LAYER_NAMES.get(GameState.current_layer, "通关！")

func _render_relics() -> void:
	for child in relic_bar.get_children(): child.queue_free()
	var relic_icons = {
		"tong_jing_sui":"🪞","wenlu_xiang":"🕯","duhun_ce":"📖",
		"shaogu_pian":"🦴","qingming_pai":"🪶","wuqing_jie":"🎀",
		"nianhua_yan":"👁","yin_yang_bi":"✒","hun_bo_lu":"🔥","si_xiang_pian":"🌾",
	}
	for rid in GameState.relics:
		var data = RelicManager._all_relics_data.get(rid, {})
		var lbl  = Label.new()
		lbl.name = "relic_" + rid          # 命名方便后续定位
		lbl.text = relic_icons.get(rid, "◈")
		lbl.tooltip_text = data.get("name","???") + "\n" + data.get("effect","")
		lbl.add_theme_font_size_override("font_size", 22)
		relic_bar.add_child(lbl)

func _update_status() -> void:
	hp_label.text   = "HP: %d/%d" % [GameState.hp, GameState.max_hp]
	gold_label.text = "💰 %d"     % GameState.gold
