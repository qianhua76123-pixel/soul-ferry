extends CanvasLayer

## TransitionManager.gd - 全局场景切换过场动画
## 功能：
##   - 黑屏淡出（fade_out）→ 切换场景 → 黑屏淡入（fade_in）
##   - 可选：场景标题字幕（层名/地点名）
##   - change_scene(path, title="") 统一入口

const FADE_DURATION  = 0.35   # 淡出时长（秒）
const TITLE_DURATION = 0.9    # 标题显示时长

var _overlay:    ColorRect
var _title_lbl:  Label
var _is_fading:  bool = false

func _ready() -> void:
	# CanvasLayer 始终在最顶层
	layer = 128

	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.65))
	_title_lbl.modulate.a = 0.0
	add_child(_title_lbl)

## 统一场景切换入口
## path: 目标场景路径
## title: 可选字幕（如"第二层·焦土"），空则不显示
func change_scene(path: String, title: String = "") -> void:
	if _is_fading: return
	_is_fading = true
	_title_lbl.text = title

	var tw = create_tween()
	# 第一阶段：fade out（黑屏）
	tw.tween_property(_overlay, "color:a", 1.0, FADE_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# 字幕淡入（有字幕时）
	if title != "":
		tw.parallel().tween_property(_title_lbl, "modulate:a", 1.0, FADE_DURATION)
	# 停顿
	tw.tween_interval(TITLE_DURATION if title != "" else 0.1)
	# 切换场景（在完全黑屏时执行）
	tw.tween_callback(func(): get_tree().change_scene_to_file(path))
	# 字幕淡出
	if title != "":
		tw.tween_property(_title_lbl, "modulate:a", 0.0, FADE_DURATION * 0.5)
	# 第二阶段：fade in（场景加载后）
	tw.tween_property(_overlay, "color:a", 0.0, FADE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func(): _is_fading = false)

## 仅执行淡入（场景 _ready() 开头调用，让场景从黑屏渐显）
func fade_in_only() -> void:
	_overlay.color.a = 1.0
	var tw = create_tween()
	tw.tween_property(_overlay, "color:a", 0.0, FADE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
