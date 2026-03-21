extends HBoxContainer

## EnergyDisplay.gd - 费用圆点显示（参考 Slay the Spire 风格）
## 实心圆 = 可用费用，空心圆 = 已消耗

const MAX_ENERGY  = 3
const DOT_SIZE    = 14

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
		dot.color = UIConstants.color_of("gold")
		# 圆形效果：用 StyleBoxFlat 圆角
		add_child(dot)
		_dots.append(dot)

func _on_cost_changed(new_cost: int) -> void:
	_current = new_cost
	for i in _dots.size():
		var empty := UIConstants.color_of("ink")
		empty = Color(empty.r * 0.35, empty.g * 0.35, empty.b * 0.35, 1.0)
		_dots[i].color = UIConstants.color_of("gold") if i < new_cost else empty
