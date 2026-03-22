extends HBoxContainer

## EnergyDisplay.gd - 费用能量球（重设计）
## 实心发光圆 = 可用，暗色空心圆 = 已消耗
## 与 EmotionRadar 共享金黑设计语言

const MAX_ENERGY: int = 3
const DOT_R:      int = 10   # 圆半径（像素）
const DOT_SIZE:   int = DOT_R * 2 + 6

var _dots:   Array[Control] = []
var _current: int = MAX_ENERGY
var _max:     int = MAX_ENERGY

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_build_dots(MAX_ENERGY)
	DeckManager.cost_changed.connect(_on_cost_changed)

func _build_dots(max_e: int) -> void:
	for c in get_children(): c.queue_free()
	_dots.clear()
	_max = max_e
	for i in max_e:
		var dot: Control = Control.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.name = "Dot%d" % i
		add_child(dot)
		_dots.append(dot)
		_update_dot(i, i < _current)

func _update_dot(idx: int, filled: bool) -> void:
	if idx >= _dots.size(): return
	var dot: Control = _dots[idx]
	# 清旧绘制回调
	if dot.draw.get_connections().size() > 0:
		dot.draw.disconnect(_make_draw_cb(idx, filled))
	dot.draw.connect(_make_draw_cb(idx, filled))
	dot.queue_redraw()

func _make_draw_cb(idx: int, filled: bool) -> Callable:
	return func():
		var dot: Control = _dots[idx] if idx < _dots.size() else null
		if not dot: return
		var c: Vector2 = dot.size / 2.0
		var r: float = float(DOT_R)
		if filled:
			# 外发光
			dot.draw_circle(c, r + 3.0,
				Color(UIConstants.COLORS["gold"].r,
					  UIConstants.COLORS["gold"].g,
					  UIConstants.COLORS["gold"].b, 0.18))
			# 实心主体
			dot.draw_circle(c, r,
				UIConstants.COLORS["gold"])
			# 高光（左上小亮斑）
			dot.draw_circle(c + Vector2(-r * 0.28, -r * 0.30), r * 0.30,
				Color(1.0, 0.98, 0.88, 0.55))
		else:
			# 暗底
			dot.draw_circle(c, r,
				Color(0.08, 0.06, 0.04, 0.90))
			# 空心圆环
			dot.draw_arc(c, r - 1.0, 0, TAU, 32,
				Color(UIConstants.COLORS["gold_dim"].r,
					  UIConstants.COLORS["gold_dim"].g,
					  UIConstants.COLORS["gold_dim"].b, 0.50), 1.5)

func _on_cost_changed(new_cost: int) -> void:
	_current = new_cost
	if new_cost > _max:
		_build_dots(new_cost)
		return
	for i in _dots.size():
		_update_dot(i, i < new_cost)
