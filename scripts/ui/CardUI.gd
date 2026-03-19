extends Control

## CardUI.gd - 单张牌卡的 UI 组件
## 显示牌名、费用、效果描述、情绪标签颜色

class_name CardUI

signal card_clicked(card_data: Dictionary)

@export var card_name_label: Label
@export var card_cost_label: Label
@export var card_desc_label: Label
@export var card_rarity_border: Panel
@export var emotion_color_bar: ColorRect

var card_data: Dictionary = {}
var is_playable: bool = true

## 初始化牌卡显示
func setup(data: Dictionary) -> void:
	card_data = data
	
	if card_name_label:
		card_name_label.text = data.get("name", "未知牌")
	
	if card_cost_label:
		# 计算实际费用（考虑定系减免）
		var cost = data.get("cost", 0) - EmotionManager.get_cost_reduction()
		card_cost_label.text = str(max(0, cost))
	
	if card_desc_label:
		card_desc_label.text = data.get("description", "")
	
	# 情绪颜色条
	if emotion_color_bar:
		var emotion = data.get("emotion_tag", "calm")
		emotion_color_bar.color = EmotionManager.get_emotion_color(emotion)
	
	# 稀有度边框颜色
	if card_rarity_border:
		match data.get("rarity", "common"):
			"common": card_rarity_border.modulate = Color(0.7, 0.7, 0.7)
			"rare": card_rarity_border.modulate = Color(1.0, 0.85, 0.0)
			"legendary": card_rarity_border.modulate = Color(0.9, 0.1, 0.1)

## 设置是否可出牌状态
func set_playable(playable: bool) -> void:
	is_playable = playable
	modulate = Color.WHITE if playable else Color(0.5, 0.5, 0.5, 0.8)

## 点击事件
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_playable:
				emit_signal("card_clicked", card_data)
