extends Node

## ThemeSetup.gd - 全局朱红暗金像素风主题（第7个 Autoload，最先加载）
## 不要加 class_name，否则与 autoload 同名冲突

# ── 主题配色系统
const C_BG      = Color(0.047, 0.031, 0.027)  # #0a0705 背景黑
const C_PANEL   = Color(0.059, 0.039, 0.027)  # #0f0a07 面板黑
const C_VERMIL  = Color(0.545, 0.102, 0.102)  # #8b1a1a 朱红
const C_GOLD    = Color(0.722, 0.525, 0.043)  # #b8860b 暗金
const C_PAPER   = Color(0.910, 0.878, 0.816)  # #e8dfc8 纸白
const C_MIST    = Color(0.627, 0.600, 0.549)  # #a09070 雾灰
const C_BORDER  = Color(0.165, 0.125, 0.094)  # #2a2018 深棕边框
const C_SHADOW  = Color(0.0,   0.0,   0.0,   0.45)

var theme: Theme = null

func _ready() -> void:
	theme = _build_theme()
	# 挂到根节点，所有 Control 子节点自动继承
	# Godot 4 没有 ProjectSettings.set_theme，改为在树就绪后设置
	get_tree().root.theme = theme

func get_theme() -> Theme:
	return theme

# ════════════════════════════════════════════
#  主题构建
# ════════════════════════════════════════════
func _build_theme() -> Theme:
	var t = Theme.new()

	# ── Label ──
	t.set_color("font_color",        "Label", C_PAPER)
	t.set_color("font_shadow_color", "Label", C_SHADOW)
	t.set_constant("shadow_offset_x","Label", 1)
	t.set_constant("shadow_offset_y","Label", 1)

	# ── Button ──
	t.set_stylebox("normal",   "Button", _btn_style(C_PANEL,  C_BORDER,  false))
	t.set_stylebox("hover",    "Button", _btn_style(Color(0.10,0.055,0.035), C_VERMIL, false))
	t.set_stylebox("pressed",  "Button", _btn_style(Color(0.18,0.055,0.055), C_GOLD,   true))
	t.set_stylebox("focus",    "Button", _btn_style(C_PANEL,  C_GOLD,   false))
	t.set_stylebox("disabled", "Button", _btn_style(Color(0.05,0.04,0.03), C_BORDER, false))
	t.set_color("font_color",          "Button", C_PAPER)
	t.set_color("font_hover_color",    "Button", C_GOLD)
	t.set_color("font_pressed_color",  "Button", C_GOLD)
	t.set_color("font_disabled_color", "Button", Color(C_MIST.r, C_MIST.g, C_MIST.b, 0.45))
	t.set_color("font_focus_color",    "Button", C_PAPER)
	t.set_constant("outline_size",     "Button", 0)

	# ── Panel / PanelContainer ──
	t.set_stylebox("panel", "Panel",          _panel_style(C_PANEL, C_BORDER, 1))
	t.set_stylebox("panel", "PanelContainer", _panel_style(C_PANEL, C_BORDER, 1))

	# ── ProgressBar ──
	t.set_stylebox("background", "ProgressBar", _flat(Color(0.10, 0.07, 0.05)))
	t.set_stylebox("fill",       "ProgressBar", _flat(C_VERMIL))
	t.set_color("font_color",    "ProgressBar", C_PAPER)

	# ── LineEdit ──
	t.set_stylebox("normal", "LineEdit", _panel_style(Color(0.06,0.04,0.03), C_BORDER, 1))
	t.set_stylebox("focus",  "LineEdit", _panel_style(Color(0.06,0.04,0.03), C_GOLD,   1))
	t.set_color("font_color", "LineEdit", C_PAPER)
	t.set_color("caret_color","LineEdit", C_GOLD)

	# ── RichTextLabel ──
	t.set_color("default_color",        "RichTextLabel", C_PAPER)
	t.set_color("font_selected_color",  "RichTextLabel", C_GOLD)
	t.set_color("selection_color",      "RichTextLabel", Color(C_VERMIL.r,C_VERMIL.g,C_VERMIL.b,0.4))
	t.set_stylebox("normal", "RichTextLabel", _flat(Color.TRANSPARENT))

	# ── ScrollBar（细化） ──
	t.set_stylebox("scroll",        "VScrollBar", _flat(Color(0.10,0.07,0.05)))
	t.set_stylebox("scroll_focus",  "VScrollBar", _flat(C_BORDER))
	t.set_stylebox("grabber",       "VScrollBar", _flat(C_VERMIL))
	t.set_stylebox("grabber_hover", "VScrollBar", _flat(C_GOLD))

	# ── HSeparator ──
	var sep = StyleBoxFlat.new()
	sep.bg_color = C_BORDER
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 1)

	# ── VSeparator ──
	t.set_stylebox("separator", "VSeparator", sep)

	# ── CheckButton / CheckBox ──
	t.set_color("font_color",        "CheckBox", C_PAPER)
	t.set_color("font_hover_color",  "CheckBox", C_GOLD)

	# ── PopupMenu ──
	t.set_stylebox("panel",          "PopupMenu", _panel_style(C_PANEL, C_BORDER, 1))
	t.set_stylebox("hover",          "PopupMenu", _flat(Color(0.14,0.08,0.05)))
	t.set_color("font_color",        "PopupMenu", C_PAPER)
	t.set_color("font_hover_color",  "PopupMenu", C_GOLD)

	return t

func _btn_style(bg: Color, border: Color, inset: bool) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color     = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	if inset:
		sb.set_content_margin_all(2)
		sb.shadow_size = 0
	return sb

func _panel_style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color     = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0)
	return sb

func _flat(bg: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)
	return sb
