extends Control

## CardPreview.gd - 鼠标悬停卡牌放大预览
## 在 BattleScene 顶层 UI 的 CanvasLayer 上显示
## 由 CardUI 节点通过 BattleScene.show_card_preview(card) 触发

var _card_data: Dictionary = {}
var _panel:     PanelContainer
var _title_lbl: Label
var _desc_lbl:  Label
var _cost_lbl:  Label
var _rarity_lbl:Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_build()
	visible = false

func _build() -> void:
	custom_minimum_size = Vector2(160, 230)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(160, 230)
	add_child(_panel)

	var style: StyleBoxFlat = UIConstants.make_panel_style()
	style.border_color = UIConstants.color_of("gold")
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# 费用圆角标
	_cost_lbl = Label.new()
	_cost_lbl.add_theme_font_size_override("font_size", 16)
	_cost_lbl.add_theme_color_override("font_color", UIConstants.color_of("gold"))
	_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_lbl.custom_minimum_size = Vector2(160, 26)
	vbox.add_child(_cost_lbl)

	# 牌图占位（颜色块）
	var art = ColorRect.new()
	art.custom_minimum_size = Vector2(156, 80)
	art.color = UIConstants.color_of("card_face")
	vbox.add_child(art)

	# 牌名
	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 13)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	vbox.add_child(_title_lbl)

	var sep: WaterInkDivider = WaterInkDivider.new()
	sep.custom_minimum_size = Vector2(150, 6)
	sep.ink_color = UIConstants.color_of("gold_dim")
	vbox.add_child(sep)

	# 描述
	_desc_lbl = Label.new()
	_desc_lbl.add_theme_font_size_override("font_size", 11)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.custom_minimum_size = Vector2(150, 60)
	_desc_lbl.add_theme_color_override("font_color", UIConstants.color_of("text_muted"))
	vbox.add_child(_desc_lbl)

	# 稀有度
	_rarity_lbl = Label.new()
	_rarity_lbl.add_theme_font_size_override("font_size", 11)
	_rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_rarity_lbl)

func show_preview(card: Dictionary, anchor_pos: Vector2) -> void:
	_card_data = card
	_title_lbl.text   = card.get("name", "???")
	_cost_lbl.text    = "%s %d" % [UIConstants.ICONS["energy"], int(card.get("cost", 1))]
	_desc_lbl.text    = card.get("description", card.get("desc", ""))
	var rarity: String = card.get("rarity", "common")
	_rarity_lbl.text  = {"common":"普通","rare":"★ 稀有","legendary":"★★ 传说"}.get(rarity, "普通")
	_rarity_lbl.add_theme_color_override("font_color",
		{
			"common": UIConstants.color_of("gold_dim"),
			"rare": UIConstants.color_of("gold"),
			"legendary": UIConstants.color_of("nu"),
		}.get(rarity, UIConstants.color_of("ash")))

	# 定位：显示在悬停牌的上方，避免超出屏幕
	var px: int = clampf(anchor_pos.x - 80, 4, 1050)
	var py: int = maxf(anchor_pos.y - 240, 4)
	position = Vector2(px, py)
	visible  = true
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)

func hide_preview() -> void:
	visible = false
