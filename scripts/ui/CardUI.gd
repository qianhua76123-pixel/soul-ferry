extends Control

## CardUI.gd - 单张牌卡的 UI 组件
## 显示牌名、费用、效果描述、情绪标签颜色


signal card_clicked(card_data: Dictionary)

@export var card_name_label: Label
@export var card_cost_label: Label
@export var card_desc_label: Label
@export var card_rarity_border: Panel
@export var emotion_color_bar: ColorRect

var card_data: Dictionary = {}
var is_playable: bool = true

## B-05 悬停动画基准 Y
var _base_y: float = 0.0

## 初始化牌卡显示
func setup(data: Dictionary) -> void:
	card_data = data
	
	if card_name_label:
		card_name_label.text = data.get("name", "未知牌")
	
	if card_cost_label:
		# 计算实际费用（考虑定系减免）
		var cost: int = data.get("cost", 0) - EmotionManager.get_cost_reduction()
		card_cost_label.text = str(maxi(0, cost))
	
	if card_desc_label:
		# 优先用 CardDatabase 动态生成的 desc（含 BBCode 升级高亮），回退到静态 description
		var desc_text: String = data.get("desc", data.get("description", ""))
		card_desc_label.text = desc_text
	
	# 情绪颜色条
	if emotion_color_bar:
		var emotion: String = data.get("emotion_tag", "calm")
		emotion_color_bar.color = EmotionManager.get_emotion_color(emotion)
	
	# 稀有度边框颜色
	if card_rarity_border:
		match data.get("rarity", "common"):
			"rare":
				card_rarity_border.modulate = UIConstants.color_of("gold")
			"legendary":
				card_rarity_border.modulate = UIConstants.color_of("nu")
			_:
				card_rarity_border.modulate = UIConstants.color_of("gold_dim")

## 设置是否可出牌状态
func set_playable(playable: bool) -> void:
	is_playable = playable
	if playable:
		modulate = Color.WHITE
	else:
		var a := UIConstants.color_of("ash")
		modulate = Color(a.r, a.g, a.b, 0.58)

func _ready() -> void:
	_base_y = position.y
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## 点击事件
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_playable:
				# 出牌消失动画
				var tw: Tween = create_tween()
				tw.tween_property(self, "scale", Vector2(0.0, 0.0), 0.15)\
					.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
				tw.tween_callback(func(): card_clicked.emit(card_data))

## B-05 鼠标悬停：上移 + 轻微放大 + 显示预览
func _on_mouse_entered() -> void:
	if not is_playable: return
	# 上移 + 轻微放大
	var tw: Tween = create_tween()
	tw.tween_property(self, "position:y", position.y - 10, 0.12)
	tw.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.12)
	# 触发 BattleScene 显示预览
	var battle: Node = get_tree().root.find_child("BattleScene", true, false)
	if battle and battle.has_method("show_card_preview"):
		battle.show_card_preview(card_data, get_global_rect().get_center())

## B-05 鼠标离开：恢复位置 + 隐藏预览
func _on_mouse_exited() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "position:y", _base_y, 0.10)
	tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.10)
	var battle: Node = get_tree().root.find_child("BattleScene", true, false)
	if battle and battle.has_method("hide_card_preview"):
		battle.hide_card_preview()
