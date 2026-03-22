extends RefCounted
class_name UIConstants

## UIConstants.gd - 全局 UI 设计常量
## 供各场景脚本统一取色、字号、常见样式参数

const COLORS := {
	# 基础色
	"ink":      Color("#0d0d0d"),
	"parch":     Color("#1a1508"),
	"parch_dim": Color(0.68, 0.62, 0.52, 0.75),   # 羊皮纸浅色（副标题/提示文字）
	"gold":     Color("#c8a96e"),
	"gold_dim": Color("#6b5a30"),
	"ash":      Color("#9a9080"),

	# 五情色
	"nu":    Color("#c0392b"),
	"ju":    Color("#6c3483"),
	"bei":   Color("#1a5276"),
	"xi":    Color("#b7770d"),
	"ding":  Color("#1d6a54"),

	# 地图节点色
	"battle": Color("#7b1a1a"),
	"shop":   Color("#5a4a00"),
	"event":  Color("#1a3a1a"),
	"rest":   Color("#1a2a3a"),
	"boss":   Color("#3d0000"),

	# 正文与遮罩（与 parch/gold 体系协调）
	"text_primary":   Color(0.92, 0.88, 0.80),
	"text_secondary": Color(0.86, 0.82, 0.74),
	"text_muted":     Color(0.78, 0.74, 0.68),
	"text_dim":       Color(0.60, 0.56, 0.50),
	"overlay_dim":    Color(0, 0, 0, 0.55),
	"damage_flash":   Color("#c0392b"),
	"heal_flash":     Color("#1d6a54"),

	# 卡牌边框（与稀有度对应）
	"card_border_common":    Color("#6b5a30"),
	"card_border_rare":      Color("#c8a96e"),
	"card_border_legendary": Color("#c0392b"),
	# 卡面内底（略亮于 ink）
	"card_face": Color(0.08, 0.06, 0.05),
}

const EMOTION_COLORS = {
	"rage":  Color(0.753, 0.224, 0.169),
	"fear":  Color(0.424, 0.204, 0.514),
	"grief": Color(0.102, 0.322, 0.463),
	"joy":   Color(0.718, 0.467, 0.051),
	"calm":  Color(0.114, 0.416, 0.329),
}

const FONT_SIZES := {
	"title":   32,
	"heading": 18,
	"body":    13,
	"caption": 11,
	"micro":   10,
}

const PANEL := {
	"corner_cut": 6.0,
	"border_width": 1.0,
	"top_line_width": 2.0,
	"fill_alpha": 0.88,
	"border_alpha": 0.40,
}

const ICONS := {
	"coin": "◎",
	"shield": "🛡",
	"hp": "♥",
	"energy": "▮",
	"spark": "✦",
}

static func color_of(key: String, fallback: Color = Color.WHITE) -> Color:
	return COLORS.get(key, fallback)

static func font_size_of(key: String, fallback: int = 12) -> int:
	return int(FONT_SIZES.get(key, fallback))

static func make_button_style(fill_key: String = "parch", border_key: String = "gold_dim") -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var fill: Color = color_of(fill_key)
	var border: Color = color_of(border_key)
	style.bg_color = Color(fill.r, fill.g, fill.b, 0.88)
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

static func make_panel_style() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	var p: Color = color_of("parch")
	s.bg_color = Color(p.r, p.g, p.b, 0.92)
	s.border_color = color_of("gold_dim")
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	return s
