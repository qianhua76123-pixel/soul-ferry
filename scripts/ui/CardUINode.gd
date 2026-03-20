extends Control

class_name CardUINode

## CardUINode.gd - 牌卡UI（_draw渲染，像素民俗风占位符）

signal card_clicked(card_data: Dictionary)

const CARD_W = 90.0
const CARD_H = 130.0
const RARITY_COLORS = {
	"common":    Color(0.55, 0.52, 0.47),
	"rare":      Color(0.85, 0.72, 0.0),
	"legendary": Color(0.85, 0.12, 0.12),
}
const BG_COLOR   = Color(0.08, 0.06, 0.05)
const TEXT_COLOR = Color(0.92, 0.88, 0.80)

var card_data: Dictionary = {}
var is_playable: bool = true
var _emotion_color: Color = Color.WHITE
var _cost_text: String = "?"
var _rarity_color: Color = RARITY_COLORS["common"]
var _hover_offset: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	mouse_entered.connect(func(): _animate_hover(true))
	mouse_exited.connect(func():  _animate_hover(false))

func setup(data: Dictionary) -> void:
	card_data = data
	_emotion_color = EmotionManager.get_emotion_color(data.get("emotion_tag", "calm"))
	var cost = data.get("cost", 0) - EmotionManager.get_cost_reduction()
	_cost_text = str(max(0, cost))
	_rarity_color = RARITY_COLORS.get(data.get("rarity", "common"), RARITY_COLORS["common"])
	queue_redraw()

func set_playable(playable: bool) -> void:
	is_playable = playable
	modulate = Color.WHITE if playable else Color(0.45, 0.45, 0.45, 0.75)

func _draw() -> void:
	var ofs = Vector2(0, -_hover_offset)
	# 外框
	draw_rect(Rect2(ofs, Vector2(CARD_W, CARD_H)), _rarity_color)
	# 底色
	draw_rect(Rect2(ofs + Vector2(2,2), Vector2(CARD_W-4, CARD_H-4)), BG_COLOR)
	# 情绪色条
	draw_rect(Rect2(ofs + Vector2(2,2), Vector2(CARD_W-4, 8)), _emotion_color)
	# 占位插图
	_draw_placeholder(ofs + Vector2(2,12), Vector2(CARD_W-4, 50))
	# 分割线
	draw_line(ofs+Vector2(2,63), ofs+Vector2(CARD_W-2,63), _rarity_color, 1.0)
	# 牌名
	var name = card_data.get("name","???")
	draw_string(ThemeDB.fallback_font, ofs+Vector2(4,76), name,
		HORIZONTAL_ALIGNMENT_LEFT, int(CARD_W-8), 11, TEXT_COLOR)
	# 描述
	var desc = card_data.get("description","")
	if desc.length() > 20: desc = desc.substr(0,18) + "…"
	draw_string(ThemeDB.fallback_font, ofs+Vector2(4,90), desc,
		HORIZONTAL_ALIGNMENT_LEFT, int(CARD_W-8), 9, Color(TEXT_COLOR.r,TEXT_COLOR.g,TEXT_COLOR.b,0.7))
	# 费用圆
	draw_circle(ofs+Vector2(14,14), 11.0, Color(0.15,0.12,0.10))
	draw_arc(ofs+Vector2(14,14), 11.0, 0, TAU, 32, _rarity_color, 1.5)
	draw_string(ThemeDB.fallback_font, ofs+Vector2(9,19), _cost_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT_COLOR)
	# 情绪图标
	var c = _emotion_color; c.a = 0.85
	draw_circle(ofs+Vector2(CARD_W-14, CARD_H-14), 7.0, c)
	draw_string(ThemeDB.fallback_font, ofs+Vector2(CARD_W-19, CARD_H-9),
		EmotionManager.get_emotion_name(card_data.get("emotion_tag","calm")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)

func _draw_placeholder(pos: Vector2, size: Vector2) -> void:
	var c = _emotion_color; c.a = 0.15
	draw_rect(Rect2(pos, size), c)
	var cx = pos.x + size.x/2.0
	var cy = pos.y + size.y/2.0
	c = _emotion_color; c.a = 0.7
	match card_data.get("emotion_tag","calm"):
		"rage":
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx,cy-16),Vector2(cx-12,cy+12),Vector2(cx+12,cy+12)]), c)
		"fear":
			draw_arc(Vector2(cx,cy),14.0,0,TAU,32,c,2.0)
			draw_circle(Vector2(cx,cy),6.0,c)
		"grief":
			draw_circle(Vector2(cx,cy+4),11.0,c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx,cy-16),Vector2(cx-7,cy),Vector2(cx+7,cy)]),c)
		"joy":
			for r in [16,11,6]:
				var cc=c; cc.a=float(r)/18.0
				draw_arc(Vector2(cx,cy),float(r),0,TAU,32,cc,2.0)
		"calm":
			draw_rect(Rect2(cx-12,cy-12,24,24),c,false,2.0)
			draw_circle(Vector2(cx,cy),6.0,c,false,2.0)
			draw_line(Vector2(cx-12,cy),Vector2(cx+12,cy),c,1.5)
			draw_line(Vector2(cx,cy-12),Vector2(cx,cy+12),c,1.5)

func _animate_hover(on: bool) -> void:
	var tween = create_tween()
	tween.tween_property(self,"_hover_offset",14.0 if on else 0.0,0.12)
	tween.connect("step_finished",func(_n): queue_redraw())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_playable:
			card_clicked.emit(card_data)
			var tween = create_tween()
			tween.tween_property(self,"scale",Vector2(0.9,0.9),0.05)
			tween.tween_property(self,"scale",Vector2(1.0,1.0),0.1)
