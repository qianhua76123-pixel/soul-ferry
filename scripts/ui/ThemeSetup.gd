## theme_setup.gd - 在 _ready() 里调用此方法来应用朱红暗金主题
## 用法：在任何场景 _ready() 中调用 ThemeSetup.apply(get_tree().root)

extends Node

# 主题配色
const C_BG       = Color(0.047, 0.031, 0.027)   # 背景 #0a0705
const C_PANEL    = Color(0.059, 0.039, 0.027)   # 面板 #0f0a07
const C_VERMIL   = Color(0.545, 0.102, 0.102)   # 朱红
const C_GOLD     = Color(0.722, 0.525, 0.043)   # 暗金
const C_PAPER    = Color(0.910, 0.878, 0.816)   # 纸白
const C_MIST     = Color(0.627, 0.600, 0.549)   # 雾灰
const C_BORDER   = Color(0.165, 0.125, 0.094)   # 边框深棕

static func make_theme() -> Theme:
	var theme = Theme.new()

	# Label
	theme.set_color("font_color", "Label", C_PAPER)

	# Button
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color     = Color(0.059, 0.039, 0.027)
	btn_normal.border_color = C_BORDER
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(0)
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color     = Color(0.12, 0.06, 0.04)
	btn_hover.border_color = C_VERMIL
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.2, 0.06, 0.06)
	btn_pressed.border_color = C_GOLD
	theme.set_stylebox("normal",  "Button", btn_normal)
	theme.set_stylebox("hover",   "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_color("font_color",          "Button", C_PAPER)
	theme.set_color("font_hover_color",    "Button", C_GOLD)
	theme.set_color("font_pressed_color",  "Button", C_GOLD)
	theme.set_color("font_disabled_color", "Button", C_MIST)

	# Panel
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color     = C_PANEL
	panel_sb.border_color = C_BORDER
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(0)
	theme.set_stylebox("panel", "Panel", panel_sb)

	# ProgressBar
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.1, 0.07, 0.05)
	pb_bg.set_corner_radius_all(0)
	var pb_fill = StyleBoxFlat.new()
	pb_fill.bg_color = C_VERMIL
	pb_fill.set_corner_radius_all(0)
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill",       "ProgressBar", pb_fill)

	# HSeparator
	var sep_sb = StyleBoxFlat.new()
	sep_sb.bg_color = C_BORDER
	theme.set_stylebox("separator", "HSeparator", sep_sb)

	return theme
