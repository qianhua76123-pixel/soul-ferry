extends VBoxContainer

class_name EnemyHealthBar

## EnemyHealthBar.gd - 敌人HP血条组件（_draw渐变血条 + 双层残影）

var _max_hp:   int   = 100
var _cur_hp:   int   = 100
var _ghost_hp: float = 100.0

var _hp_tween:    Tween = null
var _pulse_tween: Tween = null
var _is_pulsing:  bool  = false

const SLOT_COLOR  = Color(0.102, 0.031, 0.031)
const GHOST_COLOR = Color(0.700, 0.560, 0.000, 0.65)
const COLOR_HIGH  = Color(0.290, 0.478, 0.227)
const COLOR_MID   = Color(0.545, 0.416, 0.078)
const COLOR_LOW   = Color(0.545, 0.102, 0.102)
const SHINE_COLOR = Color(1.0, 1.0, 1.0, 0.18)
const BAR_H: float = 14.0
const CORNER: float = 4.0

func _ready() -> void:
	custom_minimum_size = Vector2(220, 36)
	add_theme_constant_override("separation", 2)
	alignment = BoxContainer.ALIGNMENT_END

	var bar_area: Control = Control.new()
	bar_area.name = "BarArea"
	bar_area.custom_minimum_size = Vector2(220, int(BAR_H) + 4)
	bar_area.draw.connect(_draw_bar.bind(bar_area))
	add_child(bar_area)

func _draw_bar(area: Control) -> void:
	var w: float = area.size.x
	if w <= 0.0:
		w = 220.0
	var ratio       = float(_cur_hp) / float(max(1, _max_hp))
	var ghost_ratio: float = float(_ghost_hp) / float(max(1, _max_hp))
	var fill_color  = _get_fill_color(ratio)

	_draw_chamfered_rect(area, Rect2(0, 2, w, BAR_H), SLOT_COLOR, CORNER)

	var ghost_w: int = clamp(ghost_ratio, 0.0, 1.0) * (w - CORNER * 2)
	if ghost_w > 0.0:
		_draw_chamfered_rect(area, Rect2(CORNER, 2, ghost_w, BAR_H), GHOST_COLOR, CORNER * 0.5)

	var fill_w: int = clamp(ratio, 0.0, 1.0) * (w - CORNER * 2)
	if fill_w > 0.0:
		_draw_chamfered_rect(area, Rect2(CORNER, 2, fill_w, BAR_H), fill_color, CORNER * 0.5)

	# 顶部1px亮边
	area.draw_line(Vector2(CORNER, 2), Vector2(CORNER + fill_w, 2), SHINE_COLOR, 1.0)

	# 右侧数字
	var hp_text = "%d / %d" % [_cur_hp, _max_hp]
	area.draw_string(ThemeDB.fallback_font,
		Vector2(w - 60, 2 + BAR_H - 2),
		hp_text, HORIZONTAL_ALIGNMENT_RIGHT, 60, 11, fill_color)

func _draw_chamfered_rect(area: Control, rect: Rect2, color: Color, c: float) -> void:
	var x  = rect.position.x
	var y  = rect.position.y
	var rw: float = rect.size.x
	var rh: float = rect.size.y
	var pts = PackedVector2Array([
		Vector2(x + c,      y),
		Vector2(x + rw - c, y),
		Vector2(x + rw,     y + c),
		Vector2(x + rw,     y + rh - c),
		Vector2(x + rw - c, y + rh),
		Vector2(x + c,      y + rh),
		Vector2(x,          y + rh - c),
		Vector2(x,          y + c),
	])
	area.draw_colored_polygon(pts, color)

func _get_fill_color(ratio: float) -> Color:
	if ratio > 0.6:
		return COLOR_HIGH
	elif ratio > 0.3:
		return COLOR_MID
	else:
		return COLOR_LOW

func set_hp(new_hp: int, max_hp: int) -> void:
	var old_hp = _cur_hp
	_max_hp = max_hp
	_cur_hp = new_hp

	if _hp_tween: _hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_interval(0.3)
	_hp_tween.tween_method(func(v: float):
		_ghost_hp = v
		_redraw_bar()
		, float(old_hp) if _ghost_hp > float(new_hp) else float(new_hp),
		float(new_hp), 0.5).set_ease(Tween.EASE_OUT)

	_ghost_hp = max(_ghost_hp, float(new_hp))
	_redraw_bar()

	var ratio: float = float(new_hp) / float(max(1, max_hp))
	if ratio <= 0.3:
		_start_pulse()
	else:
		_stop_pulse()

func _redraw_bar() -> void:
	var bar_area: Node = get_node_or_null("BarArea")
	if bar_area:
		bar_area.queue_redraw()

func set_shield(shield: int) -> void:
	pass  # 敌人护盾由 BattleScene 的 enemy_shield_label 显示

func _start_pulse() -> void:
	if _is_pulsing: return
	_is_pulsing = true
	if _pulse_tween: _pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate:a", 0.7, 0.75)
	_pulse_tween.tween_property(self, "modulate:a", 1.0, 0.75)

func _stop_pulse() -> void:
	if not _is_pulsing: return
	_is_pulsing = false
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	modulate.a = 1.0
