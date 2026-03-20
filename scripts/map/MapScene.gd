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
	TransitionManager.fade_in_only()
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

	# 通关检测（每次进入地图都检测一次）
	# 注意：_check_layer_done 内部已保护防重复推进
	if not GameState.check_victory_condition():
		_check_layer_done()

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

		# 层间连接线（非最后一层）
		if layer_idx < len(_map_data) - 1:
			var connector = _make_layer_connector(is_current)
			node_container.add_child(connector)

		var line = HSeparator.new()
		line.modulate = Color(0.15,0.12,0.09)
		node_container.add_child(line)

func _make_node_btn(nd: Dictionary, is_current: bool) -> Button:
	var btn     = Button.new()
	var ntype   = nd.get("type","battle")
	var visited = nd.get("visited", false)

	# 图标 + 名称（双行，大图标）
	btn.text = "%s\n%s" % [NODE_ICONS.get(ntype,"◈"), NODE_CN.get(ntype,"???")]
	btn.custom_minimum_size = Vector2(88, 80)

	# 样式：按类型定制颜色
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left    = 6
	style.corner_radius_top_right   = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right= 6
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2

	var node_colors = {
		"battle":  [Color(0.22, 0.07, 0.07), Color(0.60, 0.12, 0.10)],
		"boss":    [Color(0.30, 0.05, 0.05), Color(0.90, 0.20, 0.10)],
		"event":   [Color(0.12, 0.15, 0.08), Color(0.35, 0.60, 0.20)],
		"shop":    [Color(0.15, 0.12, 0.04), Color(0.75, 0.60, 0.10)],
		"rest":    [Color(0.05, 0.12, 0.18), Color(0.15, 0.50, 0.70)],
	}
	var nc = node_colors.get(ntype, [Color(0.1,0.1,0.1), Color(0.5,0.5,0.5)])
	style.bg_color     = nc[0]
	style.border_color = nc[1]

	if visited:
		style.bg_color     = Color(0.10, 0.09, 0.08)
		style.border_color = Color(0.28, 0.24, 0.20)
	elif not is_current:
		style.bg_color     = Color(nc[0].r*0.5, nc[0].g*0.5, nc[0].b*0.5)
		style.border_color = Color(nc[1].r*0.45, nc[1].g*0.45, nc[1].b*0.45)

	btn.add_theme_stylebox_override("normal", style)

	# 按下效果
	var pressed_style = style.duplicate()
	pressed_style.bg_color = style.border_color * 0.5
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# 字体颜色
	if visited:
		btn.add_theme_color_override("font_color", Color(0.35, 0.30, 0.25))
	elif not is_current:
		btn.add_theme_color_override("font_color", Color(0.50, 0.45, 0.40))
	elif ntype == "boss":
		btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
	else:
		btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))

	btn.add_theme_font_size_override("font_size", 12)
	btn.disabled = not is_current or visited

	# Boss 节点脉冲动画
	if ntype == "boss" and is_current and not visited:
		var tw = btn.create_tween().set_loops()
		tw.tween_property(btn, "modulate", Color(1.2, 0.8, 0.8, 1.0), 0.8)
		tw.tween_property(btn, "modulate", Color.WHITE, 0.8)

	var cap = nd
	btn.pressed.connect(func():
		# 点击缩放反馈
		var tw_2 = btn.create_tween()
		tw_2.tween_property(btn, "scale", Vector2(0.90, 0.90), 0.08)
		tw_2.tween_property(btn, "scale", Vector2(1.0,  1.0),  0.12)
		tw_2.tween_callback(func(): _on_node_pressed(cap))
	)
	return btn

func _on_node_pressed(nd: Dictionary) -> void:
	nd["visited"] = true
	GameState.set_meta("map_data", _map_data)
	GameState.advance_node(nd["id"])
	# 自动存档
	GameState.save_to_file()
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
		var eid_2 = nd.get("event_id","")
		if eid_2 != "": GameState.set_meta("pending_event_id", eid_2)

	var path = SCENE_PATHS.get(ntype,"")
	if path != "":
		TransitionManager.change_scene(path, _get_scene_title(path))

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
	# current_layer 已经超过 _map_data 层数 → 已推进过了，跳过
	var idx = GameState.current_layer - 1
	if idx < 0 or idx >= len(_map_data): return

	# 检查当前层所有节点是否全部已访问
	var all_visited = true
	for nd in _map_data[idx]:
		if not nd.get("visited", false):
			all_visited = false
			break
	if not all_visited: return

	# 推进层（内部会 reset current_node，防止重复推进）
	GameState.advance_layer()
	# 同步地图数据到 GameState（生成下一层或清空）
	GameState.set_meta("map_data", _map_data)
	# 通关判定：超过第三层 → 触发成功结局
	if GameState.check_victory_condition():
		GameState.trigger_ending("success")
		return
	# 刷新地图显示（新层）
	_render_map()

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

## 生成层间向下箭头连接线
func _make_layer_connector(is_active: bool) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(0, 28)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.anchors_preset = Control.PRESET_FULL_RECT

	# 用箭头字符 + 细线模拟路径
	lbl.text = "│\n▼"
	lbl.add_theme_font_size_override("font_size", 11)

	if is_active:
		lbl.add_theme_color_override("font_color", Color(0.65, 0.20, 0.10, 0.9))
		# 激活层的箭头带脉冲动画
		var tw = lbl.create_tween().set_loops()
		tw.tween_property(lbl, "modulate:a", 0.4, 0.7).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.7).set_ease(Tween.EASE_IN_OUT)
	else:
		lbl.add_theme_color_override("font_color", Color(0.25, 0.22, 0.18, 0.6))

	c.add_child(lbl)
	return c

## 根据目标场景路径返回过场字幕
func _get_scene_title(path: String) -> String:
	var layer = GameState.current_layer
	var layer_names = {1: "第一层·望乡", 2: "第二层·焦土", 3: "第三层·幽冥"}
	match path:
		"res://scenes/BattleScene.tscn":
			return layer_names.get(layer, "战斗")
		"res://scenes/EventScene.tscn":
			return "奇遇"
		"res://scenes/ShopScene.tscn":
			return "幽冥集市"
		"res://scenes/RestScene.tscn":
			return "古庙休息"
		_:
			return ""
