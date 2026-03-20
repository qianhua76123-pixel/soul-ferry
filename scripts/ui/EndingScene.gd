extends Node2D

## EndingScene.gd - 结局场景
## 三种结局：渡魂成功 / 魂魄消散 / 迷失轮回
## 通过 GameState.get_meta("ending_type") 判断结局类型
##
## ending_type 取值：
##   "success"  — 完成所有层的 Boss 渡化（或击败）
##   "defeat"   — HP 归零死亡
##   "lost"     — 特殊事件/路线选择触发的"迷失"结局（隐藏）

# ══════════════════════════════════════════════════════
#  节点（运行时创建，不依赖 .tscn 布局）
# ══════════════════════════════════════════════════════
var _bg_canvas:     CanvasLayer = null
var _text_label:    RichTextLabel = null
var _stat_panel:    VBoxContainer = null
var _btn_restart:   Button = null
var _btn_menu:      Button = null
var _particles:     Node2D = null   # 程序化粒子（朱砂点 / 飞灰 / 莹光）

# ══════════════════════════════════════════════════════
#  结局数据
# ══════════════════════════════════════════════════════
const ENDINGS: Dictionary = {
	"success": {
		"title":    "渡魂成功",
		"subtitle": "The Soul Has Crossed Over",
		"color":    Color(0.92, 0.80, 0.30),   # 金
		"bg_color": Color(0.04, 0.04, 0.08),
		"particle": "lantern",   # 灯笼飞升粒子
		"lines": [
			"那最后一个亡魂，",
			"终于说出了他埋在心底三十年的那句话。",
			"",
			"你没有替他做什么。",
			"只是陪他——说完了。",
			"",
			"渡魂人，渡的从不是鬼。",
			"渡的，是那一口没能咽下去的气。",
		],
		"stat_title": "此次渡魂·记录"
	},
	"defeat": {
		"title":    "魂魄消散",
		"subtitle": "The Ferryman Has Fallen",
		"color":    Color(0.70, 0.15, 0.15),   # 暗红
		"bg_color": Color(0.06, 0.02, 0.02),
		"particle": "ash",   # 飞灰粒子
		"lines": [
			"你也困在这里了。",
			"",
			"也许，是某个亡魂的怨气太重。",
			"也许，是你自己的执念——",
			"让你走不出去。",
			"",
			"渡魂人，渡人先渡己。",
			"下次，先把自己的事情理清楚。",
		],
		"stat_title": "此行终止于"
	},
	"lost": {
		"title":    "迷失轮回",
		"subtitle": "Lost Between the Living and the Dead",
		"color":    Color(0.40, 0.55, 0.80),   # 幽蓝
		"bg_color": Color(0.02, 0.03, 0.08),
		"particle": "wisp",   # 游魂萤光粒子
		"lines": [
			"有些门，打开之后就关不上了。",
			"",
			"你走进去的时候，",
			"以为自己还是渡魂人。",
			"",
			"走出来的时候，",
			"已经分不清哪边才是——生。",
			"",
			"[color=#8899cc]隐藏结局·迷失[/color]",
		],
		"stat_title": "迷途记录"
	},
}

# ══════════════════════════════════════════════════════
#  _ready
# ══════════════════════════════════════════════════════
func _ready() -> void:
	var ending_type = GameState.get_meta("ending_type", "defeat")
	if not ENDINGS.has(ending_type):
		ending_type = "defeat"
	var data = ENDINGS[ending_type]

	# 背景 BGM
	SoundManager.play_bgm("ending_good" if ending_type == "success" else "ending_bad", 1.0)

	_build_scene(data, ending_type)
	_play_intro(data)

# ══════════════════════════════════════════════════════
#  构建场景节点
# ══════════════════════════════════════════════════════
func _build_scene(data: Dictionary, ending_type: String) -> void:
	# ── 背景 Canvas ──
	_bg_canvas = CanvasLayer.new()
	_bg_canvas.name = "BgCanvas"
	add_child(_bg_canvas)
	var bg = ColorRect.new()
	bg.color = data["bg_color"]
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(1152, 648)
	_bg_canvas.add_child(bg)

	# ── 程序化背景装饰 ──
	_draw_bg_art(_bg_canvas, data, ending_type)

	# ── 标题 ──
	var title_lbl = _make_label(data["title"], 48, data["color"])
	title_lbl.name = "TitleLabel"
	title_lbl.position = Vector2(576, 80)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_bg_canvas.add_child(title_lbl)

	var sub_lbl = _make_label(data["subtitle"], 16, Color(data["color"].r, data["color"].g, data["color"].b, 0.65))
	sub_lbl.name = "SubLabel"
	sub_lbl.position = Vector2(576, 136)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_bg_canvas.add_child(sub_lbl)

	# ── 分割线 ──
	var sep = _make_separator(data["color"])
	sep.position = Vector2(288, 158)
	_bg_canvas.add_child(sep)

	# ── 正文（RichTextLabel，支持 BBCode，逐字显示） ──
	_text_label = RichTextLabel.new()
	_text_label.name               = "StoryText"
	_text_label.bbcode_enabled     = true
	_text_label.visible_characters = 0
	_text_label.custom_minimum_size = Vector2(576, 200)
	_text_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_text_label.position            = Vector2(576 - 288, 180)
	_text_label.add_theme_font_size_override("normal_font_size", 17)
	_text_label.add_theme_color_override("default_color", Color(0.88, 0.84, 0.76))
	var full_text = "\n".join(data["lines"])
	_text_label.text = full_text
	_bg_canvas.add_child(_text_label)

	# ── 统计面板 ──
	_stat_panel = _build_stat_panel(data["stat_title"], data["color"], ending_type)
	_stat_panel.position = Vector2(576 + 40, 200)
	_bg_canvas.add_child(_stat_panel)

	# ── 按钮区 ──
	var btn_row = HBoxContainer.new()
	btn_row.name = "BtnRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	btn_row.position = Vector2(576 - 140, 560)
	_bg_canvas.add_child(btn_row)

	_btn_restart = _make_button("再渡一次", data["color"])
	_btn_restart.pressed.connect(_on_restart)
	btn_row.add_child(_btn_restart)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	btn_row.add_child(spacer)

	_btn_menu = _make_button("返回主菜单", Color(0.65, 0.60, 0.55))
	_btn_menu.pressed.connect(_on_menu)
	btn_row.add_child(_btn_menu)

# ══════════════════════════════════════════════════════
#  程序化背景美术
# ══════════════════════════════════════════════════════
func _draw_bg_art(parent: CanvasLayer, data: Dictionary, ending_type: String) -> void:
	# 用 Node2D + _draw 绘制背景装饰
	var art = _BgArt.new()
	art.ending_type = ending_type
	art.accent_color = data["color"]
	parent.add_child(art)

# ══════════════════════════════════════════════════════
#  统计面板
# ══════════════════════════════════════════════════════
func _build_stat_panel(title: String, color: Color, ending_type: String) -> VBoxContainer:
	var panel = VBoxContainer.new()
	panel.name = "StatPanel"
	panel.custom_minimum_size = Vector2(260, 0)

	var title_lbl = _make_label(title, 14, Color(color.r, color.g, color.b, 0.8))
	panel.add_child(title_lbl)

	var sep = HSeparator.new()
	panel.add_child(sep)

	# 从 GameState 读取本局统计
	var stats = _collect_stats(ending_type)
	for stat in stats:
		var row = HBoxContainer.new()
		var key_lbl = _make_label(stat["key"], 13, Color(0.75, 0.70, 0.65))
		key_lbl.custom_minimum_size = Vector2(140, 0)
		row.add_child(key_lbl)
		var val_lbl = _make_label(str(stat["value"]), 13, Color(0.95, 0.90, 0.75))
		row.add_child(val_lbl)
		panel.add_child(row)

	return panel

func _collect_stats(ending_type: String) -> Array:
	var stats = []
	stats.append({"key": "渡化亡魂", "value": "%d 个" % GameState.get_meta("du_hua_count", 0)})
	stats.append({"key": "镇压亡魂", "value": "%d 个" % GameState.get_meta("zhenya_count", 0)})
	stats.append({"key": "到达楼层", "value": "第 %d 层" % GameState.current_layer})
	stats.append({"key": "剩余HP",   "value": "%d / %d" % [GameState.hp, GameState.max_hp]})
	stats.append({"key": "持有遗物", "value": "%d 件" % len(GameState.relics)})
	stats.append({"key": "牌库规模", "value": "%d 张" % (len(DeckManager.deck) + len(DeckManager.hand) + len(DeckManager.discard_pile))})
	var ach_count = AchievementManager.get_achievement_count()
	var ach_total = AchievementManager.ACHIEVEMENTS.size()
	stats.append({"key": "成就进度", "value": "%d / %d" % [ach_count, ach_total]})
	var gs = AchievementManager.get_stats()
	stats.append({"key": "累计游玩", "value": "%d 局" % gs.get("total_runs", 0)})
	stats.append({"key": "累计渡化", "value": "%d 次" % gs.get("total_du_hua", 0)})
	if ending_type == "success":
		stats.append({"key": "通关类型", "value": "✓ 渡魂成功"})
	elif ending_type == "lost":
		stats.append({"key": "隐藏结局", "value": "迷失轮回 🌀"})
	return stats

# ══════════════════════════════════════════════════════
#  入场动画序列
# ══════════════════════════════════════════════════════
func _play_intro(data: Dictionary) -> void:
	# 1. 黑屏渐显
	var overlay = ColorRect.new()
	overlay.name  = "FadeOverlay"
	overlay.color = Color.BLACK
	overlay.size  = Vector2(1152, 648)
	_bg_canvas.add_child(overlay)
	var tw = overlay.create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_OUT)
	tw.tween_callback(overlay.queue_free)

	# 2. 标题节点初始不可见，延迟淡入
	var title_lbl = _bg_canvas.get_node_or_null("TitleLabel")
	if title_lbl:
		title_lbl.modulate = Color(1, 1, 1, 0)
		var ttw = title_lbl.create_tween()
		ttw.tween_interval(0.8)
		ttw.tween_property(title_lbl, "modulate", Color.WHITE, 0.8)

	# 3. 正文逐字打出（0.8s 后开始，每字 0.06s）
	if _text_label:
		_text_label.visible_characters = 0
		var total_chars = len(_text_label.text)
		var tw2 = _text_label.create_tween()
		tw2.tween_interval(1.2)
		tw2.tween_property(_text_label, "visible_characters", total_chars, total_chars * 0.06)
		tw2.tween_callback(func(): _reveal_stats_and_buttons())

# ══════════════════════════════════════════════════════
#  文字打完后显示统计和按钮
# ══════════════════════════════════════════════════════
func _reveal_stats_and_buttons() -> void:
	if _stat_panel:
		_stat_panel.modulate = Color(1, 1, 1, 0)
		var tw = _stat_panel.create_tween()
		tw.tween_property(_stat_panel, "modulate", Color.WHITE, 0.6)

	var btn_row = _bg_canvas.get_node_or_null("BtnRow")
	if btn_row:
		btn_row.modulate = Color(1, 1, 1, 0)
		var tw2 = btn_row.create_tween()
		tw2.tween_interval(0.3)
		tw2.tween_property(btn_row, "modulate", Color.WHITE, 0.5)

# ══════════════════════════════════════════════════════
#  按钮事件
# ══════════════════════════════════════════════════════
func _on_restart() -> void:
	SoundManager.play_sfx("menu_confirm")
	GameState.new_run()
	DeckManager.init_starter_deck()
	TransitionManager.change_scene("res://scenes/MapScene.tscn")

func _on_menu() -> void:
	SoundManager.play_sfx("menu_cancel")
	GameState.new_run()
	DeckManager.init_starter_deck()
	TransitionManager.change_scene("res://scenes/MainMenu.tscn")

# ══════════════════════════════════════════════════════
#  工具函数
# ══════════════════════════════════════════════════════
func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_separator(color: Color) -> ColorRect:
	var sep = ColorRect.new()
	sep.color             = Color(color.r, color.g, color.b, 0.4)
	sep.custom_minimum_size = Vector2(576, 1)
	return sep

func _make_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 44)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", color)
	return btn

# ══════════════════════════════════════════════════════
#  内部类：程序化背景美术节点
## 根据 ending_type 绘制不同装饰
# ══════════════════════════════════════════════════════
class _BgArt extends Node2D:
	var ending_type:  String = "defeat"
	var accent_color: Color  = Color.WHITE
	var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.seed = 98765
		queue_redraw()

	func _draw() -> void:
		match ending_type:
			"success": _draw_success()
			"defeat":  _draw_defeat()
			"lost":    _draw_lost()

	## 渡魂成功：大红灯笼 + 金色符文 + 白色粒子点
	func _draw_success() -> void:
		# 毛笔书法背景大字（半透明"渡"字形）
		draw_string(ThemeDB.fallback_font,
			Vector2(80, 500), "渡",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 320,
			Color(0.85, 0.15, 0.15, 0.06))

		# 灯笼（左右各一）
		_draw_lantern(Vector2(140, 220), 28, 48, Color(0.85, 0.10, 0.10))
		_draw_lantern(Vector2(1012, 260), 22, 38, Color(0.80, 0.08, 0.08))

		# 金色散点（祝福粒子）
		_rng.seed = 11111
		for i in 40:
			var x = _rng.randf_range(50, 1100)
			var y = _rng.randf_range(50, 600)
			var r = _rng.randf_range(1.5, 3.5)
			var a = _rng.randf_range(0.2, 0.6)
			draw_circle(Vector2(x, y), r, Color(0.95, 0.82, 0.20, a))

		# 边框装饰
		draw_rect(Rect2(20, 20, 1112, 608), Color(0.70, 0.55, 0.15, 0.3), false, 2)
		draw_rect(Rect2(28, 28, 1096, 592), Color(0.70, 0.55, 0.15, 0.15), false, 1)

	## 魂魄消散：焦土碎裂 + 血迹 + 骨灰散落
	func _draw_defeat() -> void:
		draw_string(ThemeDB.fallback_font,
			Vector2(60, 520), "散",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 320,
			Color(0.60, 0.05, 0.05, 0.07))

		# 裂缝线
		_rng.seed = 22222
		for i in 8:
			var sx = _rng.randf_range(0, 1152)
			var sy = _rng.randf_range(0, 648)
			var ex = sx + _rng.randf_range(-200, 200)
			var ey = sy + _rng.randf_range(-100, 100)
			draw_line(Vector2(sx, sy), Vector2(ex, ey),
				Color(0.45, 0.08, 0.08, 0.25), 1)

		# 血迹散点
		_rng.seed = 33333
		for i in 25:
			var x = _rng.randf_range(100, 1050)
			var y = _rng.randf_range(100, 548)
			var r = _rng.randf_range(2.0, 6.0)
			draw_circle(Vector2(x, y), r,
				Color(0.55, 0.05, 0.05, _rng.randf_range(0.1, 0.35)))

		# 暗红边框
		draw_rect(Rect2(20, 20, 1112, 608), Color(0.50, 0.05, 0.05, 0.4), false, 2)

	## 迷失轮回：环形符文 + 蓝白游魂点
	func _draw_lost() -> void:
		draw_string(ThemeDB.fallback_font,
			Vector2(50, 510), "迷",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 320,
			Color(0.20, 0.30, 0.60, 0.06))

		# 同心圆（符文感）
		var center = Vector2(576, 324)
		for r in [180, 220, 260]:
			draw_arc(center, r, 0, TAU,
				64, Color(0.30, 0.45, 0.75, 0.12), 1)

		# 游魂萤光点
		_rng.seed = 44444
		for i in 50:
			var angle = _rng.randf_range(0, TAU)
			var dist  = _rng.randf_range(60, 280)
			var x     = center.x + cos(angle) * dist
			var y     = center.y + sin(angle) * dist * 0.6
			var r     = _rng.randf_range(1.0, 3.0)
			var a     = _rng.randf_range(0.15, 0.55)
			draw_circle(Vector2(x, y), r, Color(0.55, 0.75, 1.0, a))

		# 幽蓝边框
		draw_rect(Rect2(20, 20, 1112, 608), Color(0.25, 0.40, 0.75, 0.35), false, 2)

	## 画灯笼
	func _draw_lantern(pos: Vector2, w: int, h: int, color: Color) -> void:
		# 灯笼体
		draw_rect(Rect2(pos.x - w/2, pos.y, w, h), color, true)
		# 顶盖
		draw_rect(Rect2(pos.x - w/2 - 4, pos.y - 8, w + 8, 8), Color(0.15, 0.10, 0.05), true)
		# 绳子
		draw_line(Vector2(pos.x, pos.y - 8), Vector2(pos.x, pos.y - 40), Color(0.55, 0.45, 0.30), 1)
		# 金色横纹
		for i in 3:
			var y = pos.y + (i + 1) * (h / 4)
			draw_line(Vector2(pos.x - w/2, y), Vector2(pos.x + w/2, y),
				Color(0.90, 0.75, 0.15, 0.6), 1)
		# 穗子
		draw_line(Vector2(pos.x - 4, pos.y + h), Vector2(pos.x - 4, pos.y + h + 16),
			Color(0.85, 0.70, 0.15), 1)
		draw_line(Vector2(pos.x + 4, pos.y + h), Vector2(pos.x + 4, pos.y + h + 20),
			Color(0.85, 0.70, 0.15), 1)
