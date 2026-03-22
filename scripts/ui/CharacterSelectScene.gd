extends Control
## 角色选择界面
## 职责：展示三个可玩角色（含像素立绘），玩家选择后保存到 GameState，跳转 MapScene

const UIC = preload("res://scripts/ui/UIConstants.gd")

var _characters: Array = []
var _selected_index: int = 0
var _card_panels: Array = []

func _ready() -> void:
	TransitionManager.fade_in_only()
	_load_characters()
	_build_ui()

func _load_characters() -> void:
	var file: FileAccess = FileAccess.open("res://data/characters.json", FileAccess.READ)
	if not file:
		_characters = [
			{"id":"ruan_ruyue","name":"阮如月","description":"游走于庙宇与渡口间的年轻庙祝，以五情印记渡化困于世间的魂魄。","hp":80,"energy":3,"passive_desc":"施印亲和 · 渡化偏向"},
			{"id":"shen_tiejun","name":"沈铁钧","description":"已退休的老捕快，用铁链与怒气镇压不肯离去的亡魂。","hp":100,"energy":3,"passive_desc":"锁链怒爆 · 镇压偏向"},
			{"id":"wumian","name":"无名","description":"把自己情绪全部给出去的守护者，脸的位置是平的。","hp":60,"energy":4,"passive_desc":"空度系统 · 情绪转移"},
		]
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data: Variant = json.get_data()
	if data is Dictionary:
		_characters = data.get("characters", [])

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title: Label = Label.new()
	title.text = "选择渡魂人"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIC.font_size_of("title"))
	title.add_theme_color_override("font_color", UIC.color_of("gold"))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40
	title.offset_bottom = 90
	add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "每位渡魂人有独特的战斗风格与胜利路线"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", UIC.font_size_of("body"))
	subtitle.add_theme_color_override("font_color", UIC.color_of("parch_dim"))
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 92
	subtitle.offset_bottom = 120
	add_child(subtitle)

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.offset_left   = -540
	row.offset_right  = 540
	row.offset_top    = -200
	row.offset_bottom = 240
	add_child(row)

	for i in _characters.size():
		var panel: Control = _build_character_card(i)
		row.add_child(panel)
		_card_panels.append(panel)

	# ── 底部按钮行（单人 + 双人）─────────────────────
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	btn_row.offset_top    = -108
	btn_row.offset_bottom = -44
	btn_row.offset_left   = -240
	btn_row.offset_right  = 240
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	add_child(btn_row)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "▶ 单人启程"
	confirm_btn.custom_minimum_size = Vector2(200, 50)
	var btn_style: StyleBox = UIC.make_button_style("ink", "gold")
	confirm_btn.add_theme_stylebox_override("normal", btn_style)
	confirm_btn.add_theme_stylebox_override("hover",  UIC.make_button_style("ink", "gold"))
	confirm_btn.add_theme_color_override("font_color", UIC.color_of("gold"))
	confirm_btn.add_theme_font_size_override("font_size", UIC.font_size_of("body"))
	confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(confirm_btn)

	var coop_btn: Button = Button.new()
	coop_btn.text = "👥 双人渡魂"
	coop_btn.custom_minimum_size = Vector2(200, 50)
	coop_btn.add_theme_stylebox_override("normal", UIC.make_button_style("ink", "gold_dim"))
	coop_btn.add_theme_stylebox_override("hover",  UIC.make_button_style("ink", "gold"))
	coop_btn.add_theme_color_override("font_color", UIC.color_of("text_primary"))
	coop_btn.add_theme_font_size_override("font_size", UIC.font_size_of("body"))
	coop_btn.pressed.connect(_on_coop_pressed)
	btn_row.add_child(coop_btn)

	_select(0)

func _build_character_card(index: int) -> Control:
	var char_data: Dictionary = _characters[index]
	var char_id: String = char_data.get("id", "ruan_ruyue")

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 500)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.92)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = UIC.color_of("gold_dim")
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# ── 角色名 ──
	var name_lbl: Label = Label.new()
	name_lbl.text = char_data.get("name", "???")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", UIC.font_size_of("heading"))
	name_lbl.add_theme_color_override("font_color", UIC.color_of("gold"))

	# ── 像素立绘（128×192，居中）──
	var portrait_center: CenterContainer = CenterContainer.new()
	portrait_center.custom_minimum_size = Vector2(0, 200)
	var portrait: TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(128, 192)
	portrait.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 生成对应角色立绘
	portrait.texture = CharacterPortrait.create(char_id)
	portrait_center.add_child(portrait)

	# ── 核心数值区 ──
	var hp_val: int       = char_data.get("hp", 80)
	var energy_val: int   = char_data.get("energy", 3)
	var draw_val: int     = char_data.get("draw_per_turn", 5)
	var hand_val: int     = char_data.get("hand_limit", 8)
	var affinity: Array   = char_data.get("affinity", [])
	var bias: String      = char_data.get("victory_bias", "")
	var passive_key: String = char_data.get("passive", "")

	# 情绪亲和映射
	var emo_map: Dictionary = {"grief":"悲","fear":"惧","rage":"怒","joy":"喜","calm":"定"}
	var affinity_str: String = "·".join(affinity.map(func(e: String) -> String: return emo_map.get(e, e)))
	if affinity_str.is_empty(): affinity_str = "五情均衡"

	# 胜利路线映射
	var bias_map: Dictionary = {"purification":"渡化路线","suppression":"镇压路线","balanced":"均衡路线"}
	var bias_str: String = bias_map.get(bias, bias)

	# 被动名映射
	var passive_map: Dictionary = {
		"seal_affinity":     "施印亲和 — 对亲和情绪加成+20%",
		"veteran_instinct":  "老手直觉 — 愤怒叠加时爆发伤害",
		"wumian_faceless":   "空度系统 — 情绪清零转化为空鸣",
	}
	var passive_str: String = passive_map.get(passive_key, char_data.get("passive_desc",""))

	# 数值标签（两列对齐）
	var stats_rich: RichTextLabel = RichTextLabel.new()
	stats_rich.bbcode_enabled = true
	stats_rich.fit_content = true
	stats_rich.custom_minimum_size = Vector2(260, 0)
	stats_rich.add_theme_font_size_override("normal_font_size", 12)
	var gold_hex: String = UIC.color_of("gold").to_html(false)
	# parch (#1a1508) 是极暗背景色，不适合做文字。改用 text_primary 保证可读性
	var parch_hex: String = UIC.color_of("text_primary").to_html(false)
	var dim_hex: String = UIC.color_of("text_secondary").to_html(false)
	stats_rich.text = (
		"[color=#%s]❤ 生命[/color]  [color=#%s]%d[/color]   " % [dim_hex, parch_hex, hp_val] +
		"[color=#%s]⚡ 能量[/color]  [color=#%s]%d[/color]\n" % [dim_hex, parch_hex, energy_val] +
		"[color=#%s]🃏 摸牌[/color]  [color=#%s]%d/回合[/color]   " % [dim_hex, parch_hex, draw_val] +
		"[color=#%s]✋ 手牌上限[/color]  [color=#%s]%d[/color]\n" % [dim_hex, parch_hex, hand_val] +
		"[color=#%s]🎭 情绪亲和[/color]  [color=#%s]%s[/color]\n" % [dim_hex, gold_hex, affinity_str] +
		"[color=#%s]⚔ 胜利路线[/color]  [color=#%s]%s[/color]" % [dim_hex, gold_hex, bias_str]
	)

	# 被动技能
	var passive_lbl: RichTextLabel = RichTextLabel.new()
	passive_lbl.bbcode_enabled = true
	passive_lbl.fit_content = true
	passive_lbl.custom_minimum_size = Vector2(260, 0)
	passive_lbl.add_theme_font_size_override("normal_font_size", 11)
	passive_lbl.text = "[color=#%s]◆ 被动：[/color][color=#%s]%s[/color]" % [gold_hex, parch_hex, passive_str]

	# ── 简介 ──
	var desc_lbl: RichTextLabel = RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	desc_lbl.text = char_data.get("description", "")
	desc_lbl.custom_minimum_size = Vector2(260, 48)
	desc_lbl.fit_content = true
	desc_lbl.add_theme_font_size_override("normal_font_size", UIC.font_size_of("small"))
	desc_lbl.add_theme_color_override("default_color", UIC.color_of("parch_dim"))

	vbox.add_child(name_lbl)
	vbox.add_child(portrait_center)
	vbox.add_child(stats_rich)
	vbox.add_child(passive_lbl)
	vbox.add_child(desc_lbl)
	panel.add_child(vbox)

	# 点击选中
	var btn: Button = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func(): _select(index))
	panel.add_child(btn)

	return panel

func _select(index: int) -> void:
	_selected_index = index
	for i in _card_panels.size():
		var p: Control = _card_panels[i]
		var pc: PanelContainer = p as PanelContainer
		if not pc: continue
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left     = 8
		style.corner_radius_top_right    = 8
		style.corner_radius_bottom_left  = 8
		style.corner_radius_bottom_right = 8
		if i == index:
			style.bg_color = Color(0.10, 0.13, 0.18, 0.95)
			style.border_width_left   = 3
			style.border_width_right  = 3
			style.border_width_top    = 3
			style.border_width_bottom = 3
			style.border_color = UIC.color_of("gold")
		else:
			style.bg_color = Color(0.08, 0.10, 0.14, 0.92)
			style.border_width_left   = 2
			style.border_width_right  = 2
			style.border_width_top    = 2
			style.border_width_bottom = 2
			style.border_color = UIC.color_of("gold_dim")
		pc.add_theme_stylebox_override("panel", style)

func _on_confirm_pressed() -> void:
	if _characters.is_empty(): return
	var chosen: Dictionary = _characters[_selected_index]
	var char_id: String = chosen.get("id", "ruan_ruyue")

	GameState.set_meta("selected_character", char_id)

	var hp: int     = chosen.get("hp", 80)
	var energy: int = chosen.get("energy", 3)
	GameState.max_hp = hp
	GameState.hp     = hp
	DeckManager.max_cost     = energy
	DeckManager.current_cost = energy

	if char_id == "wumian":
		WumianManager.activate()
	else:
		WumianManager.deactivate()

	DeckManager.init_starter_deck()
	TransitionManager.change_scene("res://scenes/MapScene.tscn", "踏上渡魂之路")

func _on_coop_pressed() -> void:
	## 双人模式：强制选择阮如月（P1）+ 沈铁钧（P2）
	_show_coop_confirm()

func _show_coop_confirm() -> void:
	# 临时确认弹窗
	var popup: Panel = Panel.new()
	popup.z_index = 200
	popup.custom_minimum_size = Vector2(380, 220)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	popup.position = Vector2((vp.x - 380.0) * 0.5, (vp.y - 220.0) * 0.5)
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.04, 0.02, 0.98)
	ps.border_color = Color(0.78, 0.60, 0.10, 0.9)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(8)
	popup.add_theme_stylebox_override("panel", ps)
	add_child(popup)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0; vbox.offset_right = -20.0
	vbox.offset_top = 18.0; vbox.offset_bottom = -18.0
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	popup.add_child(vbox)

	var title: Label = Label.new()
	title.text = "👥  双人渡魂"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UIC.color_of("gold"))
	vbox.add_child(title)

	var desc: Label = Label.new()
	desc.text = "P1 控制  阮如月（印记·渡化）\nP2 控制  沈铁钧（锁链·镇压）\n\n双人共享HP，协同技能特化。"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UIC.color_of("text_secondary"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var ok_btn: Button = Button.new()
	ok_btn.text = "开始双人"
	ok_btn.custom_minimum_size = Vector2(130, 36)
	ok_btn.add_theme_stylebox_override("normal", UIC.make_button_style("parch", "gold"))
	ok_btn.add_theme_color_override("font_color", UIC.color_of("gold"))
	ok_btn.pressed.connect(func():
		popup.queue_free()
		_start_coop_mode()
	)
	btn_row.add_child(ok_btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.add_theme_stylebox_override("normal", UIC.make_button_style("parch", "gold_dim"))
	cancel_btn.pressed.connect(func(): popup.queue_free())
	btn_row.add_child(cancel_btn)

func _start_coop_mode() -> void:
	CoopManager.activate_coop_mode()
	GameState.set_meta("selected_character", "ruan_ruyue")
	GameState.set_meta("coop_p2_character",  "shen_tiejun")
	# 双人HP取两角色平均
	var hp_combined: int = 90  # (阮80 + 沈100) / 2 取整
	GameState.max_hp = hp_combined
	GameState.hp     = hp_combined
	DeckManager.max_cost     = 3
	DeckManager.current_cost = 3
	DeckManager.init_starter_deck()
	TransitionManager.change_scene("res://scenes/MapScene.tscn", "双魂共渡")
