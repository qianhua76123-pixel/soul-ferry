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

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "踏上渡魂之路"
	confirm_btn.custom_minimum_size = Vector2(220, 52)
	confirm_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	confirm_btn.offset_top    = -100
	confirm_btn.offset_bottom = -48
	confirm_btn.offset_left   = -110
	confirm_btn.offset_right  = 110
	var btn_style: StyleBox = UIC.make_button_style("ink", "gold")
	confirm_btn.add_theme_stylebox_override("normal", btn_style)
	confirm_btn.add_theme_color_override("font_color", UIC.color_of("gold"))
	confirm_btn.add_theme_font_size_override("font_size", UIC.font_size_of("body"))
	confirm_btn.pressed.connect(_on_confirm_pressed)
	add_child(confirm_btn)

	_select(0)

func _build_character_card(index: int) -> Control:
	var char_data: Dictionary = _characters[index]
	var char_id: String = char_data.get("id", "ruan_ruyue")

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 440)

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

	# ── HP / 能量 ──
	var stats_lbl: Label = Label.new()
	var hp_val: int = char_data.get("hp", 80)
	var energy_val: int = char_data.get("energy", 3)
	stats_lbl.text = "HP %d  ·  能量 %d" % [hp_val, energy_val]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", UIC.font_size_of("small"))
	stats_lbl.add_theme_color_override("font_color", UIC.color_of("parch"))

	# ── 被动简述 ──
	var passive_lbl: Label = Label.new()
	passive_lbl.text = char_data.get("passive_desc", "")
	passive_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_lbl.add_theme_font_size_override("font_size", UIC.font_size_of("small"))
	passive_lbl.add_theme_color_override("font_color", UIC.color_of("gold_dim"))

	# ── 简介 ──
	var desc_lbl: RichTextLabel = RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	desc_lbl.text = char_data.get("description", "")
	desc_lbl.custom_minimum_size = Vector2(260, 56)
	desc_lbl.fit_content = true
	desc_lbl.add_theme_font_size_override("normal_font_size", UIC.font_size_of("small"))
	desc_lbl.add_theme_color_override("default_color", UIC.color_of("parch_dim"))

	vbox.add_child(name_lbl)
	vbox.add_child(portrait_center)
	vbox.add_child(stats_lbl)
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
