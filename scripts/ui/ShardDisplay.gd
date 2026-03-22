extends Control
class_name ShardDisplay

## ShardDisplay.gd - 战斗中碎片状态栏
## 显示当前持有的各类碎片数量，嵌入 BattleScene HUD

const SHARD_COLORS: Dictionary = {
	"bei":    Color(0.15, 0.40, 0.70),   # 深青蓝
	"ju":     Color(0.42, 0.20, 0.55),   # 暗紫
	"nu":     Color(0.75, 0.18, 0.18),   # 红
	"xi":     Color(0.72, 0.53, 0.05),   # 暗金
	"ding":   Color(0.25, 0.55, 0.38),   # 墨绿
	"seal":   Color(0.85, 0.72, 0.30),   # 金褐
	"chain":  Color(0.50, 0.50, 0.55),   # 铁灰
	"void":   Color(0.78, 0.78, 0.75),   # 灰白
	"spirit": Color(0.55, 0.80, 0.85),   # 浅青
	"echo":   Color(0.90, 0.82, 0.55),   # 淡金
}
const SHARD_ICONS: Dictionary = {
	"bei": "悲", "ju": "惧", "nu": "怒", "xi": "喜", "ding": "定",
	"seal": "印", "chain": "锁", "void": "空", "spirit": "灵", "echo": "响",
}

# 每个碎片类型的显示节点
var _cells: Dictionary = {}
var _anim_tweens: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(220, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_cells()
	DiscardSystem.shard_gained.connect(_on_shard_gained)
	DiscardSystem.shard_resonance_triggered.connect(_on_resonance)
	DiscardSystem.shards_cleared.connect(_refresh_all)

func _build_cells() -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)

	# 只显示有碎片或当前角色相关的类型
	var char_id: String = str(GameState.get_meta("selected_character", "ruan_ruyue"))
	var visible_types: Array[String] = ["bei", "ju", "nu", "xi", "ding", "spirit"]
	if char_id == "ruan_ruyue":
		visible_types.append("seal")
	elif char_id == "shen_tiejun":
		visible_types.append("chain")
	elif char_id == "wumian":
		visible_types.append("void")
	visible_types.append("echo")

	for st in visible_types:
		var cell: Control = _make_cell(st)
		hbox.add_child(cell)
		_cells[st] = cell

func _make_cell(shard_type: String) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(26, 26)
	ctrl.name = "Cell_" + shard_type

	var dot: ColorRect = ColorRect.new()
	dot.name = "Dot"
	dot.color = SHARD_COLORS.get(shard_type, Color.WHITE)
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size = Vector2(8, 8)
	dot.position = Vector2(1, 9)
	ctrl.add_child(dot)

	var lbl: Label = Label.new()
	lbl.name = "Lbl"
	lbl.text = "%s×0" % SHARD_ICONS.get(shard_type, "?")
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", SHARD_COLORS.get(shard_type, Color.WHITE))
	lbl.position = Vector2(10, 0)
	ctrl.add_child(lbl)

	# 初始不显示（数量为0）
	ctrl.modulate.a = 0.3
	return ctrl

func _on_shard_gained(shard_type: String, amount: int) -> void:
	_refresh_cell(shard_type)
	# 溢出动画：放大+金色光晕
	var cell: Control = _cells.get(shard_type)
	if not cell: return
	if _anim_tweens.has(shard_type) and is_instance_valid(_anim_tweens[shard_type]):
		_anim_tweens[shard_type].kill()
	var tw: Tween = cell.create_tween().set_parallel(true)
	tw.tween_property(cell, "scale", Vector2(1.35, 1.35), 0.10).set_ease(Tween.EASE_OUT)
	tw.tween_property(cell, "scale", Vector2(1.0, 1.0), 0.20).set_ease(Tween.EASE_IN).set_delay(0.10)
	tw.tween_property(cell, "modulate:a", 1.0, 0.15)
	_anim_tweens[shard_type] = tw

func _on_resonance(shard_type: String) -> void:
	var cell: Control = _cells.get(shard_type)
	if not cell: return
	# 金色光晕脉冲
	var tw: Tween = cell.create_tween().set_loops(3)
	tw.tween_property(cell, "modulate", Color(1.5, 1.3, 0.5, 1.0), 0.15)
	tw.tween_property(cell, "modulate", Color.WHITE, 0.15)

func _refresh_cell(shard_type: String) -> void:
	var cell: Control = _cells.get(shard_type)
	if not cell: return
	var count: int = DiscardSystem.get_shard(shard_type)
	var lbl: Label = cell.get_node_or_null("Lbl") as Label
	if lbl:
		lbl.text = "%s×%d" % [SHARD_ICONS.get(shard_type, "?"), count]
	cell.modulate.a = 1.0 if count > 0 else 0.3

func _refresh_all() -> void:
	for st in _cells:
		_refresh_cell(st)
