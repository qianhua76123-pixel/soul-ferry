extends Node
## ForgeSystem.gd - 锻造系统（金币/碎片双轨，三层结构）
## Autoload 单例，注册名 "ForgeSystem"
## 注意：不声明 class_name，避免与 Autoload 全局名冲突

signal forge_completed(original: Dictionary, forged: Dictionary)
signal recipe_unlocked(recipe_id: String)

# ── 已解锁图纸（保留字段，后续扩展用）────────────────
var unlocked_recipes: Array[String] = []

func _ready() -> void:
	# 监听成就/遗物，自动检查图纸解锁（保留，供后续扩展）
	AchievementManager.achievement_unlocked.connect(_on_achievement)
	GameState.relic_added.connect(func(_id: String): check_and_unlock_recipes())

# ── 公共 API ───────────────────────────────────────────

## 返回该牌所有可用锻造方案（仅金币基础锻造；碎片进阶锻造已删除）
func get_available_forges(card: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var gold: int = GameState.gold

	# ── 基础锻造（金币，无需碎片）────────────────────
	result.append({
		"type":         "basic_power",
		"label":        "⚒ 强化  —  数值×1.25",
		"cost_display": "💰 80 金",
		"eligible":     gold >= 80 and not card.get("forged", false),
		"locked":       false,
		"cost_gold":    80,
	})
	result.append({
		"type":         "basic_cost",
		"label":        "✦ 减费  —  费用-1",
		"cost_display": "💰 120 金",
		"eligible":     gold >= 120 and int(card.get("cost", 0)) > 0 and not card.get("forged", false),
		"locked":       false,
		"cost_gold":    120,
	})
	result.append({
		"type":         "basic_extend",
		"label":        "＋ 扩展  —  追加升级效果",
		"cost_display": "💰 100 金",
		"eligible":     gold >= 100 and not card.get("forged", false),
		"locked":       false,
		"cost_gold":    100,
	})

	# ── 进阶锻造（碎片）已删除 ────────────────────────
	# adv_emotion / adv_void / adv_resonance 均已移除

	# ── 图纸锻造（暂时注释，后续扩展）──────────────
	# TODO: 解锁后在此追加 recipe-based forges

	return result

## 执行锻造：支持基础（金币）和进阶（碎片）两轨
func execute_forge(card: Dictionary, forge_type: String, _params: Dictionary = {}) -> Dictionary:
	var result: Dictionary = card.duplicate(true)
	result["forged"] = true

	match forge_type:
		"basic_power":
			# 强化：数值×1.25，消耗 80 金
			if not GameState.spend_gold(80):
				return card
			var ev: int = int(result.get("effect_value", 0))
			if ev > 0:
				result["effect_value"] = int(ev * 1.25)
			result["description"] = str(result.get("description", "")) + "\n[锻造] 数值强化×1.25"

		"basic_cost":
			# 减费：费用-1（最低0），消耗 120 金
			if not GameState.spend_gold(120):
				return card
			var c: int = int(result.get("cost", 1))
			result["cost"] = maxi(0, c - 1)
			result["description"] = str(result.get("description", "")) + "\n[锻造] 费用-1"

		"basic_extend":
			# 扩展：追加升级效果文字，消耗 100 金
			if not GameState.spend_gold(100):
				return card
			var extra: String = str(result.get("upgrade_extra_effect", "强化完成"))
			result["description"] = str(result.get("description", "")) + "\n[锻造] " + extra

		# ── 进阶锻造（碎片）已删除 ────────────────────
		# "adv_emotion": ...   # 已删除
		# "adv_void": ...      # 已删除
		# "adv_resonance": ... # 已删除

		_:
			# 未知锻造类型，直接返回原卡不修改
			push_warning("ForgeSystem: 未知锻造类型 %s" % forge_type)
			return card

	# 同步到 DeckManager（用 replace_card 更新牌堆中的卡牌数据）
	DeckManager.replace_card(str(card.get("id", "")), result)
	forge_completed.emit(card, result)
	return result

func check_and_unlock_recipes() -> void:
	## 检查并解锁图纸（供后续扩展）
	var stats: Dictionary = AchievementManager.stats
	if int(stats.get("total_du_hua", 0)) >= 3 and "duhua_forge" not in unlocked_recipes:
		_unlock("duhua_forge")
	if int(stats.get("total_rage_burst", 0)) >= 5 and "rage_forge" not in unlocked_recipes:
		_unlock("rage_forge")
	if int(stats.get("total_kongming", 0)) >= 2 and "kongming_forge" not in unlocked_recipes:
		_unlock("kongming_forge")
	for rid: String in ["guan_chen_jing", "tian_wang_ling"]:
		if GameState.has_relic(rid) and "legend_forge" not in unlocked_recipes:
			_unlock("legend_forge")
			break

# ── 内部工具 ───────────────────────────────────────────

func _unlock(recipe_id: String) -> void:
	if recipe_id not in unlocked_recipes:
		unlocked_recipes.append(recipe_id)
		recipe_unlocked.emit(recipe_id)

func _on_achievement(_achievement_id: String) -> void:
	check_and_unlock_recipes()
