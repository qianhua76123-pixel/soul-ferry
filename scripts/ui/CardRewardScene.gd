extends Node2D

## CardRewardScene.gd - 战斗胜利，选择一张牌加入牌库

signal reward_taken(card: Dictionary)

@onready var title_label    = $UI/Title
@onready var flavor_label   = $UI/Flavor
@onready var card_container = $UI/CardRow
@onready var skip_btn       = $UI/SkipBtn
@onready var gold_label     = $UI/GoldLabel

var _card_scene: PackedScene = preload("res://scenes/CardUI.tscn")
var _reward_cards: Array = []

func _ready() -> void:
	skip_btn.pressed.connect(_on_skip)
	_show_rewards()
	_update_gold()
	GameState.gold_changed.connect(func(_o,_n): _update_gold())

func _show_rewards() -> void:
	_reward_cards = CardDatabase.get_reward_cards(3)
	for child in card_container.get_children():
		child.queue_free()
	for card in _reward_cards:
		var slot = _build_slot(card)
		card_container.add_child(slot)

func _build_slot(card: Dictionary) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(110, 200)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var card_ui = _card_scene.instantiate()
	if card_ui.has_method("setup"):
		card_ui.setup(card)
	if card_ui.has_method("set_playable"):
		card_ui.set_playable(true)
	card_ui.card_clicked.connect(func(c): _on_card_chosen(c))
	vbox.add_child(card_ui)
	# 稀有度标签
	var rarity_lbl = Label.new()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.text = {"common":"普通","rare":"★ 稀有","legendary":"★★ 传说"}.get(card.get("rarity","common"),"普通")
	vbox.add_child(rarity_lbl)
	return vbox

func _on_card_chosen(card: Dictionary) -> void:
	DeckManager.add_card_to_deck(card)
	reward_taken.emit(card)
	get_tree().change_scene_to_file("res://scenes/MapScene.tscn")

func _on_skip() -> void:
	# 跳过奖励：补偿金币
	GameState.gain_gold(40)
	get_tree().change_scene_to_file("res://scenes/MapScene.tscn")

func _update_gold() -> void:
	gold_label.text = "💰 %d" % GameState.gold
