extends Node2D

## RestScene.gd - 休息节点场景
## 提供两种选择：回复HP / 升级一张牌
## 背景氛围：烛火、古庙

class_name RestSceneController

@onready var heal_btn: Button = $UI/Options/HealBtn
@onready var upgrade_btn: Button = $UI/Options/UpgradeBtn
@onready var leave_btn: Button = $UI/LeaveBtn
@onready var status_label: Label = $UI/StatusLabel
@onready var deck_container: GridContainer = $UI/DeckPanel/DeckGrid
@onready var deck_panel: Panel = $UI/DeckPanel

const HEAL_AMOUNT_PERCENT = 0.30  # 回复最大HP的30%

var _upgrade_mode: bool = false

func _ready() -> void:
	deck_panel.visible = false
	heal_btn.pressed.connect(_on_heal)
	upgrade_btn.pressed.connect(_on_upgrade_mode)
	leave_btn.pressed.connect(_on_leave)
	_update_status()

func _on_heal() -> void:
	var amount = int(GameState.max_hp * HEAL_AMOUNT_PERCENT)
	GameState.heal(amount)
	heal_btn.disabled = true
	status_label.text = "休息后回复了 %d HP。" % amount
	_update_status()

func _on_upgrade_mode() -> void:
	_upgrade_mode = true
	deck_panel.visible = true
	upgrade_btn.disabled = true
	status_label.text = "选择一张牌进行升级（费用-1）"

	for child in deck_container.get_children():
		child.queue_free()

	var card_scene = preload("res://scenes/CardUI.tscn")
	for card in DeckManager.get_full_deck():
		var card_ui = card_scene.instantiate()
		card_ui.setup(card)
		card_ui.set_playable(true)
		card_ui.card_clicked.connect(func(c): _on_card_upgrade_selected(c))
		deck_container.add_child(card_ui)

func _on_card_upgrade_selected(card: Dictionary) -> void:
	card["cost"] = max(0, card.get("cost", 1) - 1)
	deck_panel.visible = false
	status_label.text = "「%s」已升级，费用降为 %d。" % [card.get("name", "???"), card.get("cost", 0)]

func _on_leave() -> void:
	get_tree().change_scene_to_file("res://scenes/MapScene.tscn")

func _update_status() -> void:
	var hp_label = get_node_or_null("UI/HPStatus")
	if hp_label:
		hp_label.text = "HP: %d / %d" % [GameState.hp, GameState.max_hp]
