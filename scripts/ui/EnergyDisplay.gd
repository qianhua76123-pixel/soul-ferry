extends HBoxContainer

## EnergyDisplay.gd - 费用圆点显示（参考 Slay the Spire 风格）
## 实心圆 = 可用费用，空心圆 = 已消耗

const MAX_ENERGY  = 3
const DOT_SIZE    = 14
const DOT_FILLED  = Color(0.95, 0.76, 0.08)   # 金色实心
const DOT_EMPTY   = Color(0.27, 0.27, 0.27)   # 暗灰空心

var _dots: Array = []
var _current: int = MAX_ENERGY

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_build_dots(MAX_ENERGY)
	DeckManager.cost_changed.connect(_on_cost_changed)

func _build_dots(max_e: int) -> void:
	for child in get_children(): child.queue_free()
	_dots.clear()
	for i in max_e:
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.color = DOT_FILLED
		# 圆形效果：用 StyleBoxFlat 圆角
		add_child(dot)
		_dots.append(dot)

func _on_cost_changed(new_cost: int) -> void:
	_current = new_cost
	for i in _dots.size():
		_dots[i].color = DOT_FILLED if i < new_cost else DOT_EMPTY
